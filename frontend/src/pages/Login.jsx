import { Link } from "react-router-dom";
import Navbar from "../components/Navbar";

export default function Login() {
  return (
    <div className="landing-page">

      <Navbar />

      <div className="auth-page">

        <div className="auth-card">

          <h1>Welcome Back</h1>

          <p className="auth-subtitle">
            Sign in to continue planning your TripMate journey.
          </p>

          <form className="auth-form">

            <div className="form-group">
              <label>Email Address</label>

              <input
                type="email"
                placeholder="Enter your email"
              />
            </div>


            <div className="form-group">
              <label>Password</label>

              <input
                type="password"
                placeholder="Enter your password"
              />
            </div>


            <button
              type="submit"
              className="auth-submit-btn"
            >
              Sign In
            </button>

          </form>


          <div className="auth-footer">

            Don't have an account?{" "}

            <Link to="/register">
              Create Account
            </Link>

          </div>

        </div>

      </div>

    </div>
  );
}