-- Second bug found while watching auto_resolve_matches run against the real
-- backlog: update_last_activity() references NEW.club_id, which is correct
-- for its financial_transactions trigger (that table has a club_id column)
-- but not for its matches trigger - matches only has home_club_id/
-- away_club_id, so every match UPDATE raised 'record "new" has no field
-- "club_id"' and rolled back, same failure mode as the trigger_webhook bug
-- just fixed. Split into a matches-specific function that updates both
-- clubs' last_activity_at, and repoint the matches trigger at it.
CREATE OR REPLACE FUNCTION public.update_last_activity_for_match()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.clubs
  SET last_activity_at = now()
  WHERE id IN (NEW.home_club_id, NEW.away_club_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_last_activity_on_match ON public.matches;
CREATE TRIGGER update_last_activity_on_match
AFTER UPDATE ON public.matches
FOR EACH ROW
WHEN (NEW.is_played = TRUE AND OLD.is_played = FALSE)
EXECUTE FUNCTION public.update_last_activity_for_match();
