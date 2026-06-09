import React from 'react';
import { NavLink } from 'react-router-dom';
import { LayoutDashboard, Map as MapIcon, Cpu, User } from 'lucide-react';
import { cn } from '../lib/utils';
import { useAppStore } from '../store/useAppStore';
import { motion } from 'framer-motion';
const navItems = [
{
  path: '/',
  label: 'Dashboard',
  icon: LayoutDashboard
},
{
  path: '/map',
  label: 'Map',
  icon: MapIcon
},
{
  path: '/devices',
  label: 'Devices',
  icon: Cpu
},
{
  path: '/profile',
  label: 'Profile',
  icon: User
}];

export function BottomNav() {
  const isAlertActive = useAppStore((state) => state.isAlertActive);
  return (
    <nav
      className={cn(
        'absolute bottom-6 left-6 right-6 bg-brand-card/90 backdrop-blur-xl border border-brand-border shadow-[0_8px_32px_rgba(0,0,0,0.3)] rounded-full z-50 transition-colors duration-300 overflow-hidden',
        isAlertActive && 'border-brand-alert/50'
      )}>
      
      <div className="flex justify-around items-center h-16 px-2">
        {navItems.map((item) =>
        <NavLink
          key={item.path}
          to={item.path}
          className={({ isActive }) =>
          cn(
            'flex flex-col items-center justify-center w-full h-full space-y-1 relative',
            isActive ?
            isAlertActive ?
            'text-brand-alert' :
            'text-brand-text' :
            'text-brand-muted hover:text-brand-text'
          )
          }>
          
            {({ isActive }) =>
          <>
                <item.icon
              className="w-5 h-5 z-10"
              strokeWidth={isActive ? 2.5 : 2} />
            
                <span className="text-[10px] font-medium z-10">
                  {item.label}
                </span>
                {isActive &&
            <motion.div
              layoutId="nav-indicator"
              className={cn(
                'absolute inset-1 rounded-full opacity-30',
                isAlertActive ? 'bg-brand-alert' : 'bg-brand-primary'
              )}
              initial={false}
              transition={{
                type: 'spring',
                stiffness: 500,
                damping: 30
              }} />

            }
              </>
          }
          </NavLink>
        )}
      </div>
    </nav>);

}