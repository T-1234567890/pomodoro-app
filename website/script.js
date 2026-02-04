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
