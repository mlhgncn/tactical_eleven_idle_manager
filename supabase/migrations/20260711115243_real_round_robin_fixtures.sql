-- Eski fikstür üretimi her gün kulüpleri BAĞIMSIZ rastgele eşleştiriyordu
-- (önceki günlerin hafızası yok) - bu yüzden bazı kulüp çiftleri sezonda
-- 4-5 kez oynuyor, bazıları hiç oynamıyordu. Bunun yerine standart "circle
-- method" round-robin algoritmasıyla gerçek bir lig fikstürü üretiyoruz:
-- her kulüp her diğer kulüple TAM 1 kez (tek devre), sonra ev sahibi/
-- deplasman ters çevrilerek 2. kez (çift devre) eşleşiyor - 18 kulüp için
-- toplam 34 gün/hafta, standart bir lig sezonu uzunluğu.
CREATE OR REPLACE FUNCTION public.generate_season_fixtures_for_league(p_league_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  season_id_var UUID;
  season_number INT;
  club_ids UUID[];
  n INT;
  half INT;
  single_rounds INT;
  round_no INT;
  day_no INT;
  i INT;
  home_id UUID;
  away_id UUID;
  last_elem UUID;
  season_start TIMESTAMPTZ := (date_trunc('day', now() AT TIME ZONE 'Europe/Istanbul') + interval '21 hours') AT TIME ZONE 'Europe/Istanbul';
BEGIN
  IF season_start <= now() THEN
    season_start := season_start + interval '1 day';
  END IF;

  SELECT count(*) + 1 INTO season_number FROM public.seasons WHERE league_id = p_league_id;

  INSERT INTO public.seasons (league_id, name, start_date, current_week, is_active)
  VALUES (p_league_id, season_number || '. Sezon', season_start, 1, true)
  RETURNING id INTO season_id_var;

  INSERT INTO public.league_standings (season_id, club_id, played, wins, draws, losses, goals_for, goals_against, goal_difference, points, position)
  SELECT season_id_var, id, 0, 0, 0, 0, 0, 0, 0, 0, NULL
  FROM public.clubs WHERE league_id = p_league_id
  ON CONFLICT (season_id, club_id) DO NOTHING;

  SELECT array_agg(id ORDER BY random()) INTO club_ids FROM public.clubs WHERE league_id = p_league_id;
  n := COALESCE(array_length(club_ids, 1), 0);

  IF n < 2 THEN
    UPDATE public.leagues SET season_generated = true WHERE id = p_league_id;
    RETURN;
  END IF;

  -- Tek sayıda kulüp varsa NULL bir "bye" ekleyip çift sayıya tamamla -
  -- o turda NULL ile eşleşen kulüp maç oynamaz.
  IF n % 2 = 1 THEN
    club_ids := array_append(club_ids, NULL);
    n := n + 1;
  END IF;

  half := n / 2;
  single_rounds := n - 1;

  -- Tek devre: circle method. club_ids[1] sabit kalır, geri kalanlar her
  -- turda 1 pozisyon döner.
  FOR round_no IN 1..single_rounds LOOP
    day_no := round_no;

    FOR i IN 1..half LOOP
      home_id := club_ids[i];
      away_id := club_ids[n + 1 - i];

      IF home_id IS NOT NULL AND away_id IS NOT NULL THEN
        IF round_no % 2 = 0 THEN
          INSERT INTO public.matches (league_id, season_id, week, home_club_id, away_club_id, match_date, is_played)
          VALUES (p_league_id, season_id_var, day_no, away_id, home_id, season_start + (day_no - 1) * interval '1 day', false);
        ELSE
          INSERT INTO public.matches (league_id, season_id, week, home_club_id, away_club_id, match_date, is_played)
          VALUES (p_league_id, season_id_var, day_no, home_id, away_id, season_start + (day_no - 1) * interval '1 day', false);
        END IF;
      END IF;
    END LOOP;

    -- club_ids[2..n] dizisini 1 pozisyon sağa döndür (club_ids[1] sabit).
    last_elem := club_ids[n];
    FOR i IN REVERSE n..3 LOOP
      club_ids[i] := club_ids[i - 1];
    END LOOP;
    club_ids[2] := last_elem;
  END LOOP;

  -- Çift devre: tek devrenin tüm maçlarını ev sahibi/deplasman ters
  -- çevrilmiş olarak, sonraki günlere kaydırarak tekrar ekle.
  FOR round_no IN 1..single_rounds LOOP
    day_no := single_rounds + round_no;
    INSERT INTO public.matches (league_id, season_id, week, home_club_id, away_club_id, match_date, is_played)
    SELECT p_league_id, season_id_var, day_no, m.away_club_id, m.home_club_id,
           season_start + (day_no - 1) * interval '1 day', false
    FROM public.matches m
    WHERE m.season_id = season_id_var AND m.week = round_no;
  END LOOP;

  UPDATE public.leagues SET season_generated = true WHERE id = p_league_id;
END;
$function$;
