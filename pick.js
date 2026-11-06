// GET /api/pick?source=kopis&id=PF123456&poster=URL → { cast, time, image (data URL of the poster) }
import { KOPIS_BASE, tag, getText, IMAGE_HOSTS } from './_lib.js';

async function imageData(url) {
  try {
    const u = new URL(url);
    if (!IMAGE_HOSTS.test(u.hostname)) return '';
    const r = await fetch(u, { headers: { 'user-agent': 'TicketBook/1.0' } });
    if (!r.ok) return '';
    const type = r.headers.get('content-type') || 'image/jpeg';
    if (!type.startsWith('image/')) return '';
    const buf = Buffer.from(await r.arrayBuffer());
    if (buf.length > 3_000_000) return '';
    return `data:${type};base64,${buf.toString('base64')}`;
  } catch { return ''; }
}

export default async function handler(req, res) {
  const { source = '', id = '', poster = '' } = req.query;
  let cast = '', time = '', posterUrl = String(poster);
  if (source === 'kopis' && /^[A-Z0-9]+$/.test(id) && process.env.KOPIS_API_KEY) {
    try {
      const xml = await getText(`${KOPIS_BASE}/pblprfr/${id}?service=${encodeURIComponent(process.env.KOPIS_API_KEY)}`);
      cast = tag(xml, 'prfcast').replace(/\s*등\s*$/, '').split(',').map(s => s.trim()).filter(Boolean).slice(0, 3).join(', ').slice(0, 20);
      time = (tag(xml, 'dtguidance').match(/\b(\d{1,2}:\d{2})\b/) || [])[1] || '';
      posterUrl = tag(xml, 'poster') || posterUrl;
    } catch {}
  }
  const image = posterUrl ? await imageData(posterUrl) : '';
  return res.status(200).json({ cast, time, image });
}
