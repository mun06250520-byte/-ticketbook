-- 004 · user_events : 핵심 행동 기록 (지금은 이미지 저장. 나중에 다른 행동도 같은 표에)
-- Supabase 대시보드 → SQL Editor → New query 에 붙여 넣고 Run. 여러 번 실행해도 안전해요.
--
--  · 공연 기록은 기존 records 테이블의 created_at 으로 집계하므로 여기 넣지 않아요.
--  · event 이름은 소문자·숫자·밑줄만 (예: image_save). 로그인한 사람의 행동만 저장돼요.
--  · select 권한이 없어서 일반 사용자는 조회 불가. 집계는 서버 함수(service_role)만.

-- 1) 테이블 ------------------------------------------------------------------
create table if not exists public.user_events (
  id          bigint generated always as identity primary key,
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  event       text not null,
  created_at  timestamptz not null default now()
);

-- 2) 값 제한 -----------------------------------------------------------------
alter table public.user_events drop constraint if exists user_events_event_check;
alter table public.user_events add constraint user_events_event_check
  check (event ~ '^[a-z][a-z0-9_]{0,39}$');

-- 3) 인덱스 ------------------------------------------------------------------
create index if not exists user_events_user_idx  on public.user_events (user_id, event, created_at);
create index if not exists user_events_event_idx on public.user_events (event, created_at);

-- 4) 권한 + RLS --------------------------------------------------------------
alter table public.user_events enable row level security;

revoke all on table public.user_events from anon, authenticated;
grant insert (user_id, event) on table public.user_events to authenticated;

drop policy if exists "user_events: insert own" on public.user_events;
create policy "user_events: insert own" on public.user_events
  for insert to authenticated
  with check (user_id = (select auth.uid()));
-- select 정책 없음 → 일반 사용자는 조회 불가.

-- 회원 탈퇴 시 함께 지워지는 것 (참고) --------------------------------------------
--  auth.users 의 한 줄이 지워지면 records, user_visits, user_consents, user_events, admin_users 가
--  자동으로 따라 지워져요(on delete cascade). feedback 은 user_id 만 비워져요(기존 설계).
--  Storage 의 posters/<user id>/ 폴더는 탈퇴 서버 함수(/api/account/delete)가 먼저 지워요.
