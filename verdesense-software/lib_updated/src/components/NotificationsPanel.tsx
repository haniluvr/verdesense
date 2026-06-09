import React from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Flame, Users, Info, Clock } from 'lucide-react';
import { useAppStore } from '../store/useAppStore';
import { cn } from '../lib/utils';
export function NotificationsPanel() {
  const { isNotificationsOpen, setNotificationsOpen, logs } = useAppStore();
  const getIcon = (type: string) => {
    switch (type) {
      case 'alert':
        return <Flame className="w-4 h-4 text-brand-alert" />;
      case 'occupancy':
        return <Users className="w-4 h-4 text-blue-400" />;
      default:
        return <Info className="w-4 h-4 text-brand-primary" />;
    }
  };
  const formatTime = (date: Date) => {
    return new Intl.DateTimeFormat('en-US', {
      hour: 'numeric',
      minute: 'numeric',
      hour12: true
    }).format(date);
  };
  return (
    <AnimatePresence>
      {isNotificationsOpen &&
      <>
          <motion.div
          initial={{
            opacity: 0
          }}
          animate={{
            opacity: 1
          }}
          exit={{
            opacity: 0
          }}
          onClick={() => setNotificationsOpen(false)}
          className="absolute inset-0 bg-black/60 backdrop-blur-sm z-[60]" />
        
          <motion.div
          initial={{
            y: '100%'
          }}
          animate={{
            y: 0
          }}
          exit={{
            y: '100%'
          }}
          transition={{
            type: 'spring',
            damping: 25,
            stiffness: 200
          }}
          className="absolute bottom-0 left-0 right-0 h-[80vh] bg-brand-dark border-t border-brand-border rounded-t-[2rem] shadow-2xl z-[70] flex flex-col overflow-hidden">
          
            <div className="flex items-center justify-between p-6 border-b border-brand-border">
              <h2 className="text-xl font-bold text-brand-text">
                Notifications
              </h2>
              <button
              onClick={() => setNotificationsOpen(false)}
              className="p-2 bg-brand-card rounded-full text-brand-muted hover:text-brand-text border border-brand-border">
              
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="flex-1 overflow-y-auto p-4 space-y-3">
              {logs.slice(0, 10).map((log) =>
            <div
              key={log.id}
              className="flex items-start gap-4 p-4 bg-brand-card border border-brand-border rounded-3xl">
              
                  <div
                className={cn(
                  'p-3 rounded-2xl shrink-0',
                  log.type === 'alert' ?
                  'bg-brand-alert/20 text-brand-alert' :
                  log.type === 'occupancy' ?
                  'bg-blue-900/30 text-blue-400' :
                  'bg-brand-primary/20 text-brand-primary'
                )}>
                
                    {getIcon(log.type)}
                  </div>
                  <div className="flex-1 pt-1">
                    <p className="text-sm font-medium text-brand-text leading-snug">
                      {log.message}
                    </p>
                    <p className="text-xs text-brand-muted flex items-center gap-1 mt-2">
                      <Clock className="w-3 h-3" /> {formatTime(log.timestamp)}
                    </p>
                  </div>
                </div>
            )}
              {logs.length === 0 &&
            <p className="text-center text-brand-muted text-sm py-8">
                  No recent notifications
                </p>
            }
            </div>
          </motion.div>
        </>
      }
    </AnimatePresence>);

}