-- TICKET BOOK · 마이그레이션 전체 묶음 (001~005)
-- 이 파일은 supabase/migrations/ 의 파일들을 순서대로 이어 붙인 것이에요. 직접 고치지 말고, 마이그레이션이 바뀌면 다시 만들어요.
-- Supabase 대시보드 → SQL Editor → New query 에 전체를 붙여 넣고 Run 한 번. 여러 번 실행해도 안전해요.

-- ─────────── 001_user_visits.sql ───────────
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


-- ─────────── 002_user_consents.sql ───────────
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


-- ─────────── 003_admin_users.sql ───────────
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


-- ─────────── 004_user_events.sql ───────────
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


-- ─────────── 005_admin_stats.sql ───────────
-- 005 · admin_dashboard() : 관리자 대시보드 집계 함수 (숫자만, 개인정보 없음)
-- Supabase 대시보드 → SQL Editor → New query 에 붙여 넣고 Run. 여러 번 실행해도 안전해요.
--
--  · 서버 함수(/api/admin/stats)가 service_role 키로만 부를 수 있어요. 화면(anon/authenticated)에서는 실행 불가.
--  · 이메일 등 개인정보는 꺼내지 않고 '명수'와 '비율'만 돌려줘요.
--  · 날짜 기준은 한국 시간(Asia/Seoul). 주는 월요일에 시작해요.
--  · p_days : 최근 며칠을 볼지 (7 / 30 / 90). 1~365 사이로 잘라요.
--
--  지표 정의
--    가입          auth.users.created_at (이 서비스는 첫 로그인 = 가입)
--    활성(DAU/WAU) user_visits 에 그 날(또는 그 날 포함 7일) 방문이 있는 사람 수. 001 적용일부터 쌓여요.
--    D1 / D7 / D30 가입일 다음 날부터 1일 / 7일 / 30일 안에 한 번이라도 다시 방문한 비율.
--                  기간이 아직 다 지나지 않은 코호트는 null (아직 알 수 없음).
--    주간 재방문율  이번 주(월~오늘) 방문자 중 지난주(월~일)에도 방문한 사람의 비율.
--    퍼널          기간 내 가입자 → 공연 기록 1개 이상(records, profile 제외) → 이미지 저장 1회 이상(user_events).
--
--  결과 모양 (jsonb)
--    { meta:{today, from, days, visits_since},
--      summary:{total_users, new_today, wau, d7_cohort_size, d7_retention},
--      daily:[{day, signups, cumulative, dau, wau}],
--      cohorts:[{week, size, d1, d7, d30}],
--      weekly_return:{this_week, returning, rate},
--      funnel:{signed_up, recorded, saved_image} }

create or replace function public.admin_dashboard(p_days int default 30)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  today   date := (now() at time zone 'Asia/Seoul')::date;
  d_from  date;
  mon     date;                     -- 이번 주 월요일
  j_summary jsonb; j_daily jsonb; j_cohorts jsonb; j_week jsonb; j_funnel jsonb; j_meta jsonb;
  n_rec   bigint;                   -- 공연 기록을 1개 이상 남긴 가입자 수 (records 표가 없으면 null)
begin
  p_days := greatest(1, least(coalesce(p_days, 30), 365));
  d_from := today - (p_days - 1);
  mon    := date_trunc('week', today)::date;

  -- 가입일(한국 시간)을 한 번만 계산해 임시 표로 둬요.
  create temp table if not exists _su (id uuid, sd date) on commit drop;
  truncate _su;
  insert into _su select u.id, (u.created_at at time zone 'Asia/Seoul')::date from auth.users u;

  -- 요약 카드 ---------------------------------------------------------------
  with d7 as (
    -- 기간 안에 가입했고 7일이 다 지난 사람들
    select s.id, s.sd from _su s where s.sd between d_from and today - 7
  ), d7r as (
    select count(*) as size,
           count(*) filter (where exists (
             select 1 from public.user_visits v
             where v.user_id = d7.id and v.visit_date between d7.sd + 1 and d7.sd + 7)) as kept
    from d7
  )
  select jsonb_build_object(
    'total_users',    (select count(*) from _su),
    'new_today',      (select count(*) from _su where sd = today),
    'wau',            (select count(distinct user_id) from public.user_visits where visit_date between today - 6 and today),
    'd7_cohort_size', d7r.size,
    'd7_retention',   case when d7r.size > 0 then round(100.0 * d7r.kept / d7r.size, 1) end)
  into j_summary from d7r;

  -- 일별 추이 ---------------------------------------------------------------
  select coalesce(jsonb_agg(jsonb_build_object(
           'day', t.d, 'signups', t.s, 'cumulative', t.c, 'dau', t.dau, 'wau', t.wau) order by t.d), '[]'::jsonb)
  into j_daily
  from (
    select g.d,
      (select count(*) from _su where sd = g.d)  as s,
      (select count(*) from _su where sd <= g.d) as c,
      (select count(distinct user_id) from public.user_visits where visit_date = g.d) as dau,
      (select count(distinct user_id) from public.user_visits where visit_date between g.d - 6 and g.d) as wau
    -- generate_series 는 '시각'을 돌려주므로 먼저 날짜(date)로 바꿔요 (안 바꾸면 g.d - 6 에서 오류)
    from (select gs::date as d from generate_series(d_from, today, interval '1 day') gs) g
  ) t;

  -- 가입 주(월요일 시작) 코호트 리텐션 ----------------------------------------------
  with coh as (
    select s.id, s.sd, date_trunc('week', s.sd)::date as wk
    from _su s where s.sd >= date_trunc('week', d_from)::date
  ), per as (
    select c.id, c.wk,
      bool_or(v.visit_date = c.sd + 1)                       as r1,
      bool_or(v.visit_date between c.sd + 1 and c.sd + 7)    as r7,
      bool_or(v.visit_date between c.sd + 1 and c.sd + 30)   as r30
    from coh c
    left join public.user_visits v on v.user_id = c.id and v.visit_date > c.sd
    group by c.id, c.wk
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'week', x.wk, 'size', x.size, 'd1', x.d1, 'd7', x.d7, 'd30', x.d30) order by x.wk), '[]'::jsonb)
  into j_cohorts
  from (
    select wk, count(*) as size,
      case when wk + 6 + 1  <= today then count(*) filter (where r1)  end as d1,
      case when wk + 6 + 7  <= today then count(*) filter (where r7)  end as d7,
      case when wk + 6 + 30 <= today then count(*) filter (where r30) end as d30
    from per group by wk
  ) x;

  -- 주간 재방문율 -------------------------------------------------------------
  with tw as (select distinct user_id from public.user_visits where visit_date between mon and today),
       lw as (select distinct user_id from public.user_visits where visit_date between mon - 7 and mon - 1),
       n  as (select (select count(*) from tw) as this_week,
                     (select count(*) from tw where user_id in (select user_id from lw)) as returning)
  select jsonb_build_object(
    'this_week', n.this_week, 'returning', n.returning,
    'rate', case when n.this_week > 0 then round(100.0 * n.returning / n.this_week, 1) end)
  into j_week from n;

  -- 가입 → 핵심 행동 퍼널 (기간 내 가입자 기준) --------------------------------------
  -- 공연 기록 수는 원본 records 표(schema.sql)가 있을 때만 세요. 없으면 null 로 두고 함수는 계속 돌아가요.
  -- (표가 없으면 일반 SQL 은 컴파일 단계에서 멈추므로 execute 로 실행해요)
  if to_regclass('public.records') is not null then
    execute $q$ select count(*) from _su s
                where s.sd between $1 and $2
                  and exists (select 1 from public.records r
                              where r.user_id = s.id and coalesce(r.data->>'kind', '') <> 'profile') $q$
      into n_rec using d_from, today;
  end if;
  with su as (select id from _su where sd between d_from and today)
  select jsonb_build_object(
    'signed_up',   (select count(*) from su),
    'recorded',    n_rec,
    'saved_image', (select count(*) from su where exists (
                      select 1 from public.user_events e
                      where e.user_id = su.id and e.event = 'image_save')))
  into j_funnel;

  j_meta := jsonb_build_object(
    'today', today, 'from', d_from, 'days', p_days,
    'visits_since', (select min(visit_date) from public.user_visits));

  return jsonb_build_object(
    'meta', j_meta, 'summary', j_summary, 'daily', j_daily,
    'cohorts', j_cohorts, 'weekly_return', j_week, 'funnel', j_funnel);
end
$$;

-- 서버(service_role)만 실행 가능. 화면에서는 부를 수 없어요.
revoke all on function public.admin_dashboard(int) from public, anon, authenticated;
grant execute on function public.admin_dashboard(int) to service_role;


