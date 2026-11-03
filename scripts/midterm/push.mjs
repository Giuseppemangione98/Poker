// Web Push delivery. Subscriptions arrive from the app through a ntfy.sh topic
// (public inbox, no account needed) and are stored encrypted in the repo.
import fs from 'node:fs';
import crypto from 'node:crypto';
import webpush from 'web-push';

const SUBS_FILE = new URL('./state/subs.enc', import.meta.url);
const ALLOWED_HOSTS = /(^|\.)(push\.apple\.com|fcm\.googleapis\.com|googleapis\.com|push\.services\.mozilla\.com|notify\.windows\.com)$/;

export class Push {
  constructor({ publicKey, privateKey, subject, inboxTopic, alertsTopic }) {
    this.publicKey = publicKey;
    this.enabled = !!(publicKey && privateKey);
    this.key = crypto.createHash('sha256').update('subs:' + (privateKey || '')).digest();
    this.inboxTopic = inboxTopic;
    this.alertsTopic = alertsTopic;
    this.subs = {};
    this.since = '12h';
    this.dirty = false;
    if (this.enabled) webpush.setVapidDetails(subject, publicKey, privateKey);
    this.load();
  }

  load() {
    try {
      const raw = fs.readFileSync(SUBS_FILE, 'utf8');
      const buf = Buffer.from(raw, 'base64');
      const d = crypto.createDecipheriv('aes-256-gcm', this.key, buf.subarray(0, 12));
      d.setAuthTag(buf.subarray(12, 28));
      const data = JSON.parse(Buffer.concat([d.update(buf.subarray(28)), d.final()]).toString());
      this.subs = data.subs || {};
    } catch { this.subs = {}; }
  }

  save() {
    if (!this.dirty) return false;
    const iv = crypto.randomBytes(12);
    const c = crypto.createCipheriv('aes-256-gcm', this.key, iv);
    const enc = Buffer.concat([c.update(JSON.stringify({ subs: this.subs })), c.final()]);
    fs.mkdirSync(new URL('./state/', import.meta.url), { recursive: true });
    fs.writeFileSync(SUBS_FILE, Buffer.concat([iv, c.getAuthTag(), enc]).toString('base64'));
    this.dirty = false;
    return true;
  }

  async pollInbox() {
    if (!this.enabled || !this.inboxTopic) return 0;
    let added = 0;
    try {
      const r = await fetch(`https://ntfy.sh/${this.inboxTopic}/json?poll=1&since=${this.since}`, { signal: AbortSignal.timeout(15000) });
      if (!r.ok) return 0;
      const lines = (await r.text()).split('\n').filter(Boolean);
      for (const line of lines) {
        let m; try { m = JSON.parse(line); } catch { continue; }
        if (m.event !== 'message') continue;
        this.since = m.id;
        let p; try { p = JSON.parse(m.message); } catch { continue; }
        const sub = p && p.sub;
        if (!sub || !sub.endpoint || !sub.keys || !sub.keys.p256dh || !sub.keys.auth) continue;
        if (p.k && p.k !== this.publicKey) continue; // subscribed with an old key
        let host; try { host = new URL(sub.endpoint).hostname; } catch { continue; }
        if (!ALLOWED_HOSTS.test(host)) continue;
        const isNew = !this.subs[sub.endpoint];
        if (isNew && Object.keys(this.subs).length >= 50) continue;
        this.subs[sub.endpoint] = { endpoint: sub.endpoint, keys: { p256dh: sub.keys.p256dh, auth: sub.keys.auth }, at: Date.now() };
        if (isNew) {
          this.dirty = true; added++;
          await this.sendOne(this.subs[sub.endpoint], { title: 'Notifiche attive ✅', body: 'Riceverai qui gli aggiornamenti in tempo reale sulle elezioni di midterm.', tag: 'welcome' });
        }
      }
    } catch (e) { console.log('inbox error', e.message); }
    return added;
  }

  async sendOne(sub, payload) {
    try {
      await webpush.sendNotification(sub, JSON.stringify(payload), { timeout: 15000, TTL: 6 * 3600, urgency: 'high', topic: (payload.tag || 'midterm').replace(/[^A-Za-z0-9_-]/g, '').slice(0, 32) });
      return true;
    } catch (e) {
      if (e.statusCode === 404 || e.statusCode === 410 || e.statusCode === 403) { delete this.subs[sub.endpoint]; this.dirty = true; }
      console.log('push error', e.statusCode || e.message);
      return false;
    }
  }

  async broadcast(payload) {
    const subs = Object.values(this.subs);
    let ok = 0;
    for (const s of subs) if (await this.sendOne(s, payload)) ok++;
    // Mirror to a ntfy.sh topic: optional fallback for the ntfy iOS app.
    if (this.alertsTopic) {
      try {
        await fetch('https://ntfy.sh/', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ topic: this.alertsTopic, title: payload.title, message: payload.body, click: payload.url || undefined }), signal: AbortSignal.timeout(10000) });
      } catch {}
    }
    console.log(`push "${payload.title}" -> ${ok}/${subs.length}`);
    return ok;
  }
}
