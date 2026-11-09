import { useEffect, useState } from "react";
import { apiFetch } from "../services/api";

export default function AccommodationOwnerDashboard() {
  const [properties, setProperties] = useState(null);
  const [error, setError] = useState("");
  const [roomResult, setRoomResult] = useState(null);

  async function loadRoomTypes(propertyId) {
    setRoomResult({ propertyId, loading: true });

    try {
      const data = await apiFetch(
        `/provider/accommodations/${propertyId}/room-types`
      );
      const rooms = Array.isArray(data) ? data : data?.room_types;

      if (!Array.isArray(rooms)) {
        throw new Error("The server returned an unexpected room list.");
      }

      setRoomResult({ propertyId, rooms });
    } catch (error) {
      setRoomResult({
        propertyId,
        error: error.message || "Could not load room types.",
      });
    }
  }
  useEffect(() => {
    let active = true;

    async function loadProperties() {
      try {
        const data = await apiFetch("/provider/accommodations/");
        const list = Array.isArray(data) ? data : data?.accommodations;

        if (!Array.isArray(list)) {
          throw new Error("The server returned an unexpected property list.");
        }

        if (active) setProperties(list);
      } catch (error) {
        if (active) setError(error.message || "Could not load properties.");
      }
    }

    loadProperties();

    return () => {
      active = false;
    };
  }, []);

  return (
    <main style={{ maxWidth: 1000, margin: "40px auto", padding: "0 20px" }}>
      <h1>Accommodation Owner Dashboard</h1>
      <p>View the properties you manage.</p>

      {error && <p role="alert">{error}</p>}
      {!properties && !error && <p>Loading properties…</p>}
      {properties?.length === 0 && <p>You have no properties yet.</p>}

      {properties?.map((property) => (
        <article className="content-card" key={property.id}>
          <h2>{property.name}</h2>
          <p>{property.address || "Address not available."}</p>
          {property.description && <p>{property.description}</p>}
                    <button
            type="button"
            className="btn btn-dark"
            disabled={roomResult?.loading}
            onClick={() => loadRoomTypes(property.id)}
          >
            View room types
          </button>

          {roomResult?.propertyId === property.id && (
            <section aria-live="polite">
              {roomResult.loading && <p>Loading room types…</p>}
              {roomResult.error && <p role="alert">{roomResult.error}</p>}
              {roomResult.rooms?.length === 0 && <p>No room types yet.</p>}
              {roomResult.rooms?.length > 0 && (
                <ul>
                  {roomResult.rooms.map((room) => (
                    <li key={room.id}><strong>{room.name}</strong> <AvailabilityForm propertyId={property.id} roomId={room.id} /></li>
                  ))}
                </ul>
              )}
            </section>
          )}
        </article>
      ))}
    </main>
  );
}function AvailabilityForm({ propertyId, roomId }) {
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  async function saveAvailability(event) {
    event.preventDefault();
    if (saving) return;

    const fields = new FormData(event.currentTarget);
    const price = fields.get("price_override");

    const availability = [{
      room_type_id: roomId,
      date: fields.get("date"),
      available_rooms: Number(fields.get("available_rooms")),
      price_override: price === "" ? null : Number(price),
      minimum_stay_nights: Number(fields.get("minimum_stay_nights")),
      is_closed: fields.has("is_closed"),
    }];

    setSaving(true);
    setMessage("");
    setError("");

    try {
      await apiFetch(`/provider/accommodations/${propertyId}/room-availability`, {
        method: "PUT",
        body: JSON.stringify(availability),
      });
      setMessage("Availability saved.");
    } catch (error) {
      setError(error.message || "Could not save availability.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <form onSubmit={saveAvailability}>
      <p>
        <label>Date <input type="date" name="date" required /></label>
      </p>
      <p>
        <label>
          Available rooms
          <input type="number" name="available_rooms" min="0" step="1" required />
        </label>
      </p>
      <p>
        <label>
          Price override (optional)
          <input type="number" name="price_override" min="0" step="0.01" />
        </label>
      </p>
      <p>
        <label>
          Minimum stay (nights)
          <input
            type="number"
            name="minimum_stay_nights"
            min="1"
            step="1"
            defaultValue="1"
            required
          />
        </label>
      </p>
      <p>
        <label><input type="checkbox" name="is_closed" /> Closed for booking</label>
      </p>
      <button className="btn btn-dark" type="submit" disabled={saving}>
        {saving ? "Saving…" : "Save availability"}
      </button>
      {message && <p role="status">{message}</p>}
      {error && <p role="alert">{error}</p>}
    </form>
  );
}