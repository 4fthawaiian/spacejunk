"""SPA-compatible HTTP server for static files.

Usage:
    python3 scripts/serve_spa.py <directory> [port]

Serves files from <directory>, falling back to index.html for any
non-file path (SPA single-page app support).
"""
import http.server
import os
import sys

class SPAHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        # Strip query params and hash
        path = self.path.split('?')[0].split('#')[0]
        file_path = os.path.join(os.getcwd(), path.lstrip('/') or 'index.html')
        if os.path.exists(file_path) and os.path.isfile(file_path):
            return super().do_GET()
        # SPA fallback — serve index.html
        self.path = '/index.html'
        return super().do_GET()

    def log_message(self, format, *args):
        pass  # keep it quiet

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(f'Usage: {sys.argv[0]} <directory> [port]', file=sys.stderr)
        sys.exit(1)
    os.chdir(sys.argv[1])
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 5199
    http.server.test(HandlerClass=SPAHandler, port=port, bind='0.0.0.0')
