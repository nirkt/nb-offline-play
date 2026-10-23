#!/bin/bash
# Play Null's Brawl v68.279 offline in one window on this PC.
#   ./play.sh [WIDTHxHEIGHT] [DPI]        default 2400x1080 at 450 dpi (the Galaxy S20 FE layout)
#   NB_BATTLE_CONF=other.conf ./play.sh   the battle setup file (default battle.conf: map, map skin, brawlers, skins)
#   NB_FPS=0 ./play.sh                    no on-screen FPS counter
#   NB_ELIMINATION=0 ./play.sh            no brawlers-left count and no end at one brawler (back to the main menu)
#   NB_STORM_RULES=0 ./play.sh             no Showdown storm rules (20 %%/s of max HP, +5 %%/s after 5 s)
#   NB_CUBE_RULES=0 ./play.sh             no Showdown cube rules (pickup +400 HP, +10 %% damage per cube, cube counter)
#   NB_TARGET_FPS=N ./play.sh            N > 0: game uncapped and nbgl presents at N fps (default 0 = the game's own 60 fps pacing)
# The game's ARM64 code (loader/nbhost, static) runs under the fast patched qemu-aarch64 (qemu/bin/qemu-aarch64-nb) with
# no network (unshare -rn). Its GLES calls are replayed on this PC's GPU in an X11 window by glhost/nbgl.
# Left mouse button = finger. W A S D / arrow keys = the movement joystick. Close the window to quit.
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
SIZE="${1:-2400x1080}"; DPI="${2:-450}"
APK="${NBHOST_APK:-$ROOT/apk_extract}"
EMU="${NBHOST_QEMU:-$ROOT/qemu/bin/qemu-aarch64-nb}"
GL="$ROOT/glhost/nbgl"; HOST="$ROOT/loader/nbhost"
RUNS="$ROOT/runs"; mkdir -p "$RUNS"
CONF="${NB_BATTLE_CONF:-$ROOT/battle.conf}"
[ -f "$CONF" ] || { echo "battle setup not found: $CONF" >&2; exit 1; }
BATTLE_TXT="$(python3 "$ROOT/tools/battle_setup.py" "$CONF")" || exit 1
mapfile -t BATTLE <<< "$BATTLE_TXT"
FPS_ARG=(); [ "${NB_FPS:-1}" = "0" ] && FPS_ARG=(--no-fps)
TARGET_FPS="${NB_TARGET_FPS:-0}"
PACE_ARG=(); UNCAP_ARG=()
CUBE_ARG=(); [ "${NB_CUBE_RULES:-1}" = "0" ] || CUBE_ARG=(--cube-rules)
STORM_ARG=(); [ "${NB_STORM_RULES:-1}" = "0" ] || STORM_ARG=(--storm-rules)
ELIM_ARG=(); [ "${NB_ELIMINATION:-1}" = "0" ] || ELIM_ARG=(--elimination)
if [ "$TARGET_FPS" -gt 0 ] 2>/dev/null; then PACE_ARG=(--fps "$TARGET_FPS"); UNCAP_ARG=(--fps "$TARGET_FPS"); fi
LOG="$RUNS/game_$(date +%Y%m%d_%H%M%S).log"
SHM="/dev/shm/nbgl_play_$$"

[ -n "$DISPLAY" ] || { echo "no X display (DISPLAY is empty); the window needs one" >&2; exit 1; }
[ -x "$EMU" ] || { echo "emulator not found: $EMU (build it: qemu/build_qemu_nb.sh)" >&2; exit 1; }
[ -f "$APK/lib/arm64-v8a/libg.so" ] || { echo "extracting the APK into $APK ..."; "$ROOT/loader/setup_apk.sh" "$ROOT/apk/nb_68.279_release_7c5c5152.apk" "$APK"; }

# the fast emulator's switches (same as nbpc/instance.py qemu_cmd_env): ~2x faster, same game state
case "$(basename "$EMU")" in qemu-aarch64-nb*)
    export QEMU_NB_XPAGE="${QEMU_NB_XPAGE:-1}" QEMU_NB_INLINE="${QEMU_NB_INLINE:-1}" QEMU_CPU="${QEMU_CPU:-max,pauth-impdef=on}" ;;
esac

cleanup() { kill "$GLPID" 2>/dev/null || true; rm -f "$SHM"; }
trap cleanup EXIT INT TERM

"$GL" --shm "$SHM" --size "$SIZE" "${FPS_ARG[@]}" "${PACE_ARG[@]}" > "$RUNS/nbgl_$(basename "$LOG")" 2>&1 &
GLPID=$!
for _ in $(seq 1 200); do [ "$(stat -c%s "$SHM" 2>/dev/null || echo 0)" -ge 1048576 ] && break; kill -0 "$GLPID" 2>/dev/null || { echo "nbgl failed; see $RUNS/nbgl_$(basename "$LOG")" >&2; exit 1; }; sleep 0.1; done
echo "window $SIZE at $DPI dpi, game log: $LOG"
echo "close the window to quit"

unshare -rn "$EMU" "$HOST" --libs "$APK/lib/arm64-v8a" --assets "$APK" --payloads "$ROOT/loader/payloads" \
    --stage boot --gl "$SHM" --dpi "$DPI" --cores 2 --run-seconds 86400 "${UNCAP_ARG[@]}" "${CUBE_ARG[@]}" "${STORM_ARG[@]}" "${ELIM_ARG[@]}" "${BATTLE[@]}" > "$LOG" 2>&1 || true
echo "game exited; last battle/crash lines:"
grep -E "\[battle\]|\[crash\]|window closed" "$LOG" | tail -5 || true
