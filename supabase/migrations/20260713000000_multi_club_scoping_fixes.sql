-- Batch of "which of the user's clubs does this RPC act on" fixes. Several
-- RPCs resolve the caller's club via a bare
-- `SELECT id FROM clubs WHERE user_id = auth.uid() LIMIT 1` with no way to
-- specify which club, picking an arbitrary one (typically the oldest) once
-- a user owns more than one club (multi-league support). This silently
-- breaks any of these actions for a 2nd+ club - most visibly
-- scout_opponent, which raised "Bu maçın tarafı değilsiniz" for the 2nd
-- club's own upcoming match because it kept checking the match against the
-- FIRST club instead. Each function below adds an optional p_club_id
-- parameter (defaulting to the old LIMIT-1 behavior so existing callers
-- that don't pass one still work), matching the pattern already used by
-- hide_tactics_for_next_match/send_team_to_camp/sign_free_agent etc.

-- scout_opponent
CREATE OR REPLACE FUNCTION public.scout_opponent(p_match_id UUID, p_club_id UUID DEFAULT NULL)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  match_row public.matches%ROWTYPE;
  caller_club_id UUID;
  opponent_club_id_var UUID;
  result JSON;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot scout an opponent';
  END IF;

  IF p_club_id IS NOT NULL THEN
    SELECT id INTO caller_club_id FROM public.clubs WHERE id = p_club_id AND user_id = auth.uid();
  ELSE
    SELECT id INTO caller_club_id FROM public.clubs WHERE user_id = auth.uid() LIMIT 1;
  END IF;
  IF caller_club_id IS NULL THEN
    RAISE EXCEPTION 'Bir kulübünüz yok';
  END IF;

  SELECT * INTO match_row FROM public.matches WHERE id = p_match_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Maç bulunamadı';
  END IF;

  IF match_row.home_club_id != caller_club_id AND match_row.away_club_id != caller_club_id THEN
    RAISE EXCEPTION 'Bu maçın tarafı değilsiniz';
  END IF;

  IF match_row.is_played THEN
    RAISE EXCEPTION 'Bu maç zaten oynandı';
  END IF;

  IF match_row.match_date <= now() + interval '15 minutes' THEN
    RAISE EXCEPTION 'Rakip kadrosu maça 15 dakikadan az kala görüntülenemez';
  END IF;

  opponent_club_id_var := CASE
    WHEN match_row.home_club_id = caller_club_id THEN match_row.away_club_id
    ELSE match_row.home_club_id
  END;

  SELECT json_build_object(
    'club_id', opponent_club_id_var,
    'players', (
      SELECT COALESCE(json_agg(json_build_object(
        'id', p.id,
        'name', p.name,
        'position', p.position,
        'age', p.age,
        'current_ability', p.current_ability,
        'is_suspended', p.is_suspended,
        'injury_duration_weeks', p.injury_duration_weeks
      )), '[]'::json)
      FROM public.players p WHERE p.club_id = opponent_club_id_var
    ),
    'tactics', (
      SELECT row_to_json(t) FROM (
        SELECT formation, mentality, starting_eleven_ids, press_intensity, tempo,
               defensive_line, offside_trap, time_wasting
        FROM public.tactics WHERE club_id = opponent_club_id_var
      ) t
    )
  ) INTO result;

  RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.scout_opponent(UUID, UUID) TO authenticated;
