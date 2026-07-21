-- Social reward is now Instagram-follow only - the X/TikTok/engagement
-- branches are dropped since the UI no longer offers them (profile_screen
-- removed those buttons in the same change). Their _followed/_claimed
-- columns on profiles are left in place (harmless, avoids a data-loss
-- migration for a boolean nobody reads anymore) - only the RPC's
-- reachable branches shrink.
CREATE OR REPLACE FUNCTION public.claim_social_reward(p_platform TEXT)
RETURNS public.profiles AS $$
DECLARE
  u_id UUID := auth.uid();
  profile_row public.profiles%ROWTYPE;
BEGIN
  IF u_id IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated';
  END IF;

  SELECT * INTO profile_row FROM public.profiles WHERE id = u_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profil bulunamadı';
  END IF;

  IF p_platform = 'instagram' THEN
    IF profile_row.social_instagram_followed THEN
      RAISE EXCEPTION 'Bu ödül zaten alındı.';
    END IF;
    UPDATE public.profiles SET social_instagram_followed = true, diamonds = diamonds + 20 WHERE id = u_id RETURNING * INTO profile_row;
  ELSE
    RAISE EXCEPTION 'Bilinmeyen platform.';
  END IF;

  RETURN profile_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
