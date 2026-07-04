import json
import shutil
from pathlib import Path

import kagglehub

ROOT = Path(__file__).resolve().parent
FAKE_PLAYERS_PATH = ROOT / 'sahte_oyuncular_ve_takimlar.json'
FAKE_NAMES_PATCH_PATH = ROOT / 'gercek_isimler_yamasi.json'


def wipe_previous_outputs() -> None:
    for path in (FAKE_PLAYERS_PATH, FAKE_NAMES_PATCH_PATH):
        if path.exists():
            path.unlink()


def build_fake_dataset() -> dict:
    path = kagglehub.dataset_download('justdhia/ea-sports-fc-26-player-ratings')
    source_dir = Path(path)
    players_file = source_dir / 'players.csv'
    teams_file = source_dir / 'teams.csv'

    if not players_file.exists() or not teams_file.exists():
        raise FileNotFoundError('Expected EA FC 26 dataset files were not found.')

    import pandas as pd

    players_df = pd.read_csv(players_file)
    teams_df = pd.read_csv(teams_file)

    fake_teams = []
    for _, team in teams_df.head(20).iterrows():
        fake_teams.append({
            'id': int(team.get('id', 0) or 0),
            'name': 'Istanbul Lions' if 'Galatasaray' in str(team.get('name', '')) else 'North City FC',
            'short_name': 'IL',
            'league': 'Fantasy League',
        })

    fake_players = []
    for _, player in players_df.head(200).iterrows():
        real_name = str(player.get('name', 'Player'))
        fake_name = real_name.replace('Mauro Icardi', 'M. Cardoni').replace('Cristiano Ronaldo', 'C. Rinaldo')
        rating = int(float(player.get('overall', 70)) * 0.15 + 10)
        rating = max(10, min(20, rating))
        fake_players.append({
            'id': int(player.get('id', 0) or 0),
            'name': fake_name,
            'club': fake_teams[0]['name'],
            'position': 'ST',
            'overall': rating,
            'age': int(player.get('age', 25) or 25),
        })

    return {
        'teams': fake_teams,
        'players': fake_players,
    }


def write_outputs(dataset: dict) -> None:
    with FAKE_PLAYERS_PATH.open('w', encoding='utf-8') as fh:
        json.dump(dataset, fh, ensure_ascii=False, indent=2)

    patch = {
        'Mauro Icardi': 'M. Cardoni',
        'Galatasaray': 'Istanbul Lions',
    }
    with FAKE_NAMES_PATCH_PATH.open('w', encoding='utf-8') as fh:
        json.dump(patch, fh, ensure_ascii=False, indent=2)


def main() -> None:
    wipe_previous_outputs()
    dataset = build_fake_dataset()
    write_outputs(dataset)


if __name__ == '__main__':
    main()
