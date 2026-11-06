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
| `public/cloud.js` | Supabase 연결: 이메일(매직링크) 로그인, 기록 저장·삭제, 포스터 이미지 업로드, 공개 기록 불러오기, 기존 기록 가져오기 |
| `api/config.js` | Vercel 환경 변수의 Supabase 주소와 공개 키를 화면에 넘겨주는 함수 (secret 키는 내보내지 않아요) |
| `supabase/schema.sql` | Supabase SQL Editor에 붙여 넣을 테이블·보안 정책(RLS)·이미지 버킷 설정 |
| `api/_lib.js` | 위 함수들이 같이 쓰는 도구 (주소로 열리지 않아요) |
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
| `ANTHROPIC_API_KEY` (선택) | https://console.anthropic.com → API Keys (유료, 포스터 한 장에 몇십 원 안팎) | 검색에 없는 공연을 포스터 사진으로 만들 때 |

Supabase의 **secret 키(service_role)는 절대 넣지 마세요.** 넣으면 사이트가 일부러 오류를 내고 쓰지 않아요.
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
