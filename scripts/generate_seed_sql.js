const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const jsonPath = path.join(root, 'sahte_oyuncular_ve_takimlar.json');
const targetPath = path.join(root, 'supabase', 'seed_masked_data.sql');

const json = fs.readFileSync(jsonPath);
const b64 = Buffer.from(json).toString('base64');

const sql = `DO $$
DECLARE
    payload jsonb := convert_from(decode('${b64}', 'base64'), 'UTF8')::jsonb;
    team jsonb;
    player jsonb;
BEGIN
    FOR team IN SELECT * FROM jsonb_array_elements(payload->'teams') LOOP
        INSERT INTO public.clubs(id, name, created_at, budget, stadium_capacity, ticket_price, training_facility_level, user_id)
        VALUES (
            (team->>'id')::uuid,
            team->>'masked_name',
            now(),
            10000000,
            15000,
            20,
            1,
            NULL
        )
        ON CONFLICT (id) DO UPDATE
        SET name = excluded.name,
            budget = excluded.budget,
            stadium_capacity = excluded.stadium_capacity,
            ticket_price = excluded.ticket_price,
            training_facility_level = excluded.training_facility_level;
    END LOOP;

    FOR player IN SELECT * FROM jsonb_array_elements(payload->'players') LOOP
        INSERT INTO public.players(
            id, club_id, name, created_at,
            current_ability, potential_ability, age,
            morale, fitness, finishing, passing, tackling,
            composure, determination, consistency, injury_proneness
        )
        VALUES (
            (player->>'id')::uuid,
            (player->>'team_id')::uuid,
            player->>'masked_name',
            now(),
            (player->>'current_ability')::int,
            (player->>'potential_ability')::int,
            (player->>'age')::int,
            75,100,
            (player->>'finishing')::int,
            (player->>'passing')::int,
            (player->>'tackling')::int,
            10,10,10,5
        )
        ON CONFLICT (id) DO UPDATE
        SET club_id = excluded.club_id,
            name = excluded.name,
            current_ability = excluded.current_ability,
            potential_ability = excluded.potential_ability,
            age = excluded.age,
            finishing = excluded.finishing,
            passing = excluded.passing,
            tackling = excluded.tackling,
            morale = excluded.morale,
            fitness = excluded.fitness,
            composure = excluded.composure,
            determination = excluded.determination,
            consistency = excluded.consistency,
            injury_proneness = excluded.injury_proneness;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
`;

fs.writeFileSync(targetPath, sql, 'utf8');
console.log('seed_masked_data.sql created at', targetPath);
