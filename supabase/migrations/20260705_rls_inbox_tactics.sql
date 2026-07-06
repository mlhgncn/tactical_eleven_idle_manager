ALTER TABLE public.inbox_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tactics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS inbox_messages_select_policy ON public.inbox_messages;
CREATE POLICY inbox_messages_select_policy ON public.inbox_messages FOR SELECT TO authenticated
  USING (recipient_id = auth.uid());

DROP POLICY IF EXISTS inbox_messages_insert_policy ON public.inbox_messages;
CREATE POLICY inbox_messages_insert_policy ON public.inbox_messages FOR INSERT TO authenticated
  WITH CHECK (recipient_id = auth.uid());

DROP POLICY IF EXISTS inbox_messages_update_policy ON public.inbox_messages;
CREATE POLICY inbox_messages_update_policy ON public.inbox_messages FOR UPDATE TO authenticated
  USING (recipient_id = auth.uid())
  WITH CHECK (recipient_id = auth.uid());

DROP POLICY IF EXISTS inbox_messages_delete_policy ON public.inbox_messages;
CREATE POLICY inbox_messages_delete_policy ON public.inbox_messages FOR DELETE TO authenticated
  USING (recipient_id = auth.uid());

DROP POLICY IF EXISTS tactics_select_policy ON public.tactics;
CREATE POLICY tactics_select_policy ON public.tactics FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.clubs c
      WHERE c.id = tactics.club_id
        AND c.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS tactics_insert_policy ON public.tactics;
CREATE POLICY tactics_insert_policy ON public.tactics FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.clubs c
      WHERE c.id = club_id
        AND c.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS tactics_update_policy ON public.tactics;
CREATE POLICY tactics_update_policy ON public.tactics FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.clubs c
      WHERE c.id = tactics.club_id
        AND c.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.clubs c
      WHERE c.id = club_id
        AND c.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS tactics_delete_policy ON public.tactics;
CREATE POLICY tactics_delete_policy ON public.tactics FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.clubs c
      WHERE c.id = tactics.club_id
        AND c.user_id = auth.uid()
    )
  );
