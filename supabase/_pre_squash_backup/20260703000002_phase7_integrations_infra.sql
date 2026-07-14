-- Phase 7 infra: APNs device token storage, Realtime on training_sessions,
-- and the coach_conversations -> training_sessions FK the Phase 6 migration
-- comment promised would land in Phase 7.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS apns_device_token text;

ALTER PUBLICATION supabase_realtime ADD TABLE public.training_sessions;

ALTER TABLE public.coach_conversations
  ADD CONSTRAINT coach_conversations_session_fk
  FOREIGN KEY (session_id) REFERENCES public.training_sessions(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS coach_conversations_session_idx
  ON public.coach_conversations(session_id);
