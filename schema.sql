create extension if not exists pgcrypto;

create table public.accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  provider text not null check (provider in ('Claude', 'ChatGPT', 'Grok', 'Other')),
  label text not null,
  email text,
  status text not null default 'active' check (status in ('active', 'limited', 'parked')),
  limited_until timestamptz,
  notes text,
  created_at timestamptz not null default now()
);

create table public.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  account_id uuid not null references public.accounts(id) on delete cascade,
  title text not null,
  project text,
  summary text,
  url text,
  state text not null default 'in progress' check (state in ('in progress', 'waiting', 'done')),
  created_at timestamptz not null default now(),
  last_touched timestamptz not null default now()
);

create index accounts_user_id_idx on public.accounts(user_id);
create index sessions_user_id_idx on public.sessions(user_id);
create index sessions_account_id_idx on public.sessions(account_id);
create index sessions_project_idx on public.sessions(project);
create index sessions_last_touched_idx on public.sessions(last_touched);

alter table public.accounts enable row level security;
alter table public.sessions enable row level security;

create policy "Users can select their accounts" on public.accounts for select to authenticated using (user_id = auth.uid());
create policy "Users can insert their accounts" on public.accounts for insert to authenticated with check (user_id = auth.uid());
create policy "Users can update their accounts" on public.accounts for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Users can delete their accounts" on public.accounts for delete to authenticated using (user_id = auth.uid());

create policy "Users can select their sessions" on public.sessions for select to authenticated using (user_id = auth.uid());
create policy "Users can insert their sessions" on public.sessions for insert to authenticated with check (user_id = auth.uid() and exists (select 1 from public.accounts where accounts.id = sessions.account_id and accounts.user_id = auth.uid()));
create policy "Users can update their sessions" on public.sessions for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid() and exists (select 1 from public.accounts where accounts.id = sessions.account_id and accounts.user_id = auth.uid()));
create policy "Users can delete their sessions" on public.sessions for delete to authenticated using (user_id = auth.uid());

create or replace function public.set_session_last_touched()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.last_touched = now();
  return new;
end;
$$;

create trigger sessions_set_last_touched
before update on public.sessions
for each row execute function public.set_session_last_touched();

alter publication supabase_realtime add table public.accounts, public.sessions;
