-- 003 · admin_users : 관리자 목록 (/admin 대시보드 접근 권한)
-- Supabase 대시보드 → SQL Editor → New query 에 붙여 넣고 Run. 여러 번 실행해도 안전해요.
--
--  · 이 표에 user_id 가 있는 사람만 관리자예요. 서버 함수가 service_role 키로 확인해요.
--  · 화면(anon/authenticated)에는 아무 권한이 없어서 누가 관리자인지 볼 수 없어요.
--  · 본인이 관리자인지만 알려 주는 is_admin() 함수가 있어요 (메뉴에 관리자 링크를 보일지 결정용).
--    실제 데이터 접근 권한은 이 함수가 아니라 서버 함수에서 다시 확인해요.
--
--  관리자 추가는 이 파일이 아니라 SQL Editor 에서 아래를 따로 실행하세요(이메일을 파일에 남기지 않기 위해).
--    insert into public.admin_users (user_id)
--      select id from auth.users where email = '관리자 이메일'
--      on conflict do nothing;
--  관리자 해제:
--    delete from public.admin_users
--      where user_id = (select id from auth.users where email = '관리자 이메일');

-- 1) 테이블 ------------------------------------------------------------------
create table if not exists public.admin_users (
  user_id     uuid primary key references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now()
);

-- 2) 권한 + RLS --------------------------------------------------------------
alter table public.admin_users enable row level security;
revoke all on table public.admin_users from anon, authenticated;
-- 정책 없음 → 화면에서는 읽기·쓰기 모두 불가. service_role(서버)만 접근.

-- 3) 함수: 지금 로그인한 사람이 관리자인지 (true/false) -----------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.admin_users where user_id = auth.uid());
$$;
revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;
