-- TICKET BOOK · Supabase schema
-- Supabase 대시보드 → SQL Editor → New query 에 이 파일 전체를 붙여 넣고 Run 을 누르세요.
-- 여러 번 실행해도 안전하게 만들었어요.

-- 1) 기록 테이블 ------------------------------------------------------------
create table if not exists public.records (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  data        jsonb not null,                 -- 팔찌/티켓/페이지 정보 (이미지는 Storage 주소만)
  is_public   boolean not null default false, -- '다 같이 보기'에 공개할지 (기본 비공개)
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint records_data_size check (pg_column_size(data) < 200000) -- dataURL 같은 큰 값이 들어오는 것 방지
);

create index if not exists records_user_idx   on public.records (user_id, updated_at desc);
create index if not exists records_public_idx on public.records (updated_at desc) where is_public;

-- updated_at 자동 갱신
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$ begin new.updated_at = now(); return new; end $$;
drop trigger if exists records_touch on public.records;
create trigger records_touch before update on public.records
  for each row execute function public.touch_updated_at();

-- 2) RLS: 내 기록은 나만 쓰고, 공개 기록은 누구나 읽기만 ---------------------
alter table public.records enable row level security;

drop policy if exists "records: read public or own" on public.records;
create policy "records: read public or own" on public.records
  for select to anon, authenticated
  using (is_public or user_id = (select auth.uid()));

drop policy if exists "records: insert own" on public.records;
create policy "records: insert own" on public.records
  for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists "records: update own" on public.records;
create policy "records: update own" on public.records
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "records: delete own" on public.records;
create policy "records: delete own" on public.records
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- 3) Storage: posters 버킷 ----------------------------------------------------
-- 공개 버킷이라 이미지 주소로 누구나 볼 수 있어요(공개 기록 그림을 보여 주려면 필요).
-- 파일 이름은 무작위라 주소를 모르면 찾을 수 없어요. 업로드/수정/삭제는 본인 폴더만.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('posters', 'posters', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- 경로 규칙: posters/<내 user id>/<기록 id>/<파일 이름>
drop policy if exists "posters: owner can list" on storage.objects;
create policy "posters: owner can list" on storage.objects
  for select to authenticated
  using (bucket_id = 'posters' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "posters: owner can upload" on storage.objects;
create policy "posters: owner can upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'posters' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "posters: owner can update" on storage.objects;
create policy "posters: owner can update" on storage.objects
  for update to authenticated
  using (bucket_id = 'posters' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'posters' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "posters: owner can delete" on storage.objects;
create policy "posters: owner can delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'posters' and (storage.foldername(name))[1] = (select auth.uid())::text);
