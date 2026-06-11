-- live prod sites: junk.4ft.me and spacejunk.4ft.me both serve from /opt/junk/, updated via GH action on push to main
-- canonical domain is spacejunk.4ft.me (used in sitemap/SEO meta)
-- test site is usually running at test.4ft.me
-- if the test site isn't running you can change to build/web and run `serve -l tcp://0.0.0.0:3000` to bring it up. an nginx proxy will connect to it.
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
  Cron in /etc/cron.d/spacejunk-tle runs every 30 min.
