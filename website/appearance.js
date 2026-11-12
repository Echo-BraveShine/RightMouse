(() => {
  const root = document.documentElement;
  const system = matchMedia("(prefers-color-scheme: dark)");
  const key = "rightmouse-site-appearance";
  const choices = ["system", "light", "dark"];
  let preference = "system";
  try {
    const saved = localStorage.getItem(key);
    if (choices.includes(saved)) preference = saved;
  } catch {
    // The site also works when browser storage is unavailable.
  }

  function apply() {
    root.dataset.theme = preference === "system"
      ? (system.matches ? "dark" : "light")
      : preference;
    document.querySelectorAll("[data-theme-choice]").forEach(button => {
      button.setAttribute("aria-pressed", String(button.dataset.themeChoice === preference));
    });
  }

  apply();
  system.addEventListener("change", apply);
  document.addEventListener("DOMContentLoaded", () => {
    const controls = document.querySelector(".theme-switch");
    controls.hidden = false;
    controls.addEventListener("click", event => {
      const button = event.target.closest("[data-theme-choice]");
      if (!button) return;
      preference = button.dataset.themeChoice;
      try { localStorage.setItem(key, preference); } catch { /* Optional storage. */ }
      apply();
    });
    apply();
  }, { once: true });
})();
