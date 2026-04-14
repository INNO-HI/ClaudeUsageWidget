const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');
const https = require('https');
const crypto = require('crypto');
const { exec } = require('child_process');

const PORT = 19522;
const HOST = '127.0.0.1';
const USAGE_URL = 'https://api.anthropic.com/api/oauth/usage';

// ===== Security: session token =====
// Generated at startup, required in cookie for all API requests.
// Prevents any other local process / remote site from calling our API.
const SESSION_TOKEN = crypto.randomBytes(32).toString('hex');

// Allowed Host header values (prevent DNS rebinding attacks)
const ALLOWED_HOSTS = new Set([
  `127.0.0.1:${PORT}`,
  `localhost:${PORT}`,
]);

// Static files allowlist — only these can be served
const STATIC_DIR = path.resolve(__dirname);
const ALLOWED_STATIC = new Set([
  'index.html',
  'style.css',
  'renderer.js',
]);

// ===== Credentials (READ-ONLY) =====
// Widget never writes or refreshes. Claude Code owns the refresh flow.
function readCredentials() {
  const credPath = path.join(os.homedir(), '.claude', '.credentials.json');
  try {
    const data = fs.readFileSync(credPath, 'utf-8');
    const json = JSON.parse(data);
    const oauth = json.claudeAiOauth;
    if (!oauth || !oauth.accessToken) return null;
    return oauth;
  } catch { return null; }
}

// ===== HTTPS helper =====
function httpsRequest(url, options, body) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const opts = {
      hostname: u.hostname,
      path: u.pathname + u.search,
      // Enforce TLS verification (default, but make explicit)
      rejectUnauthorized: true,
      ...options,
    };
    const req = https.request(opts, (res) => {
      let data = '';
      res.on('data', (c) => data += c);
      res.on('end', () => resolve({ status: res.statusCode, body: data }));
    });
    req.on('error', reject);
    req.setTimeout(15000, () => { req.destroy(); reject(new Error('Timeout')); });
    if (body) req.write(body);
    req.end();
  });
}

// ===== Fetch usage (READ-ONLY) =====
async function fetchUsage() {
  const creds = readCredentials();
  if (!creds) return { error: 'NO_CREDENTIALS' };

  const res = await httpsRequest(USAGE_URL, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${creds.accessToken}`,
      'anthropic-beta': 'oauth-2025-04-20',
      Accept: 'application/json',
    },
  });

  if (res.status === 401 || res.status === 403) {
    return { error: 'TOKEN_EXPIRED' };
  }
  if (res.status === 429) {
    return { error: 'RATE_LIMITED' };
  }
  if (res.status !== 200) return { error: `HTTP ${res.status}` };

  const j = JSON.parse(res.body);
  const usage = {
    isConnected: true,
    sessionUsagePercent: j.five_hour?.utilization || 0,
    sessionResetSeconds: j.five_hour?.resets_at
      ? Math.max(0, Math.floor((new Date(j.five_hour.resets_at) - Date.now()) / 1000)) : 0,
    weeklyAllModelsPercent: j.seven_day?.utilization || 0,
    weeklyAllModelsResetDate: j.seven_day?.resets_at
      ? new Date(j.seven_day.resets_at).toLocaleString('en-US', { weekday: 'short', hour: 'numeric', minute: '2-digit', hour12: true }) : '',
    weeklySonnetPercent: j.seven_day_sonnet?.utilization || 0,
    planName: (j.extra_usage?.is_enabled) ? 'Max (Extra)' : 'Max',
  };
  return usage;
}

// ===== Security helpers =====

function setSecurityHeaders(res) {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('Content-Security-Policy',
    "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'");
  // Same-origin only — no CORS
  res.setHeader('Cache-Control', 'no-store');
}

function hasValidSession(req) {
  const cookie = req.headers.cookie || '';
  const match = cookie.match(/claude_widget_session=([a-f0-9]{64})/);
  if (!match) return false;
  // Constant-time comparison to prevent timing attacks
  try {
    const a = Buffer.from(match[1], 'hex');
    const b = Buffer.from(SESSION_TOKEN, 'hex');
    return a.length === b.length && crypto.timingSafeEqual(a, b);
  } catch {
    return false;
  }
}

function hostAllowed(req) {
  const host = req.headers.host || '';
  return ALLOWED_HOSTS.has(host);
}

// ===== MIME types =====
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
};

// ===== HTTP Server =====
const server = http.createServer(async (req, res) => {
  setSecurityHeaders(res);

  // Only allow GET/HEAD (no POST etc. to the local server)
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.writeHead(405, { 'Content-Type': 'text/plain' });
    res.end('Method Not Allowed');
    return;
  }

  // Reject requests with unknown Host headers (DNS rebinding protection)
  if (!hostAllowed(req)) {
    res.writeHead(403, { 'Content-Type': 'text/plain' });
    res.end('Forbidden');
    return;
  }

  // Parse URL safely (ignore query, only use pathname)
  let pathname;
  try {
    pathname = new URL(req.url, `http://${req.headers.host}`).pathname;
  } catch {
    res.writeHead(400);
    res.end('Bad Request');
    return;
  }

  // Root: inject session cookie and serve index.html
  if (pathname === '/' || pathname === '/index.html') {
    try {
      const content = fs.readFileSync(path.join(STATIC_DIR, 'index.html'));
      res.writeHead(200, {
        'Content-Type': MIME['.html'],
        'Set-Cookie': `claude_widget_session=${SESSION_TOKEN}; Path=/; HttpOnly; SameSite=Strict`,
      });
      res.end(content);
    } catch {
      res.writeHead(500);
      res.end('Internal error');
    }
    return;
  }

  // API endpoints require session token
  if (pathname.startsWith('/api/')) {
    if (!hasValidSession(req)) {
      res.writeHead(401, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Unauthorized' }));
      return;
    }

    if (pathname === '/api/usage') {
      try {
        const data = await fetchUsage();
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(data));
      } catch {
        // Do not leak internal error details to client
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Internal error' }));
      }
      return;
    }

    if (pathname === '/api/credentials') {
      const creds = readCredentials();
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ found: !!creds }));
      return;
    }

    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not found' }));
    return;
  }

  // Static files: strict allowlist (prevents path traversal)
  const filename = path.basename(pathname);
  if (!ALLOWED_STATIC.has(filename)) {
    res.writeHead(404);
    res.end('Not found');
    return;
  }

  const fullPath = path.join(STATIC_DIR, filename);
  // Double-check: resolved path must be inside STATIC_DIR
  if (!fullPath.startsWith(STATIC_DIR + path.sep) && fullPath !== STATIC_DIR) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  try {
    const content = fs.readFileSync(fullPath);
    const ext = path.extname(fullPath);
    res.writeHead(200, { 'Content-Type': MIME[ext] || 'application/octet-stream' });
    res.end(content);
  } catch {
    res.writeHead(404);
    res.end('Not found');
  }
});

server.listen(PORT, HOST, () => {
  const url = `http://${HOST}:${PORT}`;
  console.log(`Claude Widget running at ${url}`);
  console.log(`Session locked to this process. Close the browser tab to revoke.`);

  // Open in default browser
  const cmd = process.platform === 'darwin' ? 'open' : process.platform === 'win32' ? 'start' : 'xdg-open';
  exec(`${cmd} "${url}"`);
});

// Graceful shutdown
process.on('SIGINT', () => { server.close(() => process.exit(0)); });
process.on('SIGTERM', () => { server.close(() => process.exit(0)); });
