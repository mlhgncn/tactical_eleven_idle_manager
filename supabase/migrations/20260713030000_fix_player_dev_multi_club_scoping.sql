-- Three more "wrong club" bugs from the same family as scout_opponent:
-- start_player_development and reduce_player_development_time_with_ad
-- both resolved "the caller's club" via a bare
-- `SELECT id FROM clubs WHERE user_id = auth.uid() LIMIT 1` and then
-- checked `players.club_id = that_club_id` - so for a user with 2+ clubs,
-- calling either on a player belonging to their 2nd+ club would resolve
-- owner_club_id to the WRONG (typically oldest) club, the club_id
-- comparison would never match, and the call would fail with "Player not
-- found or not owned by current user's club" even though the player is
-- correctly owned by the user, just via a different club. Since both
-- functions already take p_player_id, the fix is to derive the owning
-- club directly from the player row instead of guessing - no new
-- parameter needed, and no ambiguity possible since a player belongs to
-- exactly one club.
--
-- open_player_pack has the same LIMIT-1 pattern but can't derive a club
-- from a player (it's creating new players, not modifying one) - gets an
-- optional p_club_id instead, same pattern as sign_free_agent etc.

CREATE OR REPLACE FUNCTION public.start_player_development(p_player_id UUID)
RETURNS public.players AS $$
DECLARE
  player_row public.players%ROWTYPE;
  target_group text;
  conflicting_player_name text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot start player development';
  END IF;

  SELECT p.* INTO player_row
  FROM public.players p
  JOIN public.clubs c ON c.id = p.club_id
  WHERE p.id = p_player_id AND c.user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Player not found or not owned by current user''s club';
  END IF;

  IF player_row.development_completes_at IS NOT NULL AND player_row.development_completes_at > now() THEN
    RAISE EXCEPTION 'Player development already in progress';
  END IF;

  IF player_row.current_ability >= player_row.potential_ability THEN
    RAISE EXCEPTION 'Player has already reached their potential';
  END IF;

  target_group := public.position_group_of(player_row.position);

  SELECT name INTO conflicting_player_name
  FROM public.players
  WHERE club_id = player_row.club_id
    AND id != p_player_id
    AND development_completes_at IS NOT NULL
    AND development_completes_at > now()
    AND public.position_group_of(position) = target_group
  LIMIT 1;

  IF conflicting_player_name IS NOT NULL THEN
    RAISE EXCEPTION 'Bu mevki grubunda zaten bir gelişim sürüyor (%).', conflicting_player_name;
  END IF;

  UPDATE public.players
  SET development_completes_at = now() + interval '2 hours',
      development_ad_uses = 0
  WHERE id = p_player_id
  RETURNING * INTO player_row;

  RETURN player_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.reduce_player_development_time_with_ad(p_player_id UUID)
RETURNS public.players AS $$
DECLARE
  player_row public.players%ROWTYPE;
  remaining INTERVAL;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot reduce development time';
  END IF;

  SELECT p.* INTO player_row
  FROM public.players p
  JOIN public.clubs c ON c.id = p.club_id
  WHERE p.id = p_player_id AND c.user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Player not found or not owned by current user''s club';
  END IF;

  IF player_row.development_completes_at IS NULL OR player_row.development_completes_at <= now() THEN
    RAISE EXCEPTION 'No active development to speed up';
  END IF;

  IF player_row.development_ad_uses >= 2 THEN
    RAISE EXCEPTION 'Bu gelişim için reklam hakkınız kalmadı (en fazla 2 kez).';
  END IF;

  remaining := player_row.development_completes_at - now();

  UPDATE public.players
  SET development_completes_at = now() + (remaining * 0.75),
      development_ad_uses = development_ad_uses + 1
  WHERE id = p_player_id
  RETURNING * INTO player_row;

  RETURN player_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.open_player_pack(p_pack_id TEXT, p_club_id UUID DEFAULT NULL)
RETURNS SETOF public.players AS $$
DECLARE
  buyer_club_id UUID;
  pack_row public.player_packs%ROWTYPE;
  current_diamonds BIGINT;
  i INT;
  new_player public.players;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot open a pack';
  END IF;

  IF p_club_id IS NOT NULL THEN
    SELECT id INTO buyer_club_id FROM public.clubs WHERE id = p_club_id AND user_id = auth.uid();
  ELSE
    SELECT id INTO buyer_club_id FROM public.clubs WHERE user_id = auth.uid() LIMIT 1;
  END IF;
  IF buyer_club_id IS NULL THEN
    RAISE EXCEPTION 'User does not own a club';
  END IF;

  SELECT * INTO pack_row FROM public.player_packs WHERE id = p_pack_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unknown pack';
  END IF;

  SELECT diamonds INTO current_diamonds FROM public.profiles WHERE id = auth.uid() FOR UPDATE;
  IF current_diamonds IS NULL OR current_diamonds < pack_row.diamond_cost THEN
    RAISE EXCEPTION 'Yetersiz elmas bakiyesi';
  END IF;

  UPDATE public.profiles SET diamonds = diamonds - pack_row.diamond_cost WHERE id = auth.uid();

  new_player := public._insert_generated_player(buyer_club_id, pack_row.guaranteed_min_ability, 99);
  RETURN NEXT new_player;

  FOR i IN 1..pack_row.random_slot_count LOOP
    new_player := public._insert_generated_player(buyer_club_id, pack_row.random_min_ability, pack_row.random_max_ability);
    RETURN NEXT new_player;
  END LOOP;

  RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.start_player_development(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reduce_player_development_time_with_ad(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.open_player_pack(TEXT, UUID) TO authenticated;
