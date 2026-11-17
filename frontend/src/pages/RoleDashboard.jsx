import React from 'react';
import { Layers, Compass, UserCheck, Settings } from 'lucide-react';

export default function RoleDashboard() {
  return (
    <div className="min-h-screen bg-[#0B1F33] text-white p-6 md:p-10 font-sans">
      <div className="mb-8 border-b border-slate-700 pb-4">
        <h1 className="text-2xl md:text-3xl font-bold text-[#21C7D9]">Role Dashboard Switcher</h1>
        <p className="text-sm text-slate-400 mt-1">Unified access portal for multi-tier TripMate service providers.</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-slate-900/60 border border-slate-800 p-6 rounded-xl hover:border-[#14B87A] transition duration-300">
          <UserCheck className="text-[#14B87A] mb-4" size={32} />
          <h3 className="text-xl font-semibold mb-2">Transport Provider</h3>
          <p className="text-xs text-slate-400 mb-4">Manage vehicle fleets, driver assignments, and live route bookings.</p>
          <span className="text-xs text-[#14B87A] font-semibold">Active Status: Online</span>
        </div>

        <div className="bg-slate-900/60 border border-slate-800 p-6 rounded-xl hover:border-[#21C7D9] transition duration-300">
          <Compass className="text-[#21C7D9] mb-4" size={32} />
          <h3 className="text-xl font-semibold mb-2">Tour Guide Portal</h3>
          <p className="text-xs text-slate-400 mb-4">Coordinate itinerary stops, traveler group chats, and schedule updates.</p>
          <span className="text-xs text-[#21C7D9] font-semibold">Active Status: Ready</span>
        </div>

        <div className="bg-slate-900/60 border border-slate-800 p-6 rounded-xl hover:border-[#F4C56A] transition duration-300">
          <Layers className="text-[#F4C56A] mb-4" size={32} />
          <h3 className="text-xl font-semibold mb-2">Accommodation Host</h3>
          <p className="text-xs text-slate-400 mb-4">Control room availability, check-in calendars, and guest reviews.</p>
          <span className="text-xs text-[#F4C56A] font-semibold">Active Status: Updated</span>
        </div>
      </div>
    </div>
  );
}