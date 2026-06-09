import React from 'react';
import { useAppStore } from '../store/useAppStore';
import { Flame, Users, Info, Clock } from 'lucide-react';
import { cn } from '../lib/utils';
import { motion } from 'framer-motion';
export function Logs() {
  const logs = useAppStore((state) => state.logs);
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
  const getBgColor = (type: string) => {
    switch (type) {
      case 'alert':
        return 'bg-brand-alert/20 border-brand-alert';
      case 'occupancy':
        return 'bg-blue-900/30 border-blue-500/50';
      default:
        return 'bg-brand-primary/20 border-brand-primary/50';
    }
  };
  const formatTime = (date: Date) => {
    return new Intl.DateTimeFormat('en-US', {
      hour: 'numeric',
      minute: 'numeric',
      hour12: true,
      month: 'short',
      day: 'numeric'
    }).format(date);
  };
  return (
    <div className="p-4 space-y-4">
      <header className="pt-4 pb-2 sticky top-0 bg-brand-dark/80 backdrop-blur-md z-10">
        <h1 className="text-2xl font-bold text-brand-text">Activity Log</h1>
        <p className="text-brand-muted text-sm">
          History of alerts and occupancy
        </p>
      </header>

      <div className="space-y-4 relative before:absolute before:inset-0 before:ml-6 before:-translate-x-px md:before:mx-auto md:before:translate-x-0 before:h-full before:w-0.5 before:bg-gradient-to-b before:from-transparent before:via-brand-border before:to-transparent">
        {logs.map((log, index) =>
        <motion.div
          key={log.id}
          initial={{
            opacity: 0,
            y: 20
          }}
          animate={{
            opacity: 1,
            y: 0
          }}
          transition={{
            delay: index * 0.05
          }}
          className="relative flex items-center justify-between md:justify-normal md:odd:flex-row-reverse group is-active">
          
            {/* Timeline dot */}
            <div
            className={cn(
              'flex items-center justify-center w-8 h-8 rounded-full border-2 shrink-0 md:order-1 md:group-odd:-translate-x-1/2 md:group-even:translate-x-1/2 shadow-sm z-10',
              getBgColor(log.type)
            )}>
            
              {getIcon(log.type)}
            </div>

            {/* Content Card */}
            <div className="w-[calc(100%-3rem)] md:w-[calc(50%-2.5rem)] p-4 rounded-3xl bg-brand-card shadow-sm border border-brand-border ml-4 md:ml-0">
              <div className="flex items-center justify-between mb-1">
                <span
                className={cn(
                  'text-xs font-bold uppercase tracking-wider',
                  log.type === 'alert' ?
                  'text-brand-alert' :
                  log.type === 'occupancy' ?
                  'text-blue-400' :
                  'text-brand-primary'
                )}>
                
                  {log.type}
                </span>
                <span className="text-xs text-brand-muted flex items-center gap-1">
                  <Clock className="w-3 h-3" />
                  {formatTime(log.timestamp)}
                </span>
              </div>
              <p className="text-sm text-brand-text font-medium">
                {log.message}
              </p>
            </div>
          </motion.div>
        )}

        {logs.length === 0 &&
        <div className="text-center py-10 text-brand-muted">
            No activity recorded yet.
          </div>
        }
      </div>
    </div>);

}