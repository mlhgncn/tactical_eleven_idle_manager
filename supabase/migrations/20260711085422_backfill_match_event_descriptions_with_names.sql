-- match_engine.ts's event descriptions used to embed player.id (a raw
-- UUID) instead of player.name - fixed in the edge function for future
-- matches, but every match_events row written before that fix still has
-- the old UUID-in-text descriptions. Backfill by literally substituting
-- the UUID substrings for the corresponding player's current name.
UPDATE public.match_events me
SET description = REPLACE(me.description, me.player_id::text, p.name)
FROM public.players p
WHERE me.player_id = p.id
  AND me.description LIKE '%' || me.player_id::text || '%';

UPDATE public.match_events me
SET description = REPLACE(me.description, me.assist_player_id::text, p.name)
FROM public.players p
WHERE me.assist_player_id = p.id
  AND me.description LIKE '%' || me.assist_player_id::text || '%';
