-- integrations was created with auth.uid() = user_id, but user_id is a UUID
-- (FK to users.id) while Clerk JWTs carry a text sub claim (format user_xxx).
-- auth.uid() cannot cast that to UUID, so all reads/writes fail with Clerk auth
-- (Strava/Runna connection status can never be saved or read). Same bug fixed
-- for races/training_sessions/macro_targets in 20260701000001_fix_rls_clerk_jwt.sql.

DROP POLICY IF EXISTS "integrations_manage_own" ON public.integrations;
CREATE POLICY "integrations_manage_own" ON public.integrations
  FOR ALL
  USING (user_id = (SELECT id FROM public.users WHERE clerk_id = requesting_user_id()));
