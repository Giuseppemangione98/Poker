import { STATE_PATHS } from './states.js';
import { fetchFeeds, buildSnapshot, STATE_NAMES } from './nyt.js';
import { RAW_DATA, NTFY_INBOX } from './config.js';

// States with a scheduled 2026 race (shown as "in attesa" before votes arrive).
const SENATE_2026 = 'AL AK AR CO DE FL GA ID IL IA KS KY LA ME MA MI MN MS MT NE NH NJ NM NC OH OK OR RI SC SD TN TX VA WV WY'.split(' ');
const GOV_2026 = 'AL AK AZ AR CA CO CT FL GA HI ID IL IA KS ME MD MA MI MN NE NV NH NM NY OH OK OR PA RI SC SD TN TX VT WI WY'.split(' ');
const SMALL_NE = new Set(['VT', 'NH', 'MA', 'RI', 'CT', 'NJ', 'DE', 'MD', 'DC']);
const OFFICE_IT = { S: 'Senato', H: 'Camera', G: 'Governatore' };
const PARTY_IT = { D: 'Dem.', R: 'Rep.', O: 'Ind.' };

const $ = s => document.querySelector(s);
const esc = v => String(v ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const nf = new Intl.NumberFormat('it-IT');
const timeIt = ts => new Date(ts).toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' });
const ago = ts => {
  const m = Math.round((Date.now() - new Date(ts)) / 60000);
  if (m < 1) return 'ora'; if (m < 60) return `${m} min fa`;
  const h = Math.round(m / 60); return h < 24 ? `${h} h fa` : new Date(ts).toLocaleDateString('it-IT', { day: 'numeric', month: 'short' });
};

const app = {
  mode: localGet('mode') || 'S',
  snap: null,
  source: null,
  lastOk: 0,
  selected: null,
};

function localGet(k) { try { return localStorage.getItem('mt-' + k); } catch { return null; } }
function localSet(k, v) { try { localStorage.setItem('mt-' + k, v); } catch {} }

function toast(msg) {
  const t = $('#toast'); t.textContent = msg; t.classList.add('show');
  clearTimeout(toast.t); toast.t = setTimeout(() => t.classList.remove('show'), 3200);
}

/* ---------------- data ---------------- */
async function getJSON(url) {
  const r = await fetch(url + (url.includes('?') ? '&' : '?') + 't=' + Date.now(), { cache: 'no-store' });
  if (!r.ok) throw new Error(r.status);
  return r.json();
}

async function loadResults() {
  let snap = null, source = null;
  // 1) live, straight from the public AP/NYT files
  try {
    const feeds = await fetchFeeds();
    if (feeds.S || feeds.H || feeds.G) { snap = buildSnapshot(feeds); source = 'live'; }
  } catch {}
  // 2) snapshot written every minute by the updater (GitHub Actions)
  if (!snap) for (const u of [RAW_DATA + 'results.json', './data/results.json']) {
    try { snap = await getJSON(u); source = 'relay'; break; } catch {}
  }
  if (snap) { app.snap = snap; app.source = source; app.lastOk = Date.now(); }
  renderAll();
}

async function loadNews() {
  for (const u of [RAW_DATA + 'news.json', './data/news.json']) {
    try { renderNews(await getJSON(u)); return; } catch {}
  }
  $('#stories').innerHTML = '<p class="muted">Le notizie compariranno qui a breve.</p>';
}

/* ---------------- helpers ---------------- */
function racesOf(st, mode) { return (app.snap && app.snap.states[st] && app.snap.states[st][mode]) || []; }

function stateFill(st) {
  const mode = app.mode;
  const races = racesOf(st, mode);
  if (mode === 'H') {
    if (!races.length) return 'wait';
    const c = { D: 0, R: 0, O: 0 }, l = { D: 0, R: 0, O: 0 };
    for (const r of races) { if (r.winner) c[r.winner]++; else if (r.leader) l[r.leader]++; }
    const half = races.length / 2;
    for (const p of ['D', 'R', 'O']) if (c[p] > half) return p.toLowerCase() + '2';
    const tot = { D: c.D + l.D, R: c.R + l.R, O: c.O + l.O };
    const best = Object.entries(tot).sort((a, b) => b[1] - a[1])[0];
    if (!best[1]) return 'wait';
    if (tot.D === tot.R && best[0] !== 'O') return 'wait';
    return best[0].toLowerCase() + '1';
  }
  const scheduled = (mode === 'S' ? SENATE_2026 : GOV_2026).includes(st);
  if (!races.length) return scheduled ? 'wait' : 'none';
  // the main (non-special) race decides the colour; a called race beats a lead
  const r = races.find(x => !x.special) || races[0];
  if (r.winner) return r.winner.toLowerCase() + '2';
  if (r.leader && r.total > 0) return r.leader.toLowerCase() + '1';
  return 'wait';
}

/* ---------------- render ---------------- */
function renderStatus() {
  const s = $('#status'); const dot = s.querySelector('.dot'); const txt = s.querySelector('span');
  if (!app.snap) {
    dot.className = 'dot'; txt.textContent = 'In attesa dei primi risultati';
    return;
  }
  const counted = app.snap.control.S.counted + app.snap.control.H.counted + app.snap.control.G.counted;
  const upd = app.snap.updated || app.snap.fetchedAt;
  dot.className = 'dot ' + (Date.now() - app.lastOk < 5 * 60e3 ? 'live' : 'err');
  txt.textContent = counted ? `Live · agg. ${timeIt(upd)}${app.source === 'relay' ? ' (relay)' : ''}` : 'Seggi aperti · spoglio non iniziato';
}

function renderControl() {
  const el = $('#control');
  const S = app.snap ? app.snap.control.S : { total: 100, needed: 51, won: { D: 34, R: 31, O: 0 }, lead: { D: 0, R: 0, O: 0 }, races: 35 };
  const H = app.snap ? app.snap.control.H : { total: 435, needed: 218, won: { D: 0, R: 0, O: 0 }, lead: { D: 0, R: 0, O: 0 }, races: 435 };
  const G = app.snap ? app.snap.control.G : { total: 50, needed: 26, won: { D: 6, R: 8, O: 0 }, lead: { D: 0, R: 0, O: 0 }, races: 36 };
  const block = (name, t, note) => {
    const pct = v => (v / t.total * 100).toFixed(2) + '%';
    const decided = t.won.D >= t.needed ? 'D' : t.won.R >= t.needed ? 'R' : null;
    return `<div class="ch">
      <div class="ch-top"><b>${name}</b>${decided ? `<span class="badge ${decided}">Maggioranza ${decided === 'D' ? 'Democratica' : 'Repubblicana'}</span>` : `<span class="muted">${t.needed} per la maggioranza</span>`}</div>
      <div class="nums"><span class="d"><strong>${t.won.D}</strong><small>${t.lead.D ? `+${t.lead.D} in testa` : 'Dem.'}</small></span>
        <span class="r"><small>${t.lead.R ? `+${t.lead.R} in testa` : 'Rep.'}</small><strong>${t.won.R}</strong></span></div>
      <div class="bar" role="img" aria-label="${name}: Democratici ${t.won.D}, Repubblicani ${t.won.R}">
        <i class="bd2" style="width:${pct(t.won.D)}"></i><i class="bd1" style="width:${pct(t.lead.D)}"></i>
        <i class="gap"></i>
        <i class="bo" style="width:${pct(t.won.O + t.lead.O)}"></i>
        <i class="br1" style="width:${pct(t.lead.R)}"></i><i class="br2" style="width:${pct(t.won.R)}"></i>
      </div>
      <div class="ch-foot"><span>${note}</span>${t.won.O ? `<span>Altri: ${t.won.O}</span>` : ''}</div>
    </div>`;
  };
  el.innerHTML = block('Senato', S, `${S.races || 35} seggi in palio oggi · il totale include i seggi non in palio`) +
    block('Camera', H, `435 seggi in palio`) +
    block('Governatori', G, `${G.races || 36} in palio oggi · il totale include gli altri stati`);
}

function buildMap() {
  const svg = $('#map');
  const ns = 'http://www.w3.org/2000/svg';
  for (const [st, { d }] of Object.entries(STATE_PATHS)) {
    const p = document.createElementNS(ns, 'path');
    p.setAttribute('d', d); p.dataset.st = st;
    p.setAttribute('tabindex', '0'); p.setAttribute('role', 'button');
    p.setAttribute('aria-label', STATE_NAMES[st]);
    svg.appendChild(p);
  }
  for (const [st, { c }] of Object.entries(STATE_PATHS)) {
    if (SMALL_NE.has(st) || !c || isNaN(c[0])) continue;
    const t = document.createElementNS(ns, 'text');
    t.setAttribute('x', c[0] + (st === 'FL' ? 12 : st === 'LA' ? -8 : st === 'MI' ? 10 : 0));
    t.setAttribute('y', c[1] + (st === 'MI' ? 18 : 0));
    t.dataset.st = st; t.textContent = st;
    svg.appendChild(t);
  }
  svg.addEventListener('click', e => { const st = e.target.dataset && e.target.dataset.st; if (st) openState(st); });
  svg.addEventListener('keydown', e => { if ((e.key === 'Enter' || e.key === ' ') && e.target.dataset.st) { e.preventDefault(); openState(e.target.dataset.st); } });
}

function renderMap() {
  document.querySelectorAll('#map path').forEach(p => {
    const f = stateFill(p.dataset.st);
    p.setAttribute('class', 'f-' + f + (app.selected === p.dataset.st ? ' sel' : ''));
  });
  document.querySelectorAll('#map text').forEach(t => {
    const f = stateFill(t.dataset.st);
    t.setAttribute('class', /2$/.test(f) ? 'lt' : '');
  });
  document.querySelectorAll('.seg button').forEach(b => b.setAttribute('aria-selected', String(b.dataset.mode === app.mode)));
}

function candRows(r) {
  const max = Math.max(1, ...r.cands.map(c => c.pct));
  return r.cands.map(c => `<div class="cand">
      <div class="nm"><i class="pd p-${c.party}"></i><span>${esc(c.name)}${c.inc ? ' <small class="muted">(uscente)</small>' : ''}</span>${c.won ? '<span class="check" aria-label="eletto">✓</span>' : ''}</div>
      <div class="pc">${r.total ? c.pct.toFixed(1) + '%' : '—'}</div>
      <div class="vb"><i class="p-${c.party}" style="width:${r.total ? c.pct / max * 100 : 0}%"></i></div>
    </div>`).join('');
}

function raceStatus(r) {
  if (r.runoff) return 'Ballottaggio';
  if (r.winner) return `Eletto ${PARTY_IT[r.winner]}`;
  if (r.total > 0) return r.eevp != null ? `${r.eevp}% scrutinato` : 'Spoglio in corso';
  return 'In attesa';
}

function raceTitle(r) {
  const st = STATE_NAMES[r.st] || r.st;
  if (r.office === 'H') return `${st} · Distretto ${r.seat || 'unico'}`;
  return `${st} · ${OFFICE_IT[r.office]}${r.special ? ' (suppletiva)' : ''}`;
}

function renderWatch() {
  const el = $('#watch');
  if (!app.snap) {
    el.innerHTML = '<li class="empty">Le gare più combattute compariranno qui quando inizierà lo spoglio (dalle 00:00 ora italiana).</li>';
    $('#watchSub').textContent = '';
    return;
  }
  const all = [];
  for (const st of Object.values(app.snap.states)) for (const o of ['S', 'G']) for (const r of st[o]) all.push(r);
  const close = r => r.cands.length > 1 ? Math.abs(r.cands[0].pct - r.cands[1].pct) : 100;
  const open = all.filter(r => !r.called && r.total > 0).sort((a, b) => close(a) - close(b));
  const recent = all.filter(r => r.called);
  const list = (open.length ? open : all.filter(r => !r.called)).slice(0, 6);
  $('#watchSub').textContent = open.length ? `${open.length} gare aperte · ${recent.length} assegnate` : '';
  el.innerHTML = list.length ? list.map(r => `<li data-st="${r.st}">
      <div class="race-h"><b>${esc(raceTitle(r))}</b><span class="pill">${raceStatus(r)}</span></div>
      ${candRows({ ...r, cands: r.cands.slice(0, 2) })}
    </li>`).join('') : '<li class="empty">Tutte le gare principali sono state assegnate.</li>';
}

function openState(st) {
  app.selected = st; renderMap();
  $('#sheetTitle').textContent = STATE_NAMES[st] || st;
  const parts = [];
  for (const o of ['S', 'G']) {
    const rs = racesOf(st, o);
    const scheduled = (o === 'S' ? SENATE_2026 : GOV_2026).includes(st);
    if (!rs.length && !scheduled) continue;
    parts.push(`<section><h3>${OFFICE_IT[o]}</h3>${rs.length ? rs.map(r => `
      <div class="races"><li style="list-style:none;cursor:default">
        <div class="race-h"><span>${r.special ? 'Elezione suppletiva' : ''}</span><span class="pill">${raceStatus(r)}</span></div>
        ${candRows(r)}
        <div class="muted" style="margin-top:6px">${r.total ? nf.format(r.total) + ' voti' : ''}</div>
      </li></div>`).join('') : '<p class="empty">In attesa dei dati.</p>'}</section>`);
  }
  const hs = racesOf(st, 'H');
  if (hs.length) {
    const c = { D: 0, R: 0, O: 0 }; hs.forEach(r => r.winner && c[r.winner]++);
    parts.push(`<section><h3>Camera · ${hs.length} ${hs.length === 1 ? 'seggio' : 'seggi'}</h3>
      <p class="muted">Eletti: <b style="color:var(--d2)">D ${c.D}</b> · <b style="color:var(--r2)">R ${c.R}</b>${c.O ? ` · Altri ${c.O}` : ''}</p>
      <ul class="races">${hs.sort((a, b) => (a.seat || 0) - (b.seat || 0)).map(r => `<li style="cursor:default">
        <div class="race-h"><b>Distretto ${r.seat || 'unico'}</b><span class="pill">${raceStatus(r)}</span></div>
        ${candRows({ ...r, cands: r.cands.slice(0, 2) })}</li>`).join('')}</ul></section>`);
  } else if (!app.snap) parts.push('<section><p class="empty">I risultati compariranno qui dopo la chiusura dei seggi.</p></section>');
  if (!parts.length) parts.push('<section><p class="empty">Nessuna gara per Senato o Governatore in questo stato nel 2026.</p></section>');
  $('#sheetBody').innerHTML = parts.join('');
  $('#sheet').hidden = false;
}
function closeSheet() { $('#sheet').hidden = true; app.selected = null; renderMap(); }

function renderNews(n) {
  if (!n || !n.stories) return;
  $('#newsSub').textContent = `${n.articlesScanned} articoli · ${ago(n.generatedAt)}`;
  $('#stories').innerHTML = n.stories.map(s => `<article class="story">
      <h3>${esc(s.title)}</h3>
      ${s.summary ? `<p>${esc(s.summary)}</p>` : ''}
      <div class="meta">${s.sourcesCount} ${s.sourcesCount === 1 ? 'fonte' : 'fonti'} · ${ago(s.ts)}</div>
      <details><summary>Articoli (${s.articles.length})</summary>
        ${s.articles.map(a => `<a href="${esc(a.link)}" target="_blank" rel="noopener">${esc(a.title)} <span>· ${esc(a.source)}</span></a>`).join('')}
      </details>
    </article>`).join('') || '<p class="muted">Nessuna notizia al momento.</p>';
  $('#reads').innerHTML = (n.reads || []).map(a => `<li><a href="${esc(a.link)}" target="_blank" rel="noopener"><span>${esc(a.title)}</span><span>${esc(a.source)} · ${ago(a.ts)}</span></a></li>`).join('');
}

function renderAll() { renderStatus(); renderControl(); renderMap(); renderWatch(); if (app.selected && !$('#sheet').hidden) openState(app.selected); }

/* ---------------- push notifications ---------------- */
const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
const isStandalone = matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;

function b64ToBytes(b64) {
  const s = atob((b64 + '='.repeat((4 - b64.length % 4) % 4)).replace(/-/g, '+').replace(/_/g, '/'));
  return Uint8Array.from(s, c => c.charCodeAt(0));
}

async function pushConfig() {
  for (const u of [RAW_DATA + 'push.json', './data/push.json']) { try { return await getJSON(u); } catch {} }
  return null;
}

async function sendSubscription(sub, key) {
  await fetch(`https://ntfy.sh/${NTFY_INBOX}`, { method: 'POST', body: JSON.stringify({ sub: sub.toJSON(), k: key, v: 1 }) });
  localSet('pushKey', key);
}

async function enableNotifications() {
  if (isIOS && !isStandalone) {
    toast('Su iPhone: tocca Condividi ↑ → «Aggiungi alla schermata Home», poi apri l’app da lì e attiva le notifiche.');
    return;
  }
  if (!('serviceWorker' in navigator) || !('PushManager' in window)) { toast('Questo browser non supporta le notifiche push.'); return; }
  const perm = await Notification.requestPermission();
  if (perm !== 'granted') { toast('Notifiche non consentite. Puoi attivarle da Impostazioni → Notifiche.'); return; }
  const cfg = await pushConfig();
  if (!cfg || !cfg.publicKey) { toast('Servizio notifiche in avvio: riprova tra qualche minuto.'); return; }
  try {
    const reg = await navigator.serviceWorker.ready;
    let sub = await reg.pushManager.getSubscription();
    if (sub && localGet('pushKey') !== cfg.publicKey) { await sub.unsubscribe(); sub = null; }
    if (!sub) sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: b64ToBytes(cfg.publicKey) });
    await sendSubscription(sub, cfg.publicKey);
    localSet('push', '1');
    $('#notifyBtn').classList.add('on');
    toast('Fatto! Entro un paio di minuti riceverai una notifica di conferma.');
  } catch (e) { toast('Errore attivazione notifiche: ' + e.message); }
}

async function refreshSubscription() {
  if (!('serviceWorker' in navigator) || !('PushManager' in window) || localGet('push') !== '1') return;
  if (typeof Notification === 'undefined' || Notification.permission !== 'granted') return;
  $('#notifyBtn').classList.add('on');
  try {
    const cfg = await pushConfig(); if (!cfg || !cfg.publicKey) return;
    const reg = await navigator.serviceWorker.ready;
    let sub = await reg.pushManager.getSubscription();
    if (sub && localGet('pushKey') !== cfg.publicKey) { await sub.unsubscribe(); sub = null; }
    if (!sub) sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: b64ToBytes(cfg.publicKey) });
    // re-announce at most every 6 hours (the inbox keeps messages for 12h)
    if (Date.now() - Number(localGet('pushSent') || 0) > 6 * 3600e3 || localGet('pushKey') !== cfg.publicKey) {
      await sendSubscription(sub, cfg.publicKey); localSet('pushSent', String(Date.now()));
    }
  } catch {}
}

/* ---------------- boot ---------------- */
buildMap();
renderAll();
document.querySelectorAll('.seg button').forEach(b => b.addEventListener('click', () => { app.mode = b.dataset.mode; localSet('mode', app.mode); renderMap(); }));
$('#sheet').addEventListener('click', e => { if (e.target.closest('[data-close]')) closeSheet(); });
document.addEventListener('keydown', e => { if (e.key === 'Escape' && !$('#sheet').hidden) closeSheet(); });
$('#watch').addEventListener('click', e => { const li = e.target.closest('li[data-st]'); if (li) openState(li.dataset.st); });
$('#notifyBtn').addEventListener('click', enableNotifications);

if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(() => {});
loadResults(); loadNews(); refreshSubscription();
setInterval(() => { if (!document.hidden) loadResults(); }, 45e3);
setInterval(() => { if (!document.hidden) loadNews(); }, 5 * 60e3);
setInterval(renderStatus, 30e3);
document.addEventListener('visibilitychange', () => { if (!document.hidden) { loadResults(); loadNews(); } });
if (location.hash === '#news') setTimeout(() => $('#news').scrollIntoView({ behavior: 'smooth' }), 400);
