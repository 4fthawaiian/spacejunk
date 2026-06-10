#!/bin/bash
# Build TrashMap web release and push to gh-pages branch.
# Server cron at root@server.4ft.me pulls from gh-pages every 5 min.
set -e
cd "$(dirname "$0")"

echo "=== Building web release ==="
flutter build web --release

echo "=== Deploying to gh-pages ==="
cd build/web
git init
git checkout -b gh-pages 2>/dev/null || true
git add -A
git commit -m "Deploy $(date -u '+%Y-%m-%d %H:%M UTC')"
git push https://github.com/4fthawaiian/trashmap.git gh-pages --force

echo "=== Done! Server will pick up changes within 5 minutes ==="
echo "    https://junk.4ft.me"
