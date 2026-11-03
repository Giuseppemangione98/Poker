// Election-night updater, run by .github/workflows/midterm-live.yml.
// Every minute: fetch AP results (NYT JSON), diff against the previous state,
// send push notifications, collect new push subscriptions.
// Every 10 minutes: rebuild the news digest. Commits data files back to the branch.
import fs from 'node:fs';
import { execSync } from 'node:child_process';
import { fetchFeeds, buildSnapshot, STATE_NAMES } from '../../docs/nyt.js';
import { SITE_URL, NTFY_INBOX, NTFY_ALERTS } from '../../docs/config.js';
import { buildNews } from './news.mjs';
import { Push } from './push.mjs';

const ROOT = new URL('../../', import.meta.url);
const P = rel => new URL(rel, ROOT);
const RESULTS = P('docs/data/results.json');
const NEWS = P('docs/data/news.json');
const PUSHCFG = P('docs/data/push.json');
const NOTIFIED = P('scripts/midterm/state/notified.json');
const TRANSL = P('scripts/midterm/state/translations.json');

const LOOP_MINUTES = Number(process.env.LOOP_MINUTES || 345);
const ONCE = process.env.ONCE === '1';
const NO_GIT = process.env.NO_GIT === '1';
const HEADERS = { 'user-agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15', accept: 'application/json', referer: 'https://www.nytimes.com/' };

const readJSON = (u, d = null) => { try { return JSON.parse(fs.readFileSync(u, 'utf8')); } catch { return d; } };
const writeJSON = (u, v) => { fs.mkdirSync(new URL('.', u), { recursive: true }); fs.writeFileSync(u, JSON.stringify(v)); };
const sleep = ms => new Promise(r => setTimeout(r, ms));
const PARTY = { D: 'D', R: 'R', O: 'Ind.' };
const OFFICE_IT = { S: 'Senato', G: 'Governatore', H: 'Camera' };

const push = new Push({
  publicKey: process.env.VAPID_PUBLIC,
  privateKey: process.env.VAPID_PRIVATE,
  subject: SITE_URL,
  inboxTopic: NTFY_INBOX,
  alertsTopic: NTFY_ALERTS,
});
if (push.publicKey) {
  const cur = readJSON(PUSHCFG, {});
  if (cur.publicKey !== push.publicKey) writeJSON(PUSHCFG, { publicKey: push.publicKey, inbox: NTFY_INBOX });
}

let prev = readJSON(RESULTS);
const notified = readJSON(NOTIFIED, { calls: {}, flips: {}, control: {}, house: null, firstResults: false, news: {}, lastNewsPush: 0 });
let pendingHouse = 0;
let lastHouseSummary = Date.now();

function raceLabel(r) {
  const st = STATE_NAMES[r.st] || r.st;
  if (r.office === 'H') return `${st}-${r.seat || 'AL'}`;
  return `${OFFICE_IT[r.office]} · ${st}${r.special ? ' (suppletiva)' : ''}`;
}
const fmtCand = c => `${c.name} (${PARTY[c.party]})`;
const margin = r => r.cands.length >= 2 ? `${r.cands[0].pct}% – ${r.cands[1].pct}%` : '';

function diff(oldS, newS) {
  const events = [];
  if (!oldS) return events;
  const oldRace = {};
  for (const st of Object.values(oldS.states || {})) for (const o of ['S', 'G', 'H']) for (const r of st[o] || []) oldRace[r.id] = r;

  let anyCounted = false;
  for (const st of Object.values(newS.states)) for (const o of ['S', 'G', 'H']) for (const r of st[o]) {
    if (r.total > 0) anyCounted = true;
    const was = oldRace[r.id];
    if (r.called && !notified.calls[r.id]) {
      notified.calls[r.id] = Date.now();
      if (o === 'H') { pendingHouse++; continue; }
      if (r.uncontested && !was) continue;
      const w = r.cands.find(c => c.won) || r.cands[0];
      events.push({
        kind: 'call', office: o, st: r.st,
        title: r.runoff ? `${raceLabel(r)}: si va al ballottaggio` : `${raceLabel(r)}: vince ${w ? w.name : '—'} (${PARTY[r.winner] || '?'})`,
        body: r.runoff ? r.cands.slice(0, 2).map(fmtCand).join(' vs ') : `${r.eevp != null ? `Scrutinato ~${r.eevp}% · ` : ''}${margin(r)}${r.winner && was && was.leader && was.leader !== r.winner ? ' · rimonta!' : ''}`,
        short: `${r.st} ${PARTY[r.winner] || '?'}`,
      });
    } else if (o !== 'H' && was && !r.called && r.leader && was.leader && r.leader !== was.leader && (r.eevp || 0) >= 40) {
      const last = notified.flips[r.id] || 0;
      if (Date.now() - last > 30 * 60e3) {
        notified.flips[r.id] = Date.now();
        events.push({ kind: 'flip', title: `Sorpasso: ${raceLabel(r)}`, body: `Ora in testa ${fmtCand(r.cands[0])} · ${margin(r)} con ~${r.eevp}% scrutinato` });
      }
    }
  }
  if (anyCounted && !notified.firstResults) {
    notified.firstResults = true;
    events.push({ kind: 'first', title: 'Arrivano i primi risultati 🗳️', body: 'Lo spoglio è iniziato: apri la mappa per seguirlo in diretta.' });
  }
  const CH = { S: 'il Senato', H: 'la Camera', G: 'la maggioranza dei governatori' };
  for (const o of ['S', 'H']) {
    const t = newS.control[o];
    for (const p of ['D', 'R']) if (t.won[p] >= t.needed && notified.control[o] !== p && newS.available[o]) {
      notified.control[o] = p;
      events.push({ kind: 'control', title: `${p === 'D' ? 'I Democratici' : 'I Repubblicani'} conquistano ${CH[o]}`, body: `${p === 'D' ? 'Democratici' : 'Repubblicani'} a quota ${t.won[p]} seggi (servono ${t.needed}).` });
    }
  }
  return events;
}

function houseSummary(snap) {
  const t = snap.control.H;
  return { kind: 'house', title: `Camera: D ${t.won.D} · R ${t.won.R}`, body: `Seggi assegnati (servono 218). +${pendingHouse} nell'ultimo aggiornamento · in testa: D ${t.lead.D}, R ${t.lead.R}.` };
}

async function sendEvents(events) {
  if (!events.length) return;
  const calls = events.filter(e => e.kind === 'call');
  const rest = events.filter(e => e.kind !== 'call');
  const out = [...rest];
  if (calls.length > 3) {
    const bySenate = calls.filter(c => c.office === 'S'), byGov = calls.filter(c => c.office === 'G');
    if (bySenate.length) out.push({ title: `Senato: ${bySenate.length} nuove proiezioni`, body: bySenate.map(c => c.short).join(' · ') });
    if (byGov.length) out.push({ title: `Governatori: ${byGov.length} nuove proiezioni`, body: byGov.map(c => c.short).join(' · ') });
  } else out.push(...calls);
  for (const e of out) await push.broadcast({ title: e.title, body: e.body, url: './', tag: `${e.kind || 'call'}-${Date.now()}` });
}

function git(msg) {
  if (NO_GIT) return;
  try {
    execSync('git add docs/data scripts/midterm/state', { cwd: ROOT, stdio: 'ignore' });
    if (!execSync('git status --porcelain docs/data scripts/midterm/state', { cwd: ROOT }).toString().trim()) return;
    execSync(`git commit -q -m "${msg}"`, { cwd: ROOT });
    for (let i = 0; i < 4; i++) {
      try {
        execSync('git pull -q --rebase -X theirs origin HEAD', { cwd: ROOT, stdio: 'ignore' });
        execSync('git push -q origin HEAD', { cwd: ROOT, stdio: 'ignore' });
        return;
      } catch { execSync(`sleep ${2 ** (i + 1)}`); }
    }
    console.log('git push failed');
  } catch (e) { console.log('git error', e.message); }
}

async function newsCycle() {
  const prevNews = readJSON(NEWS);
  const tr = readJSON(TRANSL, {});
  const news = await buildNews({ translations: tr });
  if (!news) return;
  writeJSON(TRANSL, news.translations);
  delete news.translations;
  writeJSON(NEWS, news);
  // Breaking news push: a new story covered by many outlets, at most every 45 min.
  const top = news.stories[0];
  if (prevNews && top && top.sourcesCount >= 4 && !notified.news[top.titleEn] && Date.now() - (notified.lastNewsPush || 0) > 45 * 60e3) {
    notified.news[top.titleEn] = Date.now();
    notified.lastNewsPush = Date.now();
    await push.broadcast({ title: `📰 ${top.title}`, body: top.summary.slice(0, 180), url: './#news', tag: 'news' });
  }
  for (const s of news.stories) if (!notified.news[s.titleEn] && s.sourcesCount >= 4 && !prevNews) notified.news[s.titleEn] = Date.now();
}

async function resultsCycle() {
  const feeds = await fetchFeeds(fetch, HEADERS);
  if (!feeds.S && !feeds.H && !feeds.G) { console.log('results: feeds not available yet'); return false; }
  const snap = buildSnapshot(feeds);
  const events = diff(prev, snap);
  if (!prev) for (const st of Object.values(snap.states)) for (const o of ['S', 'G', 'H']) for (const r of st[o]) if (r.called) notified.calls[r.id] = Date.now();
  if (pendingHouse && (Date.now() - lastHouseSummary > 30 * 60e3 || pendingHouse >= 30)) {
    events.push(houseSummary(snap)); pendingHouse = 0; lastHouseSummary = Date.now();
  }
  await sendEvents(events);
  const changed = !prev || JSON.stringify({ ...prev, fetchedAt: 0 }) !== JSON.stringify({ ...snap, fetchedAt: 0 });
  prev = snap;
  if (changed) writeJSON(RESULTS, snap);
  return { changed, urgent: events.length > 0 };
}

const end = Date.now() + LOOP_MINUTES * 60e3;
let lastNews = 0, lastCommit = 0, dirty = false;
while (true) {
  const t0 = Date.now();
  try {
    const r = await resultsCycle();
    if (r && r.changed) dirty = true;
    if (Date.now() - lastNews > 10 * 60e3) { await newsCycle(); lastNews = Date.now(); dirty = true; }
    if (await push.pollInbox()) dirty = true;
    if (push.save()) dirty = true;
    writeJSON(NOTIFIED, notified);
    if (dirty && (ONCE || (r && r.urgent) || Date.now() - lastCommit > 6 * 60e3)) {
      git(`midterm: data update ${new Date().toISOString().slice(0, 16)}Z`);
      lastCommit = Date.now(); dirty = false;
    }
  } catch (e) { console.log('cycle error', e.stack || e.message); }
  if (ONCE || Date.now() > end) break;
  await sleep(Math.max(5e3, 60e3 - (Date.now() - t0)));
}
if (dirty) git(`midterm: data update ${new Date().toISOString().slice(0, 16)}Z`);
