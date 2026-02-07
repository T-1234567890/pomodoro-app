const scrollToHash = (hash, behavior = 'auto') => {
  if (!hash || hash === '#') return;
  const target = document.querySelector(hash);
  if (target) target.scrollIntoView({ behavior, block: 'start' });
};

// IntersectionObserver for scroll reveals
const revealObserver = new IntersectionObserver((entries) => {
  entries.forEach((entry) => {
    if (entry.isIntersecting) {
      entry.target.classList.add('visible');
      revealObserver.unobserve(entry.target);
    }
  });
}, { threshold: 0.2 });

document.querySelectorAll('.reveal').forEach((el) => revealObserver.observe(el));

let currentLang = 'en';

function applyLanguage(lang) {
  currentLang = lang;
  document.documentElement.lang = lang === 'zh' ? 'zh-Hans' : 'en';
  const elements = document.querySelectorAll('[data-en]');
  elements.forEach((el) => {
    const next = lang === 'zh' ? el.dataset.zh : el.dataset.en;
    if (next !== undefined) el.innerHTML = next;
  });
  const titleElements = document.querySelectorAll('[data-title-en]');
  titleElements.forEach((el) => {
    const nextTitle = lang === 'zh' ? el.dataset.titleZh : el.dataset.titleEn;
    if (nextTitle !== undefined) el.title = nextTitle;
  });
  const tooltipElements = document.querySelectorAll('[data-tooltip-en]');
  tooltipElements.forEach((el) => {
    const nextTooltip = lang === 'zh' ? el.dataset.tooltipZh : el.dataset.tooltipEn;
    if (nextTooltip !== undefined) el.dataset.tooltip = nextTooltip;
  });
  localStorage.setItem('pomodoro-lang', lang);
}

function animateLanguageSwitch(nextLang) {
  const prefersReduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (prefersReduce) {
    applyLanguage(nextLang);
    return;
  }

  const root = document.body;
  const outDuration = 150; // within 120–160ms
  const inDuration = 210;  // within 180–240ms

  root.classList.remove('lang-switching-in');
  root.classList.add('lang-switching-out');

  window.setTimeout(() => {
    applyLanguage(nextLang);
    root.classList.remove('lang-switching-out');
    root.classList.add('lang-switching-in');

    window.setTimeout(() => {
      root.classList.remove('lang-switching-in');
    }, inDuration);
  }, outDuration);
}

// Language toggle button
const toggleBtn = document.getElementById('lang-toggle');
if (toggleBtn) {
  toggleBtn.addEventListener('click', () => {
    const next = currentLang === 'en' ? 'zh' : 'en';
    animateLanguageSwitch(next);
  });
}

// Smooth scroll for nav links
const navLinks = document.querySelectorAll('.nav-links a[href^="#"]');
navLinks.forEach((link) => {
  link.addEventListener('click', (e) => {
    e.preventDefault();
    const hash = link.getAttribute('href');
    if (hash) history.pushState(null, '', hash);
    scrollToHash(hash, 'smooth');
  });
});

// Fade-in hero on load and only scroll when URL already has a hash
window.addEventListener('load', () => {
  document.querySelectorAll('.fade-on-load').forEach((el) => el.classList.add('visible'));

  if (location.hash) {
    const el = document.querySelector(location.hash);
    if (el) el.scrollIntoView();
  }
});

// Handle back/forward navigation between sections
window.addEventListener('popstate', () => {
  scrollToHash(window.location.hash, 'auto');
});

// Init language from storage or default
const stored = localStorage.getItem('pomodoro-lang');
applyLanguage(stored === 'zh' ? 'zh' : 'en');

// Hero phrase switcher (headline)
const phrasePool = [
  { en: '🧠 Quiet tools for deep work', zh: '🧠 为深度工作准备的安静工具' },
  { en: '🌿 Focus without pressure', zh: '🌿 无压力的专注' },
  { en: '🎯 Rhythm over speed', zh: '🎯 节律胜过速度' },
  { en: '✨ Attention is a resource', zh: '✨ 注意力是一种资源' },
  { en: '🫧 Work gently', zh: '🫧 温和地工作' },
  { en: '🌊 Depth over noise', zh: '🌊 深度胜过噪声' },
  { en: '🧩 Calm is productive', zh: '🧩 平静本身就是效率' },
  { en: '🕊 Slow focus wins', zh: '🕊 慢节奏的专注更持久' },
  { en: '🔕 Silence helps thinking', zh: '🔕 安静帮助思考' },
  { en: '📖 Work like turning pages', zh: '📖 像翻书一样工作' }
];

const heroArea = document.querySelector('.hero');
const heroArt = document.querySelector('.hero-illustration');
const heroTitle = document.querySelector('.hero .switchable-head');
let phraseAnimating = false;

function pickNewPhrase() {
  const current = currentLang === 'zh' ? heroTitle?.dataset.zh : heroTitle?.dataset.en;
  const pool = phrasePool.filter((p) => p.en !== current && p.zh !== current);
  return pool[Math.floor(Math.random() * pool.length)] || phrasePool[0];
}

function switchHeroPhrase() {
  if (!heroTitle || phraseAnimating) return;
  phraseAnimating = true;
  heroTitle.classList.add('phrase-out');
  setTimeout(() => {
    const next = pickNewPhrase();
    heroTitle.dataset.en = next.en;
    heroTitle.dataset.zh = next.zh;
    applyLanguage(currentLang);
    heroTitle.classList.remove('phrase-out');
    phraseAnimating = false;
  }, 200);
}

[heroArea, heroArt].forEach((el) => {
  if (el) el.addEventListener('click', switchHeroPhrase);
});

const REPO_OWNER = 'T-1234567890';
const REPO_NAME = 'pomodoro-app';
const RIBBON_INVITE_URL = `https://github.com/${REPO_OWNER}/${REPO_NAME}`;
const RIBBON_CACHE_KEY = 'pomodoro-ribbon-users-v1';
const RIBBON_MAX_USERS = 30;
const RIBBON_MIN_SEGMENT_ITEMS = 18;
const RIBBON_REFRESH_MS = 5 * 60 * 1000;
const RIBBON_INVITE_PLACEHOLDER = {
  login: '__you__',
  html_url: RIBBON_INVITE_URL,
  placeholder: true,
  kind: 'invite'
};
const RIBBON_PLACEHOLDERS = [
  { login: '__placeholder_1__', avatar_url: 'screenshots/pic1.jpg', html_url: '', placeholder: true },
  { login: '__placeholder_2__', avatar_url: 'screenshots/pic1.jpg', html_url: '', placeholder: true },
  { login: '__placeholder_3__', avatar_url: 'screenshots/pic1.jpg', html_url: '', placeholder: true },
  { login: '__placeholder_4__', avatar_url: 'screenshots/pic1.jpg', html_url: '', placeholder: true },
  { login: '__placeholder_5__', avatar_url: 'screenshots/pic1.jpg', html_url: '', placeholder: true },
  { login: '__placeholder_6__', avatar_url: 'screenshots/pic1.jpg', html_url: '', placeholder: true }
];

const ribbonState = {
  track: null,
  fallback: null,
  error: null,
  primarySegment: null,
  mirrorSegment: null,
  users: new Map(),
  renderedCounts: new Map(),
  initialized: false,
  requestPending: false,
  loadingRemoved: false
};

function createAvatarNode(user) {
  if (user.kind === 'invite') {
    const node = document.createElement('a');
    node.className = 'contributor-avatar contributor-avatar-invite';
    node.href = user.html_url || RIBBON_INVITE_URL;
    node.target = '_blank';
    node.rel = 'noreferrer';
    node.dataset.placeholder = 'true';
    node.dataset.titleEn = 'You could be here';
    node.dataset.titleZh = '下一个就是你';
    node.title = currentLang === 'zh' ? node.dataset.titleZh : node.dataset.titleEn;
    node.setAttribute('aria-label', node.title);

    const label = document.createElement('span');
    label.className = 'contributor-invite-label';
    label.dataset.en = 'You';
    label.dataset.zh = '你';
    label.textContent = currentLang === 'zh' ? label.dataset.zh : label.dataset.en;
    node.appendChild(label);
    return node;
  }

  const node = user.html_url ? document.createElement('a') : document.createElement('div');
  node.className = 'contributor-avatar';
  if (user.placeholder) node.dataset.placeholder = 'true';

  if (user.html_url) {
    node.href = user.html_url;
    node.target = '_blank';
    node.rel = 'noreferrer';
    node.setAttribute('aria-label', `@${user.login} on GitHub`);
  } else {
    node.setAttribute('aria-hidden', 'true');
  }

  const img = document.createElement('img');
  img.src = user.avatar_url;
  img.alt = '';
  img.loading = 'lazy';
  img.decoding = 'async';
  node.appendChild(img);

  return node;
}

function ensureRibbonDom() {
  if (ribbonState.initialized) return true;
  const track = document.getElementById('contributors-track');
  const fallback = document.getElementById('contributors-fallback');
  const error = document.getElementById('contributors-error');
  if (!track) return false;

  ribbonState.track = track;
  ribbonState.fallback = fallback;
  ribbonState.error = error;

  const primary = document.createElement('div');
  primary.className = 'contributors-segment';
  primary.dataset.segment = 'primary';

  const mirror = document.createElement('div');
  mirror.className = 'contributors-segment';
  mirror.dataset.segment = 'mirror';
  mirror.setAttribute('aria-hidden', 'true');

  track.appendChild(primary);
  track.appendChild(mirror);

  ribbonState.primarySegment = primary;
  ribbonState.mirrorSegment = mirror;
  ribbonState.initialized = true;
  return true;
}

function ribbonHasRenderedAvatars() {
  return Boolean(ribbonState.primarySegment && ribbonState.primarySegment.children.length > 0);
}

function removeRibbonLoadingNode() {
  if (!ribbonState.fallback) return;
  ribbonState.fallback.remove();
  ribbonState.fallback = null;
  ribbonState.loadingRemoved = true;
}

function setRibbonErrorVisible(visible) {
  if (!ribbonState.error) return;
  ribbonState.error.hidden = !visible;
}

function updateRibbonLoadingState() {
  if (!ribbonState.fallback || ribbonState.loadingRemoved) return;
  const shouldShowLoading = ribbonState.requestPending && !ribbonHasRenderedAvatars();
  if (!shouldShowLoading) {
    removeRibbonLoadingNode();
    return;
  }
  ribbonState.fallback.hidden = false;
}

function getRibbonViewportWidth() {
  return ribbonState.track?.parentElement?.clientWidth || 0;
}

function updateRibbonAnimationDuration() {
  if (!ribbonState.track || !ribbonState.primarySegment) return;
  const segmentWidth = ribbonState.primarySegment.scrollWidth;
  if (!segmentWidth) return;
  const duration = Math.min(30, Math.max(18, segmentWidth / 60));
  ribbonState.track.style.setProperty('--contributors-loop-duration', `${duration.toFixed(2)}s`);
}

function buildLoopSeed(users) {
  const base = Array.isArray(users) && users.length > 0 ? users : RIBBON_PLACEHOLDERS;
  const withInvite = [...base, RIBBON_INVITE_PLACEHOLDER];
  const seed = [];
  while (seed.length < RIBBON_MIN_SEGMENT_ITEMS) {
    withInvite.forEach((user) => seed.push(user));
  }
  return seed;
}

function ensureRibbonCoverage(seed, baseMaxPerLogin = 1) {
  if (!ribbonState.primarySegment) return;
  appendUsers(seed, baseMaxPerLogin);
  let maxPerLogin = baseMaxPerLogin;
  let guard = 0;
  const viewport = getRibbonViewportWidth();
  while (viewport > 0 && ribbonState.primarySegment.scrollWidth < (viewport + 40) && guard < 14) {
    maxPerLogin += 1;
    appendUsers(seed, maxPerLogin);
    guard += 1;
  }
  updateRibbonAnimationDuration();
}

function appendUsers(users, maxPerLogin = 1) {
  if (!ribbonState.primarySegment || !ribbonState.mirrorSegment) return 0;
  let added = 0;

  users.forEach((user) => {
    if (!user.login) return;
    const isInvite = user.kind === 'invite';
    if (!isInvite && !user.avatar_url) return;

    if (!ribbonState.users.has(user.login)) {
      ribbonState.users.set(user.login, {
        login: user.login,
        avatar_url: user.avatar_url,
        html_url: user.html_url || '',
        placeholder: Boolean(user.placeholder),
        kind: user.kind || ''
      });
    }

    const source = ribbonState.users.get(user.login);
    let rendered = ribbonState.renderedCounts.get(user.login) || 0;

    if (rendered >= maxPerLogin) return;
    ribbonState.primarySegment.appendChild(createAvatarNode(source));
    ribbonState.mirrorSegment.appendChild(createAvatarNode(source));
    rendered += 1;
    added += 1;

    ribbonState.renderedCounts.set(user.login, rendered);
  });

  if (added > 0) updateRibbonLoadingState();
  return added;
}

function getCachedRibbonUsers() {
  try {
    const raw = localStorage.getItem(RIBBON_CACHE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed.filter((item) => item?.login && item?.avatar_url);
  } catch {
    return [];
  }
}

function saveRibbonUsersToCache() {
  try {
    const values = Array.from(ribbonState.users.values())
      .filter((item) => !item.placeholder)
      .map((item) => ({
        login: item.login,
        avatar_url: item.avatar_url,
        html_url: item.html_url || ''
      }));
    localStorage.setItem(RIBBON_CACHE_KEY, JSON.stringify(values));
  } catch {
    // ignore cache write failures
  }
}

async function fetchCommunityUsers() {
  const contributorsApi = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contributors?per_page=100`;
  const issuesApi = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/issues?state=all&per_page=100`;
  const [contributorsRes, issuesRes] = await Promise.all([fetch(contributorsApi), fetch(issuesApi)]);
  if (!contributorsRes.ok || !issuesRes.ok) throw new Error('Request failed');

  const [contributorsPayload, issuesPayload] = await Promise.all([contributorsRes.json(), issuesRes.json()]);
  const merged = new Map();
  const seenIds = new Set();

  const putUser = (candidate) => {
    if (!candidate?.login || !candidate?.avatar_url) return;
    const id = Number.isFinite(candidate.id) ? candidate.id : null;
    if (id !== null && seenIds.has(id)) return;
    if (merged.has(candidate.login)) return;

    merged.set(candidate.login, {
      login: candidate.login,
      avatar_url: candidate.avatar_url,
      html_url: candidate.html_url || ''
    });
    if (id !== null) seenIds.add(id);
  };

  if (Array.isArray(contributorsPayload)) {
    contributorsPayload.forEach((item) => {
      putUser(item);
    });
  }

  if (Array.isArray(issuesPayload)) {
    issuesPayload.forEach((issue) => {
      putUser(issue?.user);
    });
  }

  return Array.from(merged.values()).slice(0, RIBBON_MAX_USERS);
}

async function refreshContributorRibbon() {
  if (!ensureRibbonDom()) return;
  ribbonState.requestPending = true;
  setRibbonErrorVisible(false);
  updateRibbonLoadingState();

  try {
    const fetchedUsers = await fetchCommunityUsers();
    if (fetchedUsers.length > 0) {
      ensureRibbonCoverage(buildLoopSeed(fetchedUsers), 1);
      saveRibbonUsersToCache();
    } else {
      if (!ribbonHasRenderedAvatars()) {
        ensureRibbonCoverage(buildLoopSeed([]), 1);
      }
    }
  } catch {
    const cachedUsers = getCachedRibbonUsers();
    if (cachedUsers.length > 0) {
      ensureRibbonCoverage(buildLoopSeed(cachedUsers), 1);
    } else if (!ribbonHasRenderedAvatars()) {
      ensureRibbonCoverage(buildLoopSeed([]), 1);
    }
    setRibbonErrorVisible(true);
  } finally {
    ribbonState.requestPending = false;
    updateRibbonLoadingState();
  }
}

function startContributorRibbon() {
  if (!ensureRibbonDom()) return;

  const cachedUsers = getCachedRibbonUsers();
  if (cachedUsers.length > 0) {
    ensureRibbonCoverage(buildLoopSeed(cachedUsers), 1);
  }

  refreshContributorRibbon();
  window.setInterval(refreshContributorRibbon, RIBBON_REFRESH_MS);
  window.addEventListener('resize', () => {
    if (!ribbonState.primarySegment) return;
    const realUsers = Array.from(ribbonState.users.values()).filter((user) => !user.placeholder);
    ensureRibbonCoverage(buildLoopSeed(realUsers), 1);
  });
}

function parseLastPage(linkHeader) {
  if (!linkHeader) return null;
  const parts = linkHeader.split(',').map((part) => part.trim());
  const last = parts.find((part) => part.includes('rel="last"'));
  if (!last) return null;
  const match = last.match(/[?&]page=(\d+)/);
  if (!match) return null;
  return Number.parseInt(match[1], 10);
}

const FOOTER_REFRESH_MS = 5 * 60 * 1000;

function animateFooterNumbers() {
  const numbers = [
    document.getElementById('footer-stars'),
    document.getElementById('footer-commits'),
    document.getElementById('footer-issues')
  ].filter(Boolean);

  numbers.forEach((node, index) => {
    node.classList.remove('is-live');
    // Force reflow so the same animation can be replayed on refresh.
    void node.offsetWidth;
    window.setTimeout(() => {
      node.classList.add('is-live');
    }, 200 * index);
  });
}

async function loadFooterHeartbeat() {
  const starsEl = document.getElementById('footer-stars');
  const commitsEl = document.getElementById('footer-commits');
  const issuesEl = document.getElementById('footer-issues');
  if (!starsEl || !commitsEl || !issuesEl) return;

  const repoApi = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}`;

  try {
    const repoRes = await fetch(repoApi);
    if (!repoRes.ok) throw new Error('Request failed');
    const repo = await repoRes.json();

    const branch = repo?.default_branch || 'main';
    const commitsRes = await fetch(`https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/commits?sha=${encodeURIComponent(branch)}&per_page=1`);
    if (!commitsRes.ok) throw new Error('Request failed');
    const commitsPayload = await commitsRes.json();
    const commitPages = parseLastPage(commitsRes.headers.get('link'));
    const commits = Number.isInteger(commitPages) ? commitPages : (Array.isArray(commitsPayload) ? commitsPayload.length : 0);

    const stars = Number.isFinite(repo?.stargazers_count) ? repo.stargazers_count : 0;
    const issues = Number.isFinite(repo?.open_issues_count) ? repo.open_issues_count : 0;

    const format = new Intl.NumberFormat('en-US');
    starsEl.textContent = format.format(stars);
    commitsEl.textContent = format.format(commits);
    issuesEl.textContent = format.format(issues);

    animateFooterNumbers();
  } catch (err) {}
}

startContributorRibbon();
loadFooterHeartbeat();
window.setInterval(loadFooterHeartbeat, FOOTER_REFRESH_MS);
