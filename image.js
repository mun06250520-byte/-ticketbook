// GET /api/image?url=… → the poster image itself, for search-result thumbnails (KOPIS posters are http-only).
import { IMAGE_HOSTS } from './_lib.js';

export default async function handler(req, res) {
  try {
    const u = new URL(String(req.query.url || ''));
    if (!IMAGE_HOSTS.test(u.hostname)) return res.status(400).end();
    const r = await fetch(u, { headers: { 'user-agent': 'TicketBook/1.0' } });
    const type = r.headers.get('content-type') || '';
    if (!r.ok || !type.startsWith('image/')) return res.status(404).end();
    res.setHeader('content-type', type);
    res.setHeader('cache-control', 's-maxage=604800, max-age=86400');
    return res.status(200).send(Buffer.from(await r.arrayBuffer()));
  } catch { return res.status(400).end(); }
}
