import { useEffect, useMemo, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import TravelerShell, { Badge, EmptyState, Loader } from "../components/TravelerShell";
import { apiFetch } from "../services/api";

export default function TripCart() {
  const { tripId } = useParams();
  const navigate = useNavigate();
  const [cart, setCart] = useState(null);
  const [loading, setLoading] = useState(true);
  const [removingId, setRemovingId] = useState(null);
  const [checkingOut, setCheckingOut] = useState(false);
  const [msg, setMsg] = useState({ type: "", text: "" });

  async function loadCart() {
    setLoading(true);
    try {
      const data = await apiFetch(`/traveler/trips/${tripId}/cart`);
      setCart(data);
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadCart();
  }, [tripId]);

  async function removeItem(itemId) {
    setRemovingId(itemId);
    setMsg({ type: "", text: "" });
    try {
      await apiFetch(`/traveler/trips/${tripId}/cart/${itemId}`, {
        method: "DELETE",
      });
      setMsg({ type: "success", text: "Item removed from cart." });
      await loadCart();
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setRemovingId(null);
    }
  }

  async function handleCheckout() {
    setCheckingOut(true);
    setMsg({ type: "", text: "" });
    try {
      const result = await apiFetch(`/traveler/trips/${tripId}/checkout`, {
        method: "POST",
      });
      setMsg({
        type: "success",
        text: result?.message || "Checkout successful! Your booking is confirmed.",
      });
      setTimeout(() => {
        navigate("/traveler/bookings");
      }, 1500);
    } catch (e) {
      setMsg({ type: "error", text: e.message });
      setCheckingOut(false);
    }
  }

  const items = cart?.items || [];
  const trip = cart?.trip;

  const totalAmount = useMemo(() => {
    return items.reduce((acc, item) => {
      const price = Number(item.total_price || item.unit_price || 0);
      return acc + price;
    }, 0);
  }, [items]);

  const currency = items[0]?.currency || trip?.currency || "LKR";

  return (
    <TravelerShell
      eyebrow="TRIP CART"
      title={trip?.trip_name ? `${trip.trip_name} Cart` : "Trip Cart"}
      subtitle="Review your selected rooms, meals and trip services before checkout."
      actions={
        <div style={{ display: "flex", gap: "8px" }}>
          <button className="btn btn-light" onClick={() => navigate(`/traveler/trips/${tripId}`)}>
            ← Back to trip
          </button>
        </div>
      }
    >
      {msg.text && <div className={`alert alert-${msg.type}`}>{msg.text}</div>}

      {loading ? (
        <Loader text="Loading your trip cart..." />
      ) : items.length === 0 ? (
        <EmptyState
          icon="▣"
          title="Your trip cart is empty"
          text="Add accommodation rooms or dining options to this trip to assemble your cart."
          action={
            <div style={{ display: "flex", gap: "10px", marginTop: "14px" }}>
              <Link className="btn btn-primary" to={`/traveler/trips/${tripId}/accommodations`}>
                Find Stays
              </Link>
              <Link className="btn btn-light" to={`/traveler/trips/${tripId}/restaurants`}>
                Browse Food
              </Link>
            </div>
          }
        />
      ) : (
        <div className="two-panel-layout">
          <section className="content-card">
            <div className="card-heading">
              <div>
                <div className="eyebrow">SELECTED SERVICES</div>
                <h2>{items.length} {items.length === 1 ? "Item" : "Items"} in Cart</h2>
              </div>
            </div>

            <div className="trip-list">
              {items.map((item) => (
                <div className="trip-row static" key={item.id}>
                  <div className="trip-date-box">
                    <small>{item.item_type?.toUpperCase() || "ITEM"}</small>
                    <strong>
                      {item.item_type === "room" ? "⌂" : item.item_type === "food" ? "☕" : "✦"}
                    </strong>
                  </div>
                  <div className="trip-main">
                    <div>
                      <h3>{item.item_name_snapshot || item.service_name_snapshot || `Item #${item.id}`}</h3>
                      <p>
                        {item.service_name_snapshot && item.service_name_snapshot !== item.item_name_snapshot
                          ? `${item.service_name_snapshot} · `
                          : ""}
                        {item.item_type === "room" && item.check_in_date && item.check_out_date
                          ? `${item.check_in_date} → ${item.check_out_date} (${item.quantity || 1} room)`
                          : item.quantity
                          ? `Qty: ${item.quantity}`
                          : ""}
                      </p>
                    </div>
                    <div style={{ textAlign: "right" }}>
                      <strong style={{ display: "block", fontSize: "14px" }}>
                        {item.currency || currency} {Number(item.total_price || item.unit_price || 0).toLocaleString()}
                      </strong>
                      <button
                        className="text-button"
                        style={{ color: "var(--red)", fontSize: "12px", marginTop: "4px" }}
                        disabled={removingId === item.id}
                        onClick={() => removeItem(item.id)}
                      >
                        {removingId === item.id ? "Removing..." : "Remove"}
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </section>

          <aside className="form-card sticky-card">
            <div className="card-heading">
              <div>
                <div className="eyebrow">ORDER SUMMARY</div>
                <h2>Total</h2>
              </div>
            </div>

            <div style={{ display: "grid", gap: "12px", marginBottom: "20px" }}>
              <div style={{ display: "flex", justifyContent: "space-between", color: "var(--muted)", fontSize: "14px" }}>
                <span>Selected Items</span>
                <strong>{items.length}</strong>
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", color: "var(--muted)", fontSize: "14px" }}>
                <span>Trip</span>
                <strong>{trip?.trip_name || `Trip #${tripId}`}</strong>
              </div>
              <div style={{ height: "1px", background: "var(--line)", margin: "6px 0" }} />
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
                <span style={{ fontWeight: 700 }}>Estimated Total</span>
                <strong style={{ fontSize: "22px", color: "var(--deep)" }}>
                  {currency} {totalAmount.toLocaleString()}
                </strong>
              </div>
            </div>

            <button
              className="btn btn-primary btn-full btn-lg"
              onClick={handleCheckout}
              disabled={checkingOut || items.length === 0}
            >
              {checkingOut ? "Processing..." : "Confirm & Checkout →"}
            </button>
            <p style={{ fontSize: "11px", color: "var(--muted)", textAlign: "center", marginTop: "10px" }}>
              Checkout locks services and creates confirmed booking records.
            </p>
          </aside>
        </div>
      )}
    </TravelerShell>
  );
}
