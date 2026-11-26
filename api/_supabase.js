// 서버 함수들이 같이 쓰는 Supabase 도구. 파일 이름이 "_" 로 시작해서 주소로 열리지 않아요.
//
//  · SUPABASE_SERVICE_ROLE_KEY(비밀 키)는 이 파일을 거쳐 서버 안에서만 쓰여요.
//    브라우저로 내보내는 곳은 없고, /api/config 도 이 변수를 읽지 않아요.
//  · 사용자 확인은 브라우저가 보낸 로그인 토큰을 Supabase 에 되물어 검증해요. 토큰 내용을 믿지 않아요.
//  · 관리자 여부는 admin_users 표(003 마이그레이션)에서 service_role 로 조회해요.

const URL_ = (process.env.SUPABASE_URL || '').replace(/\/+$/, '');
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const PUBLIC_KEY = process.env.SUPABASE_PUBLISHABLE_KEY || process.env.SUPABASE_ANON_KEY || '';

export const configured = () => !!(URL_ && SERVICE_KEY);

// service_role 로 Supabase 에 요청할 때 붙이는 헤더
const adminHeaders = extra => ({
  apikey: SERVICE_KEY,
  authorization: 'Bearer ' + SERVICE_KEY,
  'content-type': 'application/json',
  ...extra,
});

// 요청의 Authorization: Bearer <토큰> 에서 토큰만 꺼내요.
export function bearer(req) {
  const h = req.headers.authorization || req.headers.Authorization || '';
  const m = /^Bearer\s+(.+)$/i.exec(h);
  return m ? m[1].trim() : '';
}

// 토큰이 진짜인지 Supabase Auth 에 물어보고 사용자(id, email)를 돌려줘요. 아니면 null.
export async function getUser(token) {
  if (!token || !URL_ || !PUBLIC_KEY) return null;
  try {
    const r = await fetch(URL_ + '/auth/v1/user', {
      headers: { apikey: PUBLIC_KEY, authorization: 'Bearer ' + token },
    });
    if (!r.ok) return null;
    const u = await r.json();
    return u && u.id ? { id: u.id, email: u.email || '' } : null;
  } catch { return null; }
}

// admin_users 표에 있는 사람인지 (service_role 로 조회)
export async function isAdmin(userId) {
  if (!configured() || !userId) return false;
  const r = await fetch(URL_ + `/rest/v1/admin_users?select=user_id&user_id=eq.${encodeURIComponent(userId)}&limit=1`, {
    headers: adminHeaders(),
  });
  if (!r.ok) throw new Error('admin lookup http ' + r.status);
  const rows = await r.json();
  return Array.isArray(rows) && rows.length === 1;
}

// DB 함수(RPC)를 service_role 로 실행해요.
export async function rpc(name, args = {}) {
  const r = await fetch(URL_ + '/rest/v1/rpc/' + name, {
    method: 'POST', headers: adminHeaders(), body: JSON.stringify(args),
  });
  if (!r.ok) throw new Error(`rpc ${name} http ${r.status}: ${(await r.text()).slice(0, 200)}`);
  return r.json();
}

// 로그인한 사용자를 확인해요. 실패하면 401 을 보내고 null 을 돌려줘요.
export async function requireUser(req, res) {
  if (!configured()) { res.status(500).json({ code: 'server_not_configured' }); return null; }
  const user = await getUser(bearer(req));
  if (!user) { res.status(401).json({ code: 'unauthorized' }); return null; }
  return user;
}

// 관리자를 확인해요. 로그인 안 했으면 401, 관리자가 아니면 403. 데이터는 한 글자도 내려보내지 않아요.
export async function requireAdmin(req, res) {
  const user = await requireUser(req, res);
  if (!user) return null;
  if (!(await isAdmin(user.id))) { res.status(403).json({ code: 'forbidden' }); return null; }
  return user;
}

// Storage 의 posters/<userId>/ 아래 파일을 모두 지워요 (<id>/<기록 id>/<파일>, <id>/profile/<파일> 두 단계).
export async function removeUserFiles(userId, bucket = 'posters') {
  const list = async prefix => {
    const r = await fetch(URL_ + `/storage/v1/object/list/${bucket}`, {
      method: 'POST', headers: adminHeaders(),
      body: JSON.stringify({ prefix, limit: 1000, offset: 0 }),
    });
    if (!r.ok) throw new Error('storage list http ' + r.status);
    return r.json();
  };
  const paths = [];
  for (const e of await list(userId)) {
    if (e.id) { paths.push(`${userId}/${e.name}`); continue; }        // 파일
    for (const f of await list(`${userId}/${e.name}`)) if (f.id) paths.push(`${userId}/${e.name}/${f.name}`); // 폴더 안 파일
  }
  if (!paths.length) return 0;
  const r = await fetch(URL_ + `/storage/v1/object/${bucket}`, {
    method: 'DELETE', headers: adminHeaders(), body: JSON.stringify({ prefixes: paths }),
  });
  if (!r.ok) throw new Error('storage remove http ' + r.status);
  return paths.length;
}

// 사용자 계정을 지워요. DB 의 records / user_visits / user_consents / user_events 는 cascade 로 따라 지워져요.
export async function deleteUser(userId) {
  const r = await fetch(URL_ + '/auth/v1/admin/users/' + encodeURIComponent(userId), {
    method: 'DELETE', headers: adminHeaders(),
  });
  if (!r.ok) throw new Error('delete user http ' + r.status);
}
