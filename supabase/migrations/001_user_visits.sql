-- 001 · user_visits : 로그인한 사람이 앱에 들어온 날 (하루 1회)
-- Supabase 대시보드 → SQL Editor → New query 에 붙여 넣고 Run. 여러 번 실행해도 안전해요.
-- 기존 테이블(records, feedback)과 posters 버킷은 건드리지 않아요.
--
--  · auth.users 를 참조하고 on delete cascade → 회원이 삭제되면 함께 지워져요.
--  · 로그인한 사람은 자기 user_id 로만 insert. select 권한이 없어서 아무도 조회 못 해요.
--  · 집계(대시보드)는 서버 함수가 service_role 키로만 읽어요.
--  · 날짜 기준은 한국 시간(Asia/Seoul). (user_id, visit_date) 가 유일해서 하루 1회만 저장돼요.

-- 1) 테이블 ------------------------------------------------------------------
create table if not exists public.user_visits (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users (id) on delete cascade,
  visited_at  timestamptz not null default now(),
  visit_date  date not null default ((now() at time zone 'Asia/Seoul')::date),
  constraint user_visits_once_a_day unique (user_id, visit_date)
);

-- 2) 인덱스 ------------------------------------------------------------------
create index if not exists user_visits_date_idx on public.user_visits (visit_date);
create index if not exists user_visits_user_idx on public.user_visits (user_id, visit_date);

-- 3) 권한 + RLS --------------------------------------------------------------
alter table public.user_visits enable row level security;

revoke all on table public.user_visits from anon, authenticated;
grant insert (user_id, visited_at, visit_date) on table public.user_visits to authenticated;

drop policy if exists "user_visits: insert own" on public.user_visits;
create policy "user_visits: insert own" on public.user_visits
  for insert to authenticated
  with check (user_id = (select auth.uid()));
-- select / update / delete 정책은 일부러 만들지 않아요 → 일반 사용자는 조회·수정 불가.

-- 4) 함수: 화면에서는 이 함수만 불러요 ---------------------------------------------
-- 같은 날 이미 있으면 조용히 넘어가요. 로그인하지 않았으면 아무 일도 하지 않아요.
create or replace function public.record_visit()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then return; end if;
  insert into public.user_visits (user_id, visited_at, visit_date)
  values (auth.uid(), now(), (now() at time zone 'Asia/Seoul')::date)
  on conflict (user_id, visit_date) do nothing;
end
$$;
revoke all on function public.record_visit() from public, anon;
grant execute on function public.record_visit() to authenticated;
