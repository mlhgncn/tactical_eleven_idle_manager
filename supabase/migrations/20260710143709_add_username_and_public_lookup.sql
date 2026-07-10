-- Item: signup collects a username; standings/fixtures show it next to
-- real users' club names. profiles has RLS `id = auth.uid()` (users can
-- only read their OWN row), so a plain embedded PostgREST select
-- (clubs -> profiles) would return null for every other user's club.
-- Rather than loosening profiles' row policy (which would also expose
-- email/diamonds/fcm_token to every other user), expose only the
-- club_id -> username pairing via a narrow SECURITY DEFINER function.

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS username text;
CREATE UNIQUE INDEX IF NOT EXISTS profiles_username_unique_idx
  ON public.profiles (lower(username)) WHERE username IS NOT NULL;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, email, language, username)
  VALUES (NEW.id, NEW.email, 'tr', NEW.raw_user_meta_data->>'username')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.get_club_owner_usernames(p_club_ids uuid[])
RETURNS TABLE(club_id uuid, username text) AS $$
  SELECT c.id, p.username
  FROM public.clubs c
  JOIN public.profiles p ON p.id = c.user_id
  WHERE c.id = ANY(p_club_ids) AND p.username IS NOT NULL;
$$ LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE;

GRANT EXECUTE ON FUNCTION public.get_club_owner_usernames(uuid[]) TO authenticated;
