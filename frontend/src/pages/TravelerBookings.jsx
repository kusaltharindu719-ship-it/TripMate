import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import TravelerShell, { Badge, EmptyState, Loader } from "../components/TravelerShell";
import { apiFetch } from "../services/api";

export default function TravelerBookings() {
  const navigate = useNavigate();
  const [bookings, setBookings] = useState([]);
  const [selectedBooking, setSelectedBooking] = useState(null);
  const [bookingItems, setBookingItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [loadingDetails, setLoadingDetails] = useState(false);
  const [cancelling, setCancelling] = useState(false);
  const [cancelReason, setCancelReason] = useState("");
  const [showCancelModal, setShowCancelModal] = useState(false);
  const [msg, setMsg] = useState({ type: "", text: "" });

  async function loadBookings() {
    setLoading(true);
    try {
      const data = await apiFetch("/traveler/bookings");
      setBookings(Array.isArray(data?.bookings) ? data.bookings : []);
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadBookings();
  }, []);

  async function viewDetails(booking) {
    setSelectedBooking(booking);
    setLoadingDetails(true);
    setBookingItems([]);
    try {
      const data = await apiFetch(`/traveler/bookings/${booking.id}`);
      setBookingItems(Array.isArray(data?.items) ? data.items : []);
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setLoadingDetails(false);
    }
  }

  async function handleCancelSubmit(e) {
    e.preventDefault();
    if (!selectedBooking) return;
    setCancelling(true);
    try {
      await apiFetch(`/traveler/bookings/${selectedBooking.id}/cancellations`, {
        method: "POST",
        body: JSON.stringify({ reason: cancelReason || "Traveler requested cancellation" }),
      });
      setMsg({ type: "success", text: "Cancellation request submitted." });
      setShowCancelModal(false);
      setCancelReason("");
      await loadBookings();
      await viewDetails(selectedBooking);
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setCancelling(false);
    }
  }

  return (
    <TravelerShell
      eyebrow="MY BOOKINGS"
      title="Trip bookings"
      subtitle="Track your confirmed reservations, view receipts and manage booking requests."
      actions={
        <button className="btn btn-primary" onClick={() => navigate("/traveler")}>
          ← Dashboard
        </button>
      }
    >
      {msg.text && <div className={`alert alert-${msg.type}`}>{msg.text}</div>}

      {loading ? (
        <Loader text="Loading your bookings..." />
      ) : bookings.length === 0 ? (
        <EmptyState
          icon="▣"
          title="No bookings yet"
          text="When you complete checkout for a trip, your confirmed bookings and vouchers appear here."
          action={
            <Link className="btn btn-primary" to="/traveler">
              View Active Trips
            </Link>
          }
        />
      ) : (
        <div className="two-panel-layout">
          <section className="content-card">
            <div className="card-heading">
              <div>
                <div className="eyebrow">RESERVATIONS</div>
                <h2>{bookings.length} {bookings.length === 1 ? "Booking" : "Bookings"}</h2>
              </div>
            </div>

            <div className="trip-list">
              {bookings.map((b) => (
                <div
                  className={`trip-row ${selectedBooking?.id === b.id ? "active-row" : ""}`}
                  key={b.id}
                  onClick={() => viewDetails(b)}
                  style={{ cursor: "pointer" }}
                >
                  <div className="trip-date-box">
                    <small>REF</small>
                    <strong>#{b.id}</strong>
                  </div>
                  <div className="trip-main">
                    <div>
                      <h3>{b.booking_reference || `Booking #${b.id}`}</h3>
                      <p>
                        Trip #{b.trip_id} · {new Date(b.created_at).toLocaleDateString()}
                      </p>
                    </div>
                    <div style={{ textAlign: "right" }}>
                      <strong>
                        {b.currency || "LKR"} {Number(b.total_amount || 0).toLocaleString()}
                      </strong>
                      <div style={{ marginTop: "4px" }}>
                        <Badge tone={b.status === "confirmed" ? "green" : b.status === "cancelled" ? "red" : "blue"}>
                          {b.status || "confirmed"}
                        </Badge>
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </section>

          <aside className="form-card sticky-card">
            {selectedBooking ? (
              <>
                <div className="card-heading">
                  <div>
                    <div className="eyebrow">BOOKING DETAILS</div>
                    <h2>{selectedBooking.booking_reference || `Booking #${selectedBooking.id}`}</h2>
                  </div>
                  <Badge tone={selectedBooking.status === "confirmed" ? "green" : "red"}>
                    {selectedBooking.status}
                  </Badge>
                </div>

                <div style={{ display: "grid", gap: "10px", fontSize: "14px", marginBottom: "20px" }}>
                  <div style={{ display: "flex", justifyContent: "space-between", color: "var(--muted)" }}>
                    <span>Total Amount</span>
                    <strong style={{ color: "var(--deep)" }}>
                      {selectedBooking.currency || "LKR"} {Number(selectedBooking.total_amount || 0).toLocaleString()}
                    </strong>
                  </div>
                  <div style={{ display: "flex", justifyContent: "space-between", color: "var(--muted)" }}>
                    <span>Payment Status</span>
                    <strong style={{ textTransform: "capitalize" }}>{selectedBooking.payment_status || "Pending"}</strong>
                  </div>
                  <div style={{ display: "flex", justifyContent: "space-between", color: "var(--muted)" }}>
                    <span>Booked On</span>
                    <span>{new Date(selectedBooking.created_at).toLocaleString()}</span>
                  </div>
                </div>

                <div style={{ borderTop: "1px solid var(--line)", paddingTop: "14px", marginBottom: "16px" }}>
                  <strong style={{ fontSize: "13px", display: "block", marginBottom: "10px" }}>Booked Items</strong>
                  {loadingDetails ? (
                    <small>Loading items...</small>
                  ) : bookingItems.length === 0 ? (
                    <small style={{ color: "var(--muted)" }}>No item details available.</small>
                  ) : (
                    <div style={{ display: "grid", gap: "8px" }}>
                      {bookingItems.map((item) => (
                        <div
                          key={item.id}
                          style={{
                            background: "var(--bg)",
                            padding: "10px 12px",
                            borderRadius: "10px",
                            fontSize: "12px",
                            display: "flex",
                            justifyContent: "space-between",
                          }}
                        >
                          <div>
                            <strong>{item.item_name_snapshot || item.service_name_snapshot}</strong>
                            <div style={{ color: "var(--muted)", textTransform: "capitalize" }}>
                              {item.item_type} · Qty {item.quantity || 1}
                            </div>
                          </div>
                          <strong>
                            {item.currency || "LKR"} {Number(item.total_price || item.unit_price || 0).toLocaleString()}
                          </strong>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                {selectedBooking.status === "confirmed" && (
                  <button
                    className="btn btn-light btn-full"
                    style={{ color: "var(--red)", borderColor: "#f3d1d1" }}
                    onClick={() => setShowCancelModal(true)}
                  >
                    Request Cancellation
                  </button>
                )}
              </>
            ) : (
              <div style={{ textAlign: "center", padding: "30px 10px", color: "var(--muted)" }}>
                <span style={{ fontSize: "28px", display: "block", marginBottom: "10px" }}>▣</span>
                <p>Select a booking from the list to view its complete details and receipts.</p>
              </div>
            )}
          </aside>
        </div>
      )}

      {showCancelModal && (
        <div
          style={{
            position: "fixed",
            inset: 0,
            background: "rgba(0,0,0,0.5)",
            display: "grid",
            placeItems: "center",
            zIndex: 100,
            padding: "20px",
          }}
        >
          <div className="auth-card-pro" style={{ width: "min(100%, 450px)" }}>
            <div className="eyebrow">CANCELLATION REQUEST</div>
            <h2>Cancel Booking #{selectedBooking?.id}</h2>
            <p>Please share the reason for cancellation. Cancellations are subject to provider policy.</p>

            <form className="form-stack" onSubmit={handleCancelSubmit}>
              <label>
                Reason for cancellation
                <textarea
                  rows="3"
                  required
                  placeholder="e.g. Schedule conflict, personal reasons..."
                  value={cancelReason}
                  onChange={(e) => setCancelReason(e.target.value)}
                />
              </label>

              <div style={{ display: "flex", gap: "10px", justifyContent: "flex-end" }}>
                <button
                  type="button"
                  className="btn btn-light"
                  onClick={() => setShowCancelModal(false)}
                  disabled={cancelling}
                >
                  Keep Booking
                </button>
                <button
                  type="submit"
                  className="btn btn-dark"
                  style={{ background: "var(--red)" }}
                  disabled={cancelling}
                >
                  {cancelling ? "Submitting..." : "Confirm Cancellation"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </TravelerShell>
  );
}
