-- profiles was completely unpopulated in production (0 rows for 8 real
-- auth.users) - nothing ever created a row there. upsertProfile() exists
-- client-side but is never called from anywhere in the app. This silently
-- broke the league_titles trophy tracking just added (an UPDATE against a
-- nonexistent profile row is a no-op) and would also break any future
-- profile-editing screen. Add the standard auto-create-on-signup trigger
-- and backfill the existing users.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, email, language)
  VALUES (NEW.id, NEW.email, 'tr')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

INSERT INTO public.profiles (id, email, language)
SELECT id, email, 'tr' FROM auth.users
ON CONFLICT (id) DO NOTHING;
