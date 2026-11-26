// GET /api/admin/stats?days=30 → 관리자 대시보드 숫자 (관리자만)
//
//  흐름: 토큰 검증(Supabase Auth) → admin_users 확인 → DB 함수 admin_dashboard(p_days) 실행 → 숫자만 응답
//  관리자가 아니면 401/403 만 돌려주고 데이터는 전혀 내려보내지 않아요.
//  응답은 { range, generated_at, supabase: {...}, ga4: null } 모양이에요.
//  나중에 GA4 데이터를 붙일 때는 ga4 자리에 넣고, 화면은 그 칸이 있으면 보여 주면 돼요(지금은 구현하지 않아요).
import { requireAdmin, rpc } from '../_supabase.js';

const RANGES = new Set([7, 30, 90]);

export default async function handler(req, res) {
  res.setHeader('cache-control', 'no-store');
  if (req.method !== 'GET') return res.status(405).json({ code: 'method_not_allowed' });

  const admin = await requireAdmin(req, res);
  if (!admin) return;

  const days = Number(req.query && req.query.days) || 30;
  if (!RANGES.has(days)) return res.status(400).json({ code: 'bad_range' });

  try {
    const supabase = await rpc('admin_dashboard', { p_days: days });
    return res.status(200).json({ range: days, generated_at: new Date().toISOString(), supabase, ga4: null });
  } catch (e) {
    console.error('admin stats', e);
    return res.status(502).json({ code: 'stats_failed' });
  }
}
