-- Apple requires in-app account deletion for any app with account creation
-- (App Review Guideline 5.1.1(v)). This lets a signed-in user permanently
-- delete their own account and everything tied to it.
--
-- IMPORTANT: verified live (not from schema.sql, which is stale here) that
-- clubs.user_id -> auth.users(id) is actually ON DELETE CASCADE, not SET
-- NULL. Deleting auth.users directly would therefore delete the user's
-- club outright - orphaning its matches (home/away FKs go SET NULL),
-- destroying its league_standings row (club_id is that table's PK, so it
-- cascades), and leaving the rest of the league's fixture list with holes.
-- That's a much bigger blast radius than the existing leave_current_club()
-- flow, which deliberately keeps the club alive under bot control instead.
-- So: release the club the same way leave_current_club() does BEFORE
-- deleting auth.users, so the CASCADE has nothing left to destroy.
--
-- The rest of the cascade is fine as-is:
--   - public.profiles(id)              -> auth.users(id) ON DELETE CASCADE
--   - public.iap_transactions(user_id) -> auth.users(id) ON DELETE CASCADE
--   - public.inbox_messages(recipient_id) -> auth.users(id) ON DELETE CASCADE
--   - public.admin_* (created_by/redeemed_by/target_user_id) -> ON DELETE SET NULL
--
-- auth.users can't be deleted directly by the `authenticated` role (no
-- DELETE grant, and RLS wouldn't apply anyway since it's not one of "our"
-- tables) - SECURITY DEFINER runs as the function owner, which has the
-- necessary privilege.
CREATE OR REPLACE FUNCTION public.delete_own_account()
RETURNS void AS $$
DECLARE
  calling_user_id UUID := auth.uid();
BEGIN
  IF calling_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot delete an account';
  END IF;

  UPDATE public.clubs SET user_id = NULL WHERE user_id = calling_user_id;

  DELETE FROM auth.users WHERE id = calling_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth;

GRANT EXECUTE ON FUNCTION public.delete_own_account() TO authenticated;
