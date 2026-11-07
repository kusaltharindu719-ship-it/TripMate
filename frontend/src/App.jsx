import { BrowserRouter, Routes, Route } from "react-router-dom";

import Home from "./pages/Home";
import Login from "./pages/Login";
import Register from "./pages/Register";
import TravelerDashboard from "./pages/TravelerDashboard";
import RestaurantOwnerDashboard from "./pages/RestaurantOwnerDashboard";
import AccommodationOwnerDashboard from "./pages/AccommodationOwnerDashboard";
import DriverDashboard from "./pages/DriverDashboard";
import AdminDashboard from "./pages/AdminDashboard";

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/login" element={<Login />} />
        <Route path="/register" element={<Register />} />

        <Route path="/traveler" element={<TravelerDashboard />} />
        <Route
          path="/restaurant-owner"
          element={<RestaurantOwnerDashboard />}
        />
        <Route
          path="/accommodation-owner"
          element={<AccommodationOwnerDashboard />}
        />
        <Route path="/driver" element={<DriverDashboard />} />
        <Route path="/admin" element={<AdminDashboard />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;