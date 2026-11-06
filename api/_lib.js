// Shared helpers for the show-search functions. Files starting with "_" are not routes on Vercel.
export const KOPIS_BASE = process.env.KOPIS_BASE || 'http://www.kopis.or.kr/openApi/restful';
export const TOUR_BASE = process.env.TOUR_BASE || 'https://apis.data.go.kr/B551011/KorService2';

// Read one tag's text out of a KOPIS XML block.
export const tag = (xml, name) => {
  const m = xml.match(new RegExp(`<${name}>([\\s\\S]*?)</${name}>`));
  return m ? m[1].replace(/<!\[CDATA\[|\]\]>/g, '').trim() : '';
};
export const blocks = (xml, name) => xml.match(new RegExp(`<${name}>[\\s\\S]*?</${name}>`, 'g')) || [];

// "2024.08.02" or "20240802" → "2024-08-02"
export const isoDate = d => {
  const m = String(d || '').replace(/\D/g, '').match(/^(\d{4})(\d{2})(\d{2})$/);
  return m ? `${m[1]}-${m[2]}-${m[3]}` : '';
};
export const ymd = date => date.toISOString().slice(0, 10).replace(/-/g, '');

export async function getText(url, ms = 9000) {
  const ctl = new AbortController();
  const t = setTimeout(() => ctl.abort(), ms);
  try {
    const r = await fetch(url, { signal: ctl.signal, headers: { 'user-agent': 'TicketBook/1.0' } });
    if (!r.ok) throw new Error('http ' + r.status);
    return await r.text();
  } finally { clearTimeout(t); }
}

// Only these hosts may be fetched through /api/image and /api/pick (poster images).
export const IMAGE_HOSTS = /(^|\.)kopis\.or\.kr$|(^|\.)visitkorea\.or\.kr$/;
