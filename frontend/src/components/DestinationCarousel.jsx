import { useState, useRef, useEffect, useCallback } from "react";
import { Link } from "react-router-dom";

const destinations = [
  {
    id: "sigiriya",
    step: "01",
    name: "Sigiriya",
    rank: "#1 World Heritage",
    category: "Ancient Rock Fortress",
    tagline: "The Sky Citadel of King Kashyapa",
    rating: 4.9,
    reviews: "12.4K reviews",
    location: "Central Province",
    coordinates: "7.9570° N • 80.7603° E",
    accentColor: "#34d399",
    landmarkImg: "/images/destinations/sigiriya-cutout.png",
    landmarkPng: "/images/destinations/sigiriya-cutout.png",
    fallbackImg: "/images/sigiriya.jpg",
  },
  {
    id: "ella",
    step: "02",
    name: "Ella",
    rank: "#2 Highland Wonder",
    category: "Misty Peaks & Train Viaduct",
    tagline: "Nine Arches & Cloud Forests",
    rating: 4.8,
    reviews: "10.8K reviews",
    location: "Uva Province",
    coordinates: "6.8667° N • 81.0466° E",
    accentColor: "#38bdf8",
    landmarkImg: "/images/destinations/ella-cutout.png",
    landmarkPng: "/images/destinations/ella-cutout.png",
    fallbackImg: "/images/ella.jpg",
  },
  {
    id: "galle",
    step: "03",
    name: "Galle Fort",
    rank: "#3 UNESCO Rampart",
    category: "Colonial Ocean Bastion",
    tagline: "Historic Beacon & Cobalt Waves",
    rating: 4.7,
    reviews: "9.6K reviews",
    location: "Southern Province",
    coordinates: "6.0270° N • 80.2170° E",
    accentColor: "#f59e0b",
    landmarkImg: "/images/destinations/galle-fort-cutout.png",
    landmarkPng: "/images/destinations/galle-fort-cutout.png",
    fallbackImg: "/images/mirissa.jpg",
  },
  {
    id: "kandy",
    step: "04",
    name: "Kandy",
    rank: "#4 Royal Sanctuary",
    category: "Sacred Tooth Relic & Royal Lake",
    tagline: "Hill Country Spiritual Capital",
    rating: 4.6,
    reviews: "8.9K reviews",
    location: "Central Province",
    coordinates: "7.2906° N • 80.6337° E",
    accentColor: "#a78bfa",
    landmarkImg: "/images/destinations/kandy-cutout.png",
    landmarkPng: "/images/destinations/kandy-cutout.png",
    fallbackImg: "/images/sigiriya.jpg",
  },
  {
    id: "mirissa",
    step: "05",
    name: "Mirissa",
    rank: "#5 Tropical Paradise",
    category: "Golden Bays & Whale Watching",
    tagline: "Coconut Hill & Sunset Surfing",
    rating: 4.6,
    reviews: "8.2K reviews",
    location: "Southern Province",
    coordinates: "5.9482° N • 80.4716° E",
    accentColor: "#06b6d4",
    landmarkImg: "/images/destinations/mirissa-cutout.png",
    landmarkPng: "/images/destinations/mirissa-cutout.png",
    fallbackImg: "/images/mirissa.jpg",
  },
];

export default function DestinationCarousel() {
  const [activeIndex, setActiveIndex] = useState(0);
  const stageRef = useRef(null);
  const touchStartX = useRef(0);
  const touchEndX = useRef(0);

  const total = destinations.length;

  const handlePrev = useCallback(() => {
    setActiveIndex((prev) => (prev - 1 + total) % total);
  }, [total]);

  const handleNext = useCallback(() => {
    setActiveIndex((prev) => (prev + 1) % total);
  }, [total]);

  // Touch Swipe handlers for mobile
  function handleTouchStart(e) {
    if (!e.touches || e.touches.length === 0) return;
    touchStartX.current = e.touches[0].clientX;
    touchEndX.current = e.touches[0].clientX;
  }

  function handleTouchMove(e) {
    if (!e.touches || e.touches.length === 0) return;
    touchEndX.current = e.touches[0].clientX;
  }

  function handleTouchEnd() {
    const diff = touchStartX.current - touchEndX.current;
    if (Math.abs(diff) > 40) {
      if (diff > 0) handleNext();
      else handlePrev();
    }
  }

  // Keyboard navigation
  useEffect(() => {
    function onKeyDown(e) {
      if (e.key === "ArrowLeft") handlePrev();
      if (e.key === "ArrowRight") handleNext();
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [handlePrev, handleNext]);

  // Circular offset relative to active item (-2, -1, 0, 1, 2)
  function getOffset(index) {
    let diff = index - activeIndex;
    if (diff > total / 2) diff -= total;
    if (diff < -total / 2) diff += total;
    return diff;
  }

  return (
    <section
      className="destination-showcase"
      id="destinations"
      aria-label="Connected Island Destinations Timeline"
    >
      <span id="places" style={{ position: "absolute", top: "-90px" }} aria-hidden="true" />

      {/* 1. TOPIC HEADER */}
      <div className="showcase-topic">
        <div className="showcase-badge" aria-hidden="true">
          <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="12" cy="12" r="10" />
            <polygon points="16.24 7.76 14.12 14.12 7.76 16.24 9.88 9.88 16.24 7.76" fill="currentColor" fillOpacity="0.4" />
          </svg>
        </div>

        <div className="showcase-kicker">
          <span className="kicker-line" aria-hidden="true" />
          <span>CONNECTED ISLAND TIMELINE</span>
          <span className="kicker-line" aria-hidden="true" />
        </div>

        <h2 className="showcase-title">Explore Sri Lanka’s Iconic Destinations</h2>
        <p className="showcase-subtitle">
          Ranked by travelers. Connected into one seamless, effortless island circuit.
        </p>
      </div>

      {/* 2. FUTURISTIC INTERACTIVE CIRCUIT TIMELINE RAIL */}
      <nav className="timeline-rail" role="tablist" aria-label="Destinations timeline navigation">
        <div className="timeline-rail-line" aria-hidden="true">
          <div
            className="timeline-rail-progress"
            style={{ width: `${(activeIndex / (total - 1)) * 100}%` }}
          />
        </div>

        {destinations.map((dest, i) => {
          const isActive = i === activeIndex;
          return (
            <button
              key={dest.id}
              type="button"
              className={`timeline-node ${isActive ? "node-active" : ""}`}
              onClick={() => setActiveIndex(i)}
              role="tab"
              aria-selected={isActive}
              aria-label={`Jump to waypoint ${dest.step}: ${dest.name}`}
            >
              <div className="node-marker">
                <span className="node-step">{dest.step}</span>
                <span className="node-core" />
                {isActive && <span className="node-pulse" aria-hidden="true" />}
              </div>
              <span className="node-name">{dest.name}</span>
            </button>
          );
        })}
      </nav>

      {/* 3. 3D CAROUSEL STAGE & TIMELINE SHOWCASE */}
      <div
        className="showcase-stage"
        ref={stageRef}
        onTouchStart={handleTouchStart}
        onTouchMove={handleTouchMove}
        onTouchEnd={handleTouchEnd}
      >
        {/* Navigation Arrows with Cyberpunk Glass Orb styling */}
        <button
          type="button"
          className="stage-arrow arrow-left"
          onClick={handlePrev}
          aria-label="Previous destination"
        >
          <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <polyline points="15 18 9 12 15 6" />
          </svg>
        </button>

        <div className="stage-track">
          {destinations.map((dest, i) => {
            const offset = getOffset(i);
            const isActive = offset === 0;

            let posClass = "pos-hidden";
            if (isActive) posClass = "pos-center";
            else if (offset === -1) posClass = "pos-left-near";
            else if (offset === 1) posClass = "pos-right-near";
            else if (offset === -2) posClass = "pos-left-far";
            else if (offset === 2) posClass = "pos-right-far";

            return (
              <article
                key={dest.id}
                className={`showcase-card ${posClass} ${isActive ? "card-active" : ""}`}
                onClick={() => setActiveIndex(i)}
                role="button"
                tabIndex={isActive ? 0 : -1}
                aria-current={isActive ? "true" : undefined}
                aria-label={`${dest.name}, ${dest.rank}`}
              >
                {/* Active Item: Golden Laurel Badge */}
                {isActive && (
                  <div className="laurel-badge" aria-label={dest.rank}>
                    <svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor" aria-hidden="true">
                      <path d="M12 2l2.4 4.9 5.4.8-3.9 3.8.9 5.4-4.8-2.5-4.8 2.5.9-5.4-3.9-3.8 5.4-.8z" />
                    </svg>
                    <span>{dest.rank}</span>
                  </div>
                )}

                {/* Landmark Cutout with Levitating Hover Animation */}
                <div className={`landmark-wrap ${isActive ? "landmark-active-aura" : ""}`}>
                  <picture>
                    <source srcSet={dest.landmarkPng} type="image/png" />
                    <img
                      src={dest.landmarkImg}
                      alt={`${dest.name} landmark cutout`}
                      className="landmark-img"
                      loading="lazy"
                      onError={(e) => {
                        e.currentTarget.onerror = null;
                        e.currentTarget.src = dest.fallbackImg;
                      }}
                    />
                  </picture>
                </div>

                {/* Center Item: Futuristic Glass Capsule Info Panel */}
                {isActive ? (
                  <div className="active-glass-panel">
                    <div className="panel-telemetry">
                      <span className="telemetry-dot" />
                      <span className="telemetry-coords">{dest.coordinates}</span>
                    </div>

                    <div className="panel-heading">
                      <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                        <line x1="3" y1="21" x2="21" y2="21" />
                        <line x1="3" y1="10" x2="21" y2="10" />
                        <polyline points="5 6 12 3 19 6" />
                        <line x1="6" y1="10" x2="6" y2="21" />
                        <line x1="10" y1="10" x2="10" y2="21" />
                        <line x1="14" y1="10" x2="14" y2="21" />
                        <line x1="18" y1="10" x2="18" y2="21" />
                      </svg>
                      <h3>{dest.name}</h3>
                    </div>

                    <span className="panel-category">{dest.category}</span>
                    <span className="panel-tagline">“{dest.tagline}”</span>

                    <div className="panel-meta-row">
                      <div className="panel-rating">
                        <div className="stars" aria-label={`${dest.rating} stars`}>
                          {"★★★★★"}
                        </div>
                        <strong className="rating-num">{dest.rating}</strong>
                        <span className="rating-count">({dest.reviews})</span>
                      </div>

                      <div className="panel-location">
                        <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                          <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z" />
                          <circle cx="12" cy="10" r="3" />
                        </svg>
                        <span>{dest.location}</span>
                      </div>
                    </div>

                    <Link to="/register" className="panel-action-btn">
                      <span>Add to Itinerary</span>
                      <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                        <line x1="12" y1="5" x2="12" y2="19" />
                        <line x1="5" y1="12" x2="19" y2="12" />
                      </svg>
                    </Link>
                  </div>
                ) : (
                  /* Side Item: Compact Futuristic Glass Chip */
                  <div className="side-glass-chip">
                    <span className="side-chip-step">{dest.step}</span>
                    <h4>{dest.name}</h4>
                    <span className="side-rating">★ {dest.rating}</span>
                  </div>
                )}
              </article>
            );
          })}
        </div>

        <button
          type="button"
          className="stage-arrow arrow-right"
          onClick={handleNext}
          aria-label="Next destination"
        >
          <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <polyline points="9 18 15 12 9 6" />
          </svg>
        </button>
      </div>

      {/* 4. SEGMENTED CYBERNETIC PROGRESS INDICATOR */}
      <div className="showcase-dots" role="tablist" aria-label="Destination slides">
        {destinations.map((dest, i) => (
          <button
            key={dest.id}
            type="button"
            className={`showcase-dot ${i === activeIndex ? "dot-active" : ""}`}
            onClick={() => setActiveIndex(i)}
            aria-label={`Go to ${dest.name}`}
            role="tab"
            aria-selected={i === activeIndex}
          >
            <span className="dot-inner" />
          </button>
        ))}
      </div>
    </section>
  );
}
