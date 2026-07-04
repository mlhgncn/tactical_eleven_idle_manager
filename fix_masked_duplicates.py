#!/usr/bin/env python3
import hashlib
import json
from pathlib import Path
import random

SAHTE = Path("sahte_oyuncular_ve_takimlar.json")
GERCEK = Path("gercek_isimler_yamasi.json")


def deterministic_random(original_value: str, salt: str = "fix"):
    digest = hashlib.sha256(f"{original_value}|{salt}".encode("utf-8")).hexdigest()
    return random.Random(int(digest[:16], 16))


def fix_player_mask(original_name: str) -> str:
    rnd = deterministic_random(original_name, "fix_player")
    parts = [p for p in original_name.split() if p]
    if not parts:
        return "Unknown Player"
    first = parts[0]
    last = parts[-1] if len(parts) > 1 else parts[0]
    # prefer Initial. Lastmut
    last_mut = last[:3].capitalize() + rnd.choice(["on", "io", "an"]) if len(last) >= 3 else last.capitalize() + "io"
    if rnd.random() < 0.6:
        return f"{first[0].upper()}. {last_mut}"
    else:
        short_first = first[:3].capitalize() if len(first) >= 3 else first.capitalize()
        return f"{short_first} {last_mut}"


def fix_team_mask(original_name: str) -> str:
    rnd = deterministic_random(original_name, "fix_team")
    base = ''.join(ch for ch in original_name.split()[0] if ch.isalpha()).capitalize()
    suffix = rnd.choice([" Athletic", " United", " FC", " SK", " Rovers"]) 
    return (base + suffix)[:32]


def main():
    if not SAHTE.exists() or not GERCEK.exists():
        print("Gerekli dosyalar bulunamadı.")
        return

    sa = json.loads(SAHTE.read_text(encoding="utf-8"))
    ge = json.loads(GERCEK.read_text(encoding="utf-8"))

    # build id->original maps
    team_map = {t["id"]: t.get("original_name", "") for t in ge.get("teams", [])}
    player_map = {p["id"]: p.get("original_name", "") for p in ge.get("players", [])}

    fixed_players = 0
    for p in sa.get("players", []):
        pid = p.get("id")
        orig = player_map.get(pid, "")
        masked = p.get("masked_name", "") or ""
        if orig and masked and orig.strip().lower() == masked.strip().lower():
            new_mask = fix_player_mask(orig)
            if new_mask.strip().lower() == orig.strip().lower():
                new_mask = orig[0].upper() + ". " + orig.split()[-1][:3].capitalize()
            p["masked_name"] = new_mask
            fixed_players += 1

    fixed_teams = 0
    for t in sa.get("teams", []):
        tid = t.get("id")
        orig = team_map.get(tid, "")
        masked = t.get("masked_name", "") or ""
        if orig and masked and orig.strip().lower() == masked.strip().lower():
            new_mask = fix_team_mask(orig)
            if new_mask.strip().lower() == orig.strip().lower():
                new_mask = orig[:6].capitalize() + " FC"
            t["masked_name"] = new_mask
            fixed_teams += 1

    SAHTE.write_text(json.dumps(sa, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Düzeltilen oyuncu sayısı: {fixed_players}")
    print(f"Düzeltilen takım sayısı: {fixed_teams}")


if __name__ == "__main__":
    main()
