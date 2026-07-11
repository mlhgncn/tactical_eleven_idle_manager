-- Lets a club preview their upcoming opponent's squad + tactics, but only
-- once kickoff is within 15 minutes (not before) and only for a match
-- they're actually a participant in. players/tactics RLS stays untouched
-- (owner-only) - this is a narrow, time-boxed SECURITY DEFINER door instead
-- of loosening those policies, which would be much harder to scope
-- correctly for "only within 15 minutes of this specific match".
--
-- Deliberately returns only basic player info (name/position/age/CA/
-- injury/suspension) - not the full attribute breakdown (finishing/
-- passing/tackling/etc) - to avoid making scouting too powerful.
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

  IF match_row.match_date > now() + interval '15 minutes' THEN
    RAISE EXCEPTION 'Rakip kadrosu maça 15 dakika kalana kadar görüntülenemez';
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
