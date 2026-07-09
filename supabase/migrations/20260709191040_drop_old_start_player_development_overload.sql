-- CREATE OR REPLACE only replaces a function with the exact same argument
-- list, so the previous 5-arg start_player_development(uuid, int, int,
-- int, double precision) kept existing alongside the new 1-arg version,
-- making every call ambiguous ("function is not unique").
DROP FUNCTION IF EXISTS public.start_player_development(uuid, integer, integer, integer, double precision);
