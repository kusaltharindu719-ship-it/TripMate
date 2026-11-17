import React from 'react';
import { ShieldCheck, Server, Users, Activity, AlertTriangle } from 'lucide-react';

export default function AdminDashboard() {
  return (
    <div className="min-h-screen bg-[#0B1F33] text-white p-6 md:p-10 font-sans">
      {/* Top Header */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-8 border-b border-slate-700 pb-4">
        <div>
          <h1 className="text-2xl md:text-3xl font-bold tracking-wide text-[#21C7D9]">Admin Control Center</h1>
          <p className="text-sm text-slate-400 mt-1">Manage platform verification, system status, and providers.</p>
        </div>
        <div className="mt-4 md:mt-0 flex items-center gap-3">
          <span className="px-3 py-1 bg-[#14B87A]/20 text-[#14B87A] rounded-full text-xs font-semibold flex items-center gap-1 border border-[#14B87A]/30">
            <Activity size={14} /> Platform Operational
          </span>
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <div className="bg-slate-900/60 backdrop-blur-md border border-slate-800 p-5 rounded-xl shadow-lg hover:border-[#21C7D9] transition-all duration-300">
          <div className="flex justify-between items-center">
            <span className="text-slate-400 text-sm">Total Providers</span>
            <Users className="text-[#21C7D9]" size={20} />
          </div>
          <h2 className="text-3xl font-bold mt-3">1,248</h2>
          <span className="text-xs text-[#14B87A] mt-2 inline-block">+12% this month</span>
        </div>

        <div className="bg-slate-900/60 backdrop-blur-md border border-slate-800 p-5 rounded-xl shadow-lg hover:border-[#14B87A] transition-all duration-300">
          <div className="flex justify-between items-center">
            <span className="text-slate-400 text-sm">Pending Verifications</span>
            <ShieldCheck className="text-[#14B87A]" size={20} />
          </div>
          <h2 className="text-3xl font-bold mt-3">24</h2>
          <span className="text-xs text-[#F4C56A] mt-2 inline-block">Requires attention</span>
        </div>

        <div className="bg-slate-900/60 backdrop-blur-md border border-slate-800 p-5 rounded-xl shadow-lg hover:border-[#F4C56A] transition-all duration-300">
          <div className="flex justify-between items-center">
            <span className="text-slate-400 text-sm">System Health</span>
            <Server className="text-[#F4C56A]" size={20} />
          </div>
          <h2 className="text-3xl font-bold mt-3">99.9%</h2>
          <span className="text-xs text-[#14B87A] mt-2 inline-block">Optimal performance</span>
        </div>

        <div className="bg-slate-900/60 backdrop-blur-md border border-slate-800 p-5 rounded-xl shadow-lg hover:border-red-400 transition-all duration-300">
          <div className="flex justify-between items-center">
            <span className="text-slate-400 text-sm">Active Alerts</span>
            <AlertTriangle className="text-red-400" size={20} />
          </div>
          <h2 className="text-3xl font-bold mt-3">3</h2>
          <span className="text-xs text-red-400 mt-2 inline-block">2 low, 1 medium</span>
        </div>
      </div>

      {/* Main Sections */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Verification Cards Panel */}
        <div className="lg:col-span-2 bg-slate-900/40 backdrop-blur-md border border-slate-800 rounded-xl p-6">
          <h3 className="text-lg font-semibold mb-4 flex items-center gap-2">
            <ShieldCheck className="text-[#21C7D9]" size={20} /> Pending Provider Verifications
          </h3>
          <div className="space-y-4">
            <div className="flex items-center justify-between p-4 bg-slate-800/50 rounded-lg border border-slate-700/50 hover:bg-slate-800 transition-all">
              <div>
                <h4 className="font-medium">Sunset Ocean Resort & Spa</h4>
                <p className="text-xs text-slate-400">Submitted by Kasun Perera • Hotel Provider</p>
              </div>
              <div className="flex gap-2">
                <button className="px-3 py-1.5 bg-[#14B87A] text-slate-950 font-semibold text-xs rounded-md hover:bg-[#14B87A]/80 transition">Approve</button>
                <button className="px-3 py-1.5 bg-red-500/20 text-red-400 font-semibold text-xs rounded-md border border-red-500/30 hover:bg-red-500/30 transition">Reject</button>
              </div>
            </div>

            <div className="flex items-center justify-between p-4 bg-slate-800/50 rounded-lg border border-slate-700/50 hover:bg-slate-800 transition-all">
              <div>
                <h4 className="font-medium">Ella Spice Garden Restaurant</h4>
                <p className="text-xs text-slate-400">Submitted by Nuwan Silva • Restaurant Owner</p>
              </div>
              <div className="flex gap-2">
                <button className="px-3 py-1.5 bg-[#14B87A] text-slate-950 font-semibold text-xs rounded-md hover:bg-[#14B87A]/80 transition">Approve</button>
                <button className="px-3 py-1.5 bg-red-500/20 text-red-400 font-semibold text-xs rounded-md border border-red-500/30 hover:bg-red-500/30 transition">Reject</button>
              </div>
            </div>
          </div>
        </div>

        {/* Action Panels */}
        <div className="bg-slate-900/40 backdrop-blur-md border border-slate-800 rounded-xl p-6">
          <h3 className="text-lg font-semibold mb-4 text-[#F4C56A]">Quick Action Panel</h3>
          <div className="space-y-3">
            <button className="w-full text-left p-3 rounded-lg bg-slate-800/60 hover:bg-[#21C7D9]/20 hover:border-[#21C7D9] border border-transparent transition text-sm font-medium">
              Broadcast System Announcement
            </button>
            <button className="w-full text-left p-3 rounded-lg bg-slate-800/60 hover:bg-[#14B87A]/20 hover:border-[#14B87A] border border-transparent transition text-sm font-medium">
              Generate Monthly Audit Report
            </button>
            <button className="w-full text-left p-3 rounded-lg bg-slate-800/60 hover:bg-[#F4C56A]/20 hover:border-[#F4C56A] border border-transparent transition text-sm font-medium">
              Review Flagged User Accounts
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}