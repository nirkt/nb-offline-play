#!/bin/bash
# Headless check of battle.conf: boots the game (fast emulator, renderer hidden), waits for the lobby, taps PLAY, waits
# for the battle, saves a snapshot (PNG) and the battle-setup lines of the game log.
#   tests/battle_check.sh [battle.conf] [battle ticks to play before the snapshot; 20 per second, default 400]
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONF="${1:-$ROOT/battle.conf}"; TICKS="${2:-400}"
APK="$ROOT/apk_extract"; EMU="$ROOT/qemu/bin/qemu-aarch64-nb"; GL="$ROOT/glhost/nbgl"; HOST="$ROOT/loader/nbhost"
OUT="$ROOT/runs/battle_check_$(date +%Y%m%d_%H%M%S)"; mkdir -p "$OUT"
SHM="/dev/shm/nbgl_bc_$$"
export QEMU_NB_XPAGE=1 QEMU_NB_INLINE=1 QEMU_CPU="max,pauth-impdef=on"
mapfile -t ARGS < <(python3 "$ROOT/tools/battle_setup.py" "$CONF")

"$GL" --shm "$SHM" --size 2400x1080 --hidden --snap "$OUT/snap.ppm" > "$OUT/nbgl.log" 2>&1 & GL_PID=$!
cleanup() { kill "$G_PID" "$GL_PID" 2>/dev/null || true; wait 2>/dev/null || true; rm -f "$SHM"; }
trap cleanup EXIT
sleep 1.5
unshare -rn "$EMU" "$HOST" --libs "$APK/lib/arm64-v8a" --assets "$APK" --payloads "$ROOT/loader/payloads" \
    --stage boot --gl "$SHM" --dpi 450 --cores 2 --run-seconds 100000 --cube-rules --storm-rules ${BC_ELIM:+--elimination} "${ARGS[@]}" > "$OUT/game.log" 2>&1 & G_PID=$!

for _ in $(seq 1 300); do grep -q "home=1" "$OUT/game.log" 2>/dev/null && break; grep -q "\[crash\]" "$OUT/game.log" && break; sleep 1; done
grep -q "home=1" "$OUT/game.log" || { echo "lobby not reached; see $OUT/game.log"; exit 1; }
sleep 12
python3 "$ROOT/glhost/tap.py" "$SHM" 2134 970 > /dev/null          # the PLAY button
for _ in $(seq 1 600); do
    grep -q "\[crash\]" "$OUT/game.log" && break
    T=$(grep -o "battle-ticks=[0-9]*" "$OUT/game.log" | tail -1 | cut -d= -f2); [ "${T:-0}" -ge "$TICKS" ] && break
    sleep 1
done
echo "battle ticks reached: $(grep -o "battle-ticks=[0-9]*" "$OUT/game.log" | tail -1 | cut -d= -f2)"
convert "$OUT/snap.ppm" "$OUT/snap.png" 2>/dev/null || true
echo "snapshot: $OUT/snap.png"
grep -E "\[div\]|\[battle\] roster|\[crash\] signal|\[window\]|\[cube\]|\[storm\]|\[env\] cube|\[window\] battle|\[window\] Exit" "$OUT/game.log" | head -60
