import React from 'react';
import { useAppStore } from '../store/useAppStore';
import {
  ShieldCheck,
  Flame,
  Users,
  BellRing,
  Activity,
  MapPin,
  Bell } from
'lucide-react';
import { motion } from 'framer-motion';
import { cn } from '../lib/utils';
export function Dashboard() {
  const {
    isAlertActive,
    occupancy,
    alarmEnabled,
    resolveAlert,
    setNotificationsOpen,
    logs
  } = useAppStore();
  const unreadCount = logs.length > 0 ? logs.length : 0;
  return (
    <div className="p-4 space-y-6">
      {/* Header */}
      <header className="pt-4 pb-2 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-brand-text">VerdeSense</h1>
          <p className="text-brand-muted text-sm">
            Greenhouse Monitoring System
          </p>
        </div>
        <button
          onClick={() => setNotificationsOpen(true)}
          className="relative p-2 bg-brand-card rounded-full shadow-sm text-brand-text border border-brand-border hover:bg-brand-border">
          
          <Bell className="w-6 h-6" />
          {unreadCount > 0 &&
          <span className="absolute top-0 right-0 w-4 h-4 bg-brand-alert text-white text-[10px] font-bold rounded-full flex items-center justify-center border-2 border-brand-card">
              {unreadCount > 9 ? '9+' : unreadCount}
            </span>
          }
        </button>
      </header>

      {/* Main Status Card */}
      <motion.div
        layout
        className={cn(
          'rounded-3xl p-6 text-white shadow-lg relative overflow-hidden border',
          isAlertActive ?
          'bg-gradient-to-br from-brand-alert to-red-900 border-brand-alert' :
          'bg-gradient-to-br from-brand-card to-brand-dark border-brand-border'
        )}>
        
        {/* Background Pattern */}
        <div className="absolute top-0 right-0 -mt-4 -mr-4 opacity-5">
          {isAlertActive ?
          <Flame className="w-48 h-48" /> :

          <ShieldCheck className="w-48 h-48" />
          }
        </div>

        <div className="relative z-10 flex flex-col items-center text-center space-y-4">
          <motion.div
            animate={
            isAlertActive ?
            {
              scale: [1, 1.1, 1]
            } :
            {}
            }
            transition={{
              repeat: Infinity,
              duration: 1.5
            }}
            className={cn(
              'p-4 rounded-full',
              isAlertActive ?
              'bg-white/20' :
              'bg-brand-primary/20 text-brand-primary'
            )}>
            
            {isAlertActive ?
            <Flame className="w-12 h-12" /> :

            <ShieldCheck className="w-12 h-12" />
            }
          </motion.div>

          <div>
            <h2 className="text-3xl font-bold mb-1">
              {isAlertActive ? 'DANGER' : 'SAFE'}
            </h2>
            <p className="text-white/80 text-sm font-medium">
              {isAlertActive ?
              'Smoke/Fire detected in Zone A' :
              'All systems operating normally'}
            </p>
          </div>

          {isAlertActive &&
          <button
            onClick={resolveAlert}
            className="mt-4 px-6 py-2 bg-white text-brand-alert font-bold rounded-full shadow-md hover:bg-red-50 transition-colors active:scale-95">
            
              Resolve Alert
            </button>
          }
        </div>
      </motion.div>

      {/* Metrics Grid */}
      <div className="grid grid-cols-2 gap-4">
        {/* Occupancy Card */}
        <div className="bg-brand-card p-4 rounded-3xl shadow-sm border border-brand-border flex flex-col justify-between">
          <div className="flex items-center justify-between mb-4">
            <div className="p-2 bg-brand-dark text-brand-primary rounded-xl">
              <Users className="w-5 h-5" />
            </div>
            <span className="text-xs font-medium text-brand-muted">
              Tracker
            </span>
          </div>
          <div>
            <div className="text-3xl font-bold text-brand-text">
              {occupancy}
            </div>
            <div className="text-sm text-brand-muted">People inside</div>
          </div>
        </div>

        {/* Alarm Status Card */}
        <div className="bg-brand-card p-4 rounded-3xl shadow-sm border border-brand-border flex flex-col justify-between">
          <div className="flex items-center justify-between mb-4">
            <div
              className={cn(
                'p-2 rounded-xl',
                alarmEnabled ?
                'bg-brand-primary/20 text-brand-primary' :
                'bg-brand-dark text-brand-muted'
              )}>
              
              <BellRing className="w-5 h-5" />
            </div>
            <span className="text-xs font-medium text-brand-muted">Siren</span>
          </div>
          <div>
            <div className="text-lg font-bold text-brand-text">
              {alarmEnabled ? 'Armed' : 'Disarmed'}
            </div>
            <div className="text-sm text-brand-muted">Loud Alarm</div>
          </div>
        </div>
      </div>

      {/* Active Sensors List */}
      <div className="space-y-3">
        <h3 className="font-semibold text-brand-text flex items-center gap-2">
          <Activity className="w-4 h-4 text-brand-primary" />
          Active Sensors
        </h3>
        <div className="bg-brand-card rounded-3xl shadow-sm border border-brand-border divide-y divide-brand-border">
          {[
          {
            name: 'Main Warehouse',
            status: 'online',
            type: 'smoke'
          },
          {
            name: 'Greenhouse Alpha',
            status: 'online',
            type: 'smoke'
          },
          {
            name: 'Entrance Gate',
            status: 'online',
            type: 'occupancy'
          }].
          map((sensor, i) =>
          <div key={i} className="p-4 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-2 h-2 rounded-full bg-brand-primary" />
                <div>
                  <p className="text-sm font-medium text-brand-text">
                    {sensor.name}
                  </p>
                  <p className="text-xs text-brand-muted capitalize">
                    {sensor.type} sensor
                  </p>
                </div>
              </div>
              <span className="text-xs font-medium text-brand-primary bg-brand-primary/10 px-2 py-1 rounded-md">
                Online
              </span>
            </div>
          )}
        </div>
      </div>
    </div>);

}