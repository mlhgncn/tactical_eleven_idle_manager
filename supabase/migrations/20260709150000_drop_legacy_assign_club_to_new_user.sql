-- This old trigger (predating the OSM league work entirely) auto-assigned
-- the first unclaimed club to every new auth.users signup, completely
-- bypassing the create-league/join-league onboarding screen - a brand new
-- user landed straight in an existing bot club instead of ever seeing the
-- "Lig Oluştur" / "Lige Katıl" choice.
DROP TRIGGER IF EXISTS assign_club_to_new_user_trigger ON auth.users;
DROP FUNCTION IF EXISTS public.assign_club_to_new_user();
