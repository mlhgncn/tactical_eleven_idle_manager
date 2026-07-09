-- Sponsor upgrades used to complete instantly. Make them take time,
-- escalating by level (1/3/5/7 days as level goes 1->2->3->4->5), capped
-- at the existing max level 5. Cost formula unchanged (only item 8, club
-- development, asked for a higher cost).
ALTER TABLE public.clubs
  ADD COLUMN IF NOT EXISTS sponsor_upgrade_completes_at TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION public.upgrade_sponsor(club_id UUID)
RETURNS public.clubs AS $$
DECLARE
  current_club public.clubs%ROWTYPE;
  updated_row public.clubs;
  new_budget BIGINT;
  duration_days INT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot upgrade sponsor';
  END IF;

  SELECT * INTO current_club
  FROM public.clubs
  WHERE id = club_id
    AND user_id = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Club not found or not owned by current user';
  END IF;

  IF current_club.sponsor_level >= 5 THEN
    RAISE EXCEPTION 'Sponsor level cannot exceed 5';
  END IF;

  IF current_club.sponsor_upgrade_completes_at IS NOT NULL AND current_club.sponsor_upgrade_completes_at > now() THEN
    RAISE EXCEPTION 'Sponsor upgrade already in progress';
  END IF;

  new_budget := current_club.budget - (5000 * current_club.sponsor_level);
  IF new_budget < 0 THEN
    RAISE EXCEPTION 'Not enough budget to upgrade sponsor';
  END IF;

  -- 1, 3, 5, 7 days for levels 1->2, 2->3, 3->4, 4->5.
  duration_days := 2 * current_club.sponsor_level - 1;

  UPDATE public.clubs
  SET budget = new_budget,
      sponsor_upgrade_completes_at = now() + make_interval(days => duration_days)
  WHERE id = club_id
  RETURNING * INTO updated_row;

  INSERT INTO public.financial_transactions(club_id, type, amount, description, source)
  VALUES (
    club_id,
    'upgrade_sponsor',
    -(5000 * current_club.sponsor_level),
    format('Sponsor yükseltme harcaması: -%s GP (%s gün sürecek)', 5000 * current_club.sponsor_level, duration_days),
    'upgrade_sponsor'
  );

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.process_sponsor_upgrades()
RETURNS void AS $$
DECLARE
  club_row public.clubs%ROWTYPE;
  new_level INT;
BEGIN
  FOR club_row IN
    SELECT * FROM public.clubs
    WHERE sponsor_upgrade_completes_at IS NOT NULL AND sponsor_upgrade_completes_at <= now()
  LOOP
    new_level := LEAST(5, club_row.sponsor_level + 1);

    UPDATE public.clubs
    SET sponsor_level = new_level,
        sponsor_upgrade_completes_at = NULL
    WHERE id = club_row.id;

    IF club_row.user_id IS NOT NULL THEN
      INSERT INTO public.inbox_messages(recipient_id, title, body, is_read, created_at)
      VALUES (
        club_row.user_id,
        'Sponsor Anlaşması',
        format('Sponsor seviyesi %s''e yükseltildi! Yeni aylık gelir: %s GP', new_level, new_level * 1000),
        false,
        now()
      );
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
