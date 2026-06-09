import React from 'react';
import { Outlet } from 'react-router-dom';
import { BottomNav } from './BottomNav';
import { NotificationsPanel } from './NotificationsPanel';
import { useAppStore } from '../store/useAppStore';
import { cn } from '../lib/utils';
import { motion, AnimatePresence } from 'framer-motion';
import { AlertTriangle } from 'lucide-react';
export function Layout() {
  const isAlertActive = useAppStore((state) => state.isAlertActive);
  return (
    <div className="min-h-screen bg-black flex justify-center overflow-hidden">
      {/* Mobile Device Simulator Wrapper */}
      <div className="w-full max-w-md bg-brand-dark h-[100dvh] relative shadow-2xl overflow-hidden flex flex-col">
        {/* Global Alert Banner */}
        <AnimatePresence>
          {isAlertActive &&
          <motion.div
            initial={{
              height: 0,
              opacity: 0
            }}
            animate={{
              height: 'auto',
              opacity: 1
            }}
            exit={{
              height: 0,
              opacity: 0
            }}
            className="bg-brand-alert text-white px-4 py-3 flex items-center justify-center gap-2 z-40 shadow-md">
            
              <motion.div
              animate={{
                scale: [1, 1.2, 1]
              }}
              transition={{
                repeat: Infinity,
                duration: 1
              }}>
              
                <AlertTriangle className="w-5 h-5" />
              </motion.div>
              <span className="font-bold text-sm tracking-wide uppercase">
                Fire Alert Active
              </span>
            </motion.div>
          }
        </AnimatePresence>

        {/* Main Content Area */}
        <main
          className={cn(
            'flex-1 overflow-y-auto pb-28 transition-colors duration-500',
            isAlertActive ? 'bg-brand-alert/10' : 'bg-brand-dark'
          )}>
          
          <Outlet />
        </main>

        <BottomNav />
        <NotificationsPanel />
      </div>
    </div>);

}