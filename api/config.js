// GET /api/config → 화면에서 쓸 Supabase 공개 설정
// Vercel 환경 변수 SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY 를 읽어요.
// publishable(anon) 키는 브라우저에 공개돼도 되는 키예요. service_role(secret) 키는 절대 넣지 마세요.

// 실수로 secret 키를 넣었을 때 화면으로 내보내지 않도록 막아요.
function isSecretKey(key) {
  if (key.startsWith('sb_secret_')) return true;
  const parts = key.split('.');
  if (parts.length === 3) {
    try {
      const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
      return payload.role === 'service_role';
    } catch { return false; }
  }
  return false;
}

export default function handler(req, res) {
  const supabaseUrl = process.env.SUPABASE_URL || '';
  const supabaseKey = process.env.SUPABASE_PUBLISHABLE_KEY || process.env.SUPABASE_ANON_KEY || '';
  if (supabaseKey && isSecretKey(supabaseKey)) {
    return res.status(500).json({ code: 'secret_key_not_allowed' });
  }
  res.setHeader('cache-control', 'public, max-age=300');
  return res.status(200).json({ supabaseUrl, supabaseKey });
}
