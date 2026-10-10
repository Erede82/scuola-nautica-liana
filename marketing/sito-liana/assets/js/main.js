(() => {
  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const root = document.documentElement;
  const topBar = document.querySelector("[data-top-bar]");

  /* Nav */
  const toggle = document.querySelector("[data-nav-toggle]");
  const nav = document.querySelector("[data-nav]");
  if (toggle && nav) {
    const close = () => {
      nav.classList.remove("is-open");
      toggle.setAttribute("aria-expanded", "false");
    };
    toggle.addEventListener("click", () => {
      const open = !nav.classList.contains("is-open");
      nav.classList.toggle("is-open", open);
      toggle.setAttribute("aria-expanded", open ? "true" : "false");
    });
    nav.querySelectorAll("a").forEach((a) => a.addEventListener("click", close));
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape") close();
    });
  }

  /* Header */
  const header = document.querySelector("[data-header]");
  if (header) {
    const onScrollHeader = () => {
      header.classList.toggle("is-scrolled", window.scrollY > 6);
    };
    onScrollHeader();
    window.addEventListener("scroll", onScrollHeader, { passive: true });
  }

  /* Progress: load then scroll */
  let loadDone = false;
  const setProgress = (pct) => {
    root.style.setProperty("--progress", `${Math.max(0, Math.min(100, pct))}%`);
  };

  const updateScrollProgress = () => {
    if (!loadDone || !document.body.classList.contains("is-scroll-progress")) return;
    const max = document.documentElement.scrollHeight - window.innerHeight;
    setProgress(max > 0 ? (window.scrollY / max) * 100 : 0);
  };

  const finishLoad = () => {
    if (loadDone) return;
    loadDone = true;
    setProgress(100);
    if (topBar) {
      topBar.classList.remove("is-loading");
      topBar.classList.add("is-done");
    }
    window.setTimeout(() => {
      document.body.classList.add("is-scroll-progress");
      updateScrollProgress();
    }, reduced ? 0 : 400);
  };

  if (topBar) {
    topBar.classList.add("is-loading");
    setProgress(10);
    const heroes = [
      ...document.querySelectorAll(
        "[data-hero-asset], .home-world__media img, .page-hero__media img"
      ),
    ];
    let loaded = 0;
    const total = Math.max(heroes.length, 1);
    const bump = () => {
      loaded += 1;
      setProgress(15 + (loaded / total) * 75);
      if (loaded >= total) finishLoad();
    };
    if (!heroes.length) {
      window.requestAnimationFrame(() => finishLoad());
    } else {
      heroes.forEach((el) => {
        if (el.complete || el.readyState >= 2) bump();
        else {
          el.addEventListener("load", bump, { once: true });
          el.addEventListener("error", bump, { once: true });
        }
      });
      window.setTimeout(finishLoad, 2400);
    }
  } else {
    loadDone = true;
    document.body.classList.add("is-scroll-progress");
  }

  window.addEventListener("scroll", updateScrollProgress, { passive: true });
  window.addEventListener("resize", updateScrollProgress, { passive: true });
  window.addEventListener("load", () => {
    document.querySelectorAll(".page-hero").forEach((h) => h.classList.add("is-ready"));
    finishLoad();
  });

  /* Home narrative acts */
  const act1 = document.querySelector("[data-home-act1]");
  const act2 = document.querySelector("[data-home-act2]");
  const worlds = document.querySelector("[data-home-worlds]");

  const updateHome = () => {
    if (!act1 && !act2) return;
    const y = window.scrollY;
    const vh = window.innerHeight;

    if (act1) {
      const complete = reduced || y > vh * 0.08;
      act1.classList.toggle("is-complete", complete);
    }

    if (act2) {
      const rect = act2.getBoundingClientRect();
      const progress = Math.min(
        1,
        Math.max(0, (vh - rect.top) / (vh + rect.height * 0.28))
      );
      const open = reduced || progress > 0.12;
      const doors = reduced || progress > 0.28;
      act2.classList.toggle("is-open", open);
      act2.classList.toggle("is-doors", doors);
    }
  };

  updateHome();
  window.addEventListener("scroll", updateHome, { passive: true });
  window.addEventListener("resize", updateHome, { passive: true });

  /* Split hover desktop */
  if (
    worlds &&
    !reduced &&
    window.matchMedia("(hover: hover) and (min-width: 900px)").matches
  ) {
    const auto = worlds.querySelector(".home-world--auto");
    const nau = worlds.querySelector(".home-world--nautica");
    const clear = () => {
      worlds.classList.remove("is-hover-auto", "is-hover-nautica");
    };
    auto?.addEventListener("mouseenter", () => {
      worlds.classList.add("is-hover-auto");
      worlds.classList.remove("is-hover-nautica");
    });
    nau?.addEventListener("mouseenter", () => {
      worlds.classList.add("is-hover-nautica");
      worlds.classList.remove("is-hover-auto");
    });
    worlds.addEventListener("mouseleave", clear);
    auto?.addEventListener("focusin", () => {
      worlds.classList.add("is-hover-auto");
      worlds.classList.remove("is-hover-nautica");
    });
    nau?.addEventListener("focusin", () => {
      worlds.classList.add("is-hover-nautica");
      worlds.classList.remove("is-hover-auto");
    });
  }

  /* Reveal: handled by motion.js (GSAP ScrollTrigger). Fallback if motion absent. */
  if (!document.documentElement.classList.contains("motion-ready")) {
    const reveals = document.querySelectorAll(".reveal, [data-reveal]");
    if (reveals.length) {
      if (reduced || !("IntersectionObserver" in window)) {
        reveals.forEach((el) => el.classList.add("is-in"));
      } else {
        root.classList.add("js-io-reveal");
        const io = new IntersectionObserver(
          (entries) => {
            entries.forEach((entry) => {
              if (entry.isIntersecting) {
                entry.target.classList.add("is-in");
                io.unobserve(entry.target);
              }
            });
          },
          { rootMargin: "0px 0px -8% 0px", threshold: 0.12 }
        );
        reveals.forEach((el) => io.observe(el));
      }
    }
  }

  /* Sticky story panels */
  document.querySelectorAll("[data-story]").forEach((story) => {
    const panels = [...story.querySelectorAll("[data-story-panel]")];
    if (!panels.length) return;
    if (reduced || window.matchMedia("(max-width: 899px)").matches) {
      panels.forEach((p) => p.classList.add("is-active"));
      return;
    }
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            panels.forEach((p) => p.classList.remove("is-active"));
            entry.target.classList.add("is-active");
          }
        });
      },
      { rootMargin: "-38% 0px -38% 0px", threshold: 0.01 }
    );
    panels.forEach((p, i) => {
      if (i === 0) p.classList.add("is-active");
      io.observe(p);
    });
  });

  /* Path rail sync */
  const rail = document.querySelector("[data-path-rail]");
  if (rail && !reduced && window.matchMedia("(min-width: 900px)").matches) {
    const links = [...rail.querySelectorAll("a[href^='#']")];
    const sections = links
      .map((a) => document.querySelector(a.getAttribute("href")))
      .filter(Boolean);
    const sync = () => {
      let active = links[0];
      sections.forEach((sec, i) => {
        const top = sec.getBoundingClientRect().top;
        if (top < window.innerHeight * 0.45) active = links[i];
      });
      links.forEach((l) => l.classList.remove("is-active"));
      active?.classList.add("is-active");
    };
    sync();
    window.addEventListener("scroll", sync, { passive: true });
  }

  /* Parallax: handled by motion.js (ScrollTrigger scrub) when available. */
})();
