import { Link } from "react-router-dom";
import Navbar from "../components/Navbar";

export default function Register() {
  return (
    <div className="landing-page">

      <Navbar />

      <div className="auth-page">

        <div className="auth-card">

          <h1>Create Account</h1>

          <p className="auth-subtitle">
            Join TripMate and start planning your journey.
          </p>

          <form className="auth-form">

            <div className="form-group">
              <label>Full Name</label>

              <input
                type="text"
                placeholder="Enter your full name"
              />
            </div>


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
                placeholder="Create a password"
              />
            </div>


            <div className="form-group">
              <label>Confirm Password</label>

              <input
                type="password"
                placeholder="Confirm your password"
              />
            </div>


            <div className="form-group">
              <label>Account Type</label>

              <select defaultValue="traveler">
                <option value="traveler">
                  Traveler
                </option>

                <option value="provider">
                  Service Provider
                </option>
              </select>
            </div>


            <button
              type="submit"
              className="auth-submit-btn"
            >
              Create Account
            </button>

          </form>


          <div className="auth-footer">

            Already have an account?{" "}

            <Link to="/login">
              Sign In
            </Link>

          </div>

        </div>

      </div>

    </div>
  );
}