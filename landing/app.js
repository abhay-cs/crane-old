/* =========================================================
   crane — landing interactions
   theme toggle · pill state machine · typing demo · reveal-on-scroll
   ========================================================= */

(() => {
  "use strict";

  /* ----------------- theme ----------------- */

  const THEME_KEY = "crane-theme";
  const root = document.documentElement;
  const toggle = document.querySelector("[data-theme-toggle]");

  function applyTheme(theme, persist = true) {
    root.setAttribute("data-theme", theme);
    if (persist) {
      try {
        localStorage.setItem(THEME_KEY, theme);
      } catch {}
    }
  }

  function initTheme() {
    let stored = null;
    try {
      stored = localStorage.getItem(THEME_KEY);
    } catch {}
    if (stored === "light" || stored === "dark") {
      applyTheme(stored, false);
      return;
    }
    // System preference fallback
    const prefersLight = window.matchMedia(
      "(prefers-color-scheme: light)"
    ).matches;
    applyTheme(prefersLight ? "light" : "dark", false);
  }

  initTheme();

  toggle?.addEventListener("click", () => {
    const next = root.getAttribute("data-theme") === "light" ? "dark" : "light";
    applyTheme(next);
  });

  /* ----------------- nav border on scroll ----------------- */

  const nav = document.querySelector(".nav");
  const onScroll = () => {
    if (window.scrollY > 8) nav?.classList.add("is-scrolled");
    else nav?.classList.remove("is-scrolled");
  };
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  /* ----------------- reveal on scroll ----------------- */

  const reveals = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window) {
    const io = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) {
            const el = entry.target;
            const delay = Number(el.getAttribute("data-delay") || 0);
            setTimeout(() => el.classList.add("is-in"), delay);
            io.unobserve(el);
          }
        }
      },
      { threshold: 0.18 }
    );
    reveals.forEach((el) => io.observe(el));
  } else {
    reveals.forEach((el) => el.classList.add("is-in"));
  }

  /* ----------------- pill state machine ----------------- */

  const pill = document.getElementById("capturePill");
  const pillText = document.getElementById("pillText");
  const history = document.getElementById("historyCard");
  const chips = document.querySelectorAll("[data-pill-state]");
  const replayBtn = document.querySelector("[data-pill-replay]");

  if (pill && pillText) {
    const PHRASES = [
      "Email Maya about Friday — try the late slot",
      "Try a tag system for crane — local mlx?",
      "Re-read the typography section before Monday",
    ];
    const LINK_TEXT = "linear.app/issue/CRN-204";

    const CARET = '<span class="pill__caret"></span>';
    let typingTimer = null;
    let stateTimer = null;
    let currentState = "capture";

    function clearTimers() {
      if (typingTimer) clearTimeout(typingTimer);
      if (stateTimer) clearTimeout(stateTimer);
    }

    function setState(state, { silent = false } = {}) {
      clearTimers();
      currentState = state;
      pill.setAttribute("data-state", state);
      if (history) {
        history.classList.toggle("is-open", state === "history");
      }
      chips.forEach((chip) => {
        chip.classList.toggle(
          "is-active",
          chip.getAttribute("data-pill-state") === state
        );
      });
      if (silent) return;
      runState(state);
    }

    function typeText(target, str, done) {
      let i = 0;
      target.innerHTML = CARET;
      const tick = () => {
        if (i >= str.length) {
          if (done) typingTimer = setTimeout(done, 700);
          return;
        }
        const partial = str.slice(0, i + 1);
        target.innerHTML = partial + CARET;
        i++;
        typingTimer = setTimeout(tick, 36 + Math.random() * 60);
      };
      tick();
    }

    function runState(state) {
      switch (state) {
        case "capture": {
          const phrase = PHRASES[Math.floor(Math.random() * PHRASES.length)];
          typeText(pillText, phrase, () => {
            if (currentState === "capture") setState("saved");
          });
          break;
        }
        case "link": {
          typeText(pillText, LINK_TEXT, () => {
            if (currentState === "link") setState("saved");
          });
          break;
        }
        case "saved": {
          pillText.innerHTML = '<span style="opacity: 0.5">Saved.</span>';
          stateTimer = setTimeout(() => {
            if (currentState === "saved") setState("history");
          }, 1300);
          break;
        }
        case "history": {
          pillText.innerHTML = CARET;
          // Auto-loop back to capture after a while
          stateTimer = setTimeout(() => {
            if (currentState === "history") setState("capture");
          }, 5200);
          break;
        }
      }
    }

    // Chip clicks: jump to that state
    chips.forEach((chip) => {
      chip.addEventListener("click", () => {
        const target = chip.getAttribute("data-pill-state");
        if (target) setState(target);
      });
    });

    replayBtn?.addEventListener("click", () => setState("capture"));

    // Boot — once the hero is visible, start the typing demo
    const heroStage = document.querySelector(".stage");
    if (heroStage && "IntersectionObserver" in window) {
      const startObs = new IntersectionObserver(
        (entries, obs) => {
          for (const entry of entries) {
            if (entry.isIntersecting) {
              setTimeout(() => setState("capture"), 700);
              obs.disconnect();
            }
          }
        },
        { threshold: 0.35 }
      );
      startObs.observe(heroStage);
    } else {
      setTimeout(() => setState("capture"), 700);
    }

    // Pause when tab not visible (nicer on battery)
    document.addEventListener("visibilitychange", () => {
      if (document.hidden) {
        clearTimers();
      } else {
        runState(currentState);
      }
    });
  }

  /* ----------------- keyboard shortcuts (delight) ----------------- */

  // Pressing ⌘⇧Space anywhere triggers a "demo" capture
  document.addEventListener("keydown", (e) => {
    const isMod = e.metaKey || e.ctrlKey;
    if (isMod && e.shiftKey && e.code === "Space") {
      e.preventDefault();
      const stage = document.querySelector(".stage");
      if (stage) {
        stage.scrollIntoView({ behavior: "smooth", block: "center" });
        const btn = document.querySelector(
          '.stage-chip[data-pill-state="capture"]'
        );
        btn?.click();
      }
    }
  });
})();
