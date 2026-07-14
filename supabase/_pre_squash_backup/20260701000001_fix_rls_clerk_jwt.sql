-- races, training_sessions, and macro_targets were created with auth.uid() = user_id,
-- but user_id is a UUID (FK to users.id) while Clerk JWTs carry a text sub claim
-- (format user_xxx). auth.uid() cannot cast that to UUID, so all reads fail with
-- Clerk auth. Fix: resolve clerk_id → users.id via subquery using requesting_user_id().

DROP POLICY IF EXISTS "races_manage_own" ON public.races;
CREATE POLICY "races_manage_own" ON public.races
  FOR ALL
  USING (user_id = (SELECT id FROM public.users WHERE clerk_id = requesting_user_id()));

DROP POLICY IF EXISTS "training_sessions_manage_own" ON public.training_sessions;
CREATE POLICY "training_sessions_manage_own" ON public.training_sessions
  FOR ALL
  USING (user_id = (SELECT id FROM public.users WHERE clerk_id = requesting_user_id()));

DROP POLICY IF EXISTS "macro_targets_manage_own" ON public.macro_targets;
CREATE POLICY "macro_targets_manage_own" ON public.macro_targets
  FOR ALL
  USING (user_id = (SELECT id FROM public.users WHERE clerk_id = requesting_user_id()));
