-- New premium currency ("Elmas"/Diamonds), purchased with real money via
-- iOS StoreKit. Lives on profiles (not clubs) so it survives
-- leave_current_club() - a user who paid real money for it keeps it even
-- if they leave their club, exactly like league_titles.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS diamonds BIGINT NOT NULL DEFAULT 0;

-- Catalog of player packs purchasable with diamonds. A public read-only
-- reference table (like a price list) rather than hardcoded in application
-- code, so costs/ranges can be tuned without a code deploy.
CREATE TABLE IF NOT EXISTS public.player_packs (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  diamond_cost INT NOT NULL,
  guaranteed_min_ability INT NOT NULL,
  random_min_ability INT NOT NULL,
  random_max_ability INT NOT NULL,
  random_slot_count INT NOT NULL DEFAULT 2,
  sort_order INT NOT NULL DEFAULT 0
);

INSERT INTO public.player_packs (id, name, diamond_cost, guaranteed_min_ability, random_min_ability, random_max_ability, random_slot_count, sort_order)
VALUES
  ('silver', 'Gümüş Paket', 100, 80, 65, 75, 2, 1),
  ('gold', 'Altın Paket', 300, 85, 70, 80, 2, 2),
  ('diamond', 'Elmas Paket', 800, 90, 75, 85, 2, 3)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  diamond_cost = EXCLUDED.diamond_cost,
  guaranteed_min_ability = EXCLUDED.guaranteed_min_ability,
  random_min_ability = EXCLUDED.random_min_ability,
  random_max_ability = EXCLUDED.random_max_ability,
  random_slot_count = EXCLUDED.random_slot_count,
  sort_order = EXCLUDED.sort_order;

ALTER TABLE public.player_packs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS player_packs_select_policy ON public.player_packs;
CREATE POLICY player_packs_select_policy ON public.player_packs FOR SELECT USING (true);

-- Catalog mapping an App Store product ID to how many diamonds it grants.
-- Real prices are NOT stored here - StoreKit is the source of truth for
-- localized pricing; this table only needs to know the diamond payout.
CREATE TABLE IF NOT EXISTS public.diamond_products (
  product_id TEXT PRIMARY KEY,
  diamonds INT NOT NULL,
  label TEXT NOT NULL,
  bonus_note TEXT,
  sort_order INT NOT NULL DEFAULT 0
);

INSERT INTO public.diamond_products (product_id, diamonds, label, bonus_note, sort_order)
VALUES
  ('com.melih.tacticaleleven.diamonds_100', 100, '100 Elmas', NULL, 1),
  ('com.melih.tacticaleleven.diamonds_550', 550, '550 Elmas', '+50 bonus', 2),
  ('com.melih.tacticaleleven.diamonds_1200', 1200, '1200 Elmas', '+200 bonus', 3),
  ('com.melih.tacticaleleven.diamonds_3100', 3100, '3100 Elmas', '+600 bonus', 4)
ON CONFLICT (product_id) DO UPDATE SET
  diamonds = EXCLUDED.diamonds,
  label = EXCLUDED.label,
  bonus_note = EXCLUDED.bonus_note,
  sort_order = EXCLUDED.sort_order;

ALTER TABLE public.diamond_products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS diamond_products_select_policy ON public.diamond_products;
CREATE POLICY diamond_products_select_policy ON public.diamond_products FOR SELECT USING (true);

-- Processed App Store transactions, keyed by Apple's transaction_id, so a
-- retried/duplicate client verification call (network retry, restored
-- purchase replay) can never credit diamonds twice for the same payment.
CREATE TABLE IF NOT EXISTS public.iap_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL,
  transaction_id TEXT NOT NULL UNIQUE,
  diamonds_credited INT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS iap_transactions_user_idx ON public.iap_transactions(user_id);

ALTER TABLE public.iap_transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS iap_transactions_select_policy ON public.iap_transactions;
CREATE POLICY iap_transactions_select_policy ON public.iap_transactions
FOR SELECT USING (user_id = auth.uid());
-- No INSERT/UPDATE policy for authenticated users - only the
-- verify_iap_purchase Edge Function (service role, bypasses RLS) writes
-- here, after independently verifying the receipt with Apple.
