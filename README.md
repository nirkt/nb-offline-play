# nb-offline-play

Null's Brawl v68.279 running offline in a window. The game's ARM64 code (from the APK) runs under a patched, faster
`qemu-aarch64`; its graphics calls are replayed on the local GPU. No network is used.

## Setup

```bash
./setup.sh                                   # packages, game files, emulator, game host, renderer
```

Setup needs Ubuntu or Debian (it uses `apt` and `sudo`) and an internet connection for the qemu source. Rerun with
`./setup.sh --skip-apt` once the packages are installed.

## Play

```bash
./play.sh                 # default window (2400x1080 at 450 dpi)
./play.sh 1600x720 300    # another size and dpi
```

- Left mouse button = finger. W A S D / arrow keys = move.
- Close the window to quit. The game log is written to `runs/`.
- The first run extracts the APK into `apk_extract/`.
- Needs an X display, user namespaces (for `unshare`), and Mesa EGL/GLES.

## Battle setup

The battle is set in `battle.conf`, which `./play.sh` reads at every match:

```
location = Survival612        # map (locations.csv Name)
theme    = location           # map skin (location_themes.csv Name, or "location" for the map's own)
brawler  = Piper, Colt, ...   # one per player, up to 10 (characters.csv name or display name)
skin     = alt, alt, ...      # one per player: "alt", "default", or a skins.csv name
```

Use another file with `NB_BATTLE_CONF=other.conf ./play.sh`. The names come from the game's tables in
`apk_extract/assets/csv_logic/`. `tools/battle_setup.py` converts them to ids.

- **Brawlers:** the display name (Piper, Colt, ...) or the characters.csv name.
- **Skins:** `alt` is the brawler's alternate skin; `default` is its own skin; or any skins.csv name.
- **Maps and map skins:** see below.

### Supported brawlers

Ten brawlers have been tested, each with its alternate skin. They were picked so that each one attacks in a different way,
which makes the battles easier to read and gives coverage of the main attack types:

| display name | characters.csv name | attack |
|---|---|---|
| Piper | Sniper | long-range straight shot, damage grows with distance |
| Colt | Gunslinger | burst of straight shots |
| Shelly | ShotgunGirl | pellets (shotgun) |
| Bull | BullDude | short pellets; super is a charge |
| Dynamike | TntGuy | lobbed sticks with an area explosion |
| Penny | ArtilleryDude | splash shot; super summons a mortar |
| Poco | DeadMariachi | wide wave |
| Brock | RocketGirl | rocket with an area explosion |
| Nita | Shaman | shock wave; super summons a bear |
| Jessie | Mechanic | bouncing orb; super summons a turret |

Other brawlers may load, but they have not been checked.

### Supported maps

- **Survival612** (the default) is the only map that has been tested to run through a full battle.
- Other Showdown maps (for example Survival611, Survival3 and Survival601) crash early in the battle in this build.
  Some of the game's map data points to online content that is not in the APK, which is the likely cause. Map skins
  (themes) work on the default map.

## Showdown rules

The Showdown rules were recreated by hand. They are not taken from the game's own server code, so they can differ from the
real game in details.

These are on by default and can be turned off with environment variables:

- **Cubes** (`NB_CUBE_RULES=0`): picked-up power cubes add HP and increase damage, and the cube counter is shown.
- **Storm** (`NB_STORM_RULES=0`): brawlers in the storm lose HP over time, increasing the longer they stay.
- **Brawlers left** (`NB_ELIMINATION=0`): the count of brawlers still alive. When one is left the battle ends and the game
  returns to the main menu. The end and the return to the menu are not verified yet.

## Known limits

- Anything that depends on online content may not work, because the APK does not contain it. Some maps and brawlers
  point to that content and can crash or misbehave.
- The Showdown rules are hand-made approximations (see above).
- The end of a battle and the return to the main menu have not been verified yet.

## Tests

```bash
tests/battle_check.sh                   # battle.conf: start, PLAY, run 400 battle ticks, save a snapshot and log
tests/battle_check.sh battle.conf 1200  # more ticks
```

Output goes to `runs/battle_check_<time>/`.

## Repository layout

| part | where |
|---|---|
| game | `apk/` (the APK), `apk_extract/` (generated) |
| game host | `loader/` (`nbhost`, sources; build with `loader/build.sh`) |
| renderer | `glhost/` (`nbgl`; build with `glhost/build.sh`) |
| fast emulator | `qemu/` (`qemu/bin/qemu-aarch64-nb`; build with `qemu/build_qemu_nb.sh`) |
| battle setup | `battle.conf`, `tools/battle_setup.py` |
| tests | `tests/` |
