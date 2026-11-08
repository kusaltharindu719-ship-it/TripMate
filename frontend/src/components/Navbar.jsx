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
        <span className="brand-mark">T</span>
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
