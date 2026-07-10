-- "Aynı anda her mevkiden sadece bir oyuncu geliştirme yapılabilsin":
-- at most 1 in-progress player development per position group
-- (GK/DEF/MID/FWD) per club at a time. position_group_of mirrors
-- lib/models/player_fm.dart's positionGroup getter exactly, so the
-- server-side grouping matches what the client already shows.
CREATE OR REPLACE FUNCTION public.position_group_of(p_position text)
RETURNS text AS $$
DECLARE
  upper_pos text := upper(p_position);
BEGIN
  IF upper_pos = 'GK' THEN RETURN 'GK'; END IF;
  IF upper_pos ~ '^(CB|LB|RB|WB|LWB|RWB|FB)' THEN RETURN 'DEF'; END IF;
  IF upper_pos ~ '^(CM|CDM|CAM|LM|RM|DM|AM)' THEN RETURN 'MID'; END IF;
  IF upper_pos ~ '^(ST|CF|LW|RW|LF|RF)' THEN RETURN 'FWD'; END IF;
  RETURN 'MID';
END;
$$ LANGUAGE plpgsql IMMUTABLE SET search_path = public;

CREATE OR REPLACE FUNCTION public.start_player_development(p_player_id uuid)
 RETURNS players
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  player_row public.players%ROWTYPE;
  owner_club_id UUID;
  target_group text;
  conflicting_player_name text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot start player development';
  END IF;

  SELECT id INTO owner_club_id FROM public.clubs WHERE user_id = auth.uid() LIMIT 1;

  SELECT * INTO player_row
  FROM public.players
  WHERE id = p_player_id
    AND club_id = owner_club_id;

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
  WHERE club_id = owner_club_id
    AND id != p_player_id
    AND development_completes_at IS NOT NULL
    AND development_completes_at > now()
    AND public.position_group_of(position) = target_group
  LIMIT 1;

  IF conflicting_player_name IS NOT NULL THEN
    RAISE EXCEPTION 'Bu mevki grubunda zaten bir gelişim sürüyor (%).', conflicting_player_name;
  END IF;

  UPDATE public.players
  SET development_completes_at = now() + interval '2 hours'
  WHERE id = p_player_id
  RETURNING * INTO player_row;

  RETURN player_row;
END;
$function$;
