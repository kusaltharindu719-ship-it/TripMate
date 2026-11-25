import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import TravelerShell, { Badge, EmptyState, Loader } from "../components/TravelerShell";
import { apiFetch } from "../services/api";

export default function TripTransport() {
  const { tripId } = useParams();
  const navigate = useNavigate();
  const [requests, setRequests] = useState([]);
  const [destinations, setDestinations] = useState([]);
  const [luggage, setLuggage] = useState(0);
  const [loading, setLoading] = useState(true);
  const [creating, setCreating] = useState(false);
  const [msg, setMsg] = useState({ type: "", text: "" });

  async function load() {
    setLoading(true);
    try {
      const [reqData, destData] = await Promise.all([
        apiFetch("/traveler/transport-requests").catch(() => []),
        apiFetch(`/traveler/trips/${tripId}/destinations`).catch(() => []),
      ]);
      setRequests(Array.isArray(reqData) ? reqData : []);
      setDestinations(Array.isArray(destData) ? destData : []);
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, [tripId]);

  async function create() {
    if (destinations.length === 0) {
      setMsg({
        type: "error",
        text: "Your trip must have at least one destination before creating a transport request.",
      });
      return;
    }

    setCreating(true);
    setMsg({ type: "", text: "" });
    try {
      await apiFetch(`/traveler/trips/${tripId}/transport-requests`, {
        method: "POST",
        body: JSON.stringify({ luggage_count: Number(luggage) }),
      });
      setMsg({ type: "success", text: "Draft transport request created successfully." });
      const reqData = await apiFetch("/traveler/transport-requests");
      setRequests(Array.isArray(reqData) ? reqData : []);
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setCreating(false);
    }
  }

  const mine = requests.filter((r) => String(r.trip_id) === String(tripId));

  return (
    <TravelerShell
      eyebrow="TRANSPORT"
      title="Driver requests"
      subtitle="Create a draft request for this trip and manage driver bidding from the backend flow."
      actions={
        <button className="btn btn-light" onClick={() => navigate(`/traveler/trips/${tripId}`)}>
          ← Back to trip
        </button>
      }
    >
      {msg.text && <div className={`alert alert-${msg.type}`}>{msg.text}</div>}

      {!loading && destinations.length === 0 && (
        <div className="alert alert-info" style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <span>Tip: Add destinations to your route before requesting transport.</span>
          <button className="btn btn-dark btn-sm" onClick={() => navigate(`/traveler/trips/${tripId}/destinations`)}>
            Add destinations →
          </button>
        </div>
      )}

      <section className="transport-create">
        <div>
          <div className="eyebrow">NEW REQUEST</div>
          <h2>Need a driver?</h2>
          <p>Create the draft now. Route distance and bidding details can be opened once your journey is finalized.</p>
        </div>
        <label>
          Luggage
          <input
            type="number"
            min="0"
            value={luggage}
            onChange={(e) => setLuggage(e.target.value)}
          />
        </label>
        <button className="btn btn-primary" onClick={create} disabled={creating}>
          {creating ? "Creating..." : "Create request"}
        </button>
      </section>

      <section className="content-card">
        <div className="card-heading">
          <div>
            <div className="eyebrow">THIS TRIP</div>
            <h2>Transport requests</h2>
          </div>
        </div>
        {loading ? (
          <Loader />
        ) : mine.length === 0 ? (
          <EmptyState
            title="No transport request yet"
            text="Create one when this trip needs a driver."
          />
        ) : (
          <div className="trip-list">
            {mine.map((r) => (
              <div className="trip-row static" key={r.id}>
                <div className="trip-date-box">
                  <small>ID</small>
                  <strong>{r.id}</strong>
                </div>
                <div className="trip-main">
                  <div>
                    <h3>Transport request #{r.id}</h3>
                    <p>
                      {r.luggage_count || 0} luggage · {r.route_distance_km ? `${r.route_distance_km} km` : "Distance pending"}
                    </p>
                  </div>
                  <Badge tone={r.status === "open" ? "blue" : "green"}>{r.status || "draft"}</Badge>
                </div>
              </div>
            ))}
          </div>
        )}
      </section>
    </TravelerShell>
  );
}
