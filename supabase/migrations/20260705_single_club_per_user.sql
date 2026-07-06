CREATE UNIQUE INDEX IF NOT EXISTS clubs_user_id_unique_partial
ON public.clubs (user_id)
WHERE user_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.claim_club(club_id UUID)
RETURNS public.clubs AS $$
DECLARE
  updated_row public.clubs;
  current_user_id UUID := auth.uid();
  owned_club_id UUID;
BEGIN
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot claim club';
  END IF;

  SELECT id INTO owned_club_id
  FROM public.clubs
  WHERE user_id = current_user_id
  LIMIT 1;

  IF FOUND THEN
    RAISE EXCEPTION 'This user already owns a club';
  END IF;

  UPDATE public.clubs
  SET user_id = current_user_id
  WHERE id = club_id
    AND user_id IS NULL
  RETURNING * INTO updated_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Kulüp bulunamadı veya zaten sahiplenilmiş.';
  END IF;

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, row_security = off;
