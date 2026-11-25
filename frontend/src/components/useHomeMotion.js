import { useEffect } from "react";

export default function useHomeMotion(rootRef) {
  useEffect(() => {
    let context;
    let cancelled = false;

    async function setupMotion() {
      const [{ default: gsap }, { ScrollTrigger }] = await Promise.all([
        import("gsap"),
        import("gsap/ScrollTrigger"),
      ]);

      if (cancelled || !rootRef.current) return;

      gsap.registerPlugin(ScrollTrigger);

      context = gsap.context(() => {
        const media = gsap.matchMedia();

        media.add("(prefers-reduced-motion: no-preference)", () => {
          // 1. Hero Intro Sequence
          const intro = gsap.timeline({ defaults: { ease: "power3.out" } });

          intro
            .from(".cinematic-kicker", { y: 16, opacity: 0, duration: 0.6 })
            .from(
              ".title-row",
              { y: 24, opacity: 0, duration: 0.75, stagger: 0.14 },
              "-=0.2"
            )
            .from(
              ".cinematic-lead",
              { y: 18, opacity: 0, duration: 0.55 },
              "-=0.3"
            )
            .from(
              ".cinematic-actions",
              { y: 18, opacity: 0, duration: 0.55 },
              "-=0.3"
            )
            .from(
              ".hero-feature-pill",
              { y: 20, opacity: 0, duration: 0.55, stagger: 0.1 },
              "-=0.3"
            );

          // 2. Destinations Timeline & 3D Showcase Scroll Reveal
          const placesTl = gsap.timeline({
            scrollTrigger: {
              trigger: ".destination-showcase",
              start: "top 80%",
              once: true,
            },
          });

          placesTl
            .from(".showcase-topic", {
              y: -30,
              opacity: 0,
              duration: 0.7,
              ease: "power2.out",
            })
            .from(
              ".timeline-rail",
              {
                scale: 0.94,
                opacity: 0,
                duration: 0.6,
                ease: "power2.out",
              },
              "-=0.4"
            )
            .from(
              ".showcase-stage",
              {
                scale: 0.9,
                y: 45,
                opacity: 0,
                duration: 0.75,
                ease: "power3.out",
              },
              "-=0.4"
            )
            .from(
              ".showcase-dots",
              {
                y: 15,
                opacity: 0,
                duration: 0.5,
                ease: "power2.out",
              },
              "-=0.3"
            );

          // 3. Journey Builder Animated SVG Circuit & Metric HUD
          const routePath = rootRef.current?.querySelector(".journey-path");
          if (routePath) {
            const pathLength = routePath.getTotalLength();
            gsap.set(routePath, {
              strokeDasharray: pathLength,
              strokeDashoffset: pathLength,
            });

            gsap.to(routePath, {
              strokeDashoffset: 0,
              duration: 1.6,
              ease: "power2.out",
              scrollTrigger: {
                trigger: ".journey-builder",
                start: "top 75%",
                once: true,
              },
            });
          }

          gsap.from(".journey-builder-visual", {
            y: 35,
            opacity: 0,
            duration: 0.8,
            ease: "power2.out",
            scrollTrigger: {
              trigger: ".journey-builder",
              start: "top 80%",
              once: true,
            },
          });

          const stages = gsap.utils.toArray(".journey-stage");
          if (stages.length) {
            gsap.from(stages, {
              y: 28,
              opacity: 0,
              duration: 0.65,
              stagger: 0.12,
              ease: "power2.out",
              scrollTrigger: {
                trigger: ".journey-stages",
                start: "top 82%",
                once: true,
              },
            });
          }

          // 4. Discover Sri Lanka 3D Cards
          gsap.utils.toArray(".discover-card").forEach((card, idx) => {
            gsap.from(card, {
              y: 45,
              opacity: 0,
              duration: 0.75,
              delay: idx * 0.1,
              ease: "power3.out",
              scrollTrigger: {
                trigger: ".discover-grid",
                start: "top 82%",
                once: true,
              },
            });
          });

          // 5. CTA Section Reveal
          gsap.from(".cinematic-cta", {
            y: 35,
            opacity: 0,
            duration: 0.8,
            ease: "power2.out",
            scrollTrigger: {
              trigger: ".cinematic-cta",
              start: "top 85%",
              once: true,
            },
          });
        });
      }, rootRef);
    }

    setupMotion();

    return () => {
      cancelled = true;
      if (context) {
        context.revert();
      }
    };
  }, [rootRef]);
}
