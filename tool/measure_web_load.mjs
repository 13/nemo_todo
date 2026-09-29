#!/usr/bin/env node
// Measures how long the web app takes to load, the way a visitor gets it:
// headless Chrome over a throttled network, first visit with an empty
// cache and a repeat visit with a warm one, the median of several runs.
//
//   node tool/measure_web_load.mjs [url] [--network=fast4g|slow4g|none]
//                                  [--cpu=1] [--runs=5]
//                                  [--max-first-kb=N] [--max-repeat-kb=N]
//
// With a --max, it exits 1 when the median bytes of a first or repeat
// visit go over it. CI holds the image it builds to these, because bytes
// are what a regression changes -- 0.15.2 shipped repeat visits that
// downloaded everything again -- while timings on a shared runner vary
// too much to hold anything to.
//
// Point it at a running server (default http://localhost:8080/). It
// reports, from the start of navigation:
//   splash      the loading screen painted (first contentful paint)
//   engine      the compiled app has arrived (main.dart.js / .wasm)
//   db          the database worker was requested (the app is running)
//   frame       the app's first frame (the splash starts to fade)
//   bytes       what went over the wire, compressed
//
// No dependencies: it drives Chrome over the DevTools protocol with
// Node's own WebSocket. CHROME overrides which Chrome it starts.
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const args = process.argv.slice(2);
const flag = (name, fallback) =>
  args.find((a) => a.startsWith(`--${name}=`))?.split('=')[1] ?? fallback;
const url = args.find((a) => !a.startsWith('--')) ?? 'http://localhost:8080/';
const runs = Number(flag('runs', 5));
const cpu = Number(flag('cpu', 1));
// DevTools' own presets: throughput in bytes per second, latency in ms.
const networks = {
  none: null,
  fast4g: { latency: 60, down: (9 * 1024 * 1024) / 8, up: (1.5 * 1024 * 1024) / 8 },
  slow4g: { latency: 150, down: (1.6 * 1024 * 1024) / 8, up: (750 * 1024) / 8 },
};
const maxFirstKb = Number(flag('max-first-kb', Infinity));
const maxRepeatKb = Number(flag('max-repeat-kb', Infinity));
const networkName = flag('network', 'fast4g');
if (!(networkName in networks)) throw new Error(`unknown --network ${networkName}`);
const network = networks[networkName];

// Runs in the page before anything else: notes when the app's first frame
// asks the splash to fade (lib/core/splash adds `done`).
const probe = `
  window.__nemo = {};
  new MutationObserver((_, obs) => {
    const splash = document.getElementById('splash');
    if (splash && splash.classList.contains('done')) {
      window.__nemo.frame = performance.now();
      obs.disconnect();
    }
  }).observe(document, { subtree: true, attributes: true, attributeFilter: ['class'] });
`;

const collect = `(() => {
  const res = performance.getEntriesByType('resource');
  const at = (re) => res.find((r) => re.test(r.name));
  const fcp = performance.getEntriesByName('first-contentful-paint')[0];
  return {
    splash: fcp?.startTime,
    engine: at(/main\\.dart\\.(js|wasm|mjs)$/)?.responseEnd,
    db: at(/drift_worker\\.js/)?.startTime,
    frame: window.__nemo?.frame,
  };
})()`;

async function main() {
  const profile = mkdtempSync(join(tmpdir(), 'nemo-measure-'));
  const chrome = spawn(
    process.env.CHROME ?? 'google-chrome-stable',
    [
      '--headless=new',
      '--remote-debugging-port=0',
      `--user-data-dir=${profile}`,
      '--no-first-run',
      '--no-default-browser-check',
      // CanvasKit needs WebGL; headless has no GPU, so SwiftShader
      // stands in. Absolute times run slower than a real browser, which
      // is fine for comparing one build with another.
      '--use-angle=swiftshader',
      '--enable-unsafe-swiftshader',
      '--window-size=1280,800',
      // GitHub's Ubuntu runners forbid the user namespaces Chrome's
      // sandbox needs. The page is our own build, served locally.
      ...(process.env.CI ? ['--no-sandbox'] : []),
      'about:blank',
    ],
    { stdio: ['ignore', 'ignore', 'pipe'] },
  );
  try {
    const wsUrl = await new Promise((resolve, reject) => {
      let err = '';
      chrome.stderr.on('data', (d) => {
        err += d;
        const m = err.match(/DevTools listening on (ws:\/\/\S+)/);
        if (m) resolve(m[1]);
      });
      chrome.on('exit', (code) => reject(new Error(`chrome exited ${code}: ${err}`)));
    });
    const browser = await connect(wsUrl);
    const cold = [];
    const warm = [];
    for (let i = 0; i < runs; i++) {
      // A fresh context per run: an empty cache for the first visit,
      // then the same context again for the repeat.
      const { browserContextId } = await browser.send('Target.createBrowserContext');
      const { targetId } = await browser.send('Target.createTarget', {
        url: 'about:blank',
        browserContextId,
      });
      const { sessionId } = await browser.send('Target.attachToTarget', {
        targetId,
        flatten: true,
      });
      const page = browser.session(sessionId);
      await page.send('Page.enable');
      await page.send('Network.enable');
      await page.send('Page.addScriptToEvaluateOnNewDocument', { source: probe });
      if (network) {
        await page.send('Network.emulateNetworkConditions', {
          offline: false,
          latency: network.latency,
          downloadThroughput: network.down,
          uploadThroughput: network.up,
        });
      }
      if (cpu > 1) await page.send('Emulation.setCPUThrottlingRate', { rate: cpu });
      cold.push(await load(page, url));
      warm.push(await load(page, url));
      await browser.send('Target.disposeBrowserContext', { browserContextId });
    }
    browser.close();
    console.log(
      `${url}  network=${networkName} cpu=${cpu}x  median of ${runs} runs (ms from navigation)`,
    );
    const over = [
      ...budget('first visit', report('first visit', cold), maxFirstKb),
      ...budget('repeat visit', report('repeat visit', warm), maxRepeatKb),
    ];
    for (const line of over) console.error(line);
    if (over.length) process.exitCode = 1;
  } finally {
    chrome.kill();
    rmSync(profile, { recursive: true, force: true });
  }
}

async function load(page, target) {
  let bytes = 0;
  const off = page.on('Network.loadingFinished', (e) => (bytes += e.encodedDataLength));
  const loaded = page.once('Page.loadEventFired');
  await page.send('Page.navigate', { url: target });
  await loaded;
  const deadline = Date.now() + 60_000;
  let m;
  for (;;) {
    ({ result: { value: m } } = await page.send('Runtime.evaluate', {
      expression: collect,
      returnByValue: true,
    }));
    if (m.frame !== undefined) break;
    if (Date.now() > deadline) throw new Error(`no first frame from ${target} in 60s`);
    await new Promise((r) => setTimeout(r, 50));
  }
  // Let late requests (fonts, the database) finish before counting bytes.
  await new Promise((r) => setTimeout(r, 1000));
  off();
  return { ...m, bytes };
}

function budget(label, kb, max) {
  return kb > max
    ? [`over budget: ${label} sent ${kb.toFixed(0)} KB, more than ${max} KB`]
    : [];
}

// Prints the medians and returns the median bytes, in KB.
function report(label, results) {
  const median = (key) => {
    const v = results.map((r) => r[key]).filter((x) => x !== undefined).sort((a, b) => a - b);
    return v.length ? v[Math.floor(v.length / 2)] : undefined;
  };
  const ms = (key) => `${key} ${median(key)?.toFixed(0).padStart(5) ?? '    -'}`;
  const mb = (median('bytes') / 1024 / 1024).toFixed(2);
  console.log(
    `  ${label.padEnd(13)} ${ms('splash')}  ${ms('engine')}  ${ms('db')}  ${ms('frame')}  bytes ${mb} MB`,
  );
  return median('bytes') / 1024;
}

// A DevTools protocol client over one WebSocket, with flattened sessions.
function connect(wsUrl) {
  const ws = new WebSocket(wsUrl);
  let id = 0;
  const pending = new Map();
  const listeners = new Set();
  ws.onmessage = ({ data }) => {
    const msg = JSON.parse(data);
    if (msg.id !== undefined) {
      const p = pending.get(msg.id);
      pending.delete(msg.id);
      if (msg.error) p.reject(new Error(`${p.method}: ${msg.error.message}`));
      else p.resolve(msg.result);
    } else {
      for (const l of listeners) l(msg);
    }
  };
  const send = (method, params = {}, sessionId) =>
    new Promise((resolve, reject) => {
      const msgId = ++id;
      pending.set(msgId, { resolve, reject, method });
      ws.send(JSON.stringify({ id: msgId, method, params, sessionId }));
    });
  const session = (sessionId) => ({
    send: (method, params) => send(method, params, sessionId),
    on(method, fn) {
      const l = (m) => m.sessionId === sessionId && m.method === method && fn(m.params);
      listeners.add(l);
      return () => listeners.delete(l);
    },
    once(method) {
      return new Promise((resolve) => {
        const off = this.on(method, (p) => {
          off();
          resolve(p);
        });
      });
    },
  });
  return new Promise((resolve, reject) => {
    ws.onerror = reject;
    ws.onopen = () =>
      resolve({ send, session, close: () => ws.close() });
  });
}

await main();
