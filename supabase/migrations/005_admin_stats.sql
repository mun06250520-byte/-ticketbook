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
