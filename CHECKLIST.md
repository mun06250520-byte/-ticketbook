# TICKET BOOK · 운영 체크리스트

분석 기능 · 관리자 대시보드 · 개인정보 고지/동의 기능을 켜기 위해 **운영자가 직접 해야 하는 일**과 **배포 전 점검** 항목이에요.
코드가 하는 일은 `README.md` 에, 여기에는 사람이 해야 하는 일만 모았어요. 끝낸 항목은 `[x]` 로 바꾸세요.

---

## 1. Vercel 환경 변수

Vercel → 프로젝트 → **Settings → Environment Variables**. Production · Preview · Development 모두 체크 → Save → **Deployments → ⋯ → Redeploy** (등록만 하면 적용되지 않아요).

| 상태 | Key | 값 출처 | 하는 일 |
| --- | --- | --- | --- |
| [ ] | `SUPABASE_URL` | Supabase → Project Settings → API → Project URL | 로그인·저장 |
| [ ] | `SUPABASE_PUBLISHABLE_KEY` | 같은 화면 Publishable key (anon public) | 로그인·저장 |
| [ ] | `SUPABASE_SERVICE_ROLE_KEY` | 같은 화면 **Secret key** (service_role). **이 이름으로만** 넣기 | 관리자 대시보드, 회원 탈퇴 (서버 전용) |
| [ ] | `GTM_ID` | GTM 컨테이너 ID (`GTM-…`) | 분석 태그 (동의 후 로드) |
| [ ] | `KOPIS_API_KEY` | KOPIS 오픈API 마이페이지 | 공연 검색 |
| [ ] | `TOUR_API_KEY` | 공공데이터포털 → 활용신청 현황 → 일반 인증키(Decoding) | 축제 검색 |
| 선택 | `GA4_MEASUREMENT_ID`, `CLARITY_PROJECT_ID` | GTM 을 쓰지 않을 때만 | 직접 로드 (GTM_ID 있으면 무시) |
| 선택 | `ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL` | console.anthropic.com | 포스터 사진 읽기 (유료) |

전체 이름 목록은 `.env.example` 에 있어요.

## 2. Supabase

- [ ] **마이그레이션 실행**: SQL Editor → New query → `supabase/apply_all.sql` 전체 붙여 넣기 → Run → `Success`. (GitHub 에서 파일을 열고 **Raw** 를 눌러 복사하면 줄이 잘리지 않아요.)
- [ ] **확인**: Table Editor 에 `user_visits` `user_consents` `admin_users` `user_events` / Database → Functions 에 `record_visit` `is_admin` `admin_dashboard`
- [ ] **관리자 등록**: 사이트에 본인 계정으로 한 번 로그인한 뒤, SQL Editor 에서 이메일만 바꿔 실행 → `1 rows affected`
  ```sql
  insert into public.admin_users (user_id)
    select id from auth.users where email = 'me@example.com'
    on conflict do nothing;
  ```
- [ ] **로그인 돌려보낼 주소**: Authentication → URL Configuration → Redirect URLs 에 `https://<배포 주소>/**` 추가 (미리보기 배포까지 쓰면 `https://*-<팀이름>.vercel.app/**` 도). 없으면 메일 링크가 `localhost` 로 가요.
- [ ] (권장) **자체 메일 발송**: Authentication → Emails → SMTP Settings → Custom SMTP (Resend 등). 기본 발송은 **시간당 2통** 제한이 있어요. 도메인이 있어야 다른 사람에게 보낼 수 있어요.

## 3. Google Tag Manager (컨테이너 안에서 한 번만)

- [ ] 변수: 사용자 정의 변수 → **데이터 영역 변수** → 이름 `user_id`, 데이터 영역 변수 이름 `user_id`
- [ ] GA4 태그: **Google 태그**(GA4 구성) → 측정 ID → 구성 설정에 `user_id` = `{{user_id}}` → 트리거 **All Pages**
- [ ] GA4 이벤트 태그: **GA4 이벤트** → 이벤트 이름 `{{Event}}` → 트리거 **맞춤 이벤트**, 정규식 일치 `^(sign_up|login|record_save|image_save|video_save|account_delete)$`
- [ ] Clarity 태그: 커뮤니티 템플릿 **Microsoft Clarity** → Project ID → 트리거 **All Pages**
- [ ] (선택) 관리 → 컨테이너 설정 → **동의 개요 사용** → 각 태그에 `analytics_storage` 동의 필요로 설정
- [ ] **제출 → 게시**. 게시 전에는 아무 태그도 나가지 않아요.

## 4. Google Analytics 4 콘솔

- [ ] 관리 → 데이터 수집 및 수정 → **데이터 수집** → **Google 신호 데이터 수집** 끄기
- [ ] 같은 화면 → **광고 개인 최적화 허용** 끄기 (가능하면 모든 지역 비허용)
- [ ] 관리 → **데이터 보관** → 이벤트 데이터 보관 **2개월**
- [ ] 관리 → 속성 세부정보 → 보고 시간대 **대한민국**
- [ ] 관리 → 데이터 스트림 → 웹 → **향상된 측정** 에서 '사이트 검색', '양식 상호작용' 끄기
- [ ] Google Ads 등 광고 제품 연결하지 않기

## 5. Microsoft Clarity 콘솔

- [ ] Settings → **Masking** → **Strict** (모든 텍스트 가림)
- [ ] Settings → Setup 의 설치 코드는 **붙여 넣지 않기** (GTM 이 동의 뒤에 로드)
- [ ] Settings → Integrations 의 Google Analytics 연결 **끄기**

## 6. 문서 운영자 정보

- [x] 운영자·보호책임자·연락 이메일·사업자 정보·시행일·Supabase/Vercel 지역·의견 보유 기간 (2026-11-26 채움)
- [ ] (해당 시) 포스터 읽기 기능(ANTHROPIC_API_KEY)을 켜면 방침 4항에 Anthropic(미국) 행 추가
- [ ] **법률 검토**: 두 문서는 전문가 검토를 받지 않은 초안이에요. 공개 전 검토를 권해요.
- 문서를 고칠 때: '변경 이력/부칙'에 한 줄 추가 + `public/index.html` 의 `CONSENT_VERSION` 을 그 날짜로 → 회원 전원 재동의

---

## 7. 배포 전 점검 (사이트에서 직접 눌러 보기)

### 관리자 접근
- [ ] **로그아웃 상태**로 `/admin` → "로그인이 필요해요" 만 보이고 숫자 없음
- [ ] **일반 계정**(admin_users 에 없는 계정)으로 `/admin` → "관리자만 볼 수 있어요" 뒤 첫 화면으로 이동
- [ ] 개발자 도구 → Network → `/api/admin/stats` 응답이 일반 계정에서는 `403` 이고 본문에 숫자가 없음
- [ ] **관리자 계정**으로 `/admin` → 카드·차트가 보임. 화면 어디에도 이메일이 없음

### 비밀 키 노출
- [ ] 개발자 도구 → Network → `/api/config` 응답에 `supabaseUrl`, `supabaseKey`(publishable), `gtmId` 만 있고 `sb_secret_` 로 시작하는 값이나 `service_role` 이 없음
- [ ] 페이지 소스(Ctrl+U)와 `/analytics.js`, `/cloud.js`, `/admin` 소스에서 `sb_secret_` 검색 → 0건
- [ ] Vercel 환경 변수 화면에서 Secret key 가 `SUPABASE_SERVICE_ROLE_KEY` 에만 있고 `SUPABASE_PUBLISHABLE_KEY` 에 들어가 있지 않음

### 동의 기록
- [ ] 로그인 팝업: 체크박스 3개를 모두 체크하기 전에는 "로그인 링크 받기" 버튼이 비활성
- [ ] 로그인 뒤 Supabase → Table Editor → `user_consents` 에 `terms` `privacy` `age14` 세 줄(version `2026-11-26`)이 생김
- [ ] 동의 기록이 없는 기존 계정으로 로그인 → "서비스 이용 동의" 팝업이 뜨고, 바깥을 눌러도 닫히지 않음
- [ ] 하단 배너에서 허용/거부 → 로그인 상태면 `user_consents` 에 `analytics` 줄 추가
- [ ] 로그인 뒤 `user_visits` 에 오늘 날짜 한 줄. 새로고침해도 한 줄 그대로

### 회원 탈퇴
- [ ] 테스트 계정으로 기록 1개 + 이미지 저장 → 내 계정 → 회원 탈퇴 → '탈퇴' 입력 → 삭제
- [ ] Supabase → Authentication → Users 에서 그 계정이 사라짐
- [ ] `records` `user_visits` `user_consents` `user_events` 에서 그 user_id 줄이 사라짐
- [ ] Storage → posters 에서 그 user_id 폴더가 사라짐
- [ ] `feedback` 에 그 사람이 보낸 의견은 남고 `user_id` 만 비어 있음

### Clarity 녹화 제외
- [ ] Clarity Masking 이 Strict
- [ ] 허용 상태로 로그인 팝업·내 계정·의견 보내기를 열어 본 뒤 Clarity → Recordings 에서 해당 세션 재생 → 입력 내용과 이메일이 `***` 로 가려짐
- [ ] `/admin` 세션은 Recordings 에 나타나지 않음 (스크립트 자체가 없음)

### 분석 도구로 개인정보가 가지 않는지
- [ ] 배너 **허용 전**: Network 에 `googletagmanager.com`, `clarity.ms` 요청이 **없음**
- [ ] 허용 후: Network 의 `collect?v=2` (GA4) 요청 URL 과 Payload 에 `uid=`(무작위 UUID)만 있고 이메일·이름 없음
- [ ] GTM 미리보기(Tag Assistant)로 `sign_up` `login` `record_save` `image_save` 이벤트가 들어오고, 변수 `user_id` 가 UUID 형태
- [ ] "거부" 후 새로고침 → 분석 요청 없음, 쿠키 `_ga` `_clck` 삭제됨

---

## 8. 나중에 GA4 데이터를 대시보드에 붙일 때 (지금은 구현 안 함)

자리는 만들어 두었어요. 구현할 때는 아래 순서로 하면 기존 구조를 바꾸지 않아요.

1. GA4 → 관리 → 속성 액세스 관리에 서비스 계정(Google Cloud) 추가, Vercel 환경 변수 `GA4_PROPERTY_ID`, `GA4_SERVICE_ACCOUNT_JSON`(서버 전용) 등록
2. `api/_ga4.js` 를 새로 만들어 GA4 Data API(`runReport`) 호출 → 페이지뷰·세션·유입 경로 같은 집계만 반환
3. `api/admin/stats.js` 의 `ga4: null` 을 `ga4: await ga4Summary(days)` 로 교체 (관리자 확인은 이미 그 앞에서 끝나요)
4. `public/admin/index.html` 의 `<section id="ga4">` 에 그리기 — 응답에 `ga4` 가 있으면 자동으로 보이게 되어 있어요
