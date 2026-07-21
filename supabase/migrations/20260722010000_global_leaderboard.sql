-- Global leaderboard feature. The existing public.leaderboards table
-- (user_id, username, high_score) turned out to be dead: zero rows, no
-- function or trigger ever wrote to it, and its single "high_score" metric
-- doesn't match how the game actually tracks achievement (league_titles,
-- total_wins, best_win_streak on profiles). profiles_select_policy also
-- only lets a user read their own row, so a cross-user ranked query needs
-- a SECURITY DEFINER RPC - same pattern as the existing
-- get_club_owner_usernames, just aggregated across all profiles instead of
-- a specific club list. Ranking is by league_titles first (the game's
-- headline achievement), then total_wins as a tiebreaker among players
-- who haven't won a league yet.
CREATE OR REPLACE FUNCTION public.get_global_leaderboard(p_limit INT DEFAULT 50, p_offset INT DEFAULT 0)
RETURNS TABLE(
  rank BIGINT,
  id UUID,
  username TEXT,
  avatar_url TEXT,
  league_titles INT,
  total_wins INT,
  best_win_streak INT,
  has_unbeaten_title BOOLEAN
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT
    row_number() OVER (ORDER BY p.league_titles DESC, p.total_wins DESC, p.best_win_streak DESC) AS rank,
    p.id,
    p.username,
    p.avatar_url,
    p.league_titles,
    p.total_wins,
    p.best_win_streak,
    p.has_unbeaten_title
  FROM public.profiles p
  WHERE p.username IS NOT NULL
  ORDER BY p.league_titles DESC, p.total_wins DESC, p.best_win_streak DESC
  LIMIT p_limit OFFSET p_offset;
$$;

-- The caller's own rank/row, computed the same way, so the screen can show
-- "you're #N" even when that falls outside the current page of results.
CREATE OR REPLACE FUNCTION public.get_my_leaderboard_rank()
RETURNS TABLE(
  rank BIGINT,
  id UUID,
  username TEXT,
  avatar_url TEXT,
  league_titles INT,
  total_wins INT,
  best_win_streak INT,
  has_unbeaten_title BOOLEAN
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  WITH ranked AS (
    SELECT
      row_number() OVER (ORDER BY p.league_titles DESC, p.total_wins DESC, p.best_win_streak DESC) AS rank,
      p.id,
      p.username,
      p.avatar_url,
      p.league_titles,
      p.total_wins,
      p.best_win_streak,
      p.has_unbeaten_title
    FROM public.profiles p
    WHERE p.username IS NOT NULL
  )
  SELECT * FROM ranked WHERE id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION public.get_global_leaderboard(INT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_leaderboard_rank() TO authenticated;
