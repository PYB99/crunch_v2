-- coach_conversations: one row per conversation thread
create table if not exists public.coach_conversations (
  id         uuid        primary key default gen_random_uuid(),
  user_id    text        not null,
  session_id uuid,       -- nullable; FK to training_sessions added in Phase 7
  started_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.coach_conversations enable row level security;

create policy "Users manage own conversations"
  on public.coach_conversations for all
  using (requesting_user_id() = user_id);

-- coach_messages: individual turns in a conversation
create table if not exists public.coach_messages (
  id              uuid        primary key default gen_random_uuid(),
  conversation_id uuid        not null references public.coach_conversations(id) on delete cascade,
  user_id         text        not null,
  role            text        not null check (role in ('user', 'assistant')),
  content         text        not null,
  created_at      timestamptz not null default now()
);

alter table public.coach_messages enable row level security;

create policy "Users manage own messages"
  on public.coach_messages for all
  using (requesting_user_id() = user_id);

create index if not exists coach_messages_conversation_date
  on public.coach_messages(conversation_id, created_at);
