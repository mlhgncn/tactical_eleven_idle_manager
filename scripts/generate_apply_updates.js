const fs = require('fs');
const path = require('path');
const src = path.join(__dirname, '..', 'sahte_oyuncular_ve_takimlar.json');
const out = path.join(__dirname, '..', 'supabase', 'apply_player_club_updates.sql');
const data = JSON.parse(fs.readFileSync(src, 'utf8'));
const players = data.players || [];
let lines = [];
lines.push('-- apply_player_club_updates.sql — generated');
lines.push('-- Run this in Supabase SQL Editor');
lines.push('BEGIN;');
for (const p of players) {
  if (!p.id || !p.team_id) continue;
  lines.push(`UPDATE public.players SET club_id = '${p.team_id}' WHERE id = '${p.id}';`);
}
lines.push('COMMIT;');
lines.push('\n-- Verification queries:');
lines.push("-- SELECT count(*) AS total_players, count(*) FILTER (WHERE club_id IS NOT NULL) AS assigned_players FROM public.players;");
lines.push("-- SELECT id,name,club_id FROM public.players WHERE club_id IS NOT NULL LIMIT 20;");
fs.writeFileSync(out, lines.join('\n'));
console.log('Wrote', out, 'with', players.length, 'players');
