-- CI trigger: update to force supabase_deploy.yml push
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS current_ability INT DEFAULT 50;
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS potential_ability INT DEFAULT 75;
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS age INT DEFAULT 22;
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS morale INT DEFAULT 75;
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS fitness INT DEFAULT 100;
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS finishing INT DEFAULT 10;
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS passing INT DEFAULT 10;
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS tackling INT DEFAULT 10;
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS composure INT DEFAULT 10;
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS determination INT DEFAULT 10;
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS consistency INT DEFAULT 10;
ALTER TABLE public.players ADD COLUMN IF NOT EXISTS injury_proneness INT DEFAULT 5;

CREATE TABLE IF NOT EXISTS public.tactics (
    club_id UUID REFERENCES public.clubs(id) ON DELETE CASCADE PRIMARY KEY,
    formation TEXT NOT NULL DEFAULT 'f442',
    mentality TEXT NOT NULL DEFAULT 'balanced',
    captain_id UUID REFERENCES public.players(id) ON DELETE SET NULL,
    penalty_taker_id UUID REFERENCES public.players(id) ON DELETE SET NULL
);

ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS budget BIGINT DEFAULT 10000000;
ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS stadium_capacity INT DEFAULT 15000;
ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS ticket_price INT DEFAULT 20;
ALTER TABLE public.clubs ADD COLUMN IF NOT EXISTS training_facility_level INT DEFAULT 1;

ALTER TABLE IF EXISTS public.clubs
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE IF EXISTS public.clubs ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS clubs_select_policy
  ON public.clubs
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS clubs_insert_policy
  ON public.clubs
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS clubs_update_policy
  ON public.clubs
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS clubs_delete_policy
  ON public.clubs
  FOR DELETE
  USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.assign_club_to_new_user()
RETURNS trigger AS $$
BEGIN
  UPDATE public.clubs
  SET user_id = NEW.id
  WHERE user_id IS NULL
  ORDER BY id
  LIMIT 1;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS assign_club_to_new_user_trigger ON auth.users;
CREATE TRIGGER assign_club_to_new_user_trigger
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.assign_club_to_new_user();
