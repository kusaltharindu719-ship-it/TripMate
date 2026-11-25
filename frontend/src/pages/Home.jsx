import { useEffect, useRef } from "react";
import { Link } from "react-router-dom";
import Navbar from "../components/Navbar";
import DestinationCarousel from "../components/DestinationCarousel";
import useHomeMotion from "../components/useHomeMotion";
import "../styles/home-cinematic.css";

const destinations = [
  {
    name: "Ella",
    label: "Highlands",
    text: "Tea country, mountain trails and one of Sri Lanka's most memorable train journeys.",
    image: "/images/ella.jpg",
  },
  {
    name: "Sigiriya",
    label: "Heritage",
    text: "Ancient architecture, dramatic views and a landmark route through the Cultural Triangle.",
    image: "/images/sigiriya.jpg",
  },
  {
    name: "Mirissa",
    label: "Coast",
    text: "Warm beaches, ocean mornings and a slower final chapter for your island route.",
    image: "/images/mirissa.jpg",
  },
];

const journeyStages = [
  {
    number: "01",
    title: "Shape the trip",
    text: "Choose dates, people and budget. TripMate creates the workspace for everything that follows.",
  },
  {
    number: "02",
    title: "Build the route",
    text: "Add destinations in travel order and keep every stop connected to one plan.",
  },
  {
    number: "03",
    title: "Attach the services",
    text: "Compare stays, restaurants and transport around the route instead of planning in separate places.",
  },
  {
    number: "04",
    title: "Travel with one view",
    text: "Bookings, updates and trip decisions stay together in a single traveler dashboard.",
  },
];

export default function Home() {
  const rootRef = useRef(null);
  const videoRef = useRef(null);
  useHomeMotion(rootRef);

  useEffect(() => {
    // Ensure autoplay triggers reliably on mobile and desktop without user interaction
    if (videoRef.current) {
      videoRef.current.play().catch(() => {
        // Handled silently: poster image fallback displays cleanly
      });
    }
  }, []);

  return (
    <div className="cinematic-home" ref={rootRef}>
      {/* Persistent Full-Page Fixed Live Cinematic Background with Image Fallback */}
      <div className="cinematic-bg-fixed" aria-hidden="true">
        <video
          ref={videoRef}
          className="cinematic-fixed-video"
          autoPlay
          muted
          loop
          playsInline
          webkit-playsinline="true"
          preload="auto"
          poster="/images/sigiriya.jpg"
        >
          <source src="/videos/sigiriya-live.webm" type="video/webm" />
          <source src="/videos/sigiriya-live.mp4" type="video/mp4" />
          <img
            src="/images/sigiriya.jpg"
            alt="Sigiriya landscape background fallback"
            className="cinematic-fixed-fallback"
          />
        </video>
      </div>

      <Navbar />

      <main className="cinematic-main">
        {/* 1. CINEMATIC HERO SECTION */}
        <section className="cinematic-hero">
          <div className="cinematic-copy">
            <div className="cinematic-kicker">
              <span className="kicker-dot" />
              <span>ITINERARY OS FOR SRI LANKA // CONNECTED CIRCUITS</span>
            </div>

            <h1 className="cinematic-title" aria-label="Travel that flows with your world.">
              <span className="title-row">Travel that flows</span>
              <span className="title-row title-serif text-glow-gradient">with your world.</span>
            </h1>

            <p className="cinematic-lead">
              TripMate connects destinations, boutique stays, curated dining and private transport into one seamless, continuous live itinerary across Sri Lanka.
            </p>

            <div className="cinematic-actions">
              <Link className="cinematic-primary" to="/register">
                <span>Start your journey</span>
                <svg className="action-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                  <line x1="5" y1="12" x2="19" y2="12"></line>
                  <polyline points="12 5 19 12 12 19"></polyline>
                </svg>
              </Link>
              <a className="cinematic-secondary" href="#destinations">
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                  <circle cx="12" cy="12" r="10" />
                  <polygon points="12 8 8 12 12 16 12 8" />
                  <line x1="16" y1="12" x2="12" y2="12" />
                </svg>
                <span>Explore Circuit</span>
              </a>
            </div>

            <div className="hero-feature-row" aria-label="Core travel features">
              <div className="hero-feature-pill">
                <span className="feature-icon">
                  <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                    <circle cx="12" cy="12" r="10"></circle>
                    <polygon points="16.24 7.76 14.12 14.12 7.76 16.24 9.88 9.88 16.24 7.76"></polygon>
                  </svg>
                </span>
                <div>
                  <strong>CONNECTED BY DESIGN</strong>
                  <small>Intelligent waypoint routing</small>
                </div>
              </div>

              <div className="hero-feature-pill">
                <span className="feature-icon">
                  <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"></path>
                  </svg>
                </span>
                <div>
                  <strong>REAL-TIME DISCOVERY</strong>
                  <small>Dynamic stays & culinary match</small>
                </div>
              </div>

              <div className="hero-feature-pill">
                <span className="feature-icon">
                  <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                    <rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect>
                    <line x1="9" y1="3" x2="9" y2="21"></line>
                  </svg>
                </span>
                <div>
                  <strong>ONE WORKSPACE</strong>
                  <small>End-to-end trip in one deck</small>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* 2. CONNECTED ISLAND DESTINATIONS SHOWCASE & TIMELINE */}
        <DestinationCarousel />

        {/* 3. JOURNEY BUILDER // HOLOGRAPHIC ROUTE ENGINE */}
        <section className="journey-builder" id="journey-builder">
          <div className="journey-builder-visual">
            <div className="journey-visual-topline">
              <span className="journey-label">
                <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                  <circle cx="12" cy="12" r="10" />
                  <polygon points="16.24 7.76 14.12 14.12 7.76 16.24 9.88 9.88 16.24 7.76" fill="currentColor" fillOpacity="0.3" />
                </svg>
                TRIPMATE JOURNEY ENGINE
              </span>
              <span className="journey-live"><i /> Route Ready</span>
            </div>

            <div className="journey-map-shell">
              <svg viewBox="0 0 600 360" className="journey-map" aria-hidden="true">
                <defs>
                  <linearGradient id="journeyRouteGrad" x1="0%" y1="100%" x2="100%" y2="0%">
                    <stop offset="0%" stopColor="#10b981" />
                    <stop offset="50%" stopColor="#34d399" />
                    <stop offset="100%" stopColor="#06b6d4" />
                  </linearGradient>
                  <filter id="journeyGlow" x="-20%" y="-20%" width="140%" height="140%">
                    <feDropShadow dx="0" dy="0" stdDeviation="6" floodColor="#34d399" floodOpacity="0.55" />
                  </filter>
                </defs>

                <path
                  className="journey-path-shadow"
                  d="M70 270 C150 270 170 190 230 190 C300 190 320 100 390 100 C450 100 480 65 520 65"
                />
                <path
                  className="journey-path"
                  d="M70 270 C150 270 170 190 230 190 C300 190 320 100 390 100 C450 100 480 65 520 65"
                  filter="url(#journeyGlow)"
                />

                <g className="journey-node node-start">
                  <circle cx="70" cy="270" r="15" className="node-glow" />
                  <circle cx="70" cy="270" r="7" className="node-core" />
                  <text x="70" y="304" textAnchor="middle" className="node-text">Start</text>
                </g>
                <g className="journey-node node-stay">
                  <circle cx="230" cy="190" r="15" className="node-glow" />
                  <circle cx="230" cy="190" r="7" className="node-core" />
                  <text x="230" y="224" textAnchor="middle" className="node-text">Stay</text>
                </g>
                <g className="journey-node node-food">
                  <circle cx="390" cy="100" r="15" className="node-glow" />
                  <circle cx="390" cy="100" r="7" className="node-core" />
                  <text x="390" y="134" textAnchor="middle" className="node-text">Food</text>
                </g>
                <g className="journey-node node-ready">
                  <circle cx="520" cy="65" r="18" className="node-glow-accent" />
                  <circle cx="520" cy="65" r="8" className="node-core-accent" />
                  <text x="520" y="40" textAnchor="middle" className="node-text node-text-ready">Ready</text>
                </g>
              </svg>

              <div className="map-metric metric-budget">
                <span className="metric-dot" />
                <div>
                  <small>Budget</small>
                  <strong>Smart Tracked</strong>
                </div>
              </div>
              <div className="map-metric metric-services">
                <span className="metric-dot" />
                <div>
                  <small>Services</small>
                  <strong>Live Connected</strong>
                </div>
              </div>
              <div className="map-metric metric-status">
                <span className="metric-dot" />
                <div>
                  <small>Engine Status</small>
                  <strong>Optimized</strong>
                </div>
              </div>
            </div>
          </div>

          <div className="journey-builder-copy">
            <div className="journey-heading">
              <span className="section-label">ONE CONTINUOUS FLOW</span>
              <h2>A trip that assembles itself as you move forward.</h2>
              <p>Each stage adds another layer to the same travel plan instead of sending you into separate tools and disconnected screens.</p>
            </div>

            <div className="journey-stages">
              {journeyStages.map((stage) => (
                <article className="journey-stage" key={stage.number}>
                  <div className="stage-num-badge">
                    <span>{stage.number}</span>
                  </div>
                  <div className="stage-info">
                    <h3>{stage.title}</h3>
                    <p>{stage.text}</p>
                  </div>
                </article>
              ))}
            </div>
          </div>
        </section>

        {/* 4. DISCOVER SRI LANKA // HOLOGRAPHIC GRID */}
        <section className="cinematic-discover" id="discover">
          <div className="discover-heading">
            <div>
              <span className="section-label">DISCOVER SRI LANKA</span>
              <h2>Different landscapes. One connected plan.</h2>
            </div>
            <p>Start with a place, then let the route grow around the way you want to travel.</p>
          </div>

          <div className="discover-grid">
            {destinations.map((destination, index) => (
              <article className={`discover-card discover-card-${index + 1}`} key={destination.name}>
                <img src={destination.image} alt={destination.name} />
                <div className="discover-shade" />
                <div className="discover-index">// 0{index + 1}</div>
                <div className="discover-content">
                  <span className="discover-pill">{destination.label}</span>
                  <h3>{destination.name}</h3>
                  <p>{destination.text}</p>
                  <Link to="/register" className="discover-link">
                    <span>Add to a trip</span>
                    <b aria-hidden="true">↗</b>
                  </Link>
                </div>
              </article>
            ))}
          </div>
        </section>

        {/* 5. CINEMATIC FINAL CTA */}
        <section className="cinematic-cta">
          <div className="cta-route" aria-hidden="true" />
          <div className="cta-content">
            <span className="section-label section-label-light">YOUR NEXT ROUTE</span>
            <h2>Start with an idea. Leave with a complete travel workspace.</h2>
            <p className="cta-lead">
              Join thousands of travelers exploring Sri Lanka with smart itineraries, verified boutique stays, and authentic local experiences.
            </p>
          </div>
          <Link className="cinematic-primary cinematic-primary-light" to="/register">
            <span>Start planning</span>
            <svg className="action-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
              <line x1="5" y1="12" x2="19" y2="12"></line>
              <polyline points="12 5 19 12 12 19"></polyline>
            </svg>
          </Link>
        </section>
      </main>

      {/* 6. FUTURISTIC TECH FOOTER */}
      <footer className="cinematic-footer">
        <div className="footer-topline">
          <div className="footer-brand">
            <strong>TripMate</strong>
            <span>Smart travel planning & itinerary OS for Sri Lanka.</span>
          </div>
          <div className="footer-status-pill">
            <span className="status-ping" />
            <span>ALL SYSTEMS OPERATIONAL // v2.4</span>
          </div>
        </div>
        <div className="footer-bottomline">
          <small>© {new Date().getFullYear()} TripMate Inc. All rights reserved.</small>
          <div className="footer-links">
            <a href="#destinations">Destinations</a>
            <a href="#journey-builder">Engine</a>
            <a href="#discover">Discover</a>
            <Link to="/login">Sign In</Link>
          </div>
        </div>
      </footer>
    </div>
  );
}
