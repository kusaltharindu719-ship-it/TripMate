import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import TravelerShell, { Badge, EmptyState, Loader } from "../components/TravelerShell";
import { apiFetch } from "../services/api";

export default function TravelerNotifications() {
  const navigate = useNavigate();
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [markingAll, setMarkingAll] = useState(false);
  const [msg, setMsg] = useState({ type: "", text: "" });

  async function loadNotifications() {
    setLoading(true);
    try {
      const data = await apiFetch("/traveler/notifications");
      setNotifications(Array.isArray(data?.notifications) ? data.notifications : []);
      setUnreadCount(data?.unread_count || 0);
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadNotifications();
  }, []);

  async function markAllRead() {
    setMarkingAll(true);
    setMsg({ type: "", text: "" });
    try {
      await apiFetch("/traveler/notifications/read-all", { method: "PATCH" });
      setNotifications((prev) => prev.map((n) => ({ ...n, is_read: true })));
      setUnreadCount(0);
      setMsg({ type: "success", text: "All updates marked as read." });
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    } finally {
      setMarkingAll(false);
    }
  }

  async function toggleRead(notification) {
    const nextState = !notification.is_read;
    try {
      await apiFetch(`/traveler/notifications/${notification.id}/read?is_read=${nextState}`, {
        method: "PATCH",
      });
      setNotifications((prev) =>
        prev.map((n) => (n.id === notification.id ? { ...n, is_read: nextState } : n))
      );
      setUnreadCount((c) => (nextState ? Math.max(0, c - 1) : c + 1));
    } catch (e) {
      setMsg({ type: "error", text: e.message });
    }
  }

  return (
    <TravelerShell
      eyebrow="UPDATES & NOTIFICATIONS"
      title="Trip updates"
      subtitle="Stay informed on driver bids, booking changes and trip alerts."
      actions={
        <div style={{ display: "flex", gap: "10px" }}>
          {unreadCount > 0 && (
            <button className="btn btn-primary btn-sm" onClick={markAllRead} disabled={markingAll}>
              {markingAll ? "Marking..." : "Mark all as read"}
            </button>
          )}
          <button className="btn btn-light btn-sm" onClick={() => navigate("/traveler")}>
            ← Dashboard
          </button>
        </div>
      }
    >
      {msg.text && <div className={`alert alert-${msg.type}`}>{msg.text}</div>}

      {loading ? (
        <Loader text="Loading your updates..." />
      ) : notifications.length === 0 ? (
        <EmptyState
          icon="◉"
          title="No updates yet"
          text="When drivers bid on your transport requests or bookings update, you will see notifications here."
          action={
            <Link className="btn btn-primary" to="/traveler">
              Go to Dashboard
            </Link>
          }
        />
      ) : (
        <section className="content-card">
          <div className="card-heading">
            <div>
              <div className="eyebrow">ACTIVITY FEED</div>
              <h2>
                {notifications.length} {notifications.length === 1 ? "Update" : "Updates"}
                {unreadCount > 0 && ` (${unreadCount} unread)`}
              </h2>
            </div>
          </div>

          <div className="trip-list">
            {notifications.map((n) => (
              <div
                className="trip-row static"
                key={n.id}
                style={{
                  background: n.is_read ? "transparent" : "var(--mint)",
                  borderRadius: "14px",
                  padding: "16px 14px",
                  marginBottom: "8px",
                }}
              >
                <div className="trip-date-box" style={{ background: n.is_read ? "#f0f6f3" : "#fff" }}>
                  <small>{n.is_read ? "SEEN" : "NEW"}</small>
                  <strong>{n.is_read ? "✓" : "●"}</strong>
                </div>
                <div className="trip-main">
                  <div>
                    <div style={{ display: "flex", alignItems: "center", gap: "8px", marginBottom: "4px" }}>
                      <h3 style={{ margin: 0 }}>{n.title || "Trip Notification"}</h3>
                      {!n.is_read && <Badge tone="blue">New</Badge>}
                    </div>
                    <p style={{ color: "var(--ink)", marginBottom: "4px" }}>{n.message}</p>
                    <small style={{ color: "var(--muted)", fontSize: "11px" }}>
                      {new Date(n.created_at).toLocaleString()}
                    </small>
                  </div>
                  <div>
                    <button
                      className="text-button"
                      style={{ fontSize: "12px", color: "var(--muted)" }}
                      onClick={() => toggleRead(n)}
                    >
                      {n.is_read ? "Mark unread" : "Mark read"}
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </section>
      )}
    </TravelerShell>
  );
}
