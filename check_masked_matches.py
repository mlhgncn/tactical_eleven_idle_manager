from pathlib import Path
import json

S = Path('sahte_oyuncular_ve_takimlar.json')
G = Path('gercek_isimler_yamasi.json')

if not S.exists() or not G.exists():
    print('MISSING FILES')
    raise SystemExit(1)

sa = json.loads(S.read_text(encoding='utf-8'))
ge = json.loads(G.read_text(encoding='utf-8'))

player_map = {p['id']: p.get('original_name','') for p in ge.get('players',[])}
team_map = {t['id']: t.get('original_name','') for t in ge.get('teams',[])}

same_players = []
for p in sa.get('players',[]):
    pid = p.get('id')
    orig = player_map.get(pid,'')
    masked = p.get('masked_name','') or ''
    if orig and masked and orig.strip().lower() == masked.strip().lower():
        same_players.append((pid, orig))

same_teams = []
for t in sa.get('teams',[]):
    tid = t.get('id')
    orig = team_map.get(tid,'')
    masked = t.get('masked_name','') or ''
    if orig and masked and orig.strip().lower() == masked.strip().lower():
        same_teams.append((tid, orig))

print('players_same_count=', len(same_players))
print('teams_same_count=', len(same_teams))
if same_players:
    print('\nplayer examples:')
    for x in same_players[:10]:
        print(x)
if same_teams:
    print('\nteam examples:')
    for x in same_teams[:10]:
        print(x)
