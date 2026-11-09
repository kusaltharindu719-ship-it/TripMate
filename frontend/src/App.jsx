import { BrowserRouter, Route, Routes } from "react-router-dom";
import Home from "./pages/Home";
import Login from "./pages/Login";
import Register from "./pages/Register";
import TravelerDashboard from "./pages/TravelerDashboard";
import CreateTrip from "./pages/CreateTrip";
import TripDetails from "./pages/TripDetails";
import TripPreferences from "./pages/TripPreferences";
import TripDestinations from "./pages/TripDestinations";
import TripAccommodations from "./pages/TripAccommodations";
import TripRestaurants from "./pages/TripRestaurants";
import TripTransport from "./pages/TripTransport";
import RoleDashboard from "./pages/RoleDashboard";
import AccommodationDetails from "./pages/AccommodationDetails";
import AccommodationOwnerDashboard from "./pages/AccommodationOwnerDashboard";

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Home/>}/>
        <Route path="/login" element={<Login/>}/>
        <Route path="/register" element={<Register/>}/>
        <Route path="/traveler" element={<TravelerDashboard/>}/>
        <Route path="/traveler/create-trip" element={<CreateTrip/>}/>
        <Route path="/traveler/trips/:tripId" element={<TripDetails/>}/>
        <Route path="/traveler/trips/:tripId/preferences" element={<TripPreferences/>}/>
        <Route path="/traveler/trips/:tripId/destinations" element={<TripDestinations/>}/>
        <Route  path="/traveler/trips/:tripId/accommodations/:accommodationId"element={<AccommodationDetails />}/>
        <Route path="/traveler/trips/:tripId/accommodations" element={<TripAccommodations/>}/>
        <Route path="/traveler/trips/:tripId/restaurants" element={<TripRestaurants/>}/>
        <Route path="/traveler/trips/:tripId/transport" element={<TripTransport/>}/>
        <Route path="/restaurant-owner" element={<RoleDashboard role="Restaurant owner" title="Restaurant operations"/>}/>
        <Route path="/accommodation-owner" element={<AccommodationOwnerDashboard />} />
        <Route path="/driver" element={<RoleDashboard role="Driver" title="Driver workspace"/>}/>
        <Route path="/admin" element={<RoleDashboard role="Administrator" title="Platform overview"/>}/>
        <Route path="*" element={<Home/>}/>
      </Routes>
    </BrowserRouter>
  );
}
