import React from 'react';
import { useAppStore } from '../store/useAppStore';
import {
  Bell,
  ShieldAlert,
  Smartphone,
  Users,
  ChevronRight,
  Flame } from
'lucide-react';
import { cn } from '../lib/utils';
export function Settings() {
  const {
    alarmEnabled,
    toggleAlarm,
    notificationsEnabled,
    toggleNotifications,
    triggerAlert,
    isAlertActive,
    occupancy,
    updateOccupancy
  } = useAppStore();
  return (
    <div className="p-4 space-y-6">
      <header className="pt-4 pb-2">
        <h1 className="text-2xl font-bold text-brand-text">Settings</h1>
        <p className="text-brand-muted text-sm">System configuration</p>
      </header>

      {/* Demo Actions (For testing the UI) */}
      <div className="bg-brand-card border border-brand-alert/30 rounded-3xl p-4 space-y-3">
        <h3 className="text-xs font-bold text-brand-alert uppercase tracking-wider flex items-center gap-2">
          <Flame className="w-4 h-4" /> Demo Controls
        </h3>
        <button
          onClick={triggerAlert}
          disabled={isAlertActive}
          className="w-full p-3 bg-brand-alert hover:bg-red-600 disabled:bg-brand-border disabled:text-brand-muted text-white font-bold rounded-full shadow-sm transition-colors flex items-center justify-center gap-2">
          
          <ShieldAlert className="w-5 h-5" />
          {isAlertActive ? 'Alert Already Active' : 'Simulate Fire Alert'}
        </button>

        <div className="flex items-center justify-between bg-brand-dark p-3 rounded-2xl border border-brand-border">
          <span className="text-sm font-medium text-brand-text">
            Simulate Occupancy
          </span>
          <div className="flex items-center gap-3">
            <button
              onClick={() => updateOccupancy(Math.max(0, occupancy - 1))}
              className="w-8 h-8 rounded-full bg-brand-card flex items-center justify-center text-brand-text font-bold hover:bg-brand-border border border-brand-border">
              
              -
            </button>
            <span className="font-bold w-4 text-center text-brand-text">
              {occupancy}
            </span>
            <button
              onClick={() => updateOccupancy(occupancy + 1)}
              className="w-8 h-8 rounded-full bg-brand-card flex items-center justify-center text-brand-text font-bold hover:bg-brand-border border border-brand-border">
              
              +
            </button>
          </div>
        </div>
      </div>

      {/* Configuration */}
      <div className="space-y-2">
        <h3 className="text-xs font-bold text-brand-muted uppercase tracking-wider px-2">
          Preferences
        </h3>
        <div className="bg-brand-card rounded-3xl shadow-sm border border-brand-border overflow-hidden divide-y divide-brand-border">
          {/* Notifications Toggle */}
          <div className="p-4 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="p-2 bg-brand-dark rounded-xl text-brand-primary">
                <Smartphone className="w-5 h-5" />
              </div>
              <div>
                <p className="font-medium text-brand-text">
                  Push Notifications
                </p>
                <p className="text-xs text-brand-muted">
                  Receive alerts on your phone
                </p>
              </div>
            </div>
            <button
              onClick={toggleNotifications}
              className={cn(
                'w-12 h-6 rounded-full transition-colors relative',
                notificationsEnabled ?
                'bg-brand-primary' :
                'bg-brand-dark border border-brand-border'
              )}>
              
              <div
                className={cn(
                  'absolute top-1 w-4 h-4 rounded-full bg-white transition-transform',
                  notificationsEnabled ? 'left-7' : 'left-1 bg-brand-muted'
                )} />
              
            </button>
          </div>

          {/* Alarm Toggle */}
          <div className="p-4 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="p-2 bg-brand-dark rounded-xl text-brand-primary">
                <Bell className="w-5 h-5" />
              </div>
              <div>
                <p className="font-medium text-brand-text">Loud Siren Alarm</p>
                <p className="text-xs text-brand-muted">
                  Trigger physical sirens on site
                </p>
              </div>
            </div>
            <button
              onClick={toggleAlarm}
              className={cn(
                'w-12 h-6 rounded-full transition-colors relative',
                alarmEnabled ?
                'bg-brand-primary' :
                'bg-brand-dark border border-brand-border'
              )}>
              
              <div
                className={cn(
                  'absolute top-1 w-4 h-4 rounded-full bg-white transition-transform',
                  alarmEnabled ? 'left-7' : 'left-1 bg-brand-muted'
                )} />
              
            </button>
          </div>
        </div>
      </div>

      {/* System Info */}
      <div className="space-y-2">
        <h3 className="text-xs font-bold text-brand-muted uppercase tracking-wider px-2">
          System
        </h3>
        <div className="bg-brand-card rounded-3xl shadow-sm border border-brand-border overflow-hidden divide-y divide-brand-border">
          <button className="w-full p-4 flex items-center justify-between hover:bg-brand-dark transition-colors">
            <div className="flex items-center gap-3">
              <div className="p-2 bg-brand-dark rounded-xl text-brand-primary">
                <Users className="w-5 h-5" />
              </div>
              <span className="font-medium text-brand-text">Manage Users</span>
            </div>
            <ChevronRight className="w-5 h-5 text-brand-muted" />
          </button>
          <div className="p-4 flex items-center justify-between">
            <span className="text-sm text-brand-muted">App Version</span>
            <span className="text-sm font-medium text-brand-text">v1.0.0</span>
          </div>
        </div>
      </div>
    </div>);

}