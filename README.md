# Generate Masked Players (KaggleHub)

This script downloads the EA FC 26 player ratings dataset via `kagglehub`, masks
player and team names to avoid copyright issues, converts EA ratings to
Football-Manager-style attributes, and writes two JSONs:

- `sahte_oyuncular_ve_takimlar.json` — masked dataset for the game
- `gercek_isimler_yamasi.json` — mapping of generated UUIDs to original names

Prerequisites
-------------

- Python 3.10+ (3.12 recommended)
- pip install -r requirements.txt

Usage
-----

```powershell
python generate_masked_players_kagglehub.py
```

Notes
-----
- The script includes this line as requested:

```python
import kagglehub
path = kagglehub.dataset_download("justdhia/ea-sports-fc-26-player-ratings")
print("Path to dataset files:", path)
```

- Ensure `kagglehub` is configured with your credentials if required.
- The script deletes `sahte_oyuncular_ve_takimlar.json` and `gercek_isimler_yamasi.json` at start.
