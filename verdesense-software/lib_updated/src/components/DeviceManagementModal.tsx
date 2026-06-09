import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Cpu, MapPin, Battery } from 'lucide-react';
interface DeviceManagementModalProps {
  isOpen: boolean;
  onClose: () => void;
  device?: any; // Pass device to edit, or undefined to add
}
export function DeviceManagementModal({
  isOpen,
  onClose,
  device
}: DeviceManagementModalProps) {
  const [name, setName] = useState(device?.name || '');
  const [type, setType] = useState(device?.type || 'smoke');
  const [zone, setZone] = useState(device?.zone || 'Zone A');
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    // Handle save logic here
    onClose();
  };
  return (
    <AnimatePresence>
      {isOpen &&
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
          onClick={onClose}
          className="absolute inset-0 bg-black/60 backdrop-blur-sm z-[60]" />
        
          <motion.div
          initial={{
            opacity: 0,
            scale: 0.95,
            y: 20
          }}
          animate={{
            opacity: 1,
            scale: 1,
            y: 0
          }}
          exit={{
            opacity: 0,
            scale: 0.95,
            y: 20
          }}
          className="absolute top-1/2 left-4 right-4 -translate-y-1/2 bg-brand-dark border border-brand-border rounded-[2rem] shadow-2xl z-[70] overflow-hidden">
          
            <div className="flex items-center justify-between p-5 border-b border-brand-border bg-brand-card">
              <h2 className="text-lg font-bold text-brand-text">
                {device ? 'Edit Device' : 'Add New Device'}
              </h2>
              <button
              onClick={onClose}
              className="p-2 bg-brand-dark rounded-full text-brand-muted border border-brand-border hover:text-brand-text">
              
                <X className="w-5 h-5" />
              </button>
            </div>
            <form onSubmit={handleSubmit} className="p-5 space-y-5">
              <div className="space-y-1.5">
                <label className="text-xs font-bold text-brand-muted uppercase pl-1">
                  Device Name
                </label>
                <div className="relative">
                  <Cpu className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-brand-muted" />
                  <input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="e.g. Main Warehouse Sensor"
                  className="w-full pl-12 pr-4 py-3.5 bg-brand-card border border-brand-border text-brand-text rounded-full focus:outline-none focus:ring-2 focus:ring-brand-primary focus:border-transparent transition-all placeholder:text-brand-muted/50"
                  required />
                
                </div>
              </div>

              <div className="space-y-1.5">
                <label className="text-xs font-bold text-brand-muted uppercase pl-1">
                  Sensor Type
                </label>
                <select
                value={type}
                onChange={(e) => setType(e.target.value)}
                className="w-full px-5 py-3.5 bg-brand-card border border-brand-border text-brand-text rounded-full focus:outline-none focus:ring-2 focus:ring-brand-primary focus:border-transparent transition-all appearance-none">
                
                  <option value="smoke">Smoke / Fire</option>
                  <option value="occupancy">Occupancy Tracker</option>
                  <option value="temperature">Temperature</option>
                </select>
              </div>

              <div className="space-y-1.5">
                <label className="text-xs font-bold text-brand-muted uppercase pl-1">
                  Location / Zone
                </label>
                <div className="relative">
                  <MapPin className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-brand-muted" />
                  <input
                  type="text"
                  value={zone}
                  onChange={(e) => setZone(e.target.value)}
                  placeholder="e.g. Zone A"
                  className="w-full pl-12 pr-4 py-3.5 bg-brand-card border border-brand-border text-brand-text rounded-full focus:outline-none focus:ring-2 focus:ring-brand-primary focus:border-transparent transition-all placeholder:text-brand-muted/50"
                  required />
                
                </div>
              </div>

              <button
              type="submit"
              className="w-full py-4 mt-2 bg-brand-primary hover:brightness-110 text-brand-text font-bold rounded-full shadow-lg shadow-brand-primary/20 transition-colors">
              
                {device ? 'Save Changes' : 'Add Device'}
              </button>
            </form>
          </motion.div>
        </>
      }
    </AnimatePresence>);

}