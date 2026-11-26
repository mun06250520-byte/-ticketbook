-- 002 · user_consents : 무엇에, 어느 버전으로, 언제 동의(또는 거부·철회)했는지
-- Supabase 대시보드 → SQL Editor → New query 에 붙여 넣고 Run. 여러 번 실행해도 안전해요.
--
--  consent_type
--    terms      [필수] 이용약관
--    privacy    [필수] 개인정보 수집·이용
--    age14      [필수] 만 14세 이상 확인
--    analytics  [선택] 분석 쿠키·행태정보 (배너에서 허용/거부, 설정에서 철회 가능)
--  version : 문서 버전 문자열 (예: '2026-11-26'). 문서를 고치면 버전을 올리고 다시 동의를 받아요.
--  agreed  : true 동의 / false 거부·철회. 기록은 지우지 않고 계속 쌓아요(이력 보존).

-- 1) 테이블 ------------------------------------------------------------------
create table if not exists public.user_consents (
  id            bigint generated always as identity primary key,
  user_id       uuid not null default auth.uid() references auth.users (id) on delete cascade,
  consent_type  text not null,
  version       text not null,
  agreed        boolean not null default true,
  agreed_at     timestamptz not null default now()
);

-- 2) 값 제한 (다시 실행해도 되도록 지웠다가 다시 만들어요) --------------------------
alter table public.user_consents drop constraint if exists user_consents_type_check;
alter table public.user_consents add constraint user_consents_type_check
  check (consent_type in ('terms', 'privacy', 'age14', 'analytics'));

alter table public.user_consents drop constraint if exists user_consents_version_check;
alter table public.user_consents add constraint user_consents_version_check
  check (char_length(version) between 1 and 40);

-- 3) 인덱스 ------------------------------------------------------------------
create index if not exists user_consents_user_idx
  on public.user_consents (user_id, consent_type, agreed_at desc);

-- 4) 권한 + RLS --------------------------------------------------------------
alter table public.user_consents enable row level security;

-- 쓰기는 정해진 칸만, 읽기는 본인 것만. 수정·삭제 권한은 없어요.
revoke all on table public.user_consents from anon, authenticated;
grant insert (user_id, consent_type, version, agreed) on table public.user_consents to authenticated;
grant select on table public.user_consents to authenticated;

drop policy if exists "user_consents: insert own" on public.user_consents;
create policy "user_consents: insert own" on public.user_consents
  for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists "user_consents: read own" on public.user_consents;
create policy "user_consents: read own" on public.user_consents
  for select to authenticated
  using (user_id = (select auth.uid()));
