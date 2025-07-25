// Theme Toggle Script
(function() {
  'use strict';
  
  const THEME_KEY = 'whiteblog-theme';
  const LIGHT_THEME = 'light';
  const DARK_THEME = 'dark';
  
  function getThemePreference() {
    const saved = localStorage.getItem(THEME_KEY);
    if (saved) return saved;
    
    return window.matchMedia('(prefers-color-scheme: dark)').matches 
      ? DARK_THEME 
      : LIGHT_THEME;
  }
  
  function applyTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem(THEME_KEY, theme);
    
    updateToggleButton(theme);
  }
  
  function updateToggleButton(theme) {
    const toggle = document.getElementById('theme-toggle');
    if (!toggle) return;
    
    const isDark = theme === DARK_THEME;
    const moonIcon = '<svg id="moon" width="24" height="18" viewBox="0 0 24 24" fill="none" stroke="currentcolor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.79A9 9 0 1111.21 3 7 7 0 0021 12.79z"></path></svg>';
    const sunIcon = '<svg id="sun" width="24" height="18" viewBox="0 0 24 24" fill="none" stroke="currentcolor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="5"></circle><line x1="12" y1="1" x2="12" y2="3"></line><line x1="12" y1="21" x2="12" y2="23"></line><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line><line x1="1" y1="12" x2="3" y2="12"></line><line x1="21" y1="12" x2="23" y2="12"></line><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line></svg>';
    toggle.innerHTML = isDark ? moonIcon : sunIcon;

    toggle.setAttribute('aria-label', `Cambiar a tema ${isDark ? 'claro' : 'oscuro'}`);
    toggle.title = `Cambiar a tema ${isDark ? 'claro' : 'oscuro'}`;
  }
  
  function toggleTheme() {
    const current = document.documentElement.getAttribute('data-theme') || LIGHT_THEME;
    const newTheme = current === LIGHT_THEME ? DARK_THEME : LIGHT_THEME;
    applyTheme(newTheme);
  }
  
  function init() {
    const preference = getThemePreference();
    applyTheme(preference);
    
    const toggle = document.getElementById('theme-toggle');
    if (toggle) {
      toggle.addEventListener('click', toggleTheme);
    }
    
    window.matchMedia('(prefers-color-scheme: dark)')
      .addEventListener('change', (e) => {
        if (!localStorage.getItem(THEME_KEY)) {
          applyTheme(e.matches ? DARK_THEME : LIGHT_THEME);
        }
      });
  }
  
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
  
  const initialTheme = getThemePreference();
  document.documentElement.setAttribute('data-theme', initialTheme);
})();