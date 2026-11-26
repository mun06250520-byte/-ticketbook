// POST /api/account/delete → 지금 로그인한 사람의 계정을 지워요 (회원 탈퇴)
//
//  · 본인 토큰으로만 본인 계정을 지울 수 있어요. 요청 본문에 다른 사람 id 를 넣어도 무시돼요.
//  · 순서: 토큰 검증 → Storage 의 내 이미지 폴더 삭제 → auth.users 에서 삭제
//    → records / user_visits / user_consents / user_events / admin_users 는 DB 가 cascade 로 함께 지워요.
//    feedback 은 user_id 만 비워지고 의견 내용은 남아요(기존 설계).
//  · 실수 방지로 본문에 { "confirm": "탈퇴" } 가 있어야 해요.
import { requireUser, removeUserFiles, deleteUser } from '../_supabase.js';

export default async function handler(req, res) {
  res.setHeader('cache-control', 'no-store');
  if (req.method !== 'POST') return res.status(405).json({ code: 'method_not_allowed' });

  const user = await requireUser(req, res);
  if (!user) return;

  let body = req.body;
  if (typeof body === 'string') { try { body = JSON.parse(body); } catch { body = {}; } }
  if (!body || body.confirm !== '탈퇴') return res.status(400).json({ code: 'confirm_required' });

  try {
    const removed = await removeUserFiles(user.id);
    await deleteUser(user.id);
    return res.status(200).json({ ok: true, files_removed: removed });
  } catch (e) {
    console.error('account delete', e);
    return res.status(502).json({ code: 'delete_failed' });
  }
}
