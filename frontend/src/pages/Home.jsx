import { Link } from "react-router-dom";
import Navbar from "../components/Navbar";

const places = [
  {
    name: "Ella",
    tag: "Mountains",
    text: "Tea estates, hiking, waterfalls and the famous train ride.",
    image: "/images/ella.jpg",
  },
  {
    name: "Sigiriya",
    tag: "History",
    text: "Ancient ruins, beautiful views and one of Sri Lanka's best landmarks.",
    image: "/images/sigiriya.jpg",
  },
  {
    name: "Mirissa",
    tag: "Beach",
    text: "Ocean views, beaches, whale watching and relaxed coastal life.",
    image: "/images/mirissa.jpg",
  },
];

export default function Home() {
  return (
    <div className="landing">
      <Navbar />

      <main>
        <section className="hero-section">
          <div className="hero-copy">
            <div className="pill">✦ Plan your Sri Lanka trip in one place</div>

            <h1>
              Explore more.
              <span>Stress less.</span>
            </h1>

            <p>
              Pick places, find hotels, choose restaurants, request transport
              and keep everything connected to one trip.
            </p>

            <div className="hero-actions">
              <Link className="btn btn-primary btn-lg" to="/register">
                Start a Trip <span>→</span>
              </Link>
              <a className="btn btn-light btn-lg" href="#discover">
                Explore Places
              </a>
            </div>

            <div className="trust-row">
              <span>✓ Easy trip planning</span>
              <span>✓ Sri Lanka focused</span>
              <span>✓ Services in one place</span>
            </div>
          </div>

          <div className="hero-photo-card">
            <img src="/images/travel-journey.svg" alt="Trip route" />
            <div className="hero-glass glass-one">
              <span>⌂</span>
              <div><small>Stay</small><strong>Mountain View Hotel</strong></div>
            </div>
            <div className="hero-glass glass-two">
              <span>↗</span>
              <div><small>Transport</small><strong>Driver request ready</strong></div>
            </div>
            <div className="hero-glass glass-three">
              <span>☕</span>
              <div><small>Food</small><strong>Local restaurants</strong></div>
            </div>
          </div>
        </section>

        <section className="quick-strip">
          <article><span>01</span><div><h3>Create your trip</h3><p>Add dates, budget and people.</p></div></article>
          <article><span>02</span><div><h3>Build the route</h3><p>Add destinations in your order.</p></div></article>
          <article><span>03</span><div><h3>Add services</h3><p>Hotels, food and transport.</p></div></article>
          <article><span>04</span><div><h3>Keep it together</h3><p>Manage everything from one dashboard.</p></div></article>
        </section>

        <section className="discover-section" id="discover">
          <div className="section-intro">
            <div className="eyebrow">POPULAR PLACES</div>
            <h2>Start with a place you want to remember.</h2>
            <p>Some of the best places to add to your next TripMate plan.</p>
          </div>

          <div className="destination-grid">
            {places.map((place) => (
              <article className="destination-tile" key={place.name}>
                <img src={place.image} alt={place.name} />
                <div className="destination-shade" />
                <div className="destination-content">
                  <span>{place.tag}</span>
                  <h3>{place.name}</h3>
                  <p>{place.text}</p>
                  <Link to="/register" className="place-link">Plan a trip →</Link>
                </div>
              </article>
            ))}
          </div>
        </section>

        <section className="photo-story">
          <div className="story-photo story-photo-one">
            <img src="/images/ella.jpg" alt="Ella landscape" />
          </div>
          <div className="story-copy">
            <div className="eyebrow">ONE SIMPLE FLOW</div>
            <h2>From “where should we go?” to a full trip plan.</h2>
            <p>
              TripMate keeps your route, stays, food choices and transport
              connected to the same trip, so planning feels much easier.
            </p>
            <div className="story-points">
              <span>⌖ Destination planning</span>
              <span>⌂ Accommodation</span>
              <span>☕ Restaurants</span>
              <span>↗ Transport</span>
            </div>
          </div>
          <div className="story-photo story-photo-two">
            <img src="/images/mirissa.jpg" alt="Mirissa beach" />
          </div>
        </section>

        <section className="cta-section">
          <div>
            <div className="eyebrow">READY TO START?</div>
            <h2>Make your next Sri Lanka trip easier to plan.</h2>
          </div>
          <Link className="btn btn-white btn-lg" to="/register">
            Create Account →
          </Link>
        </section>
      </main>

      <footer className="footer">
        <strong>TripMate</strong>
        <span>Travel planning for Sri Lanka.</span>
      </footer>
    </div>
  );
}
