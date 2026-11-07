import { Link } from "react-router-dom";
import { useState } from "react";

function Navbar() {
  const [blueTheme, setBlueTheme] = useState(false);

  const changeTheme = () => {
    const nextTheme = !blueTheme;

    setBlueTheme(nextTheme);

    if (nextTheme) {
      document.body.classList.add("blue-theme");
    } else {
      document.body.classList.remove("blue-theme");
    }
  };

  return (
    <nav className="navbar">
      <Link to="/" className="logo">
        <span className="logo-icon">T</span>
        <span>TripMate</span>
      </Link>

      <div className="nav-links">
        <Link to="/">Home</Link>
        <Link to="/login">Login</Link>

        <button
          className="theme-btn"
          onClick={changeTheme}
          title="Change theme"
        >
          🎨
        </button>

        <Link to="/register" className="register-btn">
          Get Started
        </Link>
      </div>
    </nav>
  );
}

export default Navbar;