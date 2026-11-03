// Builds docs/data/news.json: collects election coverage from public RSS feeds,
// groups articles about the same story, writes a short multi-source summary
// for each story and translates it to Italian (Google Translate public endpoint).
import { XMLParser } from 'fast-xml-parser';

const FEEDS = [
  ['NPR', 'https://feeds.npr.org/1014/rss.xml'],
  ['NPR Elections', 'https://feeds.npr.org/139482413/rss.xml'],
  ['Politico', 'https://rss.politico.com/politics-news.xml'],
  ['The Hill', 'https://thehill.com/homenews/campaign/feed/'],
  ['New York Times', 'https://rss.nytimes.com/services/xml/rss/nyt/Politics.xml'],
  ['BBC', 'https://feeds.bbci.co.uk/news/world/us_and_canada/rss.xml'],
  ['CBS News', 'https://www.cbsnews.com/latest/rss/politics'],
  ['Fox News', 'https://moxie.foxnews.com/google-publisher/politics.xml'],
  ['ABC News', 'https://abcnews.go.com/abcnews/politicsheadlines'],
  ['The Guardian', 'https://www.theguardian.com/us-news/us-elections-2026/rss'],
  ['Google News', 'https://news.google.com/rss/search?q=midterm+elections+results&hl=en-US&gl=US&ceid=US:en'],
];

const ELECTION_RE = /\b(midterms?|election|elections|electoral|senate|house|governor|gubernatorial|ballot|ballots|vote|votes|voters|voting|polls?|congress|congressional|race|races|democrats?|republicans?|gop|swing|seat|seats|turnout|concede|concedes|projected|wins?|flip|flips|runoff|recount)\b/i;
const STOP = new Set('the a an and or of to in on for with at by from as is are was were be been it its this that these those after before over into about than but not no new says say said will would could can may might has have had his her their they them he she we you our your what who how why when where which more most up out off just also amid vs via us u.s. news live updates update'.split(' '));
const UA = { 'user-agent': 'Mozilla/5.0 (compatible; MidtermLiveBot/1.0)', accept: 'application/rss+xml, application/xml, text/xml, */*' };

const stripHtml = s => String(s || '').replace(/<[^>]*>/g, ' ').replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&#0?39;|&apos;|&#8217;/g, "'").replace(/&#8220;|&#8221;/g, '"').replace(/&#821[12];/g, '–').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/\s+/g, ' ').trim();
const tokens = s => new Set(String(s).toLowerCase().replace(/[^a-z0-9' ]/g, ' ').split(/\s+/).filter(w => w.length > 2 && !STOP.has(w)).map(w => w.replace(/'s$/, '')));

async function fetchFeed([source, url]) {
  try {
    const r = await fetch(url, { headers: UA, signal: AbortSignal.timeout(15000) });
    if (!r.ok) return [];
    const xml = await r.text();
    const doc = new XMLParser({ ignoreAttributes: false }).parse(xml);
    let items = doc?.rss?.channel?.item || doc?.feed?.entry || [];
    if (!Array.isArray(items)) items = [items];
    return items.map(it => {
      let title = stripHtml(it.title?.['#text'] ?? it.title);
      let src = source;
      if (source === 'Google News') {
        const m = title.match(/^(.*) - ([^-]+)$/);
        if (m) { title = m[1].trim(); src = m[2].trim(); }
      }
      const link = typeof it.link === 'string' ? it.link : (it.link?.['@_href'] || it.guid?.['#text'] || it.guid || '');
      const desc = source === 'Google News' ? '' : stripHtml(it.description ?? it.summary ?? it['content:encoded'] ?? '');
      const date = new Date(it.pubDate || it.published || it.updated || it['dc:date'] || Date.now());
      return { title, link: String(link), desc: desc.slice(0, 600), source: src, ts: isNaN(date) ? Date.now() : date.getTime() };
    }).filter(a => a.title && a.link);
  } catch { return []; }
}

function cluster(articles) {
  const clusters = [];
  for (const a of articles) {
    a.tok = tokens(a.title + ' ' + a.desc.slice(0, 160));
    let best = null, bestScore = 0;
    for (const c of clusters) {
      let inter = 0;
      for (const t of a.tok) if (c.tok.has(t)) inter++;
      const score = inter / Math.min(a.tok.size || 1, c.tok.size || 1);
      if (inter >= 3 && score > bestScore) { best = c; bestScore = score; }
    }
    if (best && bestScore >= 0.34) {
      best.items.push(a);
      for (const t of a.tok) best.tok.add(t);
    } else clusters.push({ items: [a], tok: new Set(a.tok) });
  }
  return clusters;
}

function sentences(text) {
  return String(text).split(/(?<=[.!?])\s+(?=[A-Z"“])/).map(s => s.trim()).filter(s => s.length > 40 && s.length < 320);
}

function summarize(items) {
  // Pick up to 3 informative sentences from different sources, skipping near duplicates.
  const picked = [];
  const seenSources = new Set();
  const byRecency = [...items].sort((a, b) => b.ts - a.ts);
  for (const pass of [0, 1]) {
    for (const a of byRecency) {
      if (picked.length >= 3) break;
      if (pass === 0 && seenSources.has(a.source)) continue;
      for (const s of sentences(a.desc)) {
        const st = tokens(s);
        const dup = picked.some(p => { let i = 0; for (const t of st) if (p.tok.has(t)) i++; return i / (st.size || 1) > 0.5; });
        if (!dup) { picked.push({ s, tok: st }); seenSources.add(a.source); break; }
      }
    }
  }
  if (!picked.length) return byRecency.find(a => a.desc)?.desc.slice(0, 280) || '';
  return picked.map(p => p.s).join(' ');
}

const cache = new Map();
async function translate(text) {
  if (!text) return text;
  if (cache.has(text)) return cache.get(text);
  try {
    const u = 'https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=it&dt=t&q=' + encodeURIComponent(text.slice(0, 1800));
    const r = await fetch(u, { headers: { 'user-agent': UA['user-agent'] }, signal: AbortSignal.timeout(10000) });
    if (!r.ok) throw new Error(r.status);
    const j = await r.json();
    const out = (j[0] || []).map(x => x[0]).join('');
    if (out) { cache.set(text, out); return out; }
  } catch {}
  return text;
}

export async function buildNews(prev) {
  if (prev?.translations) for (const [k, v] of Object.entries(prev.translations)) cache.set(k, v);
  const all = (await Promise.all(FEEDS.map(fetchFeed))).flat();
  const now = Date.now();
  const seen = new Set();
  const relevant = all
    .filter(a => now - a.ts < 36 * 3600e3 && ELECTION_RE.test(a.title + ' ' + a.desc))
    .filter(a => { const k = a.title.toLowerCase(); if (seen.has(k)) return false; seen.add(k); return true; })
    .sort((a, b) => b.ts - a.ts);
  if (!relevant.length) return null;

  const clusters = cluster(relevant).map(c => {
    const sources = new Set(c.items.map(i => i.source));
    const newest = Math.max(...c.items.map(i => i.ts));
    const ageH = (now - newest) / 3600e3;
    return { ...c, sources, newest, score: sources.size * 3 + c.items.length - ageH * 0.6 };
  }).sort((a, b) => b.score - a.score);

  const stories = [];
  for (const c of clusters.slice(0, 8)) {
    const lead = [...c.items].sort((a, b) => (b.desc.length > 0) - (a.desc.length > 0) || b.ts - a.ts)[0];
    const summaryEn = summarize(c.items);
    stories.push({
      title: await translate(lead.title),
      titleEn: lead.title,
      summary: await translate(summaryEn),
      ts: c.newest,
      sourcesCount: c.sources.size,
      articles: c.items.slice(0, 5).map(i => ({ title: i.title, source: i.source, link: i.link, ts: i.ts })),
    });
  }

  // "Da leggere": best single articles from big stories, one per story, diverse sources.
  const reads = [];
  const usedSources = new Set();
  for (const c of clusters.slice(0, 20)) {
    const a = [...c.items].sort((x, y) => (usedSources.has(x.source) - usedSources.has(y.source)) || (y.desc.length - x.desc.length))[0];
    if (!a) continue;
    usedSources.add(a.source);
    reads.push({ title: await translate(a.title), titleEn: a.title, source: a.source, link: a.link, ts: a.ts });
    if (reads.length >= 6) break;
  }

  const translations = {};
  for (const [k, v] of cache) translations[k] = v;
  // keep the translation cache bounded
  const keep = Object.fromEntries(Object.entries(translations).slice(-300));
  return { v: 1, generatedAt: new Date().toISOString(), articlesScanned: relevant.length, stories, reads, translations: keep };
}
