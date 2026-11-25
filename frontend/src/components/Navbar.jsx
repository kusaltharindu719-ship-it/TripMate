import { Link, NavLink, useLocation, useNavigate } from "react-router-dom";
import { isLoggedIn, logoutUser } from "../services/api";

export default function Navbar() {
  const location = useLocation();
  const navigate = useNavigate();
  const loggedIn = isLoggedIn();
  const appPage = location.pathname.startsWith("/traveler");

  function logout() {
    logoutUser();
    navigate("/login");
  }

  return (
    <header className={`topbar ${appPage ? "topbar-app" : ""}`}>
      <Link className="brand" to={loggedIn ? "/traveler" : "/"}>
        <span className="brand-mark" aria-label="TripMate emblem">
          <svg
            viewBox="0 0 24 24"
            width="22"
            height="22"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
            aria-hidden="true"
          >
            <circle cx="12" cy="12" r="9.5" strokeOpacity="0.4" strokeWidth="1.4" strokeDasharray="2.5 2.5" />
            <polygon
              points="12 3 14.8 9.5 21 12 14.8 14.5 12 21 9.2 14.5 3 12 9.2 9.5"
              fill="currentColor"
              fillOpacity="0.25"
              stroke="currentColor"
              strokeWidth="1.8"
            />
            <circle cx="12" cy="12" r="2" fill="currentColor" />
          </svg>
        </span>
        <span>
          <strong>TripMate</strong>
          <small>Travel Sri Lanka</small>
        </span>
      </Link>

      <nav className="topbar-nav">
        {!loggedIn ? (
          <>
            <NavLink to="/">Home</NavLink>
            <a href="/#discover">Places</a>
            <NavLink to="/login">Login</NavLink>
            <NavLink className="btn btn-primary btn-sm" to="/register">
              Get Started
            </NavLink>
          </>
        ) : (
          <>
            <NavLink to="/traveler">Dashboard</NavLink>
            <NavLink to="/traveler/bookings">Bookings</NavLink>
            <NavLink to="/traveler/notifications">Updates</NavLink>
            <button className="btn btn-ghost btn-sm" onClick={logout}>
              Logout
            </button>
          </>
        )}
      </nav>
    </header>
  );
}
