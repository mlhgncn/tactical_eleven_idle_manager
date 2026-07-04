#!/usr/bin/env python3
"""
Generate masked player and team JSONs from EA FC dataset via kagglehub.

Usage:
  python generate_masked_players_kagglehub.py

Requirements:
  pip install pandas kagglehub

The script deletes any existing output files at start, downloads the dataset
via kagglehub, reads the CSV, masks names, converts EA ratings to FM-style
attributes, assigns UUIDs, and writes two JSON files:
  - sahte_oyuncular_ve_takimlar.json
  - gercek_isimler_yamasi.json
"""
import csv
import hashlib
import json
import os
import random
import sys
import time
import uuid
from pathlib import Path
from typing import Any, Dict, List, Optional

import pandas as pd

# REQUIRED KAGGLEHUB CALL (as requested)
import kagglehub
path = kagglehub.dataset_download("justdhia/ea-sports-fc-26-player-ratings")
print("Path to dataset files:", path)

OUTPUT_TEAM_PLAYER_FILE = "sahte_oyuncular_ve_takimlar.json"
OUTPUT_NAME_MAP_FILE = "gercek_isimler_yamasi.json"

# Basic team masks for major clubs (expandable)
TEAM_NAME_MASKS = {
    "Galatasaray": "Istanbul Lions",
    "Fenerbahce": "Kadikoy Birds",
    "Fenerbahçe": "Kadikoy Birds",
    "Beşiktaş": "Black Eagles FC",
    "Besiktas": "Black Eagles FC",
    "Real Madrid": "Royal Madrid",
    "FC Barcelona": "C. Barcelona",
    "Barcelona": "C. Barcelona",
    "Liverpool": "LFC Reds",
    "Manchester United": "Man Utd Stars",
    "Manchester City": "City Sky Blues",
}


def cleanup_existing_files() -> None:
    # Remove files immediately at script start
    for filename in (OUTPUT_TEAM_PLAYER_FILE, OUTPUT_NAME_MAP_FILE):
        try:
            p = Path(filename)
            if p.exists():
                p.unlink()
        except Exception as e:
            print(f"Dosya silinirken hata: {filename} -> {e}")
    print("Mevcut oyuncu veritabanı ve eski dosyalar tamamen temizlendi. Sıfırdan kuruluma başlanıyor...")


def deterministic_random(original_value: str, salt: str = "mask") -> random.Random:
    digest = hashlib.sha256(f"{original_value}|{salt}".encode("utf-8")).hexdigest()
    return random.Random(int(digest[:16], 16))


def mask_team_name(original_name: str) -> str:
    if not original_name:
        return "Unknown FC"
    if original_name in TEAM_NAME_MASKS:
        return TEAM_NAME_MASKS[original_name]
    rnd = deterministic_random(original_name, "team")
    base = ''.join(ch for ch in original_name.split()[0] if ch.isalpha()).capitalize()
    suffix = rnd.choice([" Athletic", " SK", " United", " FC", " Rovers", " City"])
    return (base + suffix)[:32]


def mask_player_name(original_name: str) -> str:
    # Improved masking: keep resemblance to original names by applying
    # small, deterministic edits (swap, replace vowel, truncate + suffix).
    if not original_name:
        return "Unknown Player"
    rnd = deterministic_random(original_name, "player")
    parts = original_name.strip().split()
    # normalize parts
    parts = [p for p in parts if p]
    if not parts:
        return "Unknown Player"

    first = parts[0]
    last = parts[-1] if len(parts) > 1 else parts[0]

    def mutate(token: str) -> str:
        s = ''.join(ch for ch in token if ch.isalpha())
        if len(s) <= 2:
            return s.capitalize()
        s = s.capitalize()
        op = rnd.random()
        # replace one vowel with adjacent vowel
        vowels = "aeiouAEIOU"
        if op < 0.25:
            # transpose two middle characters
            i = max(1, (len(s) // 2) - 1)
            lst = list(s)
            lst[i], lst[i+1] = lst[i+1], lst[i]
            return ''.join(lst)
        elif op < 0.55:
            # replace a vowel if present
            for i, ch in enumerate(s):
                if ch in vowels:
                    repl = rnd.choice('aeiou')
                    lst = list(s)
                    lst[i] = repl.upper() if ch.isupper() else repl
                    return ''.join(lst)
            return s
        elif op < 0.8:
            # remove one internal char
            if len(s) > 3:
                i = rnd.randint(1, len(s)-2)
                return (s[:i] + s[i+1:])
            return s
        else:
            # shorten and add suffix
            suf = rnd.choice(["on", "io", "an", "ez", "i"])
            return (s[:min(4, len(s))] + suf).capitalize()

    masked_last = mutate(last)
    masked_first_choice = rnd.random()
    if masked_first_choice < 0.35:
        # initial + last
        return f"{first[0].upper()}. {masked_last}"
    elif masked_first_choice < 0.75:
        # shortened first + last
        short_first = (first[:3].capitalize() if len(first) >= 3 else first.capitalize())
        return f"{short_first} {masked_last}"
    else:
        # full first with mutated last
        return f"{first.capitalize()} {masked_last}"


def find_csv_in_path(folder: str) -> Optional[Path]:
    p = Path(folder)
    if not p.exists():
        return None
    candidates = list(p.rglob("*.csv"))
    if not candidates:
        return None
    # Prefer filename containing 'player' or 'rating'
    for c in candidates:
        name = c.name.lower()
        if "player" in name or "rating" in name or "overall" in name:
            return c
    return candidates[0]


def map_ea_to_fm(row: pd.Series) -> Dict[str, int]:
    # Expected EA columns: Overall, Pace, Shooting, Passing, Dribbling, Defending, Physical
    def get_int(col: str, default: int = 50) -> int:
        try:
            v = row.get(col, None)
            if pd.isna(v):
                return default
            return int(float(v))
        except Exception:
            return default

    overall = get_int("Overall", 50)
    pace = get_int("Pace", 50)
    shooting = get_int("Shooting", 50)
    passing = get_int("Passing", 50)
    dribbling = get_int("Dribbling", 50)
    defending = get_int("Defending", 50)
    physical = get_int("Physical", 50)

    rnd = deterministic_random(str(overall) + str(shooting), "ability")

    # Map to 10-20 scale roughly
    def scale_to_10_20(value: int) -> int:
        # EA values usually 0-99; map 0->10, 99->20
        return max(10, min(20, 10 + int(round((value / 99.0) * 10))))

    finishing = scale_to_10_20(int((shooting * 0.6) + (dribbling * 0.2) + (pace * 0.2)) // 1)
    passing_attr = scale_to_10_20(passing)
    tackling = scale_to_10_20(defending)
    current_ability = scale_to_10_20(overall)
    potential_ability = min(20, current_ability + rnd.randint(0, 3))
    age = None
    try:
        age_val = row.get("Age") or row.get("age")
        if not pd.isna(age_val):
            age = int(float(age_val))
    except Exception:
        age = None
    if age is None:
        age = rnd.randint(16, 36)

    return {
        "finishing": int(finishing),
        "passing": int(passing_attr),
        "tackling": int(tackling),
        "age": int(age),
        "current_ability": int(current_ability),
        "potential_ability": int(potential_ability),
    }


def save_json(filename: str, data: Any) -> None:
    try:
        with open(filename, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"Kaydedildi: {filename}")
    except Exception as e:
        print(f"JSON kaydedilemedi: {filename} -> {e}")


def main():
    cleanup_existing_files()

    dataset_folder = str(path) if path else "."
    csv_file = find_csv_in_path(dataset_folder)
    if csv_file is None:
        print("CSV dosyası bulunamadı. Lütfen dataset içinde CSV olduğundan emin olun.")
        sys.exit(1)

    print(f"CSV okunuyor: {csv_file}")
    try:
        df = pd.read_csv(csv_file)
    except Exception as e:
        print(f"CSV okunurken hata: {e}")
        sys.exit(1)

    fake_dataset: Dict[str, List[Dict[str, Any]]] = {"teams": [], "players": []}
    name_map: Dict[str, List[Dict[str, str]]] = {"teams": [], "players": []}

    # Detect team and player name columns intelligently
    team_col = None
    for candidate in ("team", "Team", "Club", "club", "team_name", "teamName"):
        if candidate in df.columns:
            team_col = candidate
            break

    # Player name detection: prefer commonName, then firstName+lastName, then fallbacks
    has_common = "commonName" in df.columns
    has_first_last = ("firstName" in df.columns and "lastName" in df.columns)
    # fallback player column candidates
    player_col = None
    for candidate in ("Name", "Player", "player", "name", "full_name"):
        if candidate in df.columns:
            player_col = candidate
            break

    # Build teams map to assign unique team ids
    teams_seen: Dict[str, str] = {}
    for idx, row in df.iterrows():
        try:
            # build original player name from best available columns
            if has_common and row.get("commonName") and not pd.isna(row.get("commonName")):
                original_player = str(row.get("commonName"))
            elif has_first_last:
                fn = row.get("firstName") or ""
                ln = row.get("lastName") or ""
                original_player = f"{fn} {ln}".strip()
            elif player_col is not None:
                original_player = str(row.get(player_col, "Unknown Player"))
            else:
                original_player = str(row.get(df.columns[0], "Unknown Player"))

            original_team = str(row.get(team_col, "Unknown Team")) if team_col else "Unknown Team"

            if original_team not in teams_seen:
                team_id = str(uuid.uuid4())
                masked_team = mask_team_name(original_team)
                teams_seen[original_team] = team_id
                fake_dataset["teams"].append({
                    "id": team_id,
                    "original_name": original_team,
                    "masked_name": masked_team,
                })
                name_map["teams"].append({"id": team_id, "original_name": original_team})

            team_id = teams_seen[original_team]
            player_id = str(uuid.uuid4())
            masked_player = mask_player_name(original_player)
            attributes = map_ea_to_fm(row)

            fake_dataset["players"].append({
                "id": player_id,
                "team_id": team_id,
                "masked_name": masked_player,
                "original_position": row.get("Position") or row.get("position") or "Unknown",
                **attributes,
            })

            name_map["players"].append({"id": player_id, "original_name": original_player})
        except Exception as e:
            print(f"Satır işlenirken hata idx={idx}: {e}")

    save_json(OUTPUT_TEAM_PLAYER_FILE, fake_dataset)
    save_json(OUTPUT_NAME_MAP_FILE, name_map)
    print("İşlem tamamlandı. Çıktılar oluşturuldu.")


if __name__ == "__main__":
    main()
