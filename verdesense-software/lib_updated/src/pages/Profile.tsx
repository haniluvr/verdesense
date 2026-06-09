import React from 'react';
import { Link } from 'react-router-dom';
import {
  User,
  Settings,
  ClipboardList,
  Users,
  BarChart2,
  ChevronRight,
  LogOut } from
'lucide-react';
export function Profile() {
  return (
    <div className="p-4 space-y-6">
      <header className="pt-4 pb-2">
        <h1 className="text-2xl font-bold text-brand-text">Profile</h1>
      </header>

      {/* User Info Card */}
      <div className="bg-brand-card p-6 rounded-3xl shadow-sm border border-brand-border flex items-center gap-4">
        <div className="w-16 h-16 bg-brand-primary/20 rounded-full flex items-center justify-center text-brand-primary shrink-0">
          <User className="w-8 h-8" />
        </div>
        <div>
          <h2 className="text-xl font-bold text-brand-text">John Farmer</h2>
          <p className="text-sm text-brand-muted">Admin • VerdeSense Farm</p>
          <Link
            to="/edit-profile"
            className="text-xs font-bold text-brand-primary mt-1 inline-block">
            
            Edit Profile
          </Link>
        </div>
      </div>

      {/* Menu Links */}
      <div className="space-y-2">
        <h3 className="text-xs font-bold text-brand-muted uppercase tracking-wider px-2">
          Menu
        </h3>
        <div className="bg-brand-card rounded-3xl shadow-sm border border-brand-border overflow-hidden divide-y divide-brand-border">
          <Link
            to="/analytics"
            className="w-full p-4 flex items-center justify-between hover:bg-brand-dark transition-colors">
            
            <div className="flex items-center gap-3">
              <div className="p-2 bg-brand-dark rounded-xl text-brand-primary">
                <BarChart2 className="w-5 h-5" />
              </div>
              <span className="font-medium text-brand-text">Analytics</span>
            </div>
            <ChevronRight className="w-5 h-5 text-brand-muted" />
          </Link>

          <Link
            to="/logs"
            className="w-full p-4 flex items-center justify-between hover:bg-brand-dark transition-colors">
            
            <div className="flex items-center gap-3">
              <div className="p-2 bg-brand-dark rounded-xl text-brand-primary">
                <ClipboardList className="w-5 h-5" />
              </div>
              <span className="font-medium text-brand-text">Activity Logs</span>
            </div>
            <ChevronRight className="w-5 h-5 text-brand-muted" />
          </Link>

          <Link
            to="/user-management"
            className="w-full p-4 flex items-center justify-between hover:bg-brand-dark transition-colors">
            
            <div className="flex items-center gap-3">
              <div className="p-2 bg-brand-dark rounded-xl text-brand-primary">
                <Users className="w-5 h-5" />
              </div>
              <span className="font-medium text-brand-text">
                User Management
              </span>
            </div>
            <ChevronRight className="w-5 h-5 text-brand-muted" />
          </Link>

          <Link
            to="/settings"
            className="w-full p-4 flex items-center justify-between hover:bg-brand-dark transition-colors">
            
            <div className="flex items-center gap-3">
              <div className="p-2 bg-brand-dark rounded-xl text-brand-primary">
                <Settings className="w-5 h-5" />
              </div>
              <span className="font-medium text-brand-text">Settings</span>
            </div>
            <ChevronRight className="w-5 h-5 text-brand-muted" />
          </Link>
        </div>
      </div>

      {/* Logout */}
      <button className="w-full p-4 bg-brand-card rounded-3xl shadow-sm border border-brand-border flex items-center justify-center gap-2 text-brand-alert font-bold hover:bg-brand-dark transition-colors">
        <LogOut className="w-5 h-5" />
        Log Out
      </button>
    </div>);

}