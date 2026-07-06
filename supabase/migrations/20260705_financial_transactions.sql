-- Migration: create financial_transactions ledger table
CREATE TABLE IF NOT EXISTS public.financial_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    club_id UUID NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    amount BIGINT NOT NULL,
    description TEXT NOT NULL,
    source TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.financial_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY financial_transactions_select_policy ON public.financial_transactions FOR SELECT TO authenticated
  USING (
    club_id IN (
      SELECT id FROM public.clubs WHERE user_id = auth.uid()
    )
  );

-- Inserts should only be performed server-side (service role or DB functions)
CREATE POLICY financial_transactions_insert_policy ON public.financial_transactions FOR INSERT TO authenticated
  WITH CHECK (false);

CREATE POLICY financial_transactions_update_policy ON public.financial_transactions FOR UPDATE TO authenticated
  USING (false);

CREATE POLICY financial_transactions_delete_policy ON public.financial_transactions FOR DELETE TO authenticated
  USING (false);
