-- Bank interest rates were too low to feel like a meaningful savings option
-- next to match-day income (see 20260712190000_bank_deposit_system.sql) -
-- roughly doubling each tier while keeping the same lock-up/min-deposit
-- risk-reward shape (longer lock-up still pays a better rate).
UPDATE public.banks SET daily_interest_rate = 0.0030 WHERE id = 'emlak';
UPDATE public.banks SET daily_interest_rate = 0.0055 WHERE id = 'ticaret';
UPDATE public.banks SET daily_interest_rate = 0.0090 WHERE id = 'yatirim';
UPDATE public.banks SET daily_interest_rate = 0.0130 WHERE id = 'kartal';
