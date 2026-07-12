-- get_club_owner_usernames excluded any club owner who hasn't set a
-- username (WHERE p.username IS NOT NULL), so those owners never got a row
-- back - the client then defaults their league_titles to 0 (see
-- _attachOwnerUsernames in supabase_repository.dart), which silently hides
-- the level frame in the league standings table even for owners who do
-- have title-worthy league_titles. Drop the filter so every real club
-- owner's league_titles comes through regardless of whether they've set a
-- username yet.
--
-- Also adds avatar_url so the "next match" card can show a real opponent's
-- profile photo on their club badge instead of always falling back to
-- initials (see ClubBadge.avatarUrl / MatchFixture.opponentAvatarUrl).
DROP FUNCTION IF EXISTS public.get_club_owner_usernames(uuid[]);
CREATE FUNCTION public.get_club_owner_usernames(p_club_ids uuid[])
RETURNS TABLE(club_id uuid, username text, league_titles int, avatar_url text) AS $$
  SELECT c.id, p.username, p.league_titles, p.avatar_url
  FROM public.clubs c
  JOIN public.profiles p ON p.id = c.user_id
  WHERE c.id = ANY(p_club_ids);
$$ LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE;

GRANT EXECUTE ON FUNCTION public.get_club_owner_usernames(uuid[]) TO authenticated;
