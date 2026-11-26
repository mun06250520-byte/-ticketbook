-- 스키마 조사 쿼리 (읽기 전용 · 데이터는 한 줄도 꺼내지 않아요)
-- Supabase 대시보드 → SQL Editor → New query 에 전체를 붙여 넣고 Run 을 누른 뒤,
-- 결과 표 오른쪽 위의 다운로드(Export → CSV) 로 저장하세요.
-- 저장한 파일은 supabase/inspect/out/ 폴더에 넣어 주세요 (이 폴더는 git 에 올라가지 않아요).
--
-- 무엇이 나오나요? public 스키마의 테이블·열·제약·인덱스·RLS 정책·함수·트리거, storage 버킷·정책의
-- '정의(DDL)'만 나와요. 회원 정보, 기록 내용, 이메일 같은 '데이터'는 포함되지 않아요.

with
tables as (
  select c.oid, c.relname as name
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r', 'p')
),
cols as (
  select t.name,
         string_agg(
           format('  %I %s%s%s', a.attname, format_type(a.atttypid, a.atttypmod),
                  case when a.attnotnull then ' not null' else '' end,
                  case when d.adbin is not null then ' default ' || pg_get_expr(d.adbin, d.adrelid) else '' end),
           E',\n' order by a.attnum) as body
  from tables t
  join pg_attribute a on a.attrelid = t.oid and a.attnum > 0 and not a.attisdropped
  left join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
  group by t.name
)
select '1 table' as kind, c.name as object,
       format(E'create table if not exists public.%I (\n%s\n);', c.name, c.body) as definition
from cols c
union all
select '2 constraint', t.name || '.' || con.conname,
       format('alter table public.%I add constraint %I %s;', t.name, con.conname, pg_get_constraintdef(con.oid))
from tables t join pg_constraint con on con.conrelid = t.oid
union all
select '3 index', i.indexname, i.indexdef || ';'
from pg_indexes i
where i.schemaname = 'public' and i.indexname not in (select conname from pg_constraint)
union all
select '4 rls', t.name,
       format('alter table public.%I %s row level security;', t.name,
              case when c.relrowsecurity then 'enable' else 'disable' end)
from tables t join pg_class c on c.oid = t.oid
union all
select '5 policy', p.tablename || ' / ' || p.policyname,
       format('create policy %I on %I.%I as %s for %s to %s%s%s;',
              p.policyname, p.schemaname, p.tablename, p.permissive, p.cmd,
              array_to_string(p.roles, ', '),
              coalesce(' using (' || p.qual || ')', ''),
              coalesce(' with check (' || p.with_check || ')', ''))
from pg_policies p
where p.schemaname in ('public', 'storage')
union all
select '6 grant', g.table_name || ' → ' || g.grantee,
       string_agg(g.privilege_type || coalesce(' (' || g.column_list || ')', ''), ', ' order by g.privilege_type)
from (
  select table_name, grantee, privilege_type, null::text as column_list
  from information_schema.role_table_grants
  where table_schema = 'public' and grantee in ('anon', 'authenticated')
  union all
  select table_name, grantee, privilege_type, string_agg(column_name, ',' order by column_name)
  from information_schema.role_column_grants
  where table_schema = 'public' and grantee in ('anon', 'authenticated')
  group by table_name, grantee, privilege_type
) g
group by g.table_name, g.grantee
union all
select '7 function', p.proname, pg_get_functiondef(p.oid) || ';'
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.prokind = 'f'
union all
select '8 trigger', c.relname || ' / ' || tg.tgname, pg_get_triggerdef(tg.oid) || ';'
from pg_trigger tg join pg_class c on c.oid = tg.tgrelid join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and not tg.tgisinternal
union all
select '9 bucket', b.id,
       format('bucket %I: public=%s, file_size_limit=%s, allowed_mime_types=%s',
              b.id, b.public, coalesce(b.file_size_limit::text, 'null'),
              coalesce(array_to_string(b.allowed_mime_types, ','), 'null'))
from storage.buckets b
order by 1, 2;
