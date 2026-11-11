-- my money log: Supabase 스키마
-- Supabase 대시보드 > SQL Editor에서 실행하면 같은 구조를 만들 수 있습니다.
-- 회원 기능 없이, 브라우저마다 만든 "장부 코드"(UUID)를 x-ledger-id 헤더로 보내고
-- RLS 정책이 그 코드와 일치하는 행만 읽고 쓰도록 막습니다.

-- 요청 헤더(x-ledger-id)로 넘어온 장부 코드
create or replace function public.request_ledger_id()
returns uuid
language sql
stable
set search_path = ''
as $$
  select nullif(current_setting('request.headers', true)::json ->> 'x-ledger-id', '')::uuid
$$;

create table public.ledger_entries (
  id          uuid primary key default gen_random_uuid(),
  ledger_id   uuid not null,
  type        text not null check (type in ('income', 'expense')),
  entry_date  date not null,
  category    text not null check (char_length(category) between 1 and 20),
  amount      bigint not null check (amount > 0 and amount < 1000000000000),
  memo        text not null default '' check (char_length(memo) <= 100),
  created_at  timestamptz not null default now()
);

create index ledger_entries_ledger_date_idx on public.ledger_entries (ledger_id, entry_date);

alter table public.ledger_entries enable row level security;

-- 자기 장부 코드와 일치하는 행만 읽고 쓸 수 있음
create policy "own ledger select" on public.ledger_entries
  for select to anon, authenticated
  using (ledger_id = (select public.request_ledger_id()));

create policy "own ledger insert" on public.ledger_entries
  for insert to anon, authenticated
  with check (ledger_id = (select public.request_ledger_id()));

create policy "own ledger update" on public.ledger_entries
  for update to anon, authenticated
  using (ledger_id = (select public.request_ledger_id()))
  with check (ledger_id = (select public.request_ledger_id()));

create policy "own ledger delete" on public.ledger_entries
  for delete to anon, authenticated
  using (ledger_id = (select public.request_ledger_id()));

revoke all on public.ledger_entries from anon, authenticated;
grant select, insert, update, delete on public.ledger_entries to anon, authenticated;
