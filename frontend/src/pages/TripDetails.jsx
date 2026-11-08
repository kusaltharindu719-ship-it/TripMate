import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import TravelerShell from "../components/TravelerShell";
import { Badge, ErrorState, Loader } from "../components/Ui";
import { apiFetch } from "../services/api";

const tools = [
  ["♥", "Preferences", "Set your travel style.", "preferences", "pink"],
  ["⌖", "Destinations", "Build your route.", "destinations", "green"],
  ["⌂", "Accommodation", "Find rooms and stays.", "accommodations", "blue"],
  ["☕", "Restaurants", "Food and reservations.", "restaurants", "orange"],
  ["↗", "Transport", "Request drivers.", "transport", "purple"],
  ["▣", "Trip Cart", "Check selected services.", "cart", "dark"],
];

export default function TripDetails() {
  const { tripId } = useParams();
  const navigate = useNavigate();
  const [trip, setTrip] = useState(null);
  const [stops, setStops] = useState([]);
  const [cart, setCart] = useState({ item_count: 0 });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  async function loadTrip() {
    setLoading(true);
    setError("");

    try {
      const [tripData, stopData, cartData] = await Promise.all([
        apiFetch(`/traveler/trips/${tripId}`),
        apiFetch(`/traveler/trips/${tripId}/destinations`).catch(() => []),
        apiFetch(`/traveler/trips/${tripId}/cart`).catch(() => ({ item_count: 0 })),
      ]);

      setTrip(tripData);
      setStops(Array.isArray(stopData) ? stopData : []);
      setCart(cartData || { item_count: 0 });
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadTrip();
  }, [tripId]);

  return (
    <TravelerShell
      eyebrow="TRIP"
      title={trip?.trip_name || "Trip details"}
      subtitle={trip ? `${trip.start_location} · ${trip.start_date} → ${trip.end_date}` : ""}
      actions={<button className="btn btn-light" onClick={() => navigate("/traveler")}>← Dashboard</button>}
    >
      {loading && <Loader text="Opening your trip..." />}
      {!loading && error && <ErrorState message={error} onRetry={loadTrip} />}

      {!loading && trip && !error && (
        <>
          <section className="trip-cover">
            <img src="/images/ella.jpg" alt="Trip cover" />
            <div className="trip-cover-shade" />
            <div className="trip-cover-info">
              <div className="trip-cover-top"><Badge>{trip.status || "planning"}</Badge><span>Trip #{trip.id}</span></div>
              <h2>{trip.trip_name}</h2>
              <p>{trip.start_location}</p>
            </div>

            <div className="trip-cover-stats">
              <div><small>Travel Dates</small><strong>{trip.start_date}<br />{trip.end_date}</strong></div>
              <div><small>Travelers</small><strong>{trip.adult_count || 0} Adults<br />{trip.child_count || 0} Children</strong></div>
              <div><small>Budget</small><strong>{trip.currency || "LKR"}<br />{Number(trip.budget || 0).toLocaleString()}</strong></div>
              <div><small>Stops</small><strong>{stops.length}<br />Destinations</strong></div>
              <div><small>Cart</small><strong>{cart.item_count || 0}<br />Items</strong></div>
            </div>
          </section>

          <section className="content-card">
            <div className="card-heading">
              <div><div className="eyebrow">PLAN THE TRIP</div><h2>What do you want to add?</h2></div>
            </div>

            <div className="module-grid">
              {tools.map(([icon, title, text, slug, color]) => (
                <button key={slug} className={`module-card module-${color}`} onClick={() => navigate(`/traveler/trips/${tripId}/${slug}`)}>
                  <span className="module-icon">{icon}</span>
                  <div><h3>{title}</h3><p>{text}</p></div>
                  <b>→</b>
                </button>
              ))}
            </div>
          </section>

          {stops.length > 0 && (
            <section className="content-card">
              <div className="card-heading">
                <div><div className="eyebrow">ROUTE</div><h2>Your planned stops</h2></div>
                <button className="text-button" onClick={() => navigate(`/traveler/trips/${tripId}/destinations`)}>Edit</button>
              </div>

              <div className="route-timeline">
                {stops.map((item, index) => (
                  <div className="timeline-item" key={item.id}>
                    <span>{index + 1}</span>
                    <div>
                      <h3>{item.destinations?.name || "Destination"}</h3>
                      <p>{[item.destinations?.district, item.destinations?.province].filter(Boolean).join(", ")}</p>
                    </div>
                    <small>{item.planned_arrival_date || "Date not set"}</small>
                  </div>
                ))}
              </div>
            </section>
          )}
        </>
      )}
    </TravelerShell>
  );
}
