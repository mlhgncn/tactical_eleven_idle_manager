const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const jsonPath = path.join(root, 'sahte_oyuncular_ve_takimlar.json');
const outDir = path.join(root, 'supabase', 'seed_chunks');

if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
const data = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));

const escapeSql = (value) => {
  if (value === null || value === undefined) return 'NULL';
  return `'${String(value).replace(/'/g, "''")}'`;
};

const teamSql = [];
for (const team of data.teams) {
  const id = escapeSql(team.id);
  const name = escapeSql(team.masked_name);
  teamSql.push(`(${id}, ${name}, now(), 10000000, 15000, 20, 1, NULL)`);
}
const teamInsert = `INSERT INTO public.clubs(id, name, created_at, budget, stadium_capacity, ticket_price, training_facility_level, user_id) VALUES\n${teamSql.join(',\n')}\nON CONFLICT (id) DO UPDATE SET name = excluded.name, budget = excluded.budget, stadium_capacity = excluded.stadium_capacity, ticket_price = excluded.ticket_price, training_facility_level = excluded.training_facility_level;\n`;
fs.writeFileSync(path.join(outDir, 'seed_teams.sql'), teamInsert, 'utf8');

const players = data.players;
const chunkSize = 500;
for (let i = 0; i < players.length; i += chunkSize) {
  const chunk = players.slice(i, i + chunkSize);
  const rows = chunk.map((player) => {
    const id = escapeSql(player.id);
    const clubId = escapeSql(player.team_id);
    const name = escapeSql(player.masked_name);
    const current_ability = player.current_ability ?? 50;
    const potential_ability = player.potential_ability ?? 75;
    const age = player.age ?? 22;
    const finishing = player.finishing ?? 10;
    const passing = player.passing ?? 10;
    const tackling = player.tackling ?? 10;
    const morale = player.morale ?? 75;
    const fitness = player.fitness ?? 100;
    const composure = player.composure ?? 10;
    const determination = player.determination ?? 10;
    const consistency = player.consistency ?? 10;
    const injury_proneness = player.injury_proneness ?? 5;

    return `(${id}, ${clubId}, ${name}, now(), ${current_ability}, ${potential_ability}, ${age}, ${morale}, ${fitness}, ${finishing}, ${passing}, ${tackling}, ${composure}, ${determination}, ${consistency}, ${injury_proneness})`;
  });
  const filename = path.join(outDir, `seed_players_${String(i / chunkSize + 1).padStart(2, '0')}.sql`);
  const sql = `INSERT INTO public.players(id, club_id, name, created_at, current_ability, potential_ability, age, morale, fitness, finishing, passing, tackling, composure, determination, consistency, injury_proneness) VALUES\n${rows.join(',\n')}\nON CONFLICT (id) DO UPDATE SET club_id = excluded.club_id, name = excluded.name, current_ability = excluded.current_ability, potential_ability = excluded.potential_ability, age = excluded.age, morale = excluded.morale, fitness = excluded.fitness, finishing = excluded.finishing, passing = excluded.passing, tackling = excluded.tackling, composure = excluded.composure, determination = excluded.determination, consistency = excluded.consistency, injury_proneness = excluded.injury_proneness;\n`;
  fs.writeFileSync(filename, sql, 'utf8');
}

console.log('Generated seed teams and', Math.ceil(players.length / chunkSize), 'player chunks in', outDir);
