#!/usr/bin/env bash
# =============================================================================
# Server setup: CelesTrak caching proxy + cron for SpaceJunk
# =============================================================================
# Run this on server.4ft.me as root after the first deploy.
#
# Usage: bash server/setup.sh
#
# This will:
#   1. Install the nginx config for the TLE proxy
#   2. Set up a cron job to keep the static TLE snapshot fresh
#   3. Create the initial TLE snapshot
# =============================================================================

set -euo pipefail

echo "==> SpaceJunk server setup"
echo ""

# --- Config ---
NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
SITE_NAME="spacejunk"
TLE_OUTPUT="/opt/junk/api/tle.json"
TLE_DIR="/opt/junk/api"

# --- 1. Create TLE cache directory ---
echo "==> Creating $TLE_DIR"
mkdir -p "$TLE_DIR"

# --- 2. Install nginx config ---
# The main site config already serves /opt/junk/.
# We add the TLE proxy via a snippet.
echo "==> Checking nginx..."
if command -v nginx &>/dev/null; then
    echo "  nginx found at $(which nginx)"

    # Check if the TLE proxy snippet is already included
    if grep -q "tle-proxy" /etc/nginx/sites-enabled/* 2>/dev/null; then
        echo "  TLE proxy already configured, skipping."
    else
        echo "  NOTE: Manually add the TLE proxy location block"
        echo "  to your nginx site config. See server/nginx-tle.conf"
        echo ""
        echo "  Example snippet to add inside your server block:"
        echo ""
        echo "    location = /api/tle.json {"
        echo "        proxy_pass https://celestrak.org/NORAD/elements/gp.php?\\\$query_string;"
        echo "        proxy_cache tle_cache;"
        echo "        proxy_cache_valid 200 30m;"
        echo "    }"
        echo ""
    fi
else
    echo "  nginx not found. Install it first."
fi

# --- 3. Initial TLE snapshot ---
echo "==> Fetching initial TLE snapshot..."
# Try Celestrak directly first
SNAPSHOT_URL="https://celestrak.org/NORAD/elements/gp.php?GROUP=stations&GROUP=visual&GROUP=last-30-days&GROUP=amateur&GROUP=cubesat&GROUP=active&GROUP=rocket-body&FORMAT=json"
if curl -sf --connect-timeout 15 "$SNAPSHOT_URL" -o "$TLE_OUTPUT" 2>/dev/null; then
    COUNT=$(jq 'length' "$TLE_OUTPUT" 2>/dev/null || echo "?")
    echo "  ✓ Fetched $COUNT objects -> $TLE_OUTPUT"
else
    echo "  ⚠ Could not reach Celestrak from this server."
    echo "  The CI build will provide the initial snapshot."
    echo '[]' > "$TLE_OUTPUT"
fi

# --- 4. Cron job ---
echo "==> Setting up cron job (every 30 min)..."
CRON_JOB="*/30 * * * * root curl -sf --connect-timeout 30 '${SNAPSHOT_URL}' -o '${TLE_OUTPUT}' && echo \"TLE snapshot refreshed: \$(date)\" >> /var/log/tle-refresh.log || echo \"TLE refresh failed: \$(date)\" >> /var/log/tle-refresh.log"

if [ -d /etc/cron.d ]; then
    echo "$CRON_JOB" > /etc/cron.d/spacejunk-tle
    chmod 644 /etc/cron.d/spacejunk-tle
    echo "  ✓ Cron job installed at /etc/cron.d/spacejunk-tle"
else
    echo "  ⚠ No /etc/cron.d directory. Add this to crontab manually:"
    echo ""
    echo "  $CRON_JOB"
    echo ""
fi

echo ""
echo "==> Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Verify nginx config is serving /api/tle.json"
echo "  2. Push to main to trigger a deploy with the bundled snapshot"
echo "  3. Check /var/log/tle-refresh.log for cron results"
