// Shared parser for the public AP-sourced results files that The New York Times
// publishes at static01.nyt.com/elections-assets/pages/data/<date>/results-<office>.json.
// Used both in the browser (live polling) and in the GitHub Actions updater (Node).

export const ELECTION_DATE = '2026-11-03';
export const NYT_BASE = `https://static01.nyt.com/elections-assets/pages/data/${ELECTION_DATE}/`;
export const OFFICES = { S: 'senate', H: 'house', G: 'governor' };

export const STATE_NAMES = {AL:'Alabama',AK:'Alaska',AZ:'Arizona',AR:'Arkansas',CA:'California',CO:'Colorado',CT:'Connecticut',DE:'Delaware',DC:'District of Columbia',FL:'Florida',GA:'Georgia',HI:'Hawaii',ID:'Idaho',IL:'Illinois',IN:'Indiana',IA:'Iowa',KS:'Kansas',KY:'Kentucky',LA:'Louisiana',ME:'Maine',MD:'Maryland',MA:'Massachusetts',MI:'Michigan',MN:'Minnesota',MS:'Mississippi',MO:'Missouri',MT:'Montana',NE:'Nebraska',NV:'Nevada',NH:'New Hampshire',NJ:'New Jersey',NM:'New Mexico',NY:'New York',NC:'North Carolina',ND:'North Dakota',OH:'Ohio',OK:'Oklahoma',OR:'Oregon',PA:'Pennsylvania',RI:'Rhode Island',SC:'South Carolina',SD:'South Dakota',TN:'Tennessee',TX:'Texas',UT:'Utah',VT:'Vermont',VA:'Virginia',WA:'Washington',WV:'West Virginia',WI:'Wisconsin',WY:'Wyoming'};

// Seats not up in 2026, used only if the feed does not carry party balance.
const SENATE_HOLDOVER_FALLBACK = { D: 34, R: 31, O: 0 };
const GOV_HOLDOVER_FALLBACK = { D: 6, R: 8, O: 0 };

export function partyCode(meta) {
  const p = (meta && ((meta.party_caucus && meta.party_caucus.nyt_id) || (meta.party && (meta.party.nyt_id || meta.party.abbreviation)))) || '';
  if (/^(DEM|D)$/i.test(p)) return 'D';
  if (/^(GOP|REP|R)$/i.test(p)) return 'R';
  return 'O';
}

function stateUnit(race) {
  const ru = race.reporting_units || [];
  return ru.find(u => u.level === 'state' || u.level === 'district') || ru[0] || race.top_reporting_unit || null;
}

export function normalizeRace(race, office) {
  const unit = stateUnit(race) || {};
  const meta = race.candidate_metadata || {};
  const won = (race.outcome && race.outcome.won) || [];
  const runoff = (race.outcome && race.outcome.advanced_to_runoff) || [];
  const cands = (unit.candidates || []).filter(c => !/write-?in/i.test(String(c.nyt_id)) && !/write-?in/i.test(JSON.stringify(meta[c.nyt_id] || {}))).map(c => {
    const m = meta[c.nyt_id] || {};
    return {
      name: [m.first_name, m.last_name].filter(Boolean).join(' ') || m.full_name || String(c.nyt_id || '?'),
      party: partyCode(m),
      inc: !!m.incumbent,
      votes: Number(c.votes && c.votes.total) || 0,
      won: won.includes(c.nyt_id),
    };
  }).sort((a, b) => b.votes - a.votes);
  const total = Number(unit.total_votes) || cands.reduce((s, c) => s + c.votes, 0);
  cands.forEach(c => { c.pct = total ? Math.round(c.votes / total * 1000) / 10 : 0; });
  const winner = cands.find(c => c.won) || null;
  const leader = cands[0] && cands[0].votes > 0 ? cands[0] : null;
  const st = unit.state_postal || String(race.nyt_id || '').slice(0, 2).toUpperCase();
  const seat = race.seat_number && /^\d+$/.test(String(race.seat_number)) ? Number(race.seat_number) : null;
  return {
    id: race.nyt_id || `${st}-${office}-${seat || ''}`,
    office, st, seat,
    special: !!(race.race_type_id && race.race_type_id !== 'G') || /special|unexpired/i.test(JSON.stringify(race.seat_description || race.race_type || '')),
    uncontested: !!race.uncontested,
    eevp: unit.eevp != null ? Math.round(Number(unit.eevp)) : null,
    total,
    called: !!winner || runoff.length > 0,
    runoff: runoff.length > 0,
    winner: winner ? winner.party : null,
    leader: (winner || leader) ? (winner || leader).party : null,
    cands: cands.slice(0, office === 'H' ? 3 : 4),
  };
}

function holdovers(json, officeLetter, fallback) {
  const bal = json && json.partyControlData && json.partyControlData.results && json.partyControlData.results[0]
    && json.partyControlData.results[0].offices && json.partyControlData.results[0].offices[officeLetter]
    && json.partyControlData.results[0].offices[officeLetter].party_balance;
  if (!bal) return { ...fallback };
  const out = { D: 0, R: 0, O: 0 };
  for (const id of Object.keys(bal)) out[partyCode({ party: { nyt_id: id } })] += Number(bal[id].no_election) || 0;
  return out;
}

// feeds: { S: json|null, H: json|null, G: json|null }
export function buildSnapshot(feeds) {
  const states = {};
  const touch = st => (states[st] = states[st] || { name: STATE_NAMES[st] || st, S: [], G: [], H: [] });
  const times = [];
  for (const o of ['S', 'G', 'H']) {
    const json = feeds[o];
    if (!json) continue;
    if (json.resultsMeta && json.resultsMeta.resultsUpdatedAt) times.push(json.resultsMeta.resultsUpdatedAt);
    for (const r of json.races || []) {
      const n = normalizeRace(r, o);
      if (!STATE_NAMES[n.st]) continue;
      touch(n.st)[o].push(n);
    }
  }
  const tally = (o, total, needed, base) => {
    const t = { total, needed, won: { D: 0, R: 0, O: 0 }, lead: { D: 0, R: 0, O: 0 }, base, counted: 0, races: 0 };
    for (const st of Object.values(states)) for (const r of st[o]) {
      t.races++;
      if (r.winner) t.won[r.winner]++;
      else if (r.leader) t.lead[r.leader]++;
      if (r.total > 0) t.counted++;
    }
    for (const p of ['D', 'R', 'O']) t.won[p] += base[p] || 0;
    return t;
  };
  const control = {
    S: tally('S', 100, 51, feeds.S ? holdovers(feeds.S, 'S', SENATE_HOLDOVER_FALLBACK) : SENATE_HOLDOVER_FALLBACK),
    H: tally('H', 435, 218, { D: 0, R: 0, O: 0 }),
    G: tally('G', 50, 26, GOV_HOLDOVER_FALLBACK),
  };
  times.sort();
  return {
    v: 1,
    source: 'Associated Press via The New York Times',
    updated: times[times.length - 1] || null,
    fetchedAt: new Date().toISOString(),
    available: Object.fromEntries(['S', 'H', 'G'].map(o => [o, !!feeds[o]])),
    control,
    states,
  };
}

export async function fetchFeeds(fetchImpl = fetch, headers = {}) {
  const feeds = {};
  await Promise.all(Object.entries(OFFICES).map(async ([o, name]) => {
    try {
      const r = await fetchImpl(`${NYT_BASE}results-${name}.json?t=${Date.now()}`, { headers, cache: 'no-store' });
      feeds[o] = r.ok ? await r.json() : null;
    } catch { feeds[o] = null; }
  }));
  return feeds;
}

// Summary of who controls / leads a chamber, as text.
export function chamberStatus(t) {
  const { won, needed } = t;
  if (won.D >= needed) return { decided: 'D' };
  if (won.R >= needed) return { decided: 'R' };
  return { decided: null };
}
