const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');
const https = require('https');
const { exec } = require('child_process');

const PORT = 19522;
const USAGE_URL = 'https://api.anthropic.com/api/oauth/usage';
const TOKEN_REFRESH_URL = 'https://console.anthropic.com/v1/oauth/token';
const OAUTH_CLIENT_ID = '9d1c250a-e61b-44d9-88ed-5944d1962f5e';

// ===== Credentials =====
function readCredentials() {
  const credPath = path.join(os.homedir(), '.claude', '.credentials.json');
  try {
    const data = fs.readFileSync(credPath, 'utf-8');
    const json = JSON.parse(data);
    const oauth = json.claudeAiOauth;
    if (!oauth || !oauth.accessToken || !oauth.refreshToken) return null;
    return oauth;
  } catch { return null; }
}

function saveCredentials(creds) {
  const credPath = path.join(os.homedir(), '.claude', '.credentials.json');
  try {
    fs.writeFileSync(credPath, JSON.stringify({ claudeAiOauth: creds }, null, 2));
  } catch {}
}

// ===== HTTPS helper =====
function httpsRequest(url, options, body) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const opts = { hostname: u.hostname, path: u.pathname + u.search, ...options };
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

// ===== Refresh token =====
async function refreshToken(creds) {
  const res = await httpsRequest(TOKEN_REFRESH_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
  }, JSON.stringify({
    grant_type: 'refresh_token',
    refresh_token: creds.refreshToken,
    client_id: OAUTH_CLIENT_ID,
  }));
  const json = JSON.parse(res.body);
  if (!json.access_token) throw new Error('Refresh failed');
  const newCreds = {
    accessToken: json.access_token,
    refreshToken: json.refresh_token,
    expiresAt: Date.now() + (json.expires_in || 3600) * 1000,
  };
  saveCredentials(newCreds);
  return newCreds;
}

// ===== Fetch usage =====
async function fetchUsage() {
  let creds = readCredentials();
  if (!creds) return { error: 'NO_CREDENTIALS' };

  async function doFetch(c) {
    return httpsRequest(USAGE_URL, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${c.accessToken}`,
        'anthropic-beta': 'oauth-2025-04-20',
        Accept: 'application/json',
      },
    });
  }

  let res = await doFetch(creds);
  if ([401, 403, 429].includes(res.status)) {
    creds = await refreshToken(creds);
    res = await doFetch(creds);
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

// ===== MIME types =====
const MIME = { '.html': 'text/html', '.css': 'text/css', '.js': 'application/javascript', '.png': 'image/png', '.svg': 'image/svg+xml' };

// ===== HTTP Server =====
const server = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');

  if (req.url === '/api/usage') {
    try {
      const data = await fetchUsage();
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(data));
    } catch (e) {
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: e.message }));
    }
    return;
  }

  if (req.url === '/api/credentials') {
    const creds = readCredentials();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ found: !!creds }));
    return;
  }

  // Static files
  let filePath = req.url === '/' ? '/index.html' : req.url;
  const fullPath = path.join(__dirname, filePath);
  const ext = path.extname(fullPath);

  try {
    const content = fs.readFileSync(fullPath);
    res.writeHead(200, { 'Content-Type': MIME[ext] || 'text/plain' });
    res.end(content);
  } catch {
    res.writeHead(404);
    res.end('Not found');
  }
});

server.listen(PORT, '127.0.0.1', () => {
  const url = `http://127.0.0.1:${PORT}`;
  console.log(`Claude Widget running at ${url}`);

  // Open in default browser
  const cmd = process.platform === 'darwin' ? 'open' : process.platform === 'win32' ? 'start' : 'xdg-open';
  exec(`${cmd} "${url}"`);
});
