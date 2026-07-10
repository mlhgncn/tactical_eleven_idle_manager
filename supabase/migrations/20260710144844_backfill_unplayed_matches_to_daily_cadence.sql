-- Existing active seasons have unplayed matches still scheduled 1 week
-- apart (some as far out as September) from before the daily-cadence
-- change. Compress them onto the new daily-at-21:00-Istanbul schedule:
-- each season's remaining distinct "week" numbers become consecutive
-- days starting at the next upcoming 21:00 Istanbul slot, preserving
-- which matches were grouped into the same round.
WITH week_rank AS (
  SELECT season_id, week, DENSE_RANK() OVER (PARTITION BY season_id ORDER BY week) AS day_rank
  FROM public.matches WHERE is_played = false
  GROUP BY season_id, week
), next_slot AS (
  SELECT CASE WHEN base <= now() THEN base + interval '1 day' ELSE base END AS season_start
  FROM (SELECT (date_trunc('day', now() AT TIME ZONE 'Europe/Istanbul') + interval '21 hours') AT TIME ZONE 'Europe/Istanbul' AS base) t
)
UPDATE public.matches m
SET match_date = (SELECT season_start FROM next_slot) + (wr.day_rank - 1) * interval '1 day'
FROM week_rank wr
WHERE m.season_id = wr.season_id AND m.week = wr.week AND m.is_played = false;
