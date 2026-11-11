// TICKET BOOK · Supabase 연결 (로그인, 기록 저장, 이미지 업로드, 공개 기록)
// 설정값은 /api/config 가 Vercel 환경 변수(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY)에서 읽어 줘요.
// 설정이 없으면 아무것도 하지 않고, 사이트는 지금처럼 이 브라우저(localStorage)에만 저장해요.
import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/+esm';

const BUCKET = 'posters';
const COLS = 'id,user_id,data,is_public,updated_at';
const app = window.TBApp;            // index.html 이 먼저 만들어 둔 화면 쪽 연결 고리
const isUuid = v => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(String(v || ''));
const rand = () => Math.random().toString(36).slice(2, 10);
const newId = () => (crypto.randomUUID ? crypto.randomUUID()
  : '10000000-1000-4000-8000-100000000000'.replace(/[018]/g, c => (c ^ crypto.getRandomValues(new Uint8Array(1))[0] & 15 >> c / 4).toString(16)));

const Cloud = {
  configured: false,
  user: null,
  sb: null,

  async signIn(email) {
    const { error } = await this.sb.auth.signInWithOtp({
      email,
      options: { emailRedirectTo: location.origin + '/' },
    });
    if (error) throw error;
  },

  // 메일에 적힌 6자리 코드로 로그인 (링크가 다른 브라우저에서 열려도 지금 브라우저에 로그인돼요)
  async verifyCode(email, token) {
    const { error } = await this.sb.auth.verifyOtp({ email, token, type: 'email' });
    if (error) throw error;
  },

  async signOut() {
    await this.sb.auth.signOut();
  },

  toRec(row) {
    return { ...row.data, id: row.id, public: !!row.is_public, owner: row.user_id };
  },

  profile: null, // 내 사람·표지 설정 (records 테이블의 kind:'profile' 줄 하나)

  async loadMine() {
    const { data, error } = await this.sb.from('records').select(COLS)
      .eq('user_id', this.user.id).order('updated_at', { ascending: false });
    if (error) throw error;
    const all = (data || []).map(r => this.toRec(r));
    this.profile = all.find(r => r.kind === 'profile') || null;
    return all.filter(r => r.kind !== 'profile');
  },

  // 내 사람(아바타)과 표지 설정을 저장해요. 표지 사진은 Storage 의 <내 id>/profile/ 폴더에 올려요.
  async saveProfile({ avatar, cover }) {
    const uid = this.user.id;
    const id = this.profile && isUuid(this.profile.id) ? this.profile.id : newId();
    const folder = `${uid}/profile`;
    const keep = new Set();
    const c = { ...(cover || {}) };
    for (const k of ['photo', 'bg']) if (c[k]) c[k] = await this.upload(c[k], folder, k, keep);
    const data = { kind: 'profile', avatar: { ...(avatar || {}) }, cover: c };
    const { data: row, error } = await this.sb.from('records')
      .upsert({ id, user_id: uid, data, is_public: !avatar || avatar.show !== false })
      .select(COLS).single();
    if (error) throw error;
    const { data: files } = await this.sb.storage.from(BUCKET).list(folder, { limit: 100 });
    const stale = (files || []).map(f => `${folder}/${f.name}`).filter(p => !keep.has(p));
    if (stale.length) await this.sb.storage.from(BUCKET).remove(stale);
    this.profile = this.toRec(row);
    return this.profile;
  },

  async loadPublic(limit = 60) {
    const { data, error } = await this.sb.from('records').select(COLS)
      .eq('is_public', true).order('updated_at', { ascending: false }).limit(limit);
    if (error) throw error;
    return (data || []).map(r => this.toRec(r));
  },

  // 이미지 주소에서 Storage 안의 경로(<user id>/<기록 id>/<파일>)만 꺼내요.
  pathOf(url) {
    const m = String(url || '').match(/\/storage\/v1\/object\/public\/posters\/(.+)$/);
    return m ? decodeURIComponent(m[1].split('?')[0]) : '';
  },

  // dataURL 이면 Storage 에 올리고 주소로 바꿔요. 이미 올린 주소면 그대로 둬요.
  async upload(value, folder, name, keep) {
    if (typeof value !== 'string' || !value) return value;
    if (!value.startsWith('data:')) {
      const p = this.pathOf(value);
      if (p) keep.add(p);
      return value;
    }
    const blob = await (await fetch(value)).blob();
    const ext = blob.type === 'image/png' ? 'png' : blob.type === 'image/webp' ? 'webp' : 'jpg';
    const path = `${folder}/${name}-${rand()}.${ext}`;
    const { error } = await this.sb.storage.from(BUCKET).upload(path, blob, {
      contentType: blob.type || 'image/jpeg', upsert: false, cacheControl: '31536000',
    });
    if (error) throw error;
    keep.add(path);
    return this.sb.storage.from(BUCKET).getPublicUrl(path).data.publicUrl;
  },

  async save(rec) {
    const uid = this.user.id;
    const id = isUuid(rec.id) ? rec.id : newId();
    const folder = `${uid}/${id}`;
    const keep = new Set();
    const data = JSON.parse(JSON.stringify(rec));
    delete data.id; delete data.public; delete data.owner; delete data.sample;

    data.poster = await this.upload(data.poster, folder, 'poster', keep);
    for (let i = 0; i < (data.bands || []).length; i++) {
      if (data.bands[i].img) data.bands[i].img = await this.upload(data.bands[i].img, folder, 'band' + i, keep);
    }
    if (data.ticket && data.ticket.img) data.ticket.img = await this.upload(data.ticket.img, folder, 'ticket', keep);
    // 혹시 남은 dataURL 은 DB 에 넣지 않아요.
    const json = JSON.stringify(data, (k, v) => (typeof v === 'string' && v.startsWith('data:') ? undefined : v));

    const { data: row, error } = await this.sb.from('records')
      .upsert({ id, user_id: uid, data: JSON.parse(json), is_public: !!rec.public })
      .select(COLS).single();
    if (error) throw error;

    // 이 기록 폴더에서 더 이상 쓰지 않는 예전 이미지를 지워요.
    const { data: files } = await this.sb.storage.from(BUCKET).list(folder, { limit: 100 });
    const stale = (files || []).map(f => `${folder}/${f.name}`).filter(p => !keep.has(p));
    if (stale.length) await this.sb.storage.from(BUCKET).remove(stale);
    return this.toRec(row);
  },

  async remove(id) {
    const { error } = await this.sb.from('records').delete().eq('id', id);
    if (error) throw error;
    const folder = `${this.user.id}/${id}`;
    const { data: files } = await this.sb.storage.from(BUCKET).list(folder, { limit: 100 });
    if (files && files.length) await this.sb.storage.from(BUCKET).remove(files.map(f => `${folder}/${f.name}`));
  },

  // 이 브라우저(localStorage)의 기록을 내 계정으로 올려요. 예시 기록은 빼요.
  async importLocal(list, onProgress) {
    const todo = list.filter(r => !r.sample);
    const saved = [];
    for (let i = 0; i < todo.length; i++) {
      onProgress && onProgress(i, todo.length);
      saved.push(await this.save({ ...todo[i], id: null, public: false }));
    }
    onProgress && onProgress(todo.length, todo.length);
    return saved;
  },
};

async function start() {
  let cfg = null;
  try {
    const r = await fetch('/api/config');
    if (r.ok) cfg = await r.json();
  } catch {}
  if (!cfg || !cfg.supabaseUrl || !cfg.supabaseKey) { app.cloudUnavailable(); return; }

  Cloud.sb = createClient(cfg.supabaseUrl, cfg.supabaseKey, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, flowType: 'pkce' },
  });
  Cloud.configured = true;
  window.TBCloud = Cloud;

  let lastUid = null;
  const apply = async session => {
    const uid = session && session.user ? session.user.id : null;
    if (uid === lastUid) return;
    lastUid = uid;
    Cloud.user = session ? session.user : null;
    if (!uid) { app.useLocal(); return; }
    app.cloudLoading();
    try { app.useCloud(await Cloud.loadMine()); }
    catch (e) { console.error(e); app.cloudError('기록을 불러오지 못했어요. 잠시 뒤 새로고침해 주세요'); }
  };
  Cloud.sb.auth.onAuthStateChange((event, session) => { setTimeout(() => apply(session), 0); });
  const { data } = await Cloud.sb.auth.getSession();
  await apply(data.session);
  app.cloudReady();
}

start().catch(e => { console.error(e); app.cloudUnavailable(); });
