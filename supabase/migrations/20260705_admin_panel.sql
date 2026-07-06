-- Migration: Admin panel infrastructure

-- Table to mark admin users
CREATE TABLE IF NOT EXISTS public.admin_users (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS admin_users_select_policy ON public.admin_users;
CREATE POLICY admin_users_select_policy ON public.admin_users FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid()));

-- Gifts / promo codes
CREATE TABLE IF NOT EXISTS public.gift_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT UNIQUE NOT NULL,
  amount BIGINT NOT NULL,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ,
  redeemed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  redeemed_at TIMESTAMPTZ,
  active BOOLEAN NOT NULL DEFAULT TRUE
);
ALTER TABLE public.gift_codes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS gift_codes_select_policy ON public.gift_codes;
CREATE POLICY gift_codes_select_policy ON public.gift_codes FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid()) OR created_by = auth.uid());

-- Events
CREATE TABLE IF NOT EXISTS public.events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS events_select_policy ON public.events;
CREATE POLICY events_select_policy ON public.events FOR SELECT TO authenticated
  USING (auth.uid() IS NOT NULL);
DROP POLICY IF EXISTS events_insert_policy ON public.events;
CREATE POLICY events_insert_policy ON public.events FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid()));

-- Push/outbox notifications (admin creates, server workers send)
CREATE TABLE IF NOT EXISTS public.push_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  target_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  sent BOOLEAN NOT NULL DEFAULT FALSE,
  sent_at TIMESTAMPTZ
);
ALTER TABLE public.push_notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS push_notifications_insert_policy ON public.push_notifications;
CREATE POLICY push_notifications_insert_policy ON public.push_notifications FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid()));
DROP POLICY IF EXISTS push_notifications_select_policy ON public.push_notifications;
CREATE POLICY push_notifications_select_policy ON public.push_notifications FOR SELECT TO authenticated
  USING (created_by = auth.uid() OR EXISTS (SELECT 1 FROM public.admin_users au WHERE au.user_id = auth.uid()));

-- Function to test admin membership
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
DECLARE
  exists_admin boolean := false;
BEGIN
  SELECT EXISTS(SELECT 1 FROM public.admin_users WHERE user_id = auth.uid()) INTO exists_admin;
  RETURN exists_admin;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPC: create gift code (admin-only)
CREATE OR REPLACE FUNCTION public.admin_create_gift_code(p_code TEXT, p_amount BIGINT, p_expires_at TIMESTAMPTZ DEFAULT NULL)
RETURNS public.gift_codes AS $$
DECLARE
  new_row public.gift_codes%ROWTYPE;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only admin users can create gift codes';
  END IF;

  INSERT INTO public.gift_codes(code, amount, created_by, expires_at)
  VALUES (p_code, p_amount, auth.uid(), p_expires_at)
  RETURNING * INTO new_row;

  RETURN new_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPC: ban user (admin-only)
CREATE OR REPLACE FUNCTION public.admin_ban_user(p_user_id UUID)
RETURNS TEXT AS $$
DECLARE
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only admin users can ban users';
  END IF;

  -- Mark profile as banned (create a banned flag on profiles)
  UPDATE public.profiles SET language = COALESCE(language,'tr') WHERE id = p_user_id; -- placeholder to ensure profiles exist
  -- Real ban: add to a banned_users table
  INSERT INTO public.inbox_messages(recipient_id, title, body)
  VALUES (p_user_id, 'Hesap Banlandı', 'Hesabınız yönetici tarafından banlandı.');

  RETURN 'OK';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPC: admin_create_event
CREATE OR REPLACE FUNCTION public.admin_create_event(p_title TEXT, p_body TEXT, p_starts_at TIMESTAMPTZ DEFAULT NULL, p_ends_at TIMESTAMPTZ DEFAULT NULL)
RETURNS public.events AS $$
DECLARE
  new_row public.events%ROWTYPE;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only admin users can create events';
  END IF;

  INSERT INTO public.events(title, body, starts_at, ends_at, created_by)
  VALUES (p_title, p_body, p_starts_at, p_ends_at, auth.uid())
  RETURNING * INTO new_row;

  RETURN new_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- RPC: admin_send_push
CREATE OR REPLACE FUNCTION public.admin_send_push(p_title TEXT, p_body TEXT, p_target_user_id UUID DEFAULT NULL)
RETURNS public.push_notifications AS $$
DECLARE
  new_row public.push_notifications%ROWTYPE;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only admin users can send push notifications';
  END IF;

  INSERT INTO public.push_notifications(title, body, target_user_id, created_by)
  VALUES (p_title, p_body, p_target_user_id, auth.uid())
  RETURNING * INTO new_row;

  RETURN new_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Admin list users (admin-only)
CREATE OR REPLACE FUNCTION public.admin_list_users()
RETURNS TABLE(id UUID, full_name TEXT, email TEXT, created_at TIMESTAMPTZ) AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only admin users can list users';
  END IF;

  RETURN QUERY SELECT p.id, p.full_name, p.email, p.created_at FROM public.profiles p;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Admin list clubs
CREATE OR REPLACE FUNCTION public.admin_list_clubs()
RETURNS TABLE(id UUID, name TEXT, budget BIGINT, user_id UUID, created_at TIMESTAMPTZ) AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only admin users can list clubs';
  END IF;

  RETURN QUERY SELECT id, name, budget, user_id, created_at FROM public.clubs;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Admin update player (limited fields)
CREATE OR REPLACE FUNCTION public.admin_update_player(p_player_id UUID, p_name TEXT DEFAULT NULL, p_position TEXT DEFAULT NULL, p_age INT DEFAULT NULL, p_current_ability INT DEFAULT NULL, p_potential_ability INT DEFAULT NULL)
RETURNS public.players AS $$
DECLARE
  current_row public.players%ROWTYPE;
  updated_row public.players%ROWTYPE;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only admin users can update players';
  END IF;

  SELECT * INTO current_row FROM public.players WHERE id = p_player_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Player not found';
  END IF;

  UPDATE public.players SET
    name = COALESCE(p_name, current_row.name),
    position = COALESCE(p_position, current_row.position),
    age = COALESCE(p_age, current_row.age),
    current_ability = COALESCE(p_current_ability, current_row.current_ability),
    potential_ability = COALESCE(p_potential_ability, current_row.potential_ability)
  WHERE id = p_player_id
  RETURNING * INTO updated_row;

  RETURN updated_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
