import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import Navbar from "../components/Navbar";
import { getCurrentUser, loginUser } from "../services/api";

export default function Login(){
  const navigate=useNavigate();
  const [email,setEmail]=useState(""); const [password,setPassword]=useState(""); const [error,setError]=useState(""); const [loading,setLoading]=useState(false);
  async function submit(e){e.preventDefault();setError("");setLoading(true);try{await loginUser(email,password);const data=await getCurrentUser();const role=data?.user?.role;const routes={traveler:"/traveler",accommodation_owner:"/accommodation-owner",restaurant_owner:"/restaurant-owner",driver:"/driver",admin:"/admin"};if(!routes[role])throw new Error("Unsupported account role");navigate(routes[role]);}catch(err){setError(err.message)}finally{setLoading(false)}}
  return <div className="auth-screen"><Navbar/><div className="auth-layout">
    <section className="auth-story"><div className="pill pill-dark">TRIPMATE WORKSPACE</div><h1>Your next journey is already taking shape.</h1><p>Sign in to continue your itinerary, compare services and keep every travel decision in one place.</p><div className="auth-metrics"><div><strong>1</strong><span>Trip workspace</span></div><div><strong>4</strong><span>Service layers</span></div><div><strong>∞</strong><span>Travel ideas</span></div></div></section>
    <section className="auth-panel"><div className="auth-card-pro"><div className="eyebrow">WELCOME BACK</div><h2>Sign in to TripMate</h2><p>Continue your journey.</p>{error&&<div className="alert alert-error">{error}</div>}<form className="form-stack" onSubmit={submit}><label>Email address<input type="email" value={email} onChange={e=>setEmail(e.target.value)} placeholder="you@example.com" required/></label><label>Password<input type="password" value={password} onChange={e=>setPassword(e.target.value)} placeholder="Enter your password" required/></label><button className="btn btn-primary btn-lg btn-full" disabled={loading}>{loading?"Signing in...":"Sign in"}</button></form><p className="auth-switch">New to TripMate? <Link to="/register">Create an account</Link></p></div></section>
  </div></div>
}
