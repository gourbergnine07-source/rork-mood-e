-- Mood-E: anti-guessing hardening (21/11/2026). SELECT is NOT changed here.

-- Fix 2: anonymous clients may update only the columns the app writes
-- (DuoSessionService / ChallengeDuoService). code, created_at, expires_at
-- and month_key can no longer be changed. RLS policies are unchanged.
revoke update on public.duo_sessions from anon, authenticated;
grant update (guest_joined, guest_name, host_mood, host_goal, guest_mood, guest_goal)
  on public.duo_sessions to anon, authenticated;

revoke update on public.challenge_duos from anon, authenticated;
grant update (guest_joined, guest_name, host_progress, guest_progress)
  on public.challenge_duos to anon, authenticated;

-- Fix 3: max 10 add_friend_by_code attempts per hour per user.
-- Only the SECURITY DEFINER function reads/writes this table.
create table if not exists public.friend_code_attempts (
  user_id text not null,
  attempted_at timestamptz not null default now()
);
create index if not exists friend_code_attempts_user_idx
  on public.friend_code_attempts (user_id, attempted_at);
alter table public.friend_code_attempts enable row level security;
revoke all on public.friend_code_attempts from anon, authenticated;

-- Wrong and own codes return no rows (same result for both) instead of
-- raising, so the attempt is kept (a raise would roll it back).
-- Success result is unchanged.
create or replace function public.add_friend_by_code(code text)
 returns table(friend_user_id text, friend_name text)
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  me text := user_id();
  target record;
begin
  if me is null then
    raise exception 'NOT_SIGNED_IN';
  end if;

  -- Serialize calls of the same user so parallel requests can't bypass the limit.
  perform pg_advisory_xact_lock(hashtext('add_friend_by_code:' || me));
  delete from public.friend_code_attempts
    where user_id = me and attempted_at < now() - interval '1 hour';
  if (select count(*) from public.friend_code_attempts where user_id = me) >= 10 then
    raise exception 'RATE_LIMITED';
  end if;
  insert into public.friend_code_attempts (user_id) values (me);

  select fs.user_id, fs.display_name into target
    from public.friend_stats fs
    where fs.friend_code = upper(trim(code));
  if not found or target.user_id = me then
    return;
  end if;

  insert into public.friends(user_id, friend_id)
    values (me, target.user_id)
    on conflict do nothing;
  insert into public.friends(user_id, friend_id)
    values (target.user_id, me)
    on conflict do nothing;
  return query select target.user_id, target.display_name;
end;
$function$;
