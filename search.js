// GET /api/search?q=이름 → { results: [{ source, id, title, start, end, place, genre, poster }] }
// Searches KOPIS (공연예술통합전산망) and, if a key is set, TourAPI festivals.
import { KOPIS_BASE, TOUR_BASE, tag, blocks, isoDate, ymd, getText } from './_lib.js';

const MONTHS_BACK = +(process.env.KOPIS_MONTHS_BACK || 18);
const MONTHS_AHEAD = +(process.env.KOPIS_MONTHS_AHEAD || 6);
const MAX_DAYS = +(process.env.KOPIS_MAX_DAYS || 31); // length of one KOPIS request window

async function searchKopis(q, key) {
  const now = new Date(), start = new Date(now), end = new Date(now);
  start.setMonth(start.getMonth() - MONTHS_BACK);
  end.setMonth(end.getMonth() + MONTHS_AHEAD);
  const windows = [];
  for (let s = new Date(start); s < end; s = new Date(s.getTime() + MAX_DAYS * 864e5)) {
    const e = new Date(Math.min(end.getTime(), s.getTime() + (MAX_DAYS - 1) * 864e5));
    windows.push([ymd(s), ymd(e)]);
  }
  const seen = new Map();
  const runs = windows.map(([sd, ed]) => getText(`${KOPIS_BASE}/pblprfr?` + new URLSearchParams({
    service: key, stdate: sd, eddate: ed, cpage: '1', rows: '30', shprfnm: q,
  })).then(xml => {
    for (const db of blocks(xml, 'db')) {
      const id = tag(db, 'mt20id');
      if (!id || seen.has(id)) continue;
      seen.set(id, {
        source: 'kopis', id, title: tag(db, 'prfnm'),
        start: isoDate(tag(db, 'prfpdfrom')), end: isoDate(tag(db, 'prfpdto')),
        place: tag(db, 'fcltynm'), genre: tag(db, 'genrenm'), poster: tag(db, 'poster'),
      });
    }
  }).catch(() => {}));
  await Promise.all(runs);
  return [...seen.values()];
}

async function searchTour(q, key) {
  const params = { serviceKey: key, MobileOS: 'ETC', MobileApp: 'TicketBook', _type: 'json', numOfRows: '20', pageNo: '1' };
  const text = await getText(`${TOUR_BASE}/searchKeyword2?` + new URLSearchParams({ ...params, keyword: q }));
  const items = [].concat(JSON.parse(text)?.response?.body?.items?.item || []).filter(i => String(i.contenttypeid) === '15').slice(0, 6);
  return Promise.all(items.map(async i => {
    let start = '', end = '', place = i.addr1 || '';
    try {
      const d = JSON.parse(await getText(`${TOUR_BASE}/detailIntro2?` + new URLSearchParams({ ...params, contentId: i.contentid, contentTypeId: '15' })));
      const it = [].concat(d?.response?.body?.items?.item || [])[0] || {};
      start = isoDate(it.eventstartdate); end = isoDate(it.eventenddate); place = it.eventplace || place;
    } catch {}
    return { source: 'tour', id: String(i.contentid), title: i.title, start, end, place, genre: '축제', poster: i.firstimage || '' };
  }));
}

export default async function handler(req, res) {
  const q = String(req.query.q || '').trim().slice(0, 40);
  if (!q) return res.status(400).json({ code: 'empty_query' });
  const kopisKey = process.env.KOPIS_API_KEY, tourKey = process.env.TOUR_API_KEY;
  if (!kopisKey && !tourKey) return res.status(500).json({ code: 'no_api_key' });
  const [k, t] = await Promise.all([
    kopisKey ? searchKopis(q, kopisKey).catch(() => []) : [],
    tourKey ? searchTour(q, tourKey).catch(() => []) : [],
  ]);
  const results = [...t, ...k].sort((a, b) => (b.start || '').localeCompare(a.start || '')).slice(0, 20);
  res.setHeader('cache-control', 's-maxage=3600, stale-while-revalidate=86400');
  return res.status(200).json({ results });
}
