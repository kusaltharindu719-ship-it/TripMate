import React from 'react';
import { Utensils, CalendarDays, BellRing, PlusCircle, DollarSign, Clock } from 'lucide-react';

export default function RestaurantOwnerDashboard() {
  return (
    <div className="min-h-screen bg-slate-950 text-white p-6 md:p-10 font-sans">
      {/* Header */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-8 border-b border-slate-800 pb-4">
        <div>
          <h1 className="text-2xl md:text-3xl font-bold text-[#F4C56A]">Kandy Lake Rest & Cafe</h1>
          <p className="text-sm text-slate-400 mt-1">Restaurant Owner Operational Portal</p>
        </div>
        <button className="mt-4 md:mt-0 flex items-center gap-2 bg-[#14B87A] text-slate-950 px-4 py-2 rounded-lg font-semibold text-sm hover:bg-[#14B87A]/80 transition">
          <PlusCircle size={18} /> Add Menu Item
        </button>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-6 mb-8">
        <div className="bg-[#0B1F33] border border-slate-800 p-5 rounded-xl shadow-md">
          <div className="flex justify-between items-center text-slate-400 text-sm">
            <span>Today's Reservations</span>
            <CalendarDays className="text-[#21C7D9]" size={20} />
          </div>
          <h2 className="text-3xl font-bold mt-2">14 Tables</h2>
          <span className="text-xs text-[#14B87A] mt-1 inline-block">4 pending confirmation</span>
        </div>

        <div className="bg-[#0B1F33] border border-slate-800 p-5 rounded-xl shadow-md">
          <div className="flex justify-between items-center text-slate-400 text-sm">
            <span>Daily Revenue</span>
            <DollarSign className="text-[#14B87A]" size={20} />
          </div>
          <h2 className="text-3xl font-bold mt-2">Rs. 84,500</h2>
          <span className="text-xs text-[#14B87A] mt-1 inline-block">+18% compared to yesterday</span>
        </div>

        <div className="bg-[#0B1F33] border border-slate-800 p-5 rounded-xl shadow-md">
          <div className="flex justify-between items-center text-slate-400 text-sm">
            <span>Operational Alerts</span>
            <BellRing className="text-[#F4C56A]" size={20} />
          </div>
          <h2 className="text-3xl font-bold mt-2">2 Alerts</h2>
          <span className="text-xs text-[#F4C56A] mt-1 inline-block">Low stock on Ceylon Tea</span>
        </div>
      </div>

      {/* Reservation Cards & Menu Shortcuts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Booking / Reservation Cards */}
        <div className="bg-[#0B1F33]/60 border border-slate-800 p-6 rounded-xl">
          <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
            <Clock className="text-[#21C7D9]" size={20} /> Recent Table Reservations
          </h3>
          <div className="space-y-4">
            <div className="p-4 bg-slate-900/60 rounded-lg border border-slate-800 flex justify-between items-center">
              <div>
                <h4 className="font-medium">Table #4 (4 Persons)</h4>
                <p className="text-xs text-slate-400">Guest: Chamath Adithya • 7:30 PM Today</p>
              </div>
              <span className="px-2.5 py-1 bg-[#14B87A]/20 text-[#14B87A] text-xs font-semibold rounded-md border border-[#14B87A]/30">Confirmed</span>
            </div>

            <div className="p-4 bg-slate-900/60 rounded-lg border border-slate-800 flex justify-between items-center">
              <div>
                <h4 className="font-medium">Table #2 (2 Persons)</h4>
                <p className="text-xs text-slate-400">Guest: Nilmi • 8:15 PM Today</p>
              </div>
              <span className="px-2.5 py-1 bg-[#F4C56A]/20 text-[#F4C56A] text-xs font-semibold rounded-md border border-[#F4C56A]/30">Pending</span>
            </div>
          </div>
        </div>

        {/* Menu Management Shortcuts */}
        <div className="bg-[#0B1F33]/60 border border-slate-800 p-6 rounded-xl">
          <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
            <Utensils className="text-[#14B87A]" size={20} /> Menu & Category Management
          </h3>
          <div className="grid grid-cols-2 gap-4">
            <div className="p-4 bg-slate-900/60 rounded-lg border border-slate-800 hover:border-[#21C7D9] transition cursor-pointer text-center">
              <h4 className="font-medium text-sm"> Rice & Curries</h4>
              <p className="text-xs text-slate-400 mt-1">12 Items Available</p>
            </div>
            <div className="p-4 bg-slate-900/60 rounded-lg border border-slate-800 hover:border-[#14B87A] transition cursor-pointer text-center">
              <h4 className="font-medium text-sm"> Short Eats & Snacks</h4>
              <p className="text-xs text-slate-400 mt-1">8 Items Available</p>
            </div>
            <div className="p-4 bg-slate-900/60 rounded-lg border border-slate-800 hover:border-[#F4C56A] transition cursor-pointer text-center">
              <h4 className="font-medium text-sm"> Beverages & Tea</h4>
              <p className="text-xs text-slate-400 mt-1">6 Items Available</p>
            </div>
            <div className="p-4 bg-slate-900/60 rounded-lg border border-slate-800 hover:border-purple-400 transition cursor-pointer text-center">
              <h4 className="font-medium text-sm"> Desserts</h4>
              <p className="text-xs text-slate-400 mt-1">4 Items Available</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}