/* crane landing — interactions */

(() => {
  "use strict";

  const THEME_KEY = "crane-theme";
  const root = document.documentElement;

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
    applyTheme("light", false);
  }

  initTheme();

  document.querySelector("[data-theme-toggle]")?.addEventListener("click", () => {
    const next = root.getAttribute("data-theme") === "light" ? "dark" : "light";
    applyTheme(next);
  });

  const navToggle = document.querySelector("[data-nav-toggle]");
  const sheet = document.querySelector("[data-nav-overlay]");

  function setSheet(open) {
    sheet?.classList.toggle("is-open", open);
    navToggle?.classList.toggle("is-open", open);
    navToggle?.setAttribute("aria-expanded", String(open));
    navToggle?.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    document.body.classList.toggle("sheet-open", open);
  }

  navToggle?.addEventListener("click", () => {
    setSheet(!sheet?.classList.contains("is-open"));
  });

  sheet?.querySelectorAll("a").forEach((a) => {
    a.addEventListener("click", () => setSheet(false));
  });

  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && sheet?.classList.contains("is-open")) setSheet(false);
  });

  const enters = document.querySelectorAll(".enter");
  if ("IntersectionObserver" in window) {
    const io = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue;
          const el = entry.target;
          const delay = Number(el.getAttribute("data-delay") || 0);
          setTimeout(() => el.classList.add("is-in"), delay);
          io.unobserve(el);
        }
      },
      { threshold: 0.1, rootMargin: "0px 0px -6% 0px" }
    );
    enters.forEach((el) => io.observe(el));
  } else {
    enters.forEach((el) => el.classList.add("is-in"));
  }

  const pill = document.getElementById("capturePill");
  const pillText = document.getElementById("pillText");
  const archive = document.getElementById("historyCard");
  const tabs = document.querySelectorAll("[data-pill-state]");
  const replay = document.querySelector("[data-pill-replay]");

  if (pill && pillText) {
    const PHRASES = [
      "Email Maya about Friday — try the late slot",
      "Try a tag system for crane — local mlx?",
      "Re-read the typography section before Monday",
    ];
    const LINK = "linear.app/issue/CRN-204";
    const CARET = '<span class="capture__caret"></span>';
    let typingTimer = null;
    let stateTimer = null;
    let current = "capture";

    function clearTimers() {
      if (typingTimer) clearTimeout(typingTimer);
      if (stateTimer) clearTimeout(stateTimer);
    }

    function setState(state) {
      clearTimers();
      current = state;
      pill.setAttribute("data-state", state);
      archive?.classList.toggle("is-open", state === "history");
      tabs.forEach((t) => {
        t.classList.toggle("is-on", t.getAttribute("data-pill-state") === state);
      });
      runState(state);
    }

    function typeText(el, str, done) {
      let i = 0;
      el.innerHTML = CARET;
      const tick = () => {
        if (i >= str.length) {
          if (done) typingTimer = setTimeout(done, 700);
          return;
        }
        el.innerHTML = str.slice(0, i + 1) + CARET;
        i++;
        typingTimer = setTimeout(tick, 36 + Math.random() * 55);
      };
      tick();
    }

    function runState(state) {
      switch (state) {
        case "capture": {
          const phrase = PHRASES[Math.floor(Math.random() * PHRASES.length)];
          typeText(pillText, phrase, () => {
            if (current === "capture") setState("link");
          });
          break;
        }
        case "link": {
          typeText(pillText, LINK, () => {
            if (current === "link") setState("saved");
          });
          break;
        }
        case "saved": {
          pillText.innerHTML = '<span style="opacity:0.45">Saved.</span>';
          stateTimer = setTimeout(() => {
            if (current === "saved") setState("history");
          }, 1200);
          break;
        }
        case "history": {
          pillText.innerHTML = CARET;
          stateTimer = setTimeout(() => {
            if (current === "history") setState("capture");
          }, 5000);
          break;
        }
      }
    }

    tabs.forEach((tab) => {
      tab.addEventListener("click", () => {
        const s = tab.getAttribute("data-pill-state");
        if (s) setState(s);
      });
    });

    replay?.addEventListener("click", () => setState("capture"));

    const stage = document.querySelector(".stage");
    if (stage && "IntersectionObserver" in window) {
      const boot = new IntersectionObserver(
        (entries, obs) => {
          if (entries.some((e) => e.isIntersecting)) {
            setTimeout(() => setState("capture"), 650);
            obs.disconnect();
          }
        },
        { threshold: 0.3 }
      );
      boot.observe(stage);
    } else {
      setTimeout(() => setState("capture"), 650);
    }

    document.addEventListener("visibilitychange", () => {
      if (document.hidden) clearTimers();
      else runState(current);
    });
  }

  document.addEventListener("keydown", (e) => {
    if ((e.metaKey || e.ctrlKey) && e.shiftKey && e.code === "Space") {
      e.preventDefault();
      document.querySelector(".stage")?.scrollIntoView({ behavior: "smooth", block: "center" });
      document.querySelector('[data-pill-state="capture"]')?.click();
    }
  });
})();
