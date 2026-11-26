// TICKET BOOK · 분석 도구 (Google Tag Manager / GA4 / Microsoft Clarity)
//
//  원칙
//   · 방문자가 '분석 쿠키 허용'에 동의하기 전에는 어떤 분석 스크립트도 불러오지 않아요.
//     (Vercel Web Analytics 는 쿠키·개인식별자를 쓰지 않아 index.html 에서 그대로 유지해요.)
//   · 측정 ID 는 코드에 적지 않고 /api/config 가 Vercel 환경 변수에서 읽어 줘요.
//       GTM_ID               → 있으면 GTM 컨테이너만 로드. GA4·Clarity 태그는 GTM 안에서 만들어요.
//       GA4_MEASUREMENT_ID   → GTM 이 없을 때만 직접 로드 (예비 경로)
//       CLARITY_PROJECT_ID   → GTM 이 없을 때만 직접 로드 (예비 경로)
//     GTM 과 직접 로드를 동시에 하면 두 번 집계되므로, GTM ID 가 있으면 나머지 둘은 무시해요.
//   · 사용자 식별은 Supabase user id(무작위 UUID)만 써요. 이메일·이름 등 개인정보는 보내지 않아요.
//   · 광고 관련 기능(Google 신호, 광고 개인화)은 코드에서 꺼 두고, 동의 기본값도 모두 '거부'예요.
//
//  화면에서 쓰는 방법 (window.TBAnalytics)
//   TBAnalytics.track('sign_up')               이벤트 보내기 (동의 전이면 조용히 버려요)
//   TBAnalytics.setUser(uid | null)            로그인/로그아웃 때 user id 연결·해제
//   TBAnalytics.consent()                      {agreed, version, at} 또는 null(아직 선택 안 함)
//   TBAnalytics.needsPrompt()                  배너를 보여야 하는지 (도구가 설정돼 있고, 현재 버전 동의가 없을 때)
//   TBAnalytics.setConsent(true | false)       허용 / 거부(철회). 허용 즉시 로드, 거부는 쿠키를 지우고 다음 로드부터 완전히 멈춰요
//   TBAnalytics.onReady(fn)                    설정을 읽은 뒤 fn() 호출 (배너 표시 타이밍용)

const VERSION = '2026-11-26';              // 분석 동의 문구 버전. 문구를 바꾸면 올리고, 배너를 다시 보여 줘요.
const CONSENT_KEY = 'tb.consent.analytics';

const state = { cfg: null, mode: null, ready: false, loaded: false, uid: null, queue: [], listeners: [] };

// ── 동의 저장 (이 브라우저) ─────────────────────────────────────
function readConsent() {
  try { const v = JSON.parse(localStorage.getItem(CONSENT_KEY)); return v && typeof v.agreed === 'boolean' ? v : null; }
  catch { return null; }
}
function writeConsent(agreed) {
  const v = { agreed, version: VERSION, at: new Date().toISOString() };
  try { localStorage.setItem(CONSENT_KEY, JSON.stringify(v)); } catch {}
  return v;
}
const granted = () => { const c = readConsent(); return !!c && c.agreed === true && c.version === VERSION; };

// ── Google Consent Mode 기본값: 전부 거부 ────────────────────────
window.dataLayer = window.dataLayer || [];
function gtag() { window.dataLayer.push(arguments); }
gtag('consent', 'default', {
  ad_storage: 'denied', ad_user_data: 'denied', ad_personalization: 'denied',
  analytics_storage: 'denied', wait_for_update: 500,
});
gtag('set', { allow_google_signals: false, allow_ad_personalization_signals: false });

function loadScript(src) {
  return new Promise((ok, fail) => {
    const s = document.createElement('script');
    s.async = true; s.src = src; s.onload = ok; s.onerror = () => fail(new Error('load ' + src));
    document.head.appendChild(s);
  });
}

// GTM 공식 스니펫과 같은 동작 (dataLayer 에 gtm.start 를 넣고 gtm.js 를 불러요). noscript iframe 은 넣지 않아요:
// 자바스크립트가 꺼진 환경에서는 동의 배너도 뜨지 않아서, 동의 없이 로드하는 셈이 되기 때문이에요.
function loadGtm(id) {
  window.dataLayer.push({ 'gtm.start': Date.now(), event: 'gtm.js' });
  return loadScript('https://www.googletagmanager.com/gtm.js?id=' + encodeURIComponent(id));
}
function loadGa4(id) {
  gtag('js', new Date());
  gtag('config', id, { allow_google_signals: false, allow_ad_personalization_signals: false });
  return loadScript('https://www.googletagmanager.com/gtag/js?id=' + encodeURIComponent(id));
}
function loadClarity(id) {
  window.clarity = window.clarity || function () { (window.clarity.q = window.clarity.q || []).push(arguments); };
  return loadScript('https://www.clarity.ms/tag/' + encodeURIComponent(id));
}

// ── 실제 전송 ──────────────────────────────────────────────
function send(name, params) {
  const p = Object.assign({}, params || {});
  if (state.mode === 'gtm') window.dataLayer.push(Object.assign({ event: name }, p));
  else {
    if (state.cfg.ga4Id) gtag('event', name, p);
    if (state.cfg.clarityId && window.clarity) { try { window.clarity('event', name); } catch {} }
  }
}
function pushUser() {
  const uid = state.uid || null;
  if (state.mode === 'gtm') window.dataLayer.push({ user_id: uid });
  else {
    if (state.cfg.ga4Id) gtag('set', { user_id: uid });
    if (state.cfg.clarityId && window.clarity && uid) { try { window.clarity('identify', uid); } catch {} }
  }
}

// 동의가 있을 때 한 번만: 스크립트 로드 → user id → 쌓인 이벤트
async function enable() {
  if (state.loaded || !state.mode) return;
  state.loaded = true;
  gtag('consent', 'update', { analytics_storage: 'granted' });
  try {
    if (state.mode === 'gtm') await loadGtm(state.cfg.gtmId);
    else {
      if (state.cfg.ga4Id) await loadGa4(state.cfg.ga4Id);
      if (state.cfg.clarityId) await loadClarity(state.cfg.clarityId);
    }
  } catch (e) { console.warn('analytics', e.message); }
  if (state.uid) pushUser();
  const q = state.queue.splice(0); q.forEach(([n, p]) => send(n, p));
}

// 거부·철회: 더 보내지 않고, 알려진 분석 쿠키를 지워요. 이미 로드된 스크립트는 다음 페이지 로드부터 빠져요.
function disable() {
  gtag('consent', 'update', { analytics_storage: 'denied' });
  if (window.clarity) { try { window.clarity('consent', false); } catch {} }
  const host = location.hostname, past = 'expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/';
  document.cookie.split(';').map(c => c.split('=')[0].trim()).filter(n => /^(_ga|_gid|_gat|_gcl|_clck|_clsk|MUID)/.test(n))
    .forEach(n => { document.cookie = n + '=; ' + past; document.cookie = n + '=; ' + past + '; domain=' + host; document.cookie = n + '=; ' + past + '; domain=.' + host; });
  state.queue.length = 0;
}

// ── 공개 API ───────────────────────────────────────────────
window.TBAnalytics = {
  version: VERSION,
  consent: readConsent,
  // 도구가 설정돼 있고(측정 ID 있음) 현재 버전의 선택이 없을 때만 배너를 보여요.
  needsPrompt() { const c = readConsent(); return state.ready && !!state.mode && (!c || c.version !== VERSION); },
  configured() { return state.ready ? !!state.mode : null; },
  setConsent(agreed) {
    writeConsent(!!agreed);
    if (agreed) enable(); else disable();
  },
  track(name, params) {
    if (!/^[a-z][a-z0-9_]{0,39}$/.test(String(name))) return;
    if (!state.ready) { state.queue.push([name, params]); return; }   // 설정을 읽기 전: 잠깐 보관
    if (!granted() || !state.mode) return;                            // 동의 없음: 버림
    if (!state.loaded) { state.queue.push([name, params]); enable(); return; }
    send(name, params);
  },
  setUser(uid) {
    state.uid = uid || null;
    if (state.loaded) pushUser();
  },
  onReady(fn) { if (state.ready) fn(); else state.listeners.push(fn); },
};

// ── 시작: 설정 읽기 ─────────────────────────────────────────
(async () => {
  let cfg = {};
  try { const r = await fetch('/api/config'); if (r.ok) cfg = await r.json(); } catch {}
  state.cfg = { gtmId: cfg.gtmId || '', ga4Id: cfg.ga4Id || '', clarityId: cfg.clarityId || '' };
  state.mode = state.cfg.gtmId ? 'gtm' : (state.cfg.ga4Id || state.cfg.clarityId) ? 'direct' : null;
  state.ready = true;
  if (state.mode && granted()) await enable();
  else state.queue.length = 0;                                        // 동의 없으면 보관한 이벤트도 버려요
  state.listeners.splice(0).forEach(fn => { try { fn(); } catch (e) { console.error(e); } });
  window.dispatchEvent(new Event('tb:analytics-ready'));                // index.html 의 쿠키 배너가 이 신호를 기다려요
})();
