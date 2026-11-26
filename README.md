# TICKET BOOK

본 공연·페스티벌을 이름으로 찾아 고르면 팔찌나 티켓, 다이어리 한 장을 만들어 공책에 모아 주는 웹사이트예요.
검색에 없는 공연은 포스터 사진을 올려서 만들 수도 있어요.
이메일로 로그인하면 기록이 Supabase에 저장돼서 휴대폰·다른 컴퓨터에서도 같은 기록이 보여요. 로그인하지 않으면 지금 브라우저에만 저장돼요.

## 폴더 구성

| 파일 | 하는 일 |
| --- | --- |
| `public/index.html` | 웹사이트 화면 전체 (디자인, 공책, 다 같이 보기, 편집 화면) |
| `api/search.js` | 공연 이름으로 KOPIS(공연)와 TourAPI(축제)를 검색하는 서버 함수 |
| `api/pick.js` | 고른 공연의 출연진·시간과 포스터 이미지를 가져오는 서버 함수 |
| `api/image.js` | 검색 결과 썸네일용 포스터 이미지를 대신 받아 오는 서버 함수 |
| `public/privacy/index.html`, `public/terms/index.html`, `public/legal.css` | 개인정보처리방침(`/privacy`)·이용약관(`/terms`) 문서 페이지. **초안이며 법률 검토를 받지 않았어요.** 노란 [TODO] 칸을 채워야 해요 |
| `public/admin/index.html` | 관리자 대시보드 화면(`/admin`). 가입·활성·리텐션·퍼널 숫자와 차트. 관리자가 아니면 숫자를 받지 못하고 첫 화면으로 돌아가요 |
| `public/analytics.js` | 분석 도구(GTM / GA4 / Clarity) 로더. 방문자가 분석 쿠키에 동의한 뒤에만 스크립트를 불러오고, user id(무작위 값)만 연결해요 |
| `public/cloud.js` | Supabase 연결: 이메일(매직링크) 로그인, 기록 저장·삭제, 포스터 이미지 업로드, 공개 기록 불러오기, 기존 기록 가져오기 |
| `api/config.js` | Vercel 환경 변수의 Supabase 주소·공개 키와 분석 도구 공개 ID(GTM/GA4/Clarity)를 화면에 넘겨주는 함수 (secret 키는 내보내지 않아요) |
| `schema.sql` | (원본) 기록 테이블 `records`·보안 정책(RLS)·`posters` 이미지 버킷 설정. Supabase SQL Editor에 붙여 넣어요 |
| `supabase/feedback.sql` | '의견 보내기' 피드백 테이블·보안 정책. 누구나 쓰기만 되고 읽기는 대시보드에서만 |
| `supabase/migrations/001~005_*.sql` | 분석·동의·관리자용 추가 테이블과 집계 함수. 번호 순서대로 SQL Editor에 붙여 넣어요 (아래 '데이터베이스 설정' 참고) |
| `supabase/inspect/schema_inventory.sql` | 내 Supabase에 지금 무엇이 있는지 '구조만' 뽑아 보는 읽기 전용 조사 쿼리 |
| `api/_lib.js` | 위 함수들이 같이 쓰는 도구 (주소로 열리지 않아요) |
| `api/_supabase.js` | 서버 전용 Supabase 도구: 로그인 토큰 검증, 관리자 확인, 비밀 키(service_role)로 DB 함수 실행 (주소로 열리지 않아요) |
| `api/admin/stats.js` | 관리자 대시보드 숫자를 돌려주는 서버 함수. 관리자(`admin_users`)가 아니면 아무 데이터도 주지 않아요 |
| `api/account/delete.js` | 회원 탈퇴 서버 함수. 본인 토큰으로 본인 계정과 이미지만 지워요 |
| `api/read-poster.js` | (예비) 포스터 사진을 Claude에게 보내서 공연 정보를 읽어 오는 서버 함수 |
| `public/manifest.webmanifest`, `public/icon-*.png` | 휴대폰 홈 화면에 추가할 때 쓰는 이름과 아이콘 |
| `CHECKLIST.md` | 운영자가 직접 해야 하는 일(환경 변수, SQL, GTM·GA4·Clarity 콘솔, 문서 TODO)과 배포 전 점검 목록 |
| `vercel.json` | 포스터 읽기 함수가 최대 60초까지 기다리도록 하는 설정 |

## 처음 배포하기

### 1. 키 받기 (모두 무료, 마지막 하나만 선택)

| 환경 변수 이름 | 어디서 받나요 | 하는 일 |
| --- | --- | --- |
| `KOPIS_API_KEY` | KOPIS 공연예술통합전산망 (https://www.kopis.or.kr) → 오픈API 메뉴에서 회원가입 후 키 신청 | 콘서트·뮤지컬·연극·클래식 검색 |
| `TOUR_API_KEY` | 공공데이터포털 (https://www.data.go.kr)에서 '한국관광공사_국문 관광정보 서비스' 활용신청 → **일반 인증키(Decoding)** 복사 | 페스티벌·축제 검색 |
| `SUPABASE_URL` | Supabase 프로젝트 → Project Settings → API → **Project URL** | 로그인·기록 저장 |
| `SUPABASE_PUBLISHABLE_KEY` | 같은 화면의 **Publishable key** (예전 이름: anon public key) | 로그인·기록 저장 |
| `SUPABASE_SERVICE_ROLE_KEY` | 같은 화면의 **Secret key** (예전 이름: service_role) | 관리자 대시보드(`/admin`)와 회원 탈퇴. 서버 함수에서만 쓰여요 |
| `GTM_ID` (선택) | Google Tag Manager (https://tagmanager.google.com) → 컨테이너 만들기 → `GTM-` 로 시작하는 ID | 분석 태그 묶음. GA4·Clarity 태그는 GTM 안에서 만들어요 |
| `GA4_MEASUREMENT_ID` (선택) | Google Analytics → 관리 → 데이터 스트림 → `G-` 로 시작하는 측정 ID | GTM 을 안 쓸 때만 직접 로드 |
| `CLARITY_PROJECT_ID` (선택) | Microsoft Clarity (https://clarity.microsoft.com) → 프로젝트 → Settings → Overview 의 Project ID | GTM 을 안 쓸 때만 직접 로드 |
| `ANTHROPIC_API_KEY` (선택) | https://console.anthropic.com → API Keys (유료, 포스터 한 장에 몇십 원 안팎) | 검색에 없는 공연을 포스터 사진으로 만들 때 |

Supabase의 **secret 키는 `SUPABASE_PUBLISHABLE_KEY` 자리에 넣지 마세요.** 넣으면 사이트가 일부러 오류를 내고 쓰지 않아요. secret 키는 반드시 `SUPABASE_SERVICE_ROLE_KEY` 이름으로만 넣어요. 변수 이름 전체 목록은 `.env.example` 에 있어요.
Supabase 값이 없으면 로그인 버튼이 나오지 않고, 지금처럼 브라우저에만 저장돼요.

키는 다른 사람에게 보여주지 마세요. 키가 하나도 없으면 검색이 안 되고, `ANTHROPIC_API_KEY`가 없으면 사진 올리기는 색과 이미지만 맞춰 줘요.

### 2. GitHub에 올리기
1. https://github.com 에서 새 저장소(Repository)를 만들어요. 이름 예: `ticketbook`
2. **Add file → Upload files**를 눌러 이 폴더 안의 파일과 폴더를 전부 끌어다 놓고 **Commit changes**를 눌러요.

### 3. Vercel에 연결하기
1. https://vercel.com 에 GitHub 계정으로 가입해요.
2. **Add New → Project**에서 방금 만든 저장소를 **Import**해요.
3. 설정 화면에서:
   - Framework Preset: **Other**
   - Output Directory: **public** (보통 자동으로 잡혀요)
   - **Environment Variables**에 위 표의 이름과 키를 하나씩 넣어요.
4. **Deploy**를 누르면 1분 안에 `ticketbook-xxxx.vercel.app` 같은 주소가 생겨요.

## 데이터베이스 설정 (Supabase 마이그레이션)

DB 구조는 대시보드에서 손으로 만들지 않고 **저장소의 SQL 파일로만** 만들어요. 그래야 다른 사람이 자기 Supabase 프로젝트에서도 똑같이 재현할 수 있어요.
모든 파일은 **여러 번 실행해도 안전**하게 작성되어 있어요(`if not exists`, `create or replace`, `drop policy if exists`).

### 붙여 넣는 방법 (파일마다 반복)
1. Supabase 대시보드 → 왼쪽 메뉴 **SQL Editor** → **New query**
2. 파일을 메모장이나 GitHub에서 열어 **내용 전체를 복사**해서 붙여 넣기
3. 오른쪽 아래 **Run** → 아래에 `Success. No rows returned` 가 나오면 성공
4. 다음 번호 파일로 넘어가기

### 새 환경에서 적용하는 순서
| 순서 | 파일 | 만드는 것 |
| --- | --- | --- |
| 1 | `schema.sql` | (원본) `records` 테이블, RLS, `posters` 버킷 |
| 2 | `supabase/feedback.sql` | (원본) `feedback` 테이블, RLS |
| 3 | `supabase/migrations/001_user_visits.sql` | 방문 기록 `user_visits`, 함수 `record_visit()` |
| 4 | `supabase/migrations/002_user_consents.sql` | 동의 기록 `user_consents` |
| 5 | `supabase/migrations/003_admin_users.sql` | 관리자 목록 `admin_users`, 함수 `is_admin()` |
| 6 | `supabase/migrations/004_user_events.sql` | 행동 기록 `user_events` |
| 7 | `supabase/migrations/005_admin_stats.sql` | 대시보드 집계 함수 `admin_dashboard()` (service_role 전용) |

원본(1, 2)은 이미 있는 프로젝트라면 건너뛰어도 돼요. 3~7은 원본 테이블을 수정하지 않고 새 테이블과 함수만 추가해요.
새 마이그레이션을 만들 때는 `005_...sql` 처럼 다음 번호를 붙이고, 이 표에 한 줄 추가해 주세요.

### 관리자 등록 (파일에 넣지 않고 직접 실행)
`/admin` 대시보드를 볼 사람은 `admin_users` 표에 있어야 해요. 그 사람이 **사이트에 한 번 로그인한 뒤**, SQL Editor에서 아래를 실행해요(이메일은 본인 것으로 바꾸세요).
```sql
insert into public.admin_users (user_id)
  select id from auth.users where email = 'me@example.com'
  on conflict do nothing;
```

### 잘 적용됐는지 확인하기
- **Table Editor**에 `user_visits`, `user_consents`, `admin_users`, `user_events` 가 보이면 성공이에요.
- **Database → Functions**에 `record_visit`, `is_admin`, `admin_dashboard` 가 보이면 함수도 들어간 거예요.
- 완전히 새 프로젝트에서 검증하려면: Supabase에서 빈 프로젝트를 하나 더 만들고 위 표 1→6 순서로 붙여 넣어요. 중간에 빨간 오류가 나오면 그 파일 이름과 오류 문구를 알려 주세요. 전부 `Success` 면 재현에 문제가 없어요.
- 데이터(회원·기록)는 어떤 SQL 파일에도 들어 있지 않아요. 구조만 있어요.

### 내 Supabase에 지금 무엇이 있는지 보기
대시보드에서 손으로 만든 것이 있는지 확인할 때 `supabase/inspect/schema_inventory.sql` 을 SQL Editor에서 실행하면 테이블·정책·함수·트리거의 **정의만** 표로 나와요(데이터는 나오지 않아요). 결과를 CSV로 내려받아 `supabase/inspect/out/` 에 두면 git에는 올라가지 않아요.

## 개인정보 고지·동의 (한국 개인정보 보호법 기준)

### 동의 흐름
- **가입(= 첫 로그인) 팝업**: [필수] 이용약관 / [필수] 개인정보 수집·이용 / [필수] 만 14세 이상 체크박스 3개. 모두 체크해야 로그인 링크를 보낼 수 있고, 각 항목에 전문 보기 링크가 있어요.
- **로그인 직후 동의 관문**: 로그인되면 `user_consents` 에 현재 버전(`CONSENT_VERSION`)의 필수 동의가 있는지 확인하고, 없으면 화면을 막고 동의를 받아요. 기존 회원, 다른 기기에서 링크를 연 경우, 나중에 소셜 로그인을 붙이는 경우까지 모두 이 관문을 지나요. 동의하지 않으면 로그아웃돼요.
- **분석 쿠키(선택)**: 가입 동의와 분리한 하단 배너에서 허용/거부. 허용 전에는 분석 스크립트가 로드되지 않아요. 화면 맨 아래 **쿠키 설정**, 내 계정 → **분석 쿠키 설정**에서 언제든 바꿀 수 있어요. 로그인 상태면 선택이 `user_consents`(analytics)에도 남아요.
- **회원 탈퇴**: 내 계정 → 회원 탈퇴 → '탈퇴' 입력. 서버 함수가 본인 이미지 폴더와 계정을 지우고, 기록·방문·동의·행동 기록은 DB 가 함께 지워요.

### 문서를 고쳤을 때
`public/privacy/index.html` 또는 `public/terms/index.html` 을 고치면 ① 문서 안 '변경 이력/부칙' 표에 한 줄 추가, ② `public/index.html` 의 `CONSENT_VERSION` 을 같은 날짜로 변경. 그러면 모든 회원이 다음 로그인 때 다시 동의해요. 분석 배너 문구를 고쳤다면 `public/analytics.js` 의 `VERSION` 도 올려요.

### 운영자 정보 (2026-11-26 채움)
두 문서의 운영자 정보는 채워져 있어요. 바뀌면 아래 위치를 함께 고치고 '변경 이력/부칙'에 한 줄 추가한 뒤 `CONSENT_VERSION` 을 올려요.
- 운영자·보호책임자: 하빈 (대학교 프로젝트, 개인 운영 비영리) → 방침 1·10항, 약관 1조
- 연락 이메일 → 방침 1·6·10항, 약관 9·11조
- Supabase 지역: 대한민국(서울) / Vercel: 미국 → 방침 4항 표
- 의견 보유 기간: 접수 후 3개월 → 방침 3항
- 포스터 읽기 기능(ANTHROPIC_API_KEY)을 켜면 방침 4항에 Anthropic(미국) 행을 추가해야 해요

> **개발 메모**: 두 문서는 초안이며 변호사 등 전문가의 법률 검토를 받은 것이 아니에요. 공개 전 검토를 권해요.

## 분석 도구 설정 (GTM · GA4 · Clarity)

분석 스크립트는 **방문자가 하단 배너에서 '분석 쿠키 허용'을 누른 뒤에만** 불러와요. 허용 전에는 어떤 스크립트도 로드되지 않고, 거부하면 분석 쿠키를 지워요. 한국 개인정보 보호법상 행태정보가 구글·마이크로소프트(국외)로 가기 때문에 선택 동의로 분리했어요.
Vercel Web Analytics(쿠키 없음, 개인식별자 없음)는 동의와 상관없이 그대로 켜져 있어요.

### 코드가 보내는 이벤트
| 이벤트 | 언제 | 비고 |
| --- | --- | --- |
| `sign_up` | 첫 로그인(= 가입) | 계정 생성 10분 안의 로그인을 가입으로 봐요 |
| `login` | 그 뒤의 로그인 | |
| `record_save` | 공연 기록 '보관하기' | `storage: cloud / local` |
| `image_save` | 페이지·티켓 이미지 저장 버튼 | 로그인 상태면 DB `user_events` 에도 저장 |
| `video_save` | 동영상 저장 버튼 | |

사용자 식별은 `user_id`(Supabase 의 무작위 UUID)만 보내요. 이메일·이름·전화번호는 어떤 도구로도 보내지 않아요. `/admin` 페이지에는 분석 스크립트가 전혀 없어요.

### Vercel 환경 변수 등록과 재배포
1. Vercel → 프로젝트 → **Settings → Environment Variables**
2. **Key** 에 `GTM_ID`, **Value** 에 `GTM-` 으로 시작하는 컨테이너 ID → Environment 는 Production·Preview·Development 모두 체크 → **Save**
3. 환경 변수는 **다시 배포해야** 적용돼요: **Deployments** 탭 → 맨 위 배포의 **⋯ → Redeploy**. (GitHub 에 새 커밋을 올려도 돼요.)
4. 배포가 끝나면 사이트에서 배너 '허용'을 누르고, 브라우저 개발자 도구 → Network 에 `gtm.js` 가 보이면 성공이에요. 허용 전에는 보이지 않아야 정상이에요.

### GTM 컨테이너 안에서 만들 것 (한 번만)
1. **변수**: 사용자 정의 변수 → **데이터 영역 변수** → 이름 `user_id`, 데이터 영역 변수 이름 `user_id`
2. **GA4 태그**: 태그 → 새로 만들기 → **Google 태그**(또는 GA4 구성) → 측정 ID 입력 → 구성 설정에 `user_id` = `{{user_id}}` 추가 → 트리거 **All Pages**(Initialization 아님)
3. **GA4 이벤트 태그**: 태그 → **GA4 이벤트** → 이벤트 이름 `{{Event}}` → 트리거: **맞춤 이벤트**, 이벤트 이름에 정규식 `^(sign_up|login|record_save|image_save|video_save)# TICKET BOOK

본 공연·페스티벌을 이름으로 찾아 고르면 팔찌나 티켓, 다이어리 한 장을 만들어 공책에 모아 주는 웹사이트예요.
검색에 없는 공연은 포스터 사진을 올려서 만들 수도 있어요.
이메일로 로그인하면 기록이 Supabase에 저장돼서 휴대폰·다른 컴퓨터에서도 같은 기록이 보여요. 로그인하지 않으면 지금 브라우저에만 저장돼요.

## 폴더 구성

| 파일 | 하는 일 |
| --- | --- |
| `public/index.html` | 웹사이트 화면 전체 (디자인, 공책, 다 같이 보기, 편집 화면) |
| `api/search.js` | 공연 이름으로 KOPIS(공연)와 TourAPI(축제)를 검색하는 서버 함수 |
| `api/pick.js` | 고른 공연의 출연진·시간과 포스터 이미지를 가져오는 서버 함수 |
| `api/image.js` | 검색 결과 썸네일용 포스터 이미지를 대신 받아 오는 서버 함수 |
| `public/admin/index.html` | 관리자 대시보드 화면(`/admin`). 가입·활성·리텐션·퍼널 숫자와 차트. 관리자가 아니면 숫자를 받지 못하고 첫 화면으로 돌아가요 |
| `public/analytics.js` | 분석 도구(GTM / GA4 / Clarity) 로더. 방문자가 분석 쿠키에 동의한 뒤에만 스크립트를 불러오고, user id(무작위 값)만 연결해요 |
| `public/cloud.js` | Supabase 연결: 이메일(매직링크) 로그인, 기록 저장·삭제, 포스터 이미지 업로드, 공개 기록 불러오기, 기존 기록 가져오기 |
| `api/config.js` | Vercel 환경 변수의 Supabase 주소·공개 키와 분석 도구 공개 ID(GTM/GA4/Clarity)를 화면에 넘겨주는 함수 (secret 키는 내보내지 않아요) |
| `schema.sql` | (원본) 기록 테이블 `records`·보안 정책(RLS)·`posters` 이미지 버킷 설정. Supabase SQL Editor에 붙여 넣어요 |
| `supabase/feedback.sql` | '의견 보내기' 피드백 테이블·보안 정책. 누구나 쓰기만 되고 읽기는 대시보드에서만 |
| `supabase/migrations/001~005_*.sql` | 분석·동의·관리자용 추가 테이블과 집계 함수. 번호 순서대로 SQL Editor에 붙여 넣어요 (아래 '데이터베이스 설정' 참고) |
| `supabase/inspect/schema_inventory.sql` | 내 Supabase에 지금 무엇이 있는지 '구조만' 뽑아 보는 읽기 전용 조사 쿼리 |
| `api/_lib.js` | 위 함수들이 같이 쓰는 도구 (주소로 열리지 않아요) |
| `api/_supabase.js` | 서버 전용 Supabase 도구: 로그인 토큰 검증, 관리자 확인, 비밀 키(service_role)로 DB 함수 실행 (주소로 열리지 않아요) |
| `api/admin/stats.js` | 관리자 대시보드 숫자를 돌려주는 서버 함수. 관리자(`admin_users`)가 아니면 아무 데이터도 주지 않아요 |
| `api/account/delete.js` | 회원 탈퇴 서버 함수. 본인 토큰으로 본인 계정과 이미지만 지워요 |
| `api/read-poster.js` | (예비) 포스터 사진을 Claude에게 보내서 공연 정보를 읽어 오는 서버 함수 |
| `public/manifest.webmanifest`, `public/icon-*.png` | 휴대폰 홈 화면에 추가할 때 쓰는 이름과 아이콘 |
| `vercel.json` | 포스터 읽기 함수가 최대 60초까지 기다리도록 하는 설정 |

## 처음 배포하기

### 1. 키 받기 (모두 무료, 마지막 하나만 선택)

| 환경 변수 이름 | 어디서 받나요 | 하는 일 |
| --- | --- | --- |
| `KOPIS_API_KEY` | KOPIS 공연예술통합전산망 (https://www.kopis.or.kr) → 오픈API 메뉴에서 회원가입 후 키 신청 | 콘서트·뮤지컬·연극·클래식 검색 |
| `TOUR_API_KEY` | 공공데이터포털 (https://www.data.go.kr)에서 '한국관광공사_국문 관광정보 서비스' 활용신청 → **일반 인증키(Decoding)** 복사 | 페스티벌·축제 검색 |
| `SUPABASE_URL` | Supabase 프로젝트 → Project Settings → API → **Project URL** | 로그인·기록 저장 |
| `SUPABASE_PUBLISHABLE_KEY` | 같은 화면의 **Publishable key** (예전 이름: anon public key) | 로그인·기록 저장 |
| `SUPABASE_SERVICE_ROLE_KEY` | 같은 화면의 **Secret key** (예전 이름: service_role) | 관리자 대시보드(`/admin`)와 회원 탈퇴. 서버 함수에서만 쓰여요 |
| `GTM_ID` (선택) | Google Tag Manager (https://tagmanager.google.com) → 컨테이너 만들기 → `GTM-` 로 시작하는 ID | 분석 태그 묶음. GA4·Clarity 태그는 GTM 안에서 만들어요 |
| `GA4_MEASUREMENT_ID` (선택) | Google Analytics → 관리 → 데이터 스트림 → `G-` 로 시작하는 측정 ID | GTM 을 안 쓸 때만 직접 로드 |
| `CLARITY_PROJECT_ID` (선택) | Microsoft Clarity (https://clarity.microsoft.com) → 프로젝트 → Settings → Overview 의 Project ID | GTM 을 안 쓸 때만 직접 로드 |
| `ANTHROPIC_API_KEY` (선택) | https://console.anthropic.com → API Keys (유료, 포스터 한 장에 몇십 원 안팎) | 검색에 없는 공연을 포스터 사진으로 만들 때 |

Supabase의 **secret 키는 `SUPABASE_PUBLISHABLE_KEY` 자리에 넣지 마세요.** 넣으면 사이트가 일부러 오류를 내고 쓰지 않아요. secret 키는 반드시 `SUPABASE_SERVICE_ROLE_KEY` 이름으로만 넣어요. 변수 이름 전체 목록은 `.env.example` 에 있어요.
Supabase 값이 없으면 로그인 버튼이 나오지 않고, 지금처럼 브라우저에만 저장돼요.

키는 다른 사람에게 보여주지 마세요. 키가 하나도 없으면 검색이 안 되고, `ANTHROPIC_API_KEY`가 없으면 사진 올리기는 색과 이미지만 맞춰 줘요.

### 2. GitHub에 올리기
1. https://github.com 에서 새 저장소(Repository)를 만들어요. 이름 예: `ticketbook`
2. **Add file → Upload files**를 눌러 이 폴더 안의 파일과 폴더를 전부 끌어다 놓고 **Commit changes**를 눌러요.

### 3. Vercel에 연결하기
1. https://vercel.com 에 GitHub 계정으로 가입해요.
2. **Add New → Project**에서 방금 만든 저장소를 **Import**해요.
3. 설정 화면에서:
   - Framework Preset: **Other**
   - Output Directory: **public** (보통 자동으로 잡혀요)
   - **Environment Variables**에 위 표의 이름과 키를 하나씩 넣어요.
4. **Deploy**를 누르면 1분 안에 `ticketbook-xxxx.vercel.app` 같은 주소가 생겨요.

## 데이터베이스 설정 (Supabase 마이그레이션)

DB 구조는 대시보드에서 손으로 만들지 않고 **저장소의 SQL 파일로만** 만들어요. 그래야 다른 사람이 자기 Supabase 프로젝트에서도 똑같이 재현할 수 있어요.
모든 파일은 **여러 번 실행해도 안전**하게 작성되어 있어요(`if not exists`, `create or replace`, `drop policy if exists`).

### 붙여 넣는 방법 (파일마다 반복)
1. Supabase 대시보드 → 왼쪽 메뉴 **SQL Editor** → **New query**
2. 파일을 메모장이나 GitHub에서 열어 **내용 전체를 복사**해서 붙여 넣기
3. 오른쪽 아래 **Run** → 아래에 `Success. No rows returned` 가 나오면 성공
4. 다음 번호 파일로 넘어가기

### 새 환경에서 적용하는 순서
| 순서 | 파일 | 만드는 것 |
| --- | --- | --- |
| 1 | `schema.sql` | (원본) `records` 테이블, RLS, `posters` 버킷 |
| 2 | `supabase/feedback.sql` | (원본) `feedback` 테이블, RLS |
| 3 | `supabase/migrations/001_user_visits.sql` | 방문 기록 `user_visits`, 함수 `record_visit()` |
| 4 | `supabase/migrations/002_user_consents.sql` | 동의 기록 `user_consents` |
| 5 | `supabase/migrations/003_admin_users.sql` | 관리자 목록 `admin_users`, 함수 `is_admin()` |
| 6 | `supabase/migrations/004_user_events.sql` | 행동 기록 `user_events` |
| 7 | `supabase/migrations/005_admin_stats.sql` | 대시보드 집계 함수 `admin_dashboard()` (service_role 전용) |

원본(1, 2)은 이미 있는 프로젝트라면 건너뛰어도 돼요. 3~7은 원본 테이블을 수정하지 않고 새 테이블과 함수만 추가해요.
새 마이그레이션을 만들 때는 `005_...sql` 처럼 다음 번호를 붙이고, 이 표에 한 줄 추가해 주세요.

### 관리자 등록 (파일에 넣지 않고 직접 실행)
`/admin` 대시보드를 볼 사람은 `admin_users` 표에 있어야 해요. 그 사람이 **사이트에 한 번 로그인한 뒤**, SQL Editor에서 아래를 실행해요(이메일은 본인 것으로 바꾸세요).
```sql
insert into public.admin_users (user_id)
  select id from auth.users where email = 'me@example.com'
  on conflict do nothing;
```

### 잘 적용됐는지 확인하기
- **Table Editor**에 `user_visits`, `user_consents`, `admin_users`, `user_events` 가 보이면 성공이에요.
- **Database → Functions**에 `record_visit`, `is_admin`, `admin_dashboard` 가 보이면 함수도 들어간 거예요.
- 완전히 새 프로젝트에서 검증하려면: Supabase에서 빈 프로젝트를 하나 더 만들고 위 표 1→6 순서로 붙여 넣어요. 중간에 빨간 오류가 나오면 그 파일 이름과 오류 문구를 알려 주세요. 전부 `Success` 면 재현에 문제가 없어요.
- 데이터(회원·기록)는 어떤 SQL 파일에도 들어 있지 않아요. 구조만 있어요.

### 내 Supabase에 지금 무엇이 있는지 보기
대시보드에서 손으로 만든 것이 있는지 확인할 때 `supabase/inspect/schema_inventory.sql` 을 SQL Editor에서 실행하면 테이블·정책·함수·트리거의 **정의만** 표로 나와요(데이터는 나오지 않아요). 결과를 CSV로 내려받아 `supabase/inspect/out/` 에 두면 git에는 올라가지 않아요.

 (정규식 일치 사용 체크)
4. **Clarity 태그**: 태그 → 커뮤니티 템플릿 갤러리에서 **Microsoft Clarity** 검색 → Project ID 입력 → 트리거 **All Pages**
5. 관리 → **컨테이너 설정**에서 **동의 개요 사용** 체크(선택) → 태그마다 `analytics_storage` 동의가 필요하도록 두면 코드의 Consent Mode 기본값(전부 거부)과 맞아요
6. 오른쪽 위 **제출 → 게시**. 게시하지 않으면 아무 태그도 안 나가요.

### GA4 콘솔에서 꺼야 할 것
1. **관리 → 데이터 수집 및 수정 → 데이터 수집** → **Google 신호 데이터 수집** 끄기 → 같은 화면 **광고 개인 최적화 허용** 끄기(가능하면 '모든 지역' 비허용)
2. **관리 → 데이터 수집 및 수정 → 데이터 보관** → 이벤트 데이터 보관 **2개월**(가장 짧게)
3. **관리 → 속성 설정 → 속성 세부정보**에서 보고 시간대 **대한민국**
4. **관리 → 데이터 스트림 → 웹 → 향상된 측정**에서 '사이트 검색', '양식 상호작용' 끄기(검색어·입력 내용이 전송되지 않게)
5. Google Ads 등 광고 제품 **연결하지 않기**

### Clarity 콘솔에서 할 것
1. 프로젝트 → **Settings → Masking** → **Strict**(모든 텍스트 가림) 선택. 코드에서도 로그인·내 계정·의견 보내기 팝업에 `data-clarity-mask` 를 달아 두 겹으로 가려요
2. **Settings → Setup** 에서 Clarity 가 제안하는 설치 코드는 **붙여 넣지 마세요** (코드/GTM 이 동의 뒤에 로드해요)
3. **Settings → Integrations** 의 Google Analytics 연결은 켜지 않아요(개인식별 가능성 증가)

## 올린 다음에 수정하기

GitHub의 파일을 고치면 Vercel이 **자동으로 다시 배포**해요. 주소는 그대로예요.

- **Claude에게 고쳐 달라고 할 때:** 고친 파일을 받은 뒤 GitHub 저장소에서 같은 파일을 다시 업로드(덮어쓰기)하고 Commit 하면 돼요.
- **직접 고칠 때:** GitHub에서 파일을 열고 연필 아이콘(Edit)을 눌러 수정한 뒤 Commit 해요.
- 1~2분 뒤 사이트를 새로고침하면 바뀐 내용이 보여요. Vercel **Deployments** 탭에서 진행 상황을 볼 수 있어요.
- 문제가 생기면 Deployments에서 예전 버전을 골라 **Promote to Production**으로 되돌릴 수 있어요.

## 알아 두면 좋은 점

- **비용:** Vercel, KOPIS, TourAPI는 무료예요. 포스터 사진 읽기를 켰다면 그때만 Anthropic API 사용료가 나가요. 콘솔의 **Limits**에서 월 사용 한도를 정해 두면 안심이에요.
- **처음 배포하면 꼭 한 번 검색해 보세요.** 공공 API 문서를 이 환경에서 끝까지 확인하지 못한 부분이 있어요. 검색 결과가 비어 있으면 아래 값을 Vercel 환경 변수로 바꿔 볼 수 있어요.
  - `KOPIS_MAX_DAYS` (기본 31): KOPIS에 한 번에 묻는 기간(일). 기간 제한이 없다면 `600`처럼 크게 하면 요청 수가 줄어요.
  - `KOPIS_MONTHS_BACK` (기본 18), `KOPIS_MONTHS_AHEAD` (기본 6): 몇 달 전부터 몇 달 뒤까지의 공연을 찾을지.
  - `KOPIS_BASE` (기본 `http://www.kopis.or.kr/openApi/restful`), `TOUR_BASE` (기본 `https://apis.data.go.kr/B551011/KorService2`): API 주소.
  - 축제 검색은 `searchKeyword2`, `detailIntro2` 기능 이름을 써요. 공공데이터포털 문서의 이름과 다르면 `api/search.js`에서 바꿔 주세요.
- **전시:** 지금은 공연(KOPIS)과 축제(TourAPI)만 검색해요. 전시는 포스터 사진으로 만들 수 있어요.
- **모델 바꾸기:** 기본은 `claude-sonnet-5-5`예요. 다른 모델을 쓰려면 Vercel 환경 변수에 `ANTHROPIC_MODEL`을 추가하세요.
- **기록 저장:** 로그인하면 Supabase `records` 테이블에, 이미지는 `posters` 버킷의 `<내 user id>/<기록 id>/` 폴더에 저장돼요. 로그인하지 않은 기록은 브라우저(localStorage `bandlog.v2`)에만 있어요.
- **공개 기록:** 기록마다 '다 같이 보기에 공개'를 켤 수 있어요(기본은 비공개). 공개 기록은 로그인하지 않은 방문자도 '다 같이 보기'에서 볼 수 있어요. 이미지는 공개 버킷이라 주소를 아는 사람은 볼 수 있지만, 파일 이름이 무작위라 주소를 모르면 찾을 수 없어요.
- **내 도메인:** Vercel 프로젝트 **Settings → Domains**에서 구입한 도메인을 연결할 수 있어요.
- **방문 통계:** Vercel 프로젝트의 **Analytics**를 켜면 방문자 수를 볼 수 있어요.
