// ===== State =====
let syncInterval = 300;
let syncTimer = null;
let isSyncing = false;
let lang = 'en';

const API_BASE = window.location.origin;

const i18n = {
  en: {
    appTitle: 'Claude Monitor',
    checking: 'Checking credentials...',
    connected: 'Connected via OAuth',
    notLoggedIn: 'Claude Code not logged in',
    currentSession: 'Current session',
    weeklyLimits: 'Weekly limits',
    allModels: 'All models',
    sonnetOnly: 'Sonnet only',
    learnMore: 'Learn more',
    autoSync: 'Auto-sync',
    syncNote: 'Note: API has rate limits. Minimum 5min recommended.',
    sync: 'sync',
    quit: 'quit',
    never: 'never',
    resetsSoon: 'Resets soon',
    resetsIn: (h, m) => h > 0 ? `Resets in ${h} hr ${m} min` : `Resets in ${m} min`,
    resetsAt: (d) => `Resets ${d}`,
    lastSync: (t) => `last sync ${t}`,
    language: 'Language',
    credentials: 'Credentials',
    autoDetected: 'Auto-detected from credentials file',
    notFound: 'Not found',
    refresh: 'Refresh',
  },
  ko: {
    appTitle: 'Claude 모니터',
    checking: '인증 정보 확인 중...',
    connected: 'OAuth 연결됨',
    notLoggedIn: 'Claude Code 로그인 필요',
    currentSession: '현재 세션',
    weeklyLimits: '주간 사용량',
    allModels: '전체 모델',
    sonnetOnly: 'Sonnet 전용',
    learnMore: '자세히 알아보기',
    autoSync: '자동 동기화',
    syncNote: '참고: API 속도 제한 있음. 최소 5분 권장.',
    sync: '동기화',
    quit: '종료',
    never: '동기화 안됨',
    resetsSoon: '곧 초기화',
    resetsIn: (h, m) => h > 0 ? `${h}시간 ${m}분 후 초기화` : `${m}분 후 초기화`,
    resetsAt: (d) => `${d}에 초기화`,
    lastSync: (t) => `마지막 동기화 ${t}`,
    language: '언어',
    credentials: '인증 정보',
    autoDetected: '자격증명 파일에서 자동 감지됨',
    notFound: '찾을 수 없음',
    refresh: '새로고침',
  },
};

function t() { return i18n[lang]; }

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

function percentColor(p) {
  if (p >= 80) return 'danger';
  if (p >= 50) return 'warning';
  return 'success';
}

function setProgressBar(id, percent) {
  const el = $(`#${id}`);
  el.style.width = `${Math.min(percent, 100)}%`;
  el.className = 'progress-fill';
  if (percent >= 80) el.classList.add('danger');
  else if (percent >= 50) el.classList.add('warning');
}

function setPercentText(id, percent) {
  const el = $(`#${id}`);
  el.textContent = `${Math.round(percent)}%`;
  el.className = el.className.replace(/color-\w+/g, '').trim();
  el.classList.add(`color-${percentColor(percent)}`);
}

async function checkCredentials() {
  const dot = $('#credDot');
  const status = $('#credStatus');
  const statusIcon = $('.status-icon');
  const statusText = $('#statusText');

  try {
    const res = await fetch(`${API_BASE}/api/credentials`);
    const data = await res.json();

    if (data.found) {
      dot.className = 'cred-dot found';
      status.textContent = t().autoDetected;
      statusIcon.textContent = '\u2713';
      statusIcon.className = 'status-icon connected';
      statusText.textContent = t().connected;
      statusText.className = 'status-text connected';
      return true;
    }
  } catch {}

  dot.className = 'cred-dot not-found';
  status.textContent = t().notFound;
  statusIcon.textContent = '\u2717';
  statusIcon.className = 'status-icon error';
  statusText.textContent = t().notLoggedIn;
  statusText.className = 'status-text error';
  return false;
}

async function doSync() {
  if (isSyncing) return;
  isSyncing = true;
  $('#syncBtn').innerHTML = '<span class="syncing">\u21BB</span>';

  try {
    const res = await fetch(`${API_BASE}/api/usage`);
    const usage = await res.json();

    if (usage.error) {
      throw new Error(usage.error);
    }

    setPercentText('sessionPercent', usage.sessionUsagePercent);
    setProgressBar('sessionProgress', usage.sessionUsagePercent);

    const hrs = Math.floor(usage.sessionResetSeconds / 3600);
    const mins = Math.floor((usage.sessionResetSeconds % 3600) / 60);
    $('#sessionReset').textContent =
      (hrs === 0 && mins === 0) ? t().resetsSoon : t().resetsIn(hrs, mins);

    setPercentText('allModelsPercent', usage.weeklyAllModelsPercent);
    setProgressBar('allModelsProgress', usage.weeklyAllModelsPercent);
    $('#allModelsReset').textContent = usage.weeklyAllModelsResetDate
      ? t().resetsAt(usage.weeklyAllModelsResetDate) : '';

    setPercentText('sonnetPercent', usage.weeklySonnetPercent);
    setProgressBar('sonnetProgress', usage.weeklySonnetPercent);

    $('#planBadge').textContent = usage.planName;

    const statusIcon = $('.status-icon');
    const statusText = $('#statusText');
    statusIcon.textContent = '\u2713';
    statusIcon.className = 'status-icon connected';
    statusText.textContent = t().connected;
    statusText.className = 'status-text connected';

    const now = new Date();
    const timeStr = now.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true }).toLowerCase();
    $('#lastSync').textContent = t().lastSync(timeStr);

  } catch (err) {
    const statusIcon = $('.status-icon');
    const statusText = $('#statusText');

    if (err.message === 'NO_CREDENTIALS') {
      statusIcon.textContent = '\u2717';
      statusIcon.className = 'status-icon error';
      statusText.textContent = t().notLoggedIn;
      statusText.className = 'status-text error';
    } else if (err.message === 'TOKEN_EXPIRED') {
      statusIcon.textContent = '\u26A0';
      statusIcon.className = 'status-icon error';
      statusText.textContent = lang === 'ko'
        ? '토큰 만료. Claude Code를 한 번 실행해주세요'
        : 'Token expired. Please use Claude Code to refresh';
      statusText.className = 'status-text error';
    } else {
      statusIcon.textContent = '\u26A0';
      statusIcon.className = 'status-icon error';
      statusText.textContent = err.message.substring(0, 40);
      statusText.className = 'status-text error';
    }
  }

  isSyncing = false;
  $('#syncBtn').textContent = t().sync;
}

function setupAutoSync() {
  if (syncTimer) clearInterval(syncTimer);
  syncTimer = null;
  if (syncInterval > 0) {
    doSync();
    syncTimer = setInterval(doSync, syncInterval * 1000);
  }
}

function applyLanguage() {
  const s = t();
  $('.app-title').textContent = s.appTitle;
  $$('.card-title')[0].textContent = s.currentSession;
  $$('.card-title')[1].textContent = s.weeklyLimits;
  $$('.sub-title')[0].textContent = s.allModels;
  $$('.sub-title')[1].textContent = s.sonnetOnly;
  $('#learnMore').textContent = s.learnMore;
  $('.sync-label').textContent = s.autoSync;
  $('.sync-note').textContent = s.syncNote;
  $('#syncBtn').textContent = s.sync;
  $$('.settings-label')[0].textContent = s.language;
  $$('.settings-label')[1].textContent = s.credentials;
}

// ===== Init =====
document.addEventListener('DOMContentLoaded', () => {
  $('#settingsBtn').addEventListener('click', () => {
    const panel = $('#settingsPanel');
    panel.style.display = panel.style.display === 'none' ? 'block' : 'none';
  });

  $$('.lang-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      $$('.lang-btn').forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');
      lang = btn.dataset.lang;
      applyLanguage();
    });
  });

  $$('.sync-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      $$('.sync-btn').forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');
      syncInterval = parseInt(btn.dataset.interval);
      setupAutoSync();
    });
  });

  $('#syncBtn').addEventListener('click', doSync);

  $('#credRefreshBtn').addEventListener('click', () => {
    checkCredentials();
    doSync();
  });

  $('#learnMore').addEventListener('click', (e) => {
    e.preventDefault();
    window.open('https://support.anthropic.com/en/articles/9964580-how-does-usage-work-on-claude-ai', '_blank');
  });

  checkCredentials();
  setupAutoSync();
});
