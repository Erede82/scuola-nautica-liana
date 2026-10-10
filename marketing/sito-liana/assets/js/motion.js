(() => {
  const root = document.documentElement;
  const reducedMq = window.matchMedia("(prefers-reduced-motion: reduce)");
  const finePointerMq = window.matchMedia("(hover: hover) and (pointer: fine)");
  const desktopMq = window.matchMedia("(min-width: 900px)");

  const prefersReduced = () => reducedMq.matches;
  const hasGsap = typeof window.gsap !== "undefined";
  const hasScrollTrigger =
    hasGsap && typeof window.ScrollTrigger !== "undefined";
  const hasLenis = typeof window.Lenis !== "undefined";

  /** Runtime page state — survives breakpoint rebuilds. */
  const revealed = new WeakSet();
  let homeHeroPlayed = false;
  let pageHeroPlayed = false;
  let mediaRefreshBound = false;

  const markRevealed = (el) => {
    if (!el) return;
    revealed.add(el);
    el.classList.add("is-in", "is-revealed");
  };

  const isRevealed = (el) =>
    !!el &&
    (revealed.has(el) ||
      el.classList.contains("is-revealed") ||
      el.classList.contains("is-in"));

  const ensureVisible = (els) => {
    const list = Array.isArray(els) ? els : [els];
    list.forEach((el) => {
      if (!el) return;
      markRevealed(el);
      el.style.removeProperty("opacity");
      el.style.removeProperty("transform");
      el.style.removeProperty("visibility");
      if (hasGsap) {
        window.gsap.set(el, { clearProps: "opacity,visibility,transform" });
      }
    });
  };

  /** Reveal content without motion when libs missing or reduced motion. */
  const showStatic = () => {
    document
      .querySelectorAll(
        ".reveal, [data-reveal], [data-reveal-media], [data-reveal-group] > *"
      )
      .forEach((el) => ensureVisible(el));
    document.querySelectorAll("[data-home-act1]").forEach((el) => {
      el.classList.add("is-complete");
    });
    document.querySelectorAll("[data-home-act2]").forEach((el) => {
      el.classList.add("is-open", "is-doors");
    });
    document.querySelectorAll(".page-hero").forEach((el) => {
      el.classList.add("is-ready");
    });
    homeHeroPlayed = true;
    pageHeroPlayed = true;
  };

  if (!hasGsap || !hasScrollTrigger) {
    showStatic();
    return;
  }

  const gsap = window.gsap;
  const ScrollTrigger = window.ScrollTrigger;
  gsap.registerPlugin(ScrollTrigger);

  /** GSAP docs default example: lagSmoothing(1000, 16). */
  const GSAP_LAG_DEFAULT_THRESHOLD = 1000;
  const GSAP_LAG_DEFAULT_ADJUSTED = 16;

  let lenis = null;
  let tickerFn = null;
  let ctx = null;
  /** ScrollTriggers owned by this motion layer only. */
  const ownedTriggers = [];

  const trackTrigger = (tweenOrTrigger) => {
    const st =
      tweenOrTrigger && tweenOrTrigger.scrollTrigger
        ? tweenOrTrigger.scrollTrigger
        : tweenOrTrigger;
    if (st && typeof st.kill === "function") ownedTriggers.push(st);
    return tweenOrTrigger;
  };

  const headerOffset = () => {
    const header = document.querySelector("[data-header]");
    return header ? Math.ceil(header.getBoundingClientRect().height) : 56;
  };

  const destroyLenis = () => {
    if (tickerFn) {
      gsap.ticker.remove(tickerFn);
      tickerFn = null;
    }
    if (lenis) {
      lenis.destroy();
      lenis = null;
      root.classList.remove("lenis-active");
    }
    // Restore GSAP default lag smoothing when Lenis is not driving the ticker.
    gsap.ticker.lagSmoothing(
      GSAP_LAG_DEFAULT_THRESHOLD,
      GSAP_LAG_DEFAULT_ADJUSTED
    );
  };

  const allowLenis = () =>
    hasLenis &&
    !prefersReduced() &&
    finePointerMq.matches &&
    desktopMq.matches;

  const initLenis = () => {
    destroyLenis();
    // Native touch scroll on phones/tablets; Lenis only on desktop fine-pointer.
    if (!allowLenis()) return;

    lenis = new window.Lenis({
      autoRaf: false,
      lerp: 0.12,
      smoothWheel: true,
      syncTouch: false,
      anchors: {
        offset: -headerOffset(),
      },
      stopInertiaOnNavigate: true,
      respectReducedMotion: true,
    });

    lenis.on("scroll", ScrollTrigger.update);
    tickerFn = (time) => {
      lenis.raf(time * 1000);
    };
    gsap.ticker.add(tickerFn);
    gsap.ticker.lagSmoothing(0);
    root.classList.add("lenis-active");
  };

  const killMotion = () => {
    if (ctx) {
      ctx.revert();
      ctx = null;
    }
    while (ownedTriggers.length) {
      const st = ownedTriggers.pop();
      try {
        st.kill();
      } catch (_) {
        /* already killed via context */
      }
    }
    destroyLenis();
  };

  const setupReveals = () => {
    /* Specialized owners first — mutually exclusive with singles. */
    gsap.utils.toArray("[data-reveal-media]").forEach((el) => {
      if (isRevealed(el)) {
        ensureVisible(el);
        return;
      }
      gsap.set(el, { autoAlpha: 0, y: 20, scale: 1.02 });
      trackTrigger(
        gsap.to(el, {
          autoAlpha: 1,
          y: 0,
          scale: 1,
          duration: 0.8,
          ease: "power2.out",
          overwrite: "auto",
          scrollTrigger: {
            trigger: el,
            start: "top 90%",
            once: true,
          },
          onComplete: () => markRevealed(el),
        })
      );
    });

    gsap.utils.toArray("[data-reveal-group]").forEach((group) => {
      const items = gsap.utils.toArray(
        group.querySelectorAll(":scope > *, [data-reveal]")
      );
      if (!items.length) return;

      if (items.every(isRevealed) || isRevealed(group)) {
        ensureVisible(items);
        markRevealed(group);
        return;
      }

      const pending = items.filter((el) => !isRevealed(el));
      const done = items.filter(isRevealed);
      ensureVisible(done);
      if (!pending.length) {
        markRevealed(group);
        return;
      }

      gsap.set(pending, { autoAlpha: 0, y: 16 });
      trackTrigger(
        gsap.to(pending, {
          autoAlpha: 1,
          y: 0,
          duration: 0.55,
          ease: "power2.out",
          stagger: desktopMq.matches ? 0.08 : 0.04,
          overwrite: "auto",
          scrollTrigger: {
            trigger: group,
            start: "top 86%",
            once: true,
          },
          onComplete: () => {
            pending.forEach(markRevealed);
            markRevealed(group);
          },
        })
      );
    });

    /* Singles: exclude specialized media/group ownership. */
    const singles = gsap.utils
      .toArray("[data-reveal], .reveal")
      .filter(
        (el) =>
          !el.hasAttribute("data-reveal-media") &&
          !el.hasAttribute("data-reveal-group") &&
          !el.closest("[data-reveal-group]")
      );

    singles.forEach((el) => {
      if (isRevealed(el)) {
        ensureVisible(el);
        return;
      }
      gsap.set(el, { autoAlpha: 0, y: 18 });
      trackTrigger(
        gsap.to(el, {
          autoAlpha: 1,
          y: 0,
          duration: 0.65,
          ease: "power2.out",
          overwrite: "auto",
          scrollTrigger: {
            trigger: el,
            start: "top 88%",
            once: true,
          },
          onComplete: () => markRevealed(el),
        })
      );
    });
  };

  const setupHomeHero = () => {
    const act1 = document.querySelector("[data-home-act1]");
    if (!act1) return;
    const lines = act1.querySelectorAll(".home-act1__line");
    if (!lines.length) return;

    if (homeHeroPlayed) return;
    homeHeroPlayed = true;

    gsap.from(lines[0], {
      autoAlpha: 0,
      y: 14,
      duration: 0.7,
      ease: "power2.out",
      delay: 0.05,
    });
  };

  const setupPageHero = () => {
    const heroes = document.querySelectorAll(".page-hero");
    if (!heroes.length) return;

    if (pageHeroPlayed) {
      heroes.forEach((hero) => {
        const inner = hero.querySelector(".page-hero__inner");
        if (!inner) return;
        const parts = gsap.utils.toArray(
          inner.querySelectorAll(
            ".logo-autoscuola, .logo-nautica, h1, p, .page-hero__actions, .btn, .link-arrow"
          )
        );
        ensureVisible(parts);
      });
      return;
    }
    pageHeroPlayed = true;

    heroes.forEach((hero) => {
      const inner = hero.querySelector(".page-hero__inner");
      if (!inner) return;
      const parts = gsap.utils.toArray(
        inner.querySelectorAll(
          ".logo-autoscuola, .logo-nautica, h1, p, .page-hero__actions, .btn, .link-arrow"
        )
      );
      if (!parts.length) return;
      gsap.set(parts, { autoAlpha: 0, y: 14 });
      gsap.to(parts, {
        autoAlpha: 1,
        y: 0,
        duration: 0.6,
        ease: "power2.out",
        stagger: 0.07,
        delay: 0.08,
        onComplete: () => ensureVisible(parts),
      });
    });
  };

  const setupParallax = () => {
    if (!desktopMq.matches) return;
    gsap.utils.toArray("[data-parallax]").forEach((node) => {
      const media = node.querySelector("img, video");
      if (!media) return;
      trackTrigger(
        gsap.fromTo(
          media,
          { yPercent: -3 },
          {
            yPercent: 3,
            ease: "none",
            scrollTrigger: {
              trigger: node,
              start: "top bottom",
              end: "bottom top",
              scrub: 0.45,
            },
          }
        )
      );
    });
  };

  const refreshAfterMedia = () => {
    const medias = document.querySelectorAll(
      "img[data-hero-asset], .home-world__media img, .page-hero__media img, [data-parallax] img"
    );
    let pending = 0;
    const done = () => {
      pending -= 1;
      if (pending <= 0) ScrollTrigger.refresh();
    };
    medias.forEach((img) => {
      if (img.complete) return;
      pending += 1;
      img.addEventListener("load", done, { once: true });
      img.addEventListener("error", done, { once: true });
    });
    if (pending === 0) {
      requestAnimationFrame(() => ScrollTrigger.refresh());
    }
    if (!mediaRefreshBound) {
      mediaRefreshBound = true;
      window.addEventListener("load", () => ScrollTrigger.refresh(), {
        once: true,
      });
    }
  };

  const build = () => {
    killMotion();

    if (prefersReduced()) {
      root.classList.add("motion-reduced");
      root.classList.remove("motion-ready");
      showStatic();
      return;
    }

    root.classList.remove("motion-reduced");
    root.classList.add("motion-ready");

    initLenis();

    ctx = gsap.context(() => {
      setupHomeHero();
      setupPageHero();
      setupReveals();
      setupParallax();
    });

    refreshAfterMedia();
  };

  build();

  const onChange = () => {
    build();
  };

  if (typeof reducedMq.addEventListener === "function") {
    reducedMq.addEventListener("change", onChange);
    finePointerMq.addEventListener("change", onChange);
    desktopMq.addEventListener("change", onChange);
  } else {
    reducedMq.addListener(onChange);
    finePointerMq.addListener(onChange);
    desktopMq.addListener(onChange);
  }

  window.addEventListener(
    "resize",
    () => {
      if (lenis && typeof lenis.resize === "function") lenis.resize();
      ScrollTrigger.refresh();
    },
    { passive: true }
  );

  window.__lianaMotion = {
    get lenis() {
      return lenis;
    },
    get triggerCount() {
      return ownedTriggers.length;
    },
    refresh: () => ScrollTrigger.refresh(),
  };
})();
