import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import TravelerShell from "../components/TravelerShell";
import { Badge, EmptyState, ErrorState, Loader } from "../components/Ui";
import { apiFetch, getCurrentUser } from "../services/api";

export default function TravelerDashboard() {
  const navigate = useNavigate();
  const [user, setUser] = useState(null);
  const [trips, setTrips] = useState([]);
  const [places, setPlaces] = useState([]);
  const [bookings, setBookings] = useState([]);
  const [updates, setUpdates] = useState({ unread_count: 0 });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  async function loadData() {
    setLoading(true);
    setError("");

    try {
      const [me, tripData, placeData, bookingData, updateData] =
        await Promise.all([
          getCurrentUser(),
          apiFetch("/traveler/trips"),
          apiFetch("/traveler/destinations"),
          apiFetch("/traveler/bookings").catch(() => ({ bookings: [] })),
          apiFetch("/traveler/notifications").catch(() => ({ unread_count: 0 })),
        ]);

      if (me?.user?.role !== "traveler") {
        throw new Error("Traveler access required.");
      }

      setUser(me.user);
      setTrips(Array.isArray(tripData) ? tripData : []);
      setPlaces(Array.isArray(placeData) ? placeData : []);
      setBookings(bookingData?.bookings || []);
      setUpdates(updateData || { unread_count: 0 });
    } catch (err) {
      setError(err.message);
      if (err.message.includes("session expired")) navigate("/login");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadData();
  }, []);

  const currentTrip = useMemo(() => trips[0], [trips]);

  return (
    <TravelerShell
      eyebrow="MY DASHBOARD"
      title={`Hi${user?.full_name ? `, ${user.full_name.split(" ")[0]}` : ""} 👋`}
      subtitle="Continue your trips or start planning something new."
      actions={
        <button className="btn btn-primary" onClick={() => navigate("/traveler/create-trip")}>
          + New Trip
        </button>
      }
    >
      {loading && <Loader />}
      {!loading && error && <ErrorState message={error} onRetry={loadData} />}

      {!loading && !error && (
        <>
          <section className="stats-grid">
            <article className="stat-card stat-primary">
              <span className="stat-icon">✈</span>
              <div><small>Trips</small><strong>{trips.length}</strong><p>Saved plans</p></div>
            </article>
            <article className="stat-card">
              <span className="stat-icon">▣</span>
              <div><small>Bookings</small><strong>{bookings.length}</strong><p>Trip bookings</p></div>
            </article>
            <article className="stat-card">
              <span className="stat-icon">◉</span>
              <div><small>Updates</small><strong>{updates.unread_count || 0}</strong><p>Unread messages</p></div>
            </article>
            <article className="stat-card">
              <span className="stat-icon">⌖</span>
              <div><small>Places</small><strong>{places.length}</strong><p>Available places</p></div>
            </article>
          </section>

          {currentTrip && (
            <section className="trip-banner">
              <div className="trip-banner-photo">
                <img src="/images/ella.jpg" alt="Trip" />
              </div>
              <div className="trip-banner-info">
                <div className="eyebrow light">CONTINUE YOUR TRIP</div>
                <Badge>{currentTrip.status || "planning"}</Badge>
                <h2>{currentTrip.trip_name}</h2>
                <p>{currentTrip.start_location} · {currentTrip.start_date} → {currentTrip.end_date}</p>
                <div className="spotlight-actions">
                  <button className="btn btn-white" onClick={() => navigate(`/traveler/trips/${currentTrip.id}`)}>
                    Open Trip →
                  </button>
                  <button className="btn btn-transparent" onClick={() => navigate(`/traveler/trips/${currentTrip.id}/cart`)}>
                    Trip Cart
                  </button>
                </div>
              </div>
            </section>
          )}

          <section className="content-card">
            <div className="card-heading">
              <div><div className="eyebrow">MY TRIPS</div><h2>Recent trips</h2></div>
              <button className="text-button" onClick={() => navigate("/traveler/create-trip")}>Create New +</button>
            </div>

            {trips.length === 0 ? (
              <EmptyState
                icon="✈"
                title="No trips yet"
                text="Create your first trip and start adding places."
                action={<button className="btn btn-primary" onClick={() => navigate("/traveler/create-trip")}>Create Trip</button>}
              />
            ) : (
              <div className="trip-list">
                {trips.map((trip) => (
                  <button className="trip-row" key={trip.id} onClick={() => navigate(`/traveler/trips/${trip.id}`)}>
                    <div className="trip-date-box">
                      <small>{(trip.start_date || "").slice(5, 7)}</small>
                      <strong>{(trip.start_date || "").slice(8, 10)}</strong>
                    </div>
                    <div className="trip-main">
                      <div><h3>{trip.trip_name}</h3><p>{trip.start_location} · {trip.start_date} → {trip.end_date}</p></div>
                      <Badge tone={trip.status === "driver_selected" ? "blue" : "green"}>{trip.status || "planning"}</Badge>
                    </div>
                    <span className="trip-arrow">→</span>
                  </button>
                ))}
              </div>
            )}
          </section>

          <section className="dashboard-gallery">
            <article className="gallery-card big">
              <img src="/images/sigiriya.jpg" alt="Sigiriya" />
              <div><span>Explore</span><h3>Find your next stop</h3><p>Add Sri Lanka's best places to your plan.</p></div>
            </article>
            <article className="gallery-card">
              <img src="/images/mirissa.jpg" alt="Beach" />
              <div><span>Relax</span><h3>Beach trips</h3></div>
            </article>
            <article className="gallery-card">
              <img src="/images/ella.jpg" alt="Ella" />
              <div><span>Adventure</span><h3>Hill country</h3></div>
            </article>
          </section>
        </>
      )}
    </TravelerShell>
  );
}
