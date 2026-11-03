// Shared configuration for the app (browser) and the updater (GitHub Actions).
export const REPO = 'Giuseppemangione98/Poker';
export const BRANCH = 'claude/upbeat-gates-8xs1mk';
// Data files are read from raw.githubusercontent.com (CORS enabled, refreshed
// every commit) so the page does not have to wait for a GitHub Pages rebuild.
export const RAW_DATA = `https://raw.githubusercontent.com/${REPO}/${BRANCH}/docs/data/`;
export const SITE_URL = 'https://giuseppemangione98.github.io/Poker/';
// ntfy.sh topics: the app drops its push subscription in the inbox; the updater
// mirrors every alert on the alerts topic (usable with the ntfy iOS app too).
export const NTFY_INBOX = 'midterm26-inbox-1eb9d5dd3d8f767b';
export const NTFY_ALERTS = 'midterm26-alerts-b90c62e4dde4040d';
