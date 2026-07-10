-- One-time data fix: seasons created after the "Maçı Oyna" button removal
-- had real matches resolved by auto_resolve_matches, but their standings
-- were never updated (see 20260710142613_fix_standings_update_service_role_auth_check.sql
-- for the root cause). This recomputes league_standings from scratch, from
-- the actual matches table, for every active season - a full rebuild is
-- simpler and safer than replaying update_standings_after_match once per
-- match in order.

WITH match_stats AS (
  SELECT
    season_id,
    club_id,
    count(*) AS played,
    sum(CASE WHEN won THEN 1 ELSE 0 END) AS wins,
    sum(CASE WHEN drawn THEN 1 ELSE 0 END) AS draws,
    sum(CASE WHEN lost THEN 1 ELSE 0 END) AS losses,
    sum(goals_for) AS goals_for,
    sum(goals_against) AS goals_against
  FROM (
    SELECT
      season_id, home_club_id AS club_id,
      home_score AS goals_for, away_score AS goals_against,
      home_score > away_score AS won, home_score = away_score AS drawn, home_score < away_score AS lost
    FROM public.matches
    WHERE home_score IS NOT NULL AND away_score IS NOT NULL
    UNION ALL
    SELECT
      season_id, away_club_id AS club_id,
      away_score AS goals_for, home_score AS goals_against,
      away_score > home_score AS won, away_score = home_score AS drawn, away_score < home_score AS lost
    FROM public.matches
    WHERE home_score IS NOT NULL AND away_score IS NOT NULL
  ) both_sides
  GROUP BY season_id, club_id
)
UPDATE public.league_standings ls
SET played = COALESCE(ms.played, 0),
    wins = COALESCE(ms.wins, 0),
    draws = COALESCE(ms.draws, 0),
    losses = COALESCE(ms.losses, 0),
    goals_for = COALESCE(ms.goals_for, 0),
    goals_against = COALESCE(ms.goals_against, 0),
    goal_difference = COALESCE(ms.goals_for, 0) - COALESCE(ms.goals_against, 0),
    points = COALESCE(ms.wins, 0) * 3 + COALESCE(ms.draws, 0),
    updated_at = now()
FROM match_stats ms
WHERE ls.season_id = ms.season_id AND ls.club_id = ms.club_id;

WITH ranked AS (
  SELECT id, ROW_NUMBER() OVER (
    PARTITION BY season_id
    ORDER BY points DESC, goal_difference DESC, goals_for DESC
  ) AS rn
  FROM public.league_standings
)
UPDATE public.league_standings ls
SET position = ranked.rn
FROM ranked
WHERE ls.id = ranked.id;
