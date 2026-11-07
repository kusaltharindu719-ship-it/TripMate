import { Link } from "react-router-dom";
import Navbar from "../components/Navbar";

export default function Home() {
  return (
    <div className="landing-page">

      <Navbar />

      <div className="glow glow-one"></div>
      <div className="glow glow-two"></div>

      <main className="home-page">

        {/* ================= HERO ================= */}

        <section className="hero">

          <div className="hero-content">

            <div className="hero-badge">
              <span className="badge-dot"></span>
              Smart Travel Planning for Sri Lanka
            </div>

            <h1>
              Your entire journey.
              <span>One intelligent platform.</span>
            </h1>

            <p className="hero-text">
              Plan destinations, find accommodation, discover restaurants,
              explore activities and arrange transport — all through TripMate.
            </p>

            <div className="hero-actions">

              <Link to="/register" className="primary-btn">
                Start Your Journey
                <span>→</span>
              </Link>

              <Link to="/login" className="secondary-btn">
                Sign In
              </Link>

            </div>

            <div className="hero-mini-features">

              <div>
                <span className="mini-icon">✦</span>
                AI Assisted Planning
              </div>

              <div>
                <span className="mini-icon">✦</span>
                Smart Routes
              </div>

              <div>
                <span className="mini-icon">✓</span>
                Trusted Services
              </div>

            </div>

          </div>


          <div className="hero-visual">

            <div className="visual-card">

              <div className="visual-topbar">

                <div className="visual-dots">
                  <span></span>
                  <span></span>
                  <span></span>
                </div>

                <div className="visual-status">
                  <span></span>
                  Live Trip
                </div>

              </div>


              <div className="route-map">

                <div className="map-grid"></div>
                <div className="route-line"></div>

                <div className="route-point point-one">
                  <span></span>
                  Colombo
                </div>

                <div className="route-point point-two">
                  <span></span>
                  Kandy
                </div>

                <div className="route-point point-three">
                  <span></span>
                  Ella
                </div>


                <div className="floating-card hotel-card">

                  <div className="floating-icon">
                    ⌂
                  </div>

                  <div>
                    <small>Accommodation</small>
                    <strong>Mountain View Stay</strong>
                  </div>

                </div>


                <div className="floating-card transport-card">

                  <div className="floating-icon">
                    ↗
                  </div>

                  <div>
                    <small>Transport</small>
                    <strong>Driver Confirmed</strong>
                  </div>

                </div>

              </div>


              <div className="visual-bottom">

                <div>
                  <small>Estimated Journey</small>
                  <strong>3 Destinations</strong>
                </div>

                <div>
                  <small>Trip Status</small>
                  <strong className="status-green">
                    Ready
                  </strong>
                </div>

              </div>

            </div>

          </div>

        </section>


        {/* ================= DISCOVER SECTION ================= */}

        <section className="destination-section">

          <div className="section-heading">

            <p>
              Discover Sri Lanka
            </p>

            <h2>
              Popular destinations
            </h2>

          </div>


          <div className="destination-grid">


            <div className="destination-card">

              <img
                className="destination-image"
                src="/images/ella.jpg"
                alt="Ella"
              />

              <div className="destination-overlay">

                <span>Hill Country</span>

                <h3>
                  Ella
                </h3>

                <p>
                  Mountains, railways and unforgettable views.
                </p>

              </div>

            </div>


            <div className="destination-card">

              <img
                className="destination-image"
                src="/images/sigiriya.jpg"
                alt="Sigiriya"
              />

              <div className="destination-overlay">

                <span>
                  Culture & Heritage
                </span>

                <h3>
                  Sigiriya
                </h3>

                <p>
                  Discover one of Sri Lanka's most iconic landmarks.
                </p>

              </div>

            </div>


            <div className="destination-card">

              <img
                className="destination-image"
                src="/images/mirissa.jpg"
                alt="Mirissa"
              />

              <div className="destination-overlay">

                <span>
                  South Coast
                </span>

                <h3>
                  Mirissa
                </h3>

                <p>
                  Beaches, ocean views and tropical escapes.
                </p>

              </div>

            </div>

          </div>

        </section>


        {/* ================= FEATURES ================= */}

        <section className="feature-strip">

          <div className="feature-card">

            <div className="feature-number">
              01
            </div>

            <h3>
              Plan Smarter
            </h3>

            <p>
              Build complete trips with destinations,
              dates, budgets and preferences.
            </p>

          </div>


          <div className="feature-card">

            <div className="feature-number">
              02
            </div>

            <h3>
              Explore Everything
            </h3>

            <p>
              Discover stays, restaurants,
              attractions and activities.
            </p>

          </div>


          <div className="feature-card">

            <div className="feature-number">
              03
            </div>

            <h3>
              Travel Connected
            </h3>

            <p>
              Request transport,
              compare driver bids and manage your journey.
            </p>

          </div>

        </section>

      </main>

    </div>
  );
}