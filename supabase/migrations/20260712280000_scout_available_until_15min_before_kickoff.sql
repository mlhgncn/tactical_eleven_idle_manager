-- Reversed scout_opponent's time gate: it used to only ALLOW scouting
-- inside the last 15 minutes before kickoff (RAISE EXCEPTION when
-- match_date > now() + 15min). The actual desired behavior is the
-- opposite - scouting should be available any time before a match, and
-- lock out only in the final 15 minutes once the match is about to start.
-- Also drops the report-persistence side effect added in
-- 20260712260000_persist_scout_reports.sql (scouted_reports insert +
-- list_scouted_reports RPC) since the "saved reports" screen that used it
-- was removed - scout_opponent is a plain live lookup again.
CREATE OR REPLACE FUNCTION public.scout_opponent(p_match_id UUID)
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

  SELECT id INTO caller_club_id FROM public.clubs WHERE user_id = auth.uid() LIMIT 1;
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

GRANT EXECUTE ON FUNCTION public.scout_opponent(UUID) TO authenticated;
