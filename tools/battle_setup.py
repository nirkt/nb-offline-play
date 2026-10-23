#!/usr/bin/env python3
"""battle.conf (names) -> game host arguments for the battle setup of every PLAY (see README "Change the battle").

    python3 tools/battle_setup.py battle.conf      prints one argument per line: --div-location N, --div-theme N,
                                                   --div-chr a,b,.., --div-skin a,b,..   (global data ids)

Ids follow the game's csv tables (the same rule as the diversity round's nbpc/diversity.py): id = type * 1000000 + row,
where the row counts the named rows of the table. Standard library only; reads apk_extract/assets/csv_logic.
"""
import csv, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV = os.path.join(ROOT, "apk_extract", "assets", "csv_logic")
T_CHAR, T_SKIN, T_LOC, T_THEME = 16, 29, 15, 47

# display name (what the game shows) -> characters.csv name. Accepted in battle.conf as well.
BRAWLERS = {
    "Piper": "Sniper", "Colt": "Gunslinger", "Shelly": "ShotgunGirl", "Bull": "BullDude", "Dynamike": "TntDude",
    "Penny": "ArtilleryDude", "Poco": "DeadMariachi", "Brock": "RocketGirl", "Nita": "Shaman", "Jessie": "Mechanic",
}
# characters.csv name -> its alternate skin (skins.csv name). Chosen by the diversity round (nbpc/diversity.py ROSTER_INFO).
ALT_SKIN = {
    "Sniper": "Sniperrose", "Gunslinger": "GunSlingerRockstar", "ShotgunGirl": "BanditGirlBandita",
    "BullDude": "BullGuyHair", "TntDude": "TntGuySanta", "ArtilleryDude": "ArtilleryGalBunny",
    "DeadMariachi": "PocoPirate", "RocketGirl": "RocketGirlBeach", "Shaman": "ShamanPanda", "Mechanic": "MechanicSummer",
}
DEFAULT_BRAWLERS = ["Sniper", "Gunslinger", "ShotgunGirl", "BullDude", "TntDude", "ArtilleryDude", "DeadMariachi",
                    "RocketGirl", "Shaman", "Mechanic"]
NPLAYERS, NMAX = 10, 16

_cache = {}


def table(name):
    """{row name: global id} of a csv_logic table (named rows; the row counter is the data index)"""
    if name not in _cache:
        T = {"characters.csv": T_CHAR, "skins.csv": T_SKIN, "locations.csv": T_LOC, "location_themes.csv": T_THEME}[name]
        with open(os.path.join(CSV, name), newline="", encoding="utf-8") as f:
            rows = list(csv.reader(f))
        out, k = {}, 0
        for r in rows[2:]:
            if r and r[0]:
                out[r[0]] = T * 1000000 + k; k += 1
        _cache[name] = out
    return _cache[name]


def lookup(name, table_name, what):
    t = table(table_name)
    if name not in t:
        sys.exit(f"battle.conf: unknown {what} '{name}' (names: the csv_logic {table_name} 'Name' column)")
    return t[name]


def parse(path):
    conf = {}
    with open(path, encoding="utf-8") as f:
        for ln, line in enumerate(f, 1):
            line = line.split("#", 1)[0].strip()
            if not line:
                continue
            if "=" not in line:
                sys.exit(f"{path}:{ln}: expected 'key = value'")
            k, v = line.split("=", 1)
            conf[k.strip().lower()] = v.strip()
    return conf


def setup(conf):
    loc_name = conf.get("location", "Survival612")
    theme_name = conf.get("theme", "location")
    loc = lookup(loc_name, "locations.csv", "location (map)")
    theme = 0 if theme_name.lower() in ("", "location", "0") else lookup(theme_name, "location_themes.csv", "theme (map skin)")
    brawlers = [b.strip() for b in conf.get("brawler", ",".join(DEFAULT_BRAWLERS)).split(",") if b.strip()]
    if len(brawlers) > NPLAYERS:
        sys.exit(f"battle.conf: {len(brawlers)} brawlers given, at most {NPLAYERS} (one per player, player 1 first)")
    brawlers += ["Sniper"] * (NPLAYERS - len(brawlers))       # missing players: Piper
    chr_ids, names = [], []
    for b in brawlers:
        name = BRAWLERS.get(b, b)
        names.append(name)
        chr_ids.append(lookup(name, "characters.csv", "brawler"))
    skins = [s.strip() for s in conf.get("skin", "alt").split(",") if s.strip()]
    skins += ["alt"] * (NPLAYERS - len(skins))
    skin_ids = []
    for i, s in enumerate(skins[:NPLAYERS]):
        if s.lower() in ("", "0", "default"):
            skin_ids.append(0)                                   # the brawler's own default skin
        elif s.lower() == "alt":
            skin_ids.append(lookup(ALT_SKIN[names[i]], "skins.csv", "skin"))
        else:
            skin_ids.append(lookup(s, "skins.csv", "skin"))
    pad = lambda xs: xs + [0] * (NMAX - len(xs))
    return [("--div-location", str(loc)), ("--div-theme", str(theme)),
            ("--div-chr", ",".join(map(str, pad(chr_ids)))), ("--div-skin", ",".join(map(str, pad(skin_ids))))]


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    for flag, value in setup(parse(sys.argv[1])):
        print(flag); print(value)
