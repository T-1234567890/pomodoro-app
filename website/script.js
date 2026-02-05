// Fade-in hero on load
window.addEventListener('load', () => {
  document.querySelectorAll('.fade-on-load').forEach((el) => el.classList.add('visible'));
});

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
    const target = document.querySelector(link.getAttribute('href'));
    if (target) target.scrollIntoView({ behavior: 'smooth', block: 'start' });
  });
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
