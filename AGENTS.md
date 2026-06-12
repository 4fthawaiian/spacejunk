-- CELESTRAK COOLDOWN: Server IP is rate-limited until ~2026-06-13. NO prod updates or TLE fetches
  from the prod server until then. Cache is static at 15,834 objects (12MB).
  Do NOT push to main or gh-pages during cooldown — the deploy scripts will rsync and may
  overwrite the cache.

-- live prod sites: junk.4ft.me and spacejunk.4ft.me both serve from /opt/junk/, updated via GH action on push to main
-- server.4ft.me IS the same machine as the prod sites. SSH as root@server.4ft.me.
  The nginx vhosts are at /etc/nginx/sites-enabled/{spacejunk,junk}.4ft.me.vhost.
-- canonical domain is spacejunk.4ft.me (used in sitemap/SEO meta)
-- test site is at test.4ft.me — nginx proxies to a local `serve` on the DEV machine (10.8.0.2:3000).
   The serve process runs from /home/bem/src/trashmap/build/web/ on this machine.
   Restart with: pkill -f 'serve -l' && cd build/web && nohup npx serve -l tcp://0.0.0.0:3000 &
-- test.4ft.me nginx vhost at /etc/nginx/sites-enabled/test.4ft.me.vhost on server.4ft.me
-- ⚠ DEV SERVER: Do NOT touch/restart the dev `serve` process unless you have verified it is down
   (check with `ps aux | grep serve` or `curl localhost:3000`). The test site will be unreachable if the
   serve process is killed/restarted unexpectedly.
-- app is branded as SpaceJunk (not TrashMap) everywhere user-facing
-- this is a flutter app, concentrated on web and android for now
-- android wireless ADB device: M7 (paired via mDNS, serial adb-0123456789ABCDEF-vN4MkB)
-- once a new change is tested and pushed, remind the user to update the roadmap

-- TLE data sources (tried in order):
   1. CelesTrak direct + CORS proxies (client attempts itself first)
   2. /api/tle.json (self-hosted cache, same-origin, web only)
   3. Procedural simulation (always works)
-- Self-hosted TLE cache: bundled at CI build time by scripts/fetch-tle.mjs,
  refreshed on the server every 30 min by a cron job that runs
  /opt/junk/api/fetch-tle.py (Python, fetches 14 CelesTrak groups, dedup by NORAD_ID)
-- Nginx config on server.4ft.me: proxy_cache to Celestrak at /api/tle.json
  with 30min TTL + stale-while-revalidate + `try_files` fallback to proxy.
  Both spacejunk.4ft.me and junk.4ft.me vhosts have this configured.
-- Server setup: /opt/junk/api/ contains the TLE snapshot + fetch-tle.py script.
  Cron in /etc/cron.d/spacejunk-tle refreshes every 30 min (see below for disabling).

-- CelesTrak rate-limiting: server.4ft.me IP is rate-limited/blocked by CelesTrak.
  The cron job was removed (/etc/cron.d/spacejunk-tle) to avoid reinforcing the ban.
  As of 2026-06-11, the cache has 15,834 objects w/ SATCAT (12MB) — a one-time full fetch
  from a fresh DigitalOcean droplet (see DO droplet workflow below).
  30-minute polling got us banned. When re-enabling the cron, use a gentler interval:
    echo '0 */6 * * * root python3 /opt/junk/api/fetch-tle.py >> /var/log/tle-refresh.log 2>&1' > /etc/cron.d/spacejunk-tle
  (Every 6 hours is plenty — TLEs don't change that fast.)
  Without the cron, the cache is static — regenerated only by:
    • Manual run: ssh root@server.4ft.me "python3 /opt/junk/api/fetch-tle.py"
    • CI deploy: .github/workflows/deploy-web.yml runs scripts/fetch-tle.mjs at build time

-- DigitalOcean droplet workflow (for one-off full TLE fetch when server IP is blocked):
  WARNING: Droplets cost money ($4-6/mo prorated). Destroy immediately after use.
  The DO API token is at /home/bem/.do_token (env var $DO_TOKEN).
  CelesTrak rate-limits per IP aggressively — a fresh DO IP can do ONE successful fetch
  before getting rate-limited too. Steps:
    1. Create ONE droplet with your local ed25519 key (already registered as DO SSH key)
    2. Wait for it, ssh in, copy fetch-tle.py, run it ONCE
    3. Generate an SSH key on the droplet, add its pubkey to prod's ~/.ssh/authorized_keys
    4. scp the result to root@server.4ft.me:/opt/junk/api/tle.json
    5. Destroy the droplet immediately
    6. Remove the temp SSH key from prod's authorized_keys
  ⚠ Do NOT run fetch-tle.py twice from the same IP — the second run will be rate-limited
    and overwrite the good cache with a partial one (~1,480 objects).
    If you mess up, destroy the droplet and start fresh — don't retry from the same IP.
