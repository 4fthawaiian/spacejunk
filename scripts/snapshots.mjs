#!/usr/bin/env node
/**
 * snapshots.mjs — Takes visual screenshots of the SpaceJunk web app using Playwright.
 *
 * This script:
 *   1. Starts a Python SPA HTTP server to serve the Flutter web build
 *   2. Launches headless Chromium via Playwright
 *   3. Visits predefined scenarios (viewport sizes, filter states, URL params)
 *   4. Saves screenshots to snapshots/current/
 *   5. Writes scenario metadata
 *
 * Usage:
 *   flutter build web --wasm          # build first
 *   node scripts/snapshots.mjs        # take screenshots
 *   npm run snapshots                 # shorthand
 *   npm run snapshots:build           # build + screenshot in one step
 *
 * Scenarios are defined below — add new ones as the app evolves.
 */

import { chromium } from 'playwright';
import { spawn, execSync } from 'child_process';
import { existsSync, mkdirSync, writeFileSync, readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');
const BUILD_DIR = resolve(ROOT, 'build/web');
const SERVER_SCRIPT = resolve(__dirname, 'serve_spa.py');
const SNAPSHOTS_DIR = resolve(ROOT, 'snapshots/current');
const SCENARIOS_FILE = resolve(SNAPSHOTS_DIR, 'scenarios.json');
const PORT = 5199;

// ─── Scenario definitions ────────────────────────────────────────────────────
const SCENARIOS = [
  // ── Desktop (1920×1080) ─────────────────────────────────────────────────
  {
    name: 'desktop-default',
    viewport: { width: 1920, height: 1080 },
    url: '/',
    desc: 'Default view on load, desktop',
  },
  {
    name: 'desktop-hide-debris',
    viewport: { width: 1920, height: 1080 },
    url: '/?hideShells=Debris',
    desc: 'Debris shell hidden',
  },
  {
    name: 'desktop-starlink-only',
    viewport: { width: 1920, height: 1080 },
    url: '/?constellations=starlink&zoom=1.5',
    desc: 'Starlink filtered, zoomed in',
  },
  {
    name: 'desktop-constellations-gps',
    viewport: { width: 1920, height: 1080 },
    url: '/?constellations=gps,iridium&zoom=1.3',
    desc: 'GPS + Iridium constellations',
  },
  {
    name: 'desktop-time-plus30',
    viewport: { width: 1920, height: 1080 },
    url: '/?time=30',
    desc: 'Time scrubber at +30 days',
  },
  {
    name: 'desktop-time-minus90',
    viewport: { width: 1920, height: 1080 },
    url: '/?time=-90',
    desc: 'Time scrubber at -90 days',
  },
  {
    name: 'desktop-starfield-off',
    viewport: { width: 1920, height: 1080 },
    url: '/?starfield=false',
    desc: 'Starfield disabled',
  },
  // ── Tablet (1024×768) ───────────────────────────────────────────────────
  {
    name: 'tablet-default',
    viewport: { width: 1024, height: 768 },
    url: '/',
    desc: 'Tablet viewport',
  },
  // ── Mobile (390×844) ───────────────────────────────────────────────────
  {
    name: 'mobile-default',
    viewport: { width: 390, height: 844 },
    url: '/',
    desc: 'Mobile viewport, default state',
  },
  {
    name: 'mobile-zoom',
    viewport: { width: 390, height: 844 },
    url: '/?zoom=1.8&constellations=starlink',
    desc: 'Mobile, zoomed in on Starlink',
  },
];

// ─── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Start the Python SPA server as a child process.
 * Uses scripts/serve_spa.py to serve the build directory.
 */
function startServer(dir, port) {
  return new Promise((resolveServer, reject) => {
    const proc = spawn('python3', [SERVER_SCRIPT, dir, String(port)], {
      stdio: ['ignore', 'pipe', 'pipe'],
      detached: false,
    });

    let started = false;

    const onData = (data) => {
      if (!started) {
        started = true;
        console.error(`  🖥  Server running at http://localhost:${port}`);
        resolveServer(proc);
      }
    };

    proc.stdout.on('data', onData);
    proc.stderr.on('data', onData);

    // Safety timeout
    setTimeout(() => {
      if (!started) {
        started = true;
        console.error(`  🖥  Server assumed ready at http://localhost:${port}`);
        resolveServer(proc);
      }
    }, 3000);

    proc.on('error', (err) => {
      if (!started) reject(err);
    });
  });
}

/** Wait for Flutter to finish initialization and start rendering. */
async function waitForFlutterReady(page, timeoutMs = 25000) {
  // Flutter with skwasm or canvaskit renderer sets attributes on <body>.
  // The loading screen (#loading) gets hidden when Flutter emits its
  // first frame event.
  await page.waitForFunction(() => {
    const body = document.body;
    if (!body) return false;
    // Flutter has initialized if the renderer attribute is set
    const renderer = body.getAttribute('flt-renderer');
    if (renderer === 'skwasm' || renderer === 'canvaskit') return true;
    // Alternatively, the loading screen might be hidden
    const loading = document.getElementById('loading');
    if (loading && loading.classList.contains('hidden')) return true;
    return false;
  }, { timeout: timeoutMs });
}

/** Take a screenshot for a single scenario. */
async function captureScenario(browser, scenario) {
  const context = await browser.newContext({
    viewport: scenario.viewport,
    deviceScaleFactor: 2,
    colorScheme: 'dark',
    reducedMotion: 'reduce',
  });

  const page = await context.newPage();

  // Collect console messages for debugging
  const consoleLogs = [];
  page.on('console', (msg) => consoleLogs.push(`${msg.type()}: ${msg.text()}`));
  page.on('pageerror', (err) => consoleLogs.push(`PAGE ERROR: ${err.message}`));

  const baseUrl = `http://localhost:${PORT}`;
  console.error(`  📸 ${scenario.name}: ${scenario.desc}`);

  try {
    // Use 'load' event — 'networkidle' may never fire because CORS proxy
    // fallback requests can hang in headless mode.
    await page.goto(`${baseUrl}${scenario.url}`, {
      waitUntil: 'load',
      timeout: 30000,
    });

    // Wait for Flutter engine to initialize
    await waitForFlutterReady(page);

    // Give the renderer time to paint several frames
    await page.waitForTimeout(6000);

    // Take screenshot
    const filename = `${scenario.name}.png`;
    const filepath = resolve(SNAPSHOTS_DIR, filename);
    await page.screenshot({ path: filepath, fullPage: false });
    console.error(`    ✅ Saved ${filename} (${scenario.viewport.width}×${scenario.viewport.height})`);

    // Write console logs if there were errors
    const errors = consoleLogs.filter(l => l.startsWith('error:') || l.startsWith('PAGE ERROR'));
    if (errors.length > 0) {
      writeFileSync(resolve(SNAPSHOTS_DIR, `${scenario.name}-console.log`), consoleLogs.join('\n'));
    }
  } catch (err) {
    console.error(`    ❌ FAILED: ${err.message}`);
    try {
      await page.screenshot({ path: resolve(SNAPSHOTS_DIR, `${scenario.name}-FAILED.png`) });
      writeFileSync(resolve(SNAPSHOTS_DIR, `${scenario.name}-console.log`), consoleLogs.join('\n'));
    } catch {}
  } finally {
    await context.close();
  }
}

/**
 * Generate test TLE cache so CORS fallback doesn't hang.
 */
function ensureTestTleCache() {
  const apiDir = resolve(BUILD_DIR, 'api');
  const tlePath = resolve(apiDir, 'tle.json');

  if (existsSync(tlePath) && readFileSync(tlePath).length > 1000) {
    console.error(`  ✅ TLE cache exists`);
    return;
  }

  console.error(`  🔄 Generating test TLE cache...`);
  mkdirSync(apiDir, { recursive: true });

  try {
    execSync('python3 scripts/generate-test-tle.py', {
      cwd: ROOT,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    const size = readFileSync(tlePath).length;
    console.error(`  ✅ Generated ${(size / 1024).toFixed(0)} KB TLE cache`);
  } catch (err) {
    console.error(`  ⚠ TLE cache generation failed: ${err.message.slice(0, 100)}`);
  }
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  console.error(`\n🌐 SpaceJunk Visual Snapshots\n`);

  if (!existsSync(BUILD_DIR) || !existsSync(resolve(BUILD_DIR, 'index.html'))) {
    console.error(`\n❌ No valid build at ${BUILD_DIR}`);
    console.error(`   Run 'flutter build web --wasm' then retry\n`);
    process.exit(1);
  }

  mkdirSync(SNAPSHOTS_DIR, { recursive: true });
  ensureTestTleCache();

  // Free port
  try { spawn('sh', ['-c', `lsof -ti:${PORT} | xargs kill -9 2>/dev/null`]); } catch {}

  // Start server
  console.error(`\n  🚀 Starting server...`);
  const serverProc = await startServer(BUILD_DIR, PORT).catch((err) => {
    console.error(`  ❌ Failed: ${err.message}`);
    process.exit(1);
  });

  await new Promise((r) => setTimeout(r, 1000));

  // Verify
  try {
    const resp = await fetch(`http://localhost:${PORT}/`);
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    console.error(`  ✅ Server responding`);
  } catch (err) {
    console.error(`  ❌ Server unreachable: ${err.message}`);
    serverProc.kill('SIGTERM');
    process.exit(1);
  }

  // Launch browser
  console.error(`\n  🎭 Launching Chromium...`);
  const browser = await chromium.launch({
    headless: true,
    args: [
      '--no-sandbox',
      '--use-gl=angle',
      '--use-angle=swiftshader',
      '--enable-webgl',
      '--ignore-gpu-blocklist',
    ],
  });

  // Capture scenarios
  console.error(`\n  📋 ${SCENARIOS.length} scenarios:\n`);
  const results = [];

  for (const scenario of SCENARIOS) {
    try {
      await captureScenario(browser, scenario);
      results.push({ ...scenario, status: 'ok' });
    } catch (err) {
      console.error(`    💥 ${err.message}`);
      results.push({ ...scenario, status: 'error' });
    }
  }

  // Cleanup
  await browser.close();
  serverProc.kill('SIGTERM');
  setTimeout(() => { try { serverProc.kill('SIGKILL'); } catch {} }, 2000);

  // Write metadata
  writeFileSync(
    SCENARIOS_FILE,
    JSON.stringify(results.map(r => ({ name: r.name, viewport: r.viewport, url: r.url, status: r.status })), null, 2),
  );

  const passed = results.filter((r) => r.status === 'ok').length;
  const failed = results.filter((r) => r.status !== 'ok').length;

  console.error(`\n  ─────────────────────────────────────────`);
  console.error(`  ✅ ${passed}/${SCENARIOS.length} captured`);
  if (failed > 0) console.error(`  ❌ ${failed} failed`);
  console.error(`  📁 ${SNAPSHOTS_DIR}`);
  console.error(`\n  ➡  Run 'node scripts/visual-diff.mjs --update' to set baseline\n`);
}

main().catch((err) => {
  console.error(`\n❌ Fatal: ${err.message}`);
  process.exit(1);
});
