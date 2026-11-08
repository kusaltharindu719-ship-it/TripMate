import { NavLink, useNavigate } from "react-router-dom";
import Navbar from "./Navbar";
import { logoutUser } from "../services/api";

export function Loader({ text = "Loading your travel workspace..." }) {
  return <div className="state-card"><span className="spinner"/><strong>{text}</strong><p>TripMate is getting everything ready.</p></div>;
}
export function EmptyState({ title, text, action }) {
  return <div className="empty-state"><span className="empty-icon">✦</span><h3>{title}</h3><p>{text}</p>{action}</div>;
}
export function Badge({ children, tone = "green" }) {
  return <span className={`badge badge-${tone}`}>{children}</span>;
}

export default function TravelerShell({ children, eyebrow, title, subtitle, actions }) {
  const navigate = useNavigate();
  const logout = () => { logoutUser(); navigate("/login"); };
  return (
    <div className="app-shell">
      <Navbar />
      <div className="app-grid">
        <aside className="sidebar">
          <div className="sidebar-label">TRAVEL WORKSPACE</div>
          <nav className="sidebar-nav">
            <NavLink end to="/traveler" className={({isActive})=>`sidebar-link ${isActive?"active":""}`}><span>⌂</span>Overview</NavLink>
            <NavLink to="/traveler/create-trip" className={({isActive})=>`sidebar-link ${isActive?"active":""}`}><span>＋</span>New trip</NavLink>
          </nav>
          <div className="sidebar-help"><span>✦</span><strong>Planning tip</strong><p>Add destinations first. Then choose stays, food and transport.</p></div>
          <button className="sidebar-logout" onClick={logout}>Sign out</button>
        </aside>
        <main className="workspace">
          <section className="page-heading">
            <div>{eyebrow && <div className="eyebrow">{eyebrow}</div>}<h1>{title}</h1>{subtitle && <p>{subtitle}</p>}</div>
            {actions && <div className="page-actions">{actions}</div>}
          </section>
          {children}
        </main>
      </div>
    </div>
  );
}
