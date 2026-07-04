import hashlib
import json
import os
import random
import time
import uuid
from typing import Any, Dict, List, Optional

import requests

API_KEY = "123"
BASE_URL = "https://www.thesportsdb.com/api/v1/json/{key}/{endpoint}"
OUTPUT_TEAM_PLAYER_FILE = "sahte_oyuncular_ve_takimlar.json"
OUTPUT_NAME_MAP_FILE = "gercek_isimler_yamasi.json"
LEAGUE_IDS = [4744, 4328, 4335]
LEAGUE_NAMES = {
    4744: "Trendyol Süper Lig",
    4328: "Premier League",
    4335: "La Liga",
}

TEAM_NAME_MASKS = {
    "Galatasaray": "Istanbul Lions",
    "Fenerbahçe": "Kadıköy Kanaryaları",
    "Beşiktaş": "Black Eagles FC",
    "Trabzonspor": "Black Sea Mariners",
    "Real Madrid": "R. Madrid",
    "FC Barcelona": "C. Barcelona",
    "Barcelona": "C. Barcelona",
    "Liverpool": "LFC Reds",
    "Manchester United": "Man Utd Stars",
    "Manchester City": "City Sky Blues",
    "Bayern Munich": "Munich Royals",
    "Juventus": "Turin Bulls",
}

POSITION_ATTRIBUTE_MAP = {
    "Forward": {"finishing": (12, 20), "passing": (10, 18), "tackling": (8, 14)},
    "Midfielder": {"finishing": (8, 16), "passing": (12, 20), "tackling": (10, 16)},
    "Defender": {"finishing": (6, 14), "passing": (10, 18), "tackling": (12, 20)},
    "Goalkeeper": {"finishing": (5, 12), "passing": (8, 16), "tackling": (10, 18)},
}


def cleanup_existing_files() -> None:
    for filename in [OUTPUT_TEAM_PLAYER_FILE, OUTPUT_NAME_MAP_FILE]:
        if os.path.exists(filename):
            try:
                os.remove(filename)
                print(f"Silindi: {filename}")
            except OSError as error:
                print(f"Dosya silinirken hata oluştu: {filename} -> {error}")


def build_url(endpoint: str, identifier: Any) -> str:
    return BASE_URL.format(key=API_KEY, endpoint=f"{endpoint}?id={identifier}")


def fetch_json(url: str) -> Optional[Dict[str, Any]]:
    try:
        response = requests.get(url, timeout=15)
        response.raise_for_status()
        return response.json()
    except requests.RequestException as error:
        print(f"API isteği başarısız oldu: {url} -> {error}")
        return None


def deterministic_random(original_value: str, seed_salt: str) -> random.Random:
    digest = hashlib.sha256(f"{original_value}|{seed_salt}".encode("utf-8")).hexdigest()
    return random.Random(int(digest[:16], 16))


def mask_team_name(original_name: str) -> str:
    if original_name in TEAM_NAME_MASKS:
        return TEAM_NAME_MASKS[original_name]

    rnd = deterministic_random(original_name, "team")
    words = original_name.split()
    if len(words) == 1:
        return words[0][:3].capitalize() + " FC"

    first_word = words[0]
    last_word = words[-1]
    last_part = last_word[:3].capitalize()
    suffix = rnd.choice([" Lions", " United", " Stars", " City", " Eagles", " Warriors", " Royals"])
    return f"{first_word[0]}. {last_part}{suffix}"


def mask_player_name(original_name: str) -> str:
    rnd = deterministic_random(original_name, "player")
    name_parts = original_name.strip().split()
    if len(name_parts) == 0:
        return "Unknown Player"

    first_name = name_parts[0]
    last_name = name_parts[-1] if len(name_parts) > 1 else name_parts[0]
    first_initial = first_name[0].upper()
    sanitized_last = last_name[:3].capitalize()
    suffix = rnd.choice(["son", "don", "oni", "er", "an", "io"])
    if len(last_name) <= 3:
        masked_last_name = sanitized_last + suffix
    else:
        masked_last_name = sanitized_last + suffix

    if rnd.random() < 0.4:
        return f"{first_initial}. {masked_last_name}"

    alt_first = first_name[:3].capitalize() if len(first_name) >= 3 else first_name.capitalize()
    return f"{alt_first} {masked_last_name}"


def normalize_position(raw_position: Optional[str]) -> str:
    if not raw_position:
        return "Midfielder"

    value = raw_position.strip().lower()
    if "forward" in value or "striker" in value or "attacker" in value:
        return "Forward"
    if "defender" in value or "back" in value:
        return "Defender"
    if "goalkeeper" in value or "keeper" in value or "goalie" in value:
        return "Goalkeeper"
    return "Midfielder"


def generate_ability_values(position: str) -> Dict[str, int]:
    position = normalize_position(position)
    attribute_ranges = POSITION_ATTRIBUTE_MAP.get(position, POSITION_ATTRIBUTE_MAP["Midfielder"])
    finishing = random.randint(*attribute_ranges["finishing"])
    passing = random.randint(*attribute_ranges["passing"])
    tackling = random.randint(*attribute_ranges["tackling"])
    age = random.randint(16, 36)
    current_ability = random.randint(10, 20)
    potential_ability = min(20, max(current_ability, current_ability + random.randint(0, 4)))

    return {
        "position": position,
        "finishing": finishing,
        "passing": passing,
        "tackling": tackling,
        "age": age,
        "current_ability": current_ability,
        "potential_ability": potential_ability,
    }


def save_json(filename: str, data: Any) -> None:
    try:
        with open(filename, "w", encoding="utf-8") as file:
            json.dump(data, file, ensure_ascii=False, indent=2)
        print(f"Kaydedildi: {filename}")
    except OSError as error:
        print(f"JSON kaydedilirken hata oluştu: {filename} -> {error}")


def main() -> None:
    cleanup_existing_files()

    fake_dataset: Dict[str, List[Dict[str, Any]]] = {"teams": [], "players": []}
    name_map: Dict[str, List[Dict[str, str]]] = {"teams": [], "players": []}

    for league_id in LEAGUE_IDS:
        league_name = LEAGUE_NAMES.get(league_id, f"League {league_id}")
        team_url = build_url("lookup_all_teams.php", league_id)
        print(f"Lig verisi çekiliyor: {league_name} ({league_id})")
        league_response = fetch_json(team_url)
        time.sleep(0.25)

        if not league_response or "teams" not in league_response or league_response["teams"] is None:
            print(f"Lig için takım bulunamadı: {league_id}")
            continue

        for team in league_response["teams"]:
            original_team_name = team.get("strTeam") or team.get("strAlternate") or "Unknown Team"
            team_id = str(uuid.uuid4())
            masked_team_name = mask_team_name(original_team_name)

            fake_dataset["teams"].append(
                {
                    "id": team_id,
                    "league_id": league_id,
                    "league_name": league_name,
                    "masked_name": masked_team_name,
                }
            )
            name_map["teams"].append(
                {"id": team_id, "original_name": original_team_name}
            )

            player_url = build_url("lookup_all_players.php", team.get("idTeam") or team.get("id") or "")
            print(f"  Takım için oyuncular çekiliyor: {original_team_name}")
            player_response = fetch_json(player_url)
            time.sleep(0.25)

            if not player_response or "player" not in player_response or player_response["player"] is None:
                print(f"  Oyuncu bulunamadı: {original_team_name}")
                continue

            for player in player_response["player"]:
                original_player_name = player.get("strPlayer") or "Unknown Player"
                player_id = str(uuid.uuid4())
                masked_player_name = mask_player_name(original_player_name)
                position = normalize_position(player.get("strPosition"))
                attributes = generate_ability_values(position)

                fake_dataset["players"].append(
                    {
                        "id": player_id,
                        "team_id": team_id,
                        "masked_name": masked_player_name,
                        "original_position": player.get("strPosition") or "Unknown",
                        **attributes,
                    }
                )
                name_map["players"].append(
                    {"id": player_id, "original_name": original_player_name}
                )

    save_json(OUTPUT_TEAM_PLAYER_FILE, fake_dataset)
    save_json(OUTPUT_NAME_MAP_FILE, name_map)
    print("İşlem tamamlandı. Dosyalar sıfırdan oluşturuldu.")


if __name__ == "__main__":
    main()
