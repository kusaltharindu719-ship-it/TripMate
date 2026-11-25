import { NavLink, useNavigate } from "react-router-dom";
import Navbar from "./Navbar";
import { logoutUser } from "../services/api";

export { Badge, EmptyState, ErrorState, Loader } from "./Ui";

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
            <NavLink to="/traveler/bookings" className={({isActive})=>`sidebar-link ${isActive?"active":""}`}><span>▣</span>Bookings</NavLink>
            <NavLink to="/traveler/notifications" className={({isActive})=>`sidebar-link ${isActive?"active":""}`}><span>◉</span>Updates</NavLink>
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
