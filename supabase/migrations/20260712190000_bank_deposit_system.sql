-- Module 5: Bank / interest-bearing deposit system. 4 banks, each with a
-- different risk/reward + liquidity tradeoff (higher interest = longer
-- lock-up, not "chance of losing money" - a manager game shouldn't punish
-- saving with an actual loss risk, the tradeoff is purely how long the
-- money is unavailable):
--   1. Emlak Bankası   - lowest rate, withdraw any time (no lock-up)
--   2. Ticaret Bankası - modest rate, 3-day lock-up
--   3. Yatırım Bankası - good rate, 7-day lock-up
--   4. Kartal Sermaye  - best rate, 14-day lock-up, highest min deposit
-- Interest accrues once per day (server day, via cron) on the current
-- balance of each active deposit - simple daily compounding.

CREATE TABLE IF NOT EXISTS public.banks (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  daily_interest_rate NUMERIC NOT NULL, -- e.g. 0.004 = 0.4%/day
  lock_up_days INT NOT NULL DEFAULT 0,
  min_deposit BIGINT NOT NULL,
  max_deposit BIGINT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0
);

INSERT INTO public.banks (id, name, daily_interest_rate, lock_up_days, min_deposit, max_deposit, sort_order) VALUES
  ('emlak', 'Emlak Bankası', 0.0015, 0, 1000, 500000, 1),
  ('ticaret', 'Ticaret Bankası', 0.0028, 3, 5000, 1500000, 2),
  ('yatirim', 'Yatırım Bankası', 0.0045, 7, 20000, 5000000, 3),
  ('kartal', 'Kartal Sermaye', 0.0065, 14, 100000, 20000000, 4)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  daily_interest_rate = EXCLUDED.daily_interest_rate,
  lock_up_days = EXCLUDED.lock_up_days,
  min_deposit = EXCLUDED.min_deposit,
  max_deposit = EXCLUDED.max_deposit,
  sort_order = EXCLUDED.sort_order;

ALTER TABLE public.banks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS banks_select_policy ON public.banks;
CREATE POLICY banks_select_policy ON public.banks FOR SELECT TO authenticated USING (true);

CREATE TABLE IF NOT EXISTS public.bank_deposits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id UUID NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  bank_id TEXT NOT NULL REFERENCES public.banks(id),
  principal BIGINT NOT NULL,
  balance BIGINT NOT NULL,
  deposited_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  unlocks_at TIMESTAMPTZ NOT NULL,
  last_interest_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  withdrawn_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS bank_deposits_club_idx ON public.bank_deposits(club_id) WHERE withdrawn_at IS NULL;

ALTER TABLE public.bank_deposits ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS bank_deposits_select_policy ON public.bank_deposits;
CREATE POLICY bank_deposits_select_policy ON public.bank_deposits FOR SELECT TO authenticated
USING (club_id IN (SELECT id FROM public.clubs WHERE user_id = auth.uid()));

-- Deposits/withdrawals only through SECURITY DEFINER RPCs below.
DROP POLICY IF EXISTS bank_deposits_insert_policy ON public.bank_deposits;
CREATE POLICY bank_deposits_insert_policy ON public.bank_deposits FOR INSERT TO authenticated WITH CHECK (false);
DROP POLICY IF EXISTS bank_deposits_update_policy ON public.bank_deposits;
CREATE POLICY bank_deposits_update_policy ON public.bank_deposits FOR UPDATE TO authenticated USING (false);

CREATE OR REPLACE FUNCTION public.deposit_to_bank(p_bank_id TEXT, p_amount BIGINT, p_club_id UUID DEFAULT NULL)
RETURNS public.bank_deposits AS $$
DECLARE
  club_row public.clubs%ROWTYPE;
  bank_row public.banks%ROWTYPE;
  new_row public.bank_deposits;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot deposit';
  END IF;

  IF p_club_id IS NOT NULL THEN
    SELECT * INTO club_row FROM public.clubs WHERE id = p_club_id AND user_id = auth.uid();
  ELSE
    SELECT * INTO club_row FROM public.clubs WHERE user_id = auth.uid() LIMIT 1;
  END IF;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User does not own a club';
  END IF;

  SELECT * INTO bank_row FROM public.banks WHERE id = p_bank_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unknown bank';
  END IF;

  IF p_amount < bank_row.min_deposit THEN
    RAISE EXCEPTION 'Minimum yatırım tutarı %s GP.', bank_row.min_deposit;
  END IF;
  IF p_amount > bank_row.max_deposit THEN
    RAISE EXCEPTION 'Maksimum yatırım tutarı %s GP.', bank_row.max_deposit;
  END IF;
  IF club_row.budget - club_row.blocked_budget < p_amount THEN
    RAISE EXCEPTION 'Yetersiz bakiye.';
  END IF;

  UPDATE public.clubs SET budget = budget - p_amount WHERE id = club_row.id;

  INSERT INTO public.bank_deposits (club_id, bank_id, principal, balance, unlocks_at)
  VALUES (club_row.id, p_bank_id, p_amount, p_amount, now() + (bank_row.lock_up_days::text || ' days')::interval)
  RETURNING * INTO new_row;

  INSERT INTO public.financial_transactions(club_id, type, amount, description, source)
  VALUES (club_row.id, 'expense', -p_amount, format('%s bankasına yatırım: -%s GP', bank_row.name, p_amount), 'bank_deposit');

  RETURN new_row;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION public.withdraw_from_bank(p_deposit_id UUID)
RETURNS public.clubs AS $$
DECLARE
  deposit_row public.bank_deposits%ROWTYPE;
  bank_row public.banks%ROWTYPE;
  updated_club public.clubs;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Unauthenticated user cannot withdraw';
  END IF;

  SELECT d.* INTO deposit_row
  FROM public.bank_deposits d
  JOIN public.clubs c ON c.id = d.club_id
  WHERE d.id = p_deposit_id AND c.user_id = auth.uid() AND d.withdrawn_at IS NULL
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Yatırım bulunamadı veya zaten çekilmiş.';
  END IF;

  IF deposit_row.unlocks_at > now() THEN
    RAISE EXCEPTION 'Bu yatırım %s tarihine kadar kilitli.', to_char(deposit_row.unlocks_at, 'DD.MM.YYYY HH24:MI');
  END IF;

  SELECT * INTO bank_row FROM public.banks WHERE id = deposit_row.bank_id;

  UPDATE public.bank_deposits SET withdrawn_at = now() WHERE id = p_deposit_id;
  UPDATE public.clubs SET budget = budget + deposit_row.balance WHERE id = deposit_row.club_id
  RETURNING * INTO updated_club;

  INSERT INTO public.financial_transactions(club_id, type, amount, description, source)
  VALUES (deposit_row.club_id, 'income', deposit_row.balance, format('%s bankasından çekim: +%s GP', COALESCE(bank_row.name, deposit_row.bank_id), deposit_row.balance), 'bank_withdrawal');

  RETURN updated_club;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Daily interest accrual - runs once per server day, adds
-- daily_interest_rate * balance to every active deposit's balance and
-- credits the total to the owning club's budget as inbox-notified income.
CREATE OR REPLACE FUNCTION public.process_bank_interest()
RETURNS void AS $$
DECLARE
  deposit_row RECORD;
  interest_amount BIGINT;
  total_by_club RECORD;
BEGIN
  FOR deposit_row IN
    SELECT d.id, d.club_id, d.balance, b.daily_interest_rate, b.name AS bank_name
    FROM public.bank_deposits d
    JOIN public.banks b ON b.id = d.bank_id
    WHERE d.withdrawn_at IS NULL AND d.last_interest_at <= now() - interval '1 day'
  LOOP
    interest_amount := GREATEST(1, ROUND(deposit_row.balance * deposit_row.daily_interest_rate));

    UPDATE public.bank_deposits
    SET balance = balance + interest_amount, last_interest_at = now()
    WHERE id = deposit_row.id;

    INSERT INTO public.financial_transactions(club_id, type, amount, description, source)
    VALUES (deposit_row.club_id, 'income', interest_amount, format('%s günlük faiz: +%s GP', deposit_row.bank_name, interest_amount), 'interest_income');
  END LOOP;

  FOR total_by_club IN
    SELECT club_id, user_id, sum(amount) AS total
    FROM public.financial_transactions ft
    JOIN public.clubs c ON c.id = ft.club_id
    WHERE ft.source = 'interest_income' AND ft.created_at >= now() - interval '5 minutes' AND c.user_id IS NOT NULL
    GROUP BY club_id, user_id
  LOOP
    INSERT INTO public.inbox_messages(recipient_id, title, body, is_read, created_at)
    VALUES (total_by_club.user_id, 'Faiz Geliri', format('Banka hesaplarından toplam %s GP faiz geliri elde ettin.', total_by_club.total), false, now());
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

SELECT cron.unschedule('process-bank-interest') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'process-bank-interest'
);

-- 06:15 Istanbul (UTC+3) - clear of the other daily jobs (05:00, 06:00,
-- 06:30, 07:00, 09:00).
SELECT cron.schedule(
  'process-bank-interest',
  '15 3 * * *',
  $$SELECT public.process_bank_interest();$$
);

GRANT EXECUTE ON FUNCTION public.deposit_to_bank(TEXT, BIGINT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.withdraw_from_bank(UUID) TO authenticated;
