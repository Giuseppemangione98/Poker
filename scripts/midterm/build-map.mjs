// Regenerates docs/states.js (run once: npm i && node build-map.mjs)
import fs from 'node:fs';
import * as topo from 'topojson-client';
import * as simp from 'topojson-simplify';
import { geoPath } from 'd3-geo';
const t = JSON.parse(fs.readFileSync(new URL('./node_modules/us-atlas/states-albers-10m.json', import.meta.url)));
const pre = simp.presimplify(t);
const s = simp.simplify(pre, 0.6);
const fips = {"01":"AL","02":"AK","04":"AZ","05":"AR","06":"CA","08":"CO","09":"CT","10":"DE","11":"DC","12":"FL","13":"GA","15":"HI","16":"ID","17":"IL","18":"IN","19":"IA","20":"KS","21":"KY","22":"LA","23":"ME","24":"MD","25":"MA","26":"MI","27":"MN","28":"MS","29":"MO","30":"MT","31":"NE","32":"NV","33":"NH","34":"NJ","35":"NM","36":"NY","37":"NC","38":"ND","39":"OH","40":"OK","41":"OR","42":"PA","44":"RI","45":"SC","46":"SD","47":"TN","48":"TX","49":"UT","50":"VT","51":"VA","53":"WA","54":"WV","55":"WI","56":"WY"};
const path = geoPath().digits(1);
const out = {};
for (const f of topo.feature(s, s.objects.states).features) {
  const k = fips[f.id]; if (!k) continue;
  const d = path(f); const c = path.centroid(f);
  out[k] = { d, c: c.map(v => Math.round(v)) };
}
fs.writeFileSync(new URL('../../docs/states.js', import.meta.url), '// US states (Albers USA, 975x610) generated from us-atlas@3 (public domain, US Census)\nexport const STATE_PATHS = ' + JSON.stringify(out) + ';\n');
console.log(Object.keys(out).length, fs.statSync(new URL('../../docs/states.js', import.meta.url)).size);
