-- 20260712130000_multi_league_support.sql's DROP INDEX for the old
-- single-club-per-user index never actually took effect in production -
-- both the old (user_id) and new (user_id, league_id) unique indexes ended
-- up coexisting on public.clubs. The stale old index still enforces "one
-- club total, across all leagues" per user, so selecting a team for a
-- second league throws a unique-violation ("already exists") the moment
-- UPDATE public.clubs SET user_id = auth.uid() runs for the second club,
-- even though the per-league index alone should allow it. Drop it again,
-- this time verified to actually apply.
DROP INDEX IF EXISTS public.clubs_user_id_unique_partial;
