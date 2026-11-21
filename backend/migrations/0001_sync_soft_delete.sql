-- Mood-E: soft delete for multi-device sync (library, planner).
-- Additive only: existing rows keep deleted_at = NULL, no data is changed.
alter table public.library_entries   add column if not exists deleted_at timestamptz default null;
alter table public.planner_scheduled add column if not exists deleted_at timestamptz default null;
alter table public.planner_memories  add column if not exists deleted_at timestamptz default null;

-- updated_at already exists on all three tables; kept idempotent.
alter table public.library_entries   add column if not exists updated_at timestamptz default now();
alter table public.planner_scheduled add column if not exists updated_at timestamptz default now();
alter table public.planner_memories  add column if not exists updated_at timestamptz default now();

-- Speeds up the daily purge (deleted_at < cutoff).
create index if not exists library_entries_deleted_at_idx   on public.library_entries   (user_id, deleted_at) where deleted_at is not null;
create index if not exists planner_scheduled_deleted_at_idx on public.planner_scheduled (user_id, deleted_at) where deleted_at is not null;
create index if not exists planner_memories_deleted_at_idx  on public.planner_memories  (user_id, deleted_at) where deleted_at is not null;
