import { STATE_PATHS } from './states.js';
import { fetchFeeds, buildSnapshot, STATE_NAMES } from './nyt.js';
import { RAW_DATA, NTFY_INBOX } from './config.js';

const SENATE_2026 = 'AL AK AR CO DE FL GA ID IL IA KS KY LA ME MA MI MN MS MT NE NH NJ NM NC OH OK OR RI SC SD TN TX VA WV WY'.split(' ');
const GOV_2026 = 'AL AK AZ AR CA CO CT FL GA HI ID IL IA KS ME MD MA MI MN NE NV NH NM NY OH OK OR PA RI SC SD TN TX VT WI WY'.split(' ');
const SMALL = new Set(['VT', 'NH', 'MA', 'RI', 'CT', 'NJ', 'DE', 'MD', 'DC']);
const MODE = { S: 'Senato', H: 'Camera', G: 'Governatori' };
const OFFICE = { S: 'Senato', H: 'Camera', G: 'Governatore' };
const PARTY = { D: 'Dem', R: 'Rep', O: 'Ind' };
const FALLBACK = {
  S: { total: 100, needed: 51, won: { D: 34, R: 31, O: 0 }, lead: { D: 0, R: 0, O: 0 }, races: 35 },
  H: { total: 435, needed: 218, won: { D: 0, R: 0, O: 0 }, lead: { D: 0, R: 0, O: 0 }, races: 435 },
  G: { total: 50, needed: 26, won: { D: 6, R: 8, O: 0 }, lead: { D: 0, R: 0, O: 0 }, races: 36 },
};
const SRC_COLORS = ['#e5383b', '#2563eb', '#0f9d58', '#f59e0b', '#8b5cf6', '#0ea5e9', '#ec4899', '#64748b'];

const $ = s => document.querySelector(s);
const esc = v => String(v ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const cssUrl = u => `url("${String(u).replace(/["\\\n]/g, '')}")`;
const nf = new Intl.NumberFormat('it-IT');
const hhmm = ts => new Date(ts).toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' });
const ago = ts => {
  const m = Math.round((Date.now() - new Date(ts)) / 60000);
  if (m < 1) return 'Adesso'; if (m < 60) return `${m} min fa`;
  const h = Math.round(m / 60); return h < 24 ? `${h} h fa` : new Date(ts).toLocaleDateString('it-IT', { day: 'numeric', month: 'short' });
};
const store = {
  get: k => { try { return localStorage.getItem('mt-' + k); } catch { return null; } },
  set: (k, v) => { try { localStorage.setItem('mt-' + k, v); } catch {} },
};

const app = { tab: store.get('tab') || 'results', mode: store.get('mode') || 'S', snap: null, source: null, lastOk: 0, news: null, selected: null };

const ICON = {
  bell: '<svg viewBox="0 0 24 24"><path d="M12 22a2.4 2.4 0 0 0 2.36-2H9.64A2.4 2.4 0 0 0 12 22Zm7.2-5.6V11a7.2 7.2 0 0 0-5.7-7.05V3.2a1.5 1.5 0 0 0-3 0v.75A7.2 7.2 0 0 0 4.8 11v5.4L3 18.2V19h18v-.8l-1.8-1.8Z"/></svg>',
  chart: '<svg viewBox="0 0 24 24"><path d="M4 20h16v1.5H4zM5 11h3v8H5zm5.5-6h3v14h-3zM16 8h3v11h-3z"/></svg>',
  news: '<svg viewBox="0 0 24 24"><path d="M4 4h13a1 1 0 0 1 1 1v3h2a1 1 0 0 1 1 1v9.5a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 3 18.5V5a1 1 0 0 1 1-1Zm14 6v8.5a1 1 0 0 0 2 0V10h-2ZM6 7v4h5V7H6Zm7 0v1.5h3V7h-3Zm0 2.5V11h3V9.5h-3ZM6 13v1.5h10V13H6Zm0 3v1.5h10V16H6Z"/></svg>',
  back: '<svg viewBox="0 0 24 24"><path d="M15 5l-7 7 7 7"/></svg>',
  spark: '<svg viewBox="0 0 24 24" width="13" height="13" fill="currentColor"><path d="M12 2l1.9 6.1L20 10l-6.1 1.9L12 18l-1.9-6.1L4 10l6.1-1.9z"/></svg>',
};

/* ================= layout ================= */
document.body.insertAdjacentHTML('beforeend', `
  <section class="view" id="v-results">
    <header class="lt-head">
      <div><p class="eyebrow">Midterm 2026</p><h1 class="large-title">Risultati</h1></div>
      <div class="head-actions">
        <span class="live" id="live"><i></i><span>—</span></span>
        <button class="round" id="bell" aria-label="Notifiche">${ICON.bell}</button>
      </div>
    </header>
    <div class="seg" role="tablist" aria-label="Elezione">
      <span class="thumb"></span>
      <button role="tab" data-mode="S">Senato</button><button role="tab" data-mode="H">Camera</button><button role="tab" data-mode="G">Governatori</button>
    </div>
    <div class="panel" id="balance"></div>
    <div class="panel map-panel">
      <svg id="map" viewBox="0 0 975 610" role="img" aria-label="Mappa degli Stati Uniti"></svg>
      <ul class="legend" aria-hidden="true"><li><i class="lg-d"></i>Democratici</li><li><i class="lg-r"></i>Repubblicani</li><li><i class="lg-w"></i>In attesa</li></ul>
    </div>
    <div class="sec-h"><h2>Da seguire</h2><span id="watch-sub"></span></div>
    <div class="list" id="watch"></div>
  </section>

  <section class="view" id="v-news" hidden>
    <header class="lt-head">
      <div><p class="eyebrow" id="news-date"></p><h1 class="large-title">Notizie</h1></div>
      <div class="head-actions"><span class="live" id="news-upd"><i></i><span>—</span></span></div>
    </header>
    <div id="news-body"><div class="list"><p class="empty">Caricamento…</p></div></div>
  </section>

  <div class="sheet" id="sheet" hidden><div class="scrim" data-close></div>
    <div class="sheet-card" role="dialog" aria-modal="true" aria-labelledby="sheet-title">
      <div class="grab"></div>
      <div class="sheet-top"><h2 id="sheet-title"></h2><button class="close" data-close aria-label="Chiudi">✕</button></div>
      <div id="sheet-body"></div>
    </div>
  </div>

  <div class="page" id="story" hidden>
    <div class="page-bar"><button class="back" id="back">${ICON.back}Notizie</button></div>
    <div class="page-in" id="story-body"></div>
  </div>

  <nav class="tabbar" role="tablist">
    <button role="tab" data-tab="results">${ICON.chart}Risultati</button>
    <button role="tab" data-tab="news">${ICON.news}Notizie</button>
  </nav>
  <div class="toast" id="toast" role="status" aria-live="polite"></div>
`);

function toast(msg) {
  const t = $('#toast'); t.textContent = msg; t.classList.add('show');
  clearTimeout(toast.t); toast.t = setTimeout(() => t.classList.remove('show'), 3600);
}

/* ================= data ================= */
async function getJSON(url) {
  const r = await fetch(url + (url.includes('?') ? '&' : '?') + 't=' + Date.now(), { cache: 'no-store' });
  if (!r.ok) throw new Error(r.status);
  return r.json();
}
async function loadResults() {
  let snap = null, source = null;
  try { const f = await fetchFeeds(); if (f.S || f.H || f.G) { snap = buildSnapshot(f); source = 'live'; } } catch {}
  if (!snap) for (const u of [RAW_DATA + 'results.json', 'data/results.json']) { try { snap = await getJSON(u); source = 'relay'; break; } catch {} }
  if (snap) { app.snap = snap; app.source = source; app.lastOk = Date.now(); }
  renderResults();
}
async function loadNews() {
  for (const u of [RAW_DATA + 'news.json', 'data/news.json']) { try { app.news = await getJSON(u); break; } catch {} }
  renderNews();
}

/* ================= results ================= */
const races = (st, m) => (app.snap && app.snap.states[st] && app.snap.states[st][m]) || [];
const ctl = m => (app.snap ? app.snap.control[m] : FALLBACK[m]);

function fillOf(st) {
  const m = app.mode, rs = races(st, m);
  if (m === 'H') {
    if (!rs.length) return 'wait';
    const c = { D: 0, R: 0, O: 0 }, l = { D: 0, R: 0, O: 0 };
    rs.forEach(r => { if (r.winner) c[r.winner]++; else if (r.leader && r.total) l[r.leader]++; });
    for (const p of 'DRO') if (c[p] > rs.length / 2) return p.toLowerCase() + '2';
    const t = { D: c.D + l.D, R: c.R + l.R, O: c.O + l.O };
    const best = Object.entries(t).sort((a, b) => b[1] - a[1])[0];
    return !best[1] || t.D === t.R ? 'wait' : best[0].toLowerCase() + '1';
  }
  const sched = (m === 'S' ? SENATE_2026 : GOV_2026).includes(st);
  if (!rs.length) return sched ? 'wait' : 'none';
  const r = rs.find(x => !x.special) || rs[0];
  if (r.winner) return r.winner.toLowerCase() + '2';
  if (r.leader && r.total > 0) return r.leader.toLowerCase() + '1';
  return 'wait';
}

function renderLive() {
  const el = $('#live'), txt = el.querySelector('span');
  const counted = app.snap ? app.snap.control.S.counted + app.snap.control.H.counted + app.snap.control.G.counted : 0;
  el.className = 'live' + (app.snap && counted ? (Date.now() - app.lastOk < 5 * 60e3 ? ' on' : ' stale') : '');
  txt.textContent = !app.snap ? 'In attesa' : counted ? `Live · ${hhmm(app.snap.updated || app.snap.fetchedAt)}` : 'Seggi aperti';
}

function renderSeg() {
  const i = ['S', 'H', 'G'].indexOf(app.mode);
  $('.seg .thumb').style.transform = `translateX(${i * 100}%)`;
  document.querySelectorAll('.seg button').forEach(b => b.setAttribute('aria-selected', String(b.dataset.mode === app.mode)));
}

function renderBalance() {
  const t = ctl(app.mode);
  const pct = v => (v / t.total * 100).toFixed(2) + '%';
  const decided = t.won.D >= t.needed ? 'D' : t.won.R >= t.needed ? 'R' : null;
  const inPlay = app.mode === 'H' ? 435 : (t.races || FALLBACK[app.mode].races);
  const holdNote = app.mode === 'H' ? '435 seggi in palio' : `${inPlay} in palio · ${t.total - inPlay} non al voto`;
  $('#balance').innerHTML = `
    <div class="balance-top">
      <div class="side d"><span class="n tnum">${t.won.D}</span><span class="l">Democratici${t.lead.D ? ` · <b>+${t.lead.D}</b> in testa` : ''}</span></div>
      <div class="mid">${decided ? `<span class="won ${decided}">Maggioranza ${decided === 'D' ? 'Dem' : 'Rep'}</span>` : `<span class="need">${t.needed} per vincere</span>`}</div>
      <div class="side r"><span class="n tnum">${t.won.R}</span><span class="l">${t.lead.R ? `<b>+${t.lead.R}</b> in testa · ` : ''}Repubblicani</span></div>
    </div>
    <div class="track-wrap"><div class="track" role="img" aria-label="${MODE[app.mode]}: Democratici ${t.won.D}, Repubblicani ${t.won.R}, maggioranza ${t.needed}">
      <i class="dw" style="width:${pct(t.won.D)}"></i><i class="dl" style="width:${pct(t.lead.D)}"></i><i class="sp"></i>
      <i class="ow" style="width:${pct(t.won.O + t.lead.O)}"></i><i class="rl" style="width:${pct(t.lead.R)}"></i><i class="rw" style="width:${pct(t.won.R)}"></i>
    </div></div>
    <div class="foot-note"><span>${holdNote}</span><span>${t.won.O ? `Altri ${t.won.O}` : MODE[app.mode]}</span></div>`;
}

function buildMap() {
  const svg = $('#map'), ns = 'http://www.w3.org/2000/svg';
  for (const [st, { d }] of Object.entries(STATE_PATHS)) {
    const p = document.createElementNS(ns, 'path');
    p.setAttribute('d', d); p.dataset.st = st; p.setAttribute('tabindex', '0'); p.setAttribute('role', 'button'); p.setAttribute('aria-label', STATE_NAMES[st]);
    svg.appendChild(p);
  }
  for (const [st, { c }] of Object.entries(STATE_PATHS)) {
    if (SMALL.has(st) || !c || isNaN(c[0])) continue;
    const t = document.createElementNS(ns, 'text');
    t.setAttribute('x', c[0] + (st === 'FL' ? 12 : st === 'LA' ? -8 : st === 'MI' ? 10 : 0));
    t.setAttribute('y', c[1] + (st === 'MI' ? 18 : 0));
    t.dataset.st = st; t.textContent = st; svg.appendChild(t);
  }
  svg.addEventListener('click', e => e.target.dataset && e.target.dataset.st && openState(e.target.dataset.st));
  svg.addEventListener('keydown', e => { if ((e.key === 'Enter' || e.key === ' ') && e.target.dataset.st) { e.preventDefault(); openState(e.target.dataset.st); } });
}
function renderMap() {
  document.querySelectorAll('#map path').forEach(p => p.setAttribute('class', 'f-' + fillOf(p.dataset.st) + (app.selected === p.dataset.st ? ' sel' : '')));
  document.querySelectorAll('#map text').forEach(t => t.setAttribute('class', /2$/.test(fillOf(t.dataset.st)) ? 'inv' : ''));
}

function statusTag(r) {
  if (r.runoff) return '<span class="tag">Ballottaggio</span>';
  if (r.winner) return `<span class="tag ${r.winner}">Eletto ${PARTY[r.winner]}</span>`;
  if (r.total > 0) return `<small>${r.eevp != null ? r.eevp + '% scrutinato' : 'Spoglio in corso'}</small>`;
  return '<small>In attesa</small>';
}
function raceName(r) {
  const st = STATE_NAMES[r.st] || r.st;
  if (r.office === 'H') return `${st} ${r.seat ? r.seat + '°' : 'unico'}`;
  return `${st}${r.special ? ' · suppletiva' : ''}`;
}
function duel(r) {
  const [a, b] = r.cands;
  if (!a) return '';
  const d = r.cands.find(c => c.party === 'D') || a, rp = r.cands.find(c => c.party === 'R' && c !== d) || b || a;
  const pc = c => (r.total ? c.pct.toFixed(1) + '%' : '—');
  const sum = (d.pct + rp.pct) || 1;
  return `<div class="duel">
      <div class="c"><span class="nm">${esc(d.name)}</span><span class="pc tnum p-${d.party}">${pc(d)}</span></div>
      <span class="vs">vs</span>
      <div class="c r"><span class="nm">${esc(rp.name)}</span><span class="pc tnum p-${rp.party}">${pc(rp)}</span></div>
    </div>
    ${r.total ? '' : '<!--'}<div class="mini"><i class="b-${d.party}" style="width:${r.total ? d.pct / sum * 100 : 0}%"></i><span style="flex:1"></span><i class="b-${rp.party}" style="width:${r.total ? rp.pct / sum * 100 : 0}%"></i></div>${r.total ? '' : '-->'}`;
}

function renderWatch() {
  const el = $('#watch');
  const m = app.mode === 'H' ? 'H' : app.mode;
  if (!app.snap) { el.innerHTML = '<p class="empty">Le gare più combattute compariranno qui all’inizio dello spoglio, dalla mezzanotte italiana.</p>'; $('#watch-sub').textContent = ''; return; }
  const all = [];
  for (const st of Object.values(app.snap.states)) for (const r of st[m]) all.push(r);
  const gap = r => (r.cands.length > 1 ? Math.abs(r.cands[0].pct - r.cands[1].pct) : 100);
  const open = all.filter(r => !r.called && r.total > 0).sort((a, b) => gap(a) - gap(b));
  const called = all.filter(r => r.called).length;
  const list = (open.length ? open : all.filter(r => !r.called && !r.uncontested)).slice(0, m === 'H' ? 8 : 6);
  $('#watch-sub').textContent = open.length ? `${open.length} aperte · ${called} assegnate` : called ? `${called} assegnate` : '';
  el.innerHTML = list.length ? list.map(r => `<button class="row" data-st="${r.st}">
      <div class="row-h"><b>${esc(raceName(r))}</b>${statusTag(r)}</div>${duel(r)}</button>`).join('')
    : '<p class="empty">Tutte le gare sono state assegnate.</p>';
}

function candList(r) {
  const max = Math.max(1, ...r.cands.map(c => c.pct));
  return r.cands.map(c => `<div class="cand">
      <div class="nm"><i class="dot b-${c.party}"></i><span>${esc(c.name)}</span>${c.won ? '<i class="check">✓</i>' : ''}</div>
      <div class="pc tnum">${r.total ? c.pct.toFixed(1) + '%' : '—'}</div>
      <div class="bar"><i class="b-${c.party}" style="width:${r.total ? c.pct / max * 100 : 0}%"></i></div>
      <div class="sub">${PARTY[c.party]}${c.inc ? ' · uscente' : ''}${r.total ? ' · ' + nf.format(c.votes) + ' voti' : ''}</div>
    </div>`).join('');
}

function openState(st) {
  app.selected = st; renderMap();
  $('#sheet-title').textContent = STATE_NAMES[st] || st;
  const out = [];
  for (const o of ['S', 'G']) {
    const rs = races(st, o), sched = (o === 'S' ? SENATE_2026 : GOV_2026).includes(st);
    if (!rs.length && !sched) continue;
    out.push(`<p class="grp-h">${OFFICE[o]}</p>` + (rs.length ? rs.map(r => `<div class="card-in" style="margin-bottom:10px">
        <div class="meta"><span>${r.special ? 'Elezione suppletiva' : r.eevp != null && r.total ? r.eevp + '% scrutinato' : 'In attesa'}</span>${statusTag(r)}</div>${candList(r)}</div>`).join('')
      : '<div class="card-in"><p class="empty" style="padding:12px 0">In attesa dei dati.</p></div>'));
  }
  const hs = races(st, 'H').slice().sort((a, b) => (a.seat || 0) - (b.seat || 0));
  if (hs.length) {
    const c = { D: 0, R: 0, O: 0 }; hs.forEach(r => r.winner && c[r.winner]++);
    out.push(`<p class="grp-h">Camera · ${hs.length} ${hs.length === 1 ? 'seggio' : 'seggi'}</p>
      <div class="card-in"><div class="meta"><span><b class="p-D">D ${c.D}</b> · <b class="p-R">R ${c.R}</b>${c.O ? ` · Altri ${c.O}` : ''}</span><span>eletti</span></div>
      <div class="seats">${hs.map(r => `<i class="${r.winner ? r.winner + '2' : r.leader && r.total ? r.leader + '1' : ''}" title="Distretto ${r.seat || 1}"></i>`).join('')}</div></div>
      <div class="list" style="margin-top:10px">${hs.filter(r => !r.uncontested).slice(0, 60).map(r => `<div class="row"><div class="row-h"><b>Distretto ${r.seat || 'unico'}</b>${statusTag(r)}</div>${duel(r)}</div>`).join('')}</div>`);
  }
  if (!out.length) out.push('<div class="card-in"><p class="empty" style="padding:12px 0">Nessuna gara per Senato o Governatore nel 2026.</p></div>');
  $('#sheet-body').innerHTML = out.join('');
  $('#sheet').hidden = false;
  $('.sheet-card').scrollTop = 0;
}
function closeSheet() { $('#sheet').hidden = true; app.selected = null; renderMap(); }

function renderResults() {
  renderLive(); renderSeg(); renderBalance(); renderMap(); renderWatch();
  if (app.selected && !$('#sheet').hidden) { const y = $('.sheet-card').scrollTop; openState(app.selected); $('.sheet-card').scrollTop = y; }
}

/* ================= news ================= */
function srcStack(articles) {
  const names = [...new Set(articles.map(a => a.source))].slice(0, 4);
  return `<span class="stack">${names.map((n, i) => `<i style="background:${SRC_COLORS[(n.charCodeAt(0) + n.length) % SRC_COLORS.length]}" title="${esc(n)}">${esc(n[0])}</i>`).join('')}</span>`;
}
function renderNews() {
  $('#news-date').textContent = new Date().toLocaleDateString('it-IT', { weekday: 'long', day: 'numeric', month: 'long' });
  const n = app.news, body = $('#news-body'), upd = $('#news-upd');
  if (!n || !n.stories || !n.stories.length) { body.innerHTML = '<div class="list"><p class="empty">Le notizie compariranno qui a breve.</p></div>'; return; }
  upd.className = 'live on'; upd.querySelector('span').textContent = ago(n.generatedAt);
  const [hero, ...rest] = n.stories;
  const item = (s, i) => `<button class="item${s.img ? '' : ' noimg'}" data-story="${i}">
      <div><span class="src">${esc(s.source || (s.articles[0] && s.articles[0].source) || '')}</span><h4>${esc(s.title)}</h4>
      <div class="meta-line">${srcStack(s.articles)}<span>${s.sourcesCount} ${s.sourcesCount === 1 ? 'fonte' : 'fonti'} · ${ago(s.ts)}</span></div></div>
      ${s.img ? `<div class="thumb" style="background-image:${cssUrl(s.img)}"></div>` : ''}</button>`;
  body.innerHTML = `
    <button class="hero" data-story="0" style="width:100%;text-align:left">
      ${hero.img ? `<div class="img" style="background-image:${cssUrl(hero.img)}"></div>` : ''}
      <div class="body"><span class="src">In primo piano</span><h3>${esc(hero.title)}</h3>${hero.summary ? `<p>${esc(hero.summary)}</p>` : ''}
        <div class="meta-line">${srcStack(hero.articles)}<span>${hero.sourcesCount} fonti · ${ago(hero.ts)}</span></div></div>
    </button>
    <div class="sec-h"><h2>Le ultime</h2><span>${n.articlesScanned} articoli analizzati</span></div>
    <div class="feed">${rest.slice(0, 7).map((s, i) => item(s, i + 1)).join('')}</div>
    ${n.reads && n.reads.length ? `<div class="sec-h"><h2>Da leggere</h2><span>Scelti per te</span></div>
    <div class="carousel">${n.reads.map(a => `<a class="tile" href="${esc(a.link)}" target="_blank" rel="noopener">
        ${a.img ? `<div class="img" style="background-image:${cssUrl(a.img)}"></div>` : `<div class="img ph">${esc(a.source)}</div>`}
        <div class="body"><span class="src">${esc(a.source)}</span><h4>${esc(a.title)}</h4><div class="meta-line"><span>${ago(a.ts)}</span></div></div></a>`).join('')}</div>` : ''}
    ${rest.length > 7 ? `<div class="sec-h"><h2>Altre storie</h2><span></span></div><div class="feed">${rest.slice(7).map((s, i) => item(s, i + 8)).join('')}</div>` : ''}`;
}
function openStory(i) {
  const s = app.news && app.news.stories[i]; if (!s) return;
  $('#story-body').innerHTML = `
    ${s.img ? `<div class="cover" style="background-image:${cssUrl(s.img)}"></div>` : ''}
    <span class="src">${esc(s.source || '')}</span>
    <h1>${esc(s.title)}</h1>
    <div class="meta-line">${srcStack(s.articles)}<span>${s.sourcesCount} ${s.sourcesCount === 1 ? 'fonte' : 'fonti'} · aggiornato ${ago(s.ts)}</span></div>
    ${s.summary ? `<div class="summary-box"><h5>${ICON.spark} Riassunto da ${s.sourcesCount} ${s.sourcesCount === 1 ? 'fonte' : 'fonti'}</h5><p>${esc(s.summary)}</p></div>` : ''}
    <div class="sec-h"><h2>Copertura completa</h2><span>${s.articles.length}</span></div>
    <div class="list cov">${s.articles.map(a => `<a href="${esc(a.link)}" target="_blank" rel="noopener">
      <span class="src" style="grid-column:1">${esc(a.source)}</span><span class="chev">›</span>
      <span class="t">${esc(a.title)}</span></a>`).join('')}</div>`;
  $('#story').hidden = false; $('#story').scrollTop = 0;
  history.pushState({ story: i }, '');
}
function closeStory() { $('#story').hidden = true; }

/* ================= tabs ================= */
function setTab(t) {
  app.tab = t; store.set('tab', t);
  $('#v-results').hidden = t !== 'results'; $('#v-news').hidden = t !== 'news';
  document.querySelectorAll('.tabbar button').forEach(b => b.setAttribute('aria-selected', String(b.dataset.tab === t)));
  window.scrollTo(0, 0);
}

/* ================= push ================= */
const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
const standalone = matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
const b64 = s => Uint8Array.from(atob((s + '='.repeat((4 - s.length % 4) % 4)).replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0));
async function pushCfg() { for (const u of [RAW_DATA + 'push.json', 'data/push.json']) { try { return await getJSON(u); } catch {} } return null; }
async function announce(sub, key) {
  await fetch(`https://ntfy.sh/${NTFY_INBOX}`, { method: 'POST', body: JSON.stringify({ sub: sub.toJSON(), k: key, v: 1 }) });
  store.set('pushKey', key); store.set('pushSent', String(Date.now()));
}
async function subscribe(cfg) {
  const reg = await navigator.serviceWorker.ready;
  let sub = await reg.pushManager.getSubscription();
  if (sub && store.get('pushKey') !== cfg.publicKey) { await sub.unsubscribe(); sub = null; }
  return sub || reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: b64(cfg.publicKey) });
}
async function enablePush() {
  if (isIOS && !standalone) return toast('Aggiungi prima l’app alla schermata Home (Condividi → Aggiungi alla schermata Home) e aprila da lì.');
  if (!('serviceWorker' in navigator) || !('PushManager' in window)) return toast('Notifiche non supportate su questo browser.');
  if ((await Notification.requestPermission()) !== 'granted') return toast('Notifiche non consentite: attivale da Impostazioni → Notifiche.');
  const cfg = await pushCfg(); if (!cfg || !cfg.publicKey) return toast('Servizio notifiche in avvio, riprova tra poco.');
  try { await announce(await subscribe(cfg), cfg.publicKey); store.set('push', '1'); $('#bell').classList.add('on'); toast('Notifiche attive. A breve arriva una conferma.'); }
  catch (e) { toast('Errore: ' + e.message); }
}
async function refreshPush() {
  if (store.get('push') !== '1' || typeof Notification === 'undefined' || Notification.permission !== 'granted' || !('PushManager' in window)) return;
  $('#bell').classList.add('on');
  try {
    const cfg = await pushCfg(); if (!cfg || !cfg.publicKey) return;
    const sub = await subscribe(cfg);
    if (Date.now() - Number(store.get('pushSent') || 0) > 6 * 3600e3 || store.get('pushKey') !== cfg.publicKey) await announce(sub, cfg.publicKey);
  } catch {}
}

/* ================= boot ================= */
buildMap();
setTab(app.tab);
renderResults(); renderNews();
document.querySelectorAll('.seg button').forEach(b => b.addEventListener('click', () => { app.mode = b.dataset.mode; store.set('mode', app.mode); renderSeg(); renderBalance(); renderMap(); renderWatch(); }));
document.querySelectorAll('.tabbar button').forEach(b => b.addEventListener('click', () => setTab(b.dataset.tab)));
$('#sheet').addEventListener('click', e => { if (e.target.closest('[data-close]')) closeSheet(); });
$('#watch').addEventListener('click', e => { const r = e.target.closest('[data-st]'); if (r) openState(r.dataset.st); });
$('#news-body').addEventListener('click', e => { const s = e.target.closest('[data-story]'); if (s) openStory(Number(s.dataset.story)); });
$('#back').addEventListener('click', () => history.back());
addEventListener('popstate', closeStory);
document.addEventListener('keydown', e => { if (e.key === 'Escape') { if (!$('#story').hidden) history.back(); else if (!$('#sheet').hidden) closeSheet(); } });
$('#bell').addEventListener('click', enablePush);
if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(() => {});

loadResults(); loadNews(); refreshPush();
setInterval(() => !document.hidden && loadResults(), 45e3);
setInterval(() => !document.hidden && loadNews(), 4 * 60e3);
setInterval(() => { renderLive(); if (app.news) $('#news-upd span').textContent = ago(app.news.generatedAt); }, 30e3);
document.addEventListener('visibilitychange', () => { if (!document.hidden) { loadResults(); loadNews(); } });
if (location.hash === '#news') setTab('news');
