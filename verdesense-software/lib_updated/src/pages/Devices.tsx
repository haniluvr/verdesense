import React, { useState } from 'react';
import {
  Cpu,
  Battery,
  BatteryMedium,
  BatteryLow,
  Plus,
  Wifi,
  WifiOff } from
'lucide-react';
import { DeviceManagementModal } from '../components/DeviceManagementModal';
import { cn } from '../lib/utils';
const initialDevices = [
{
  id: 1,
  name: 'Main Warehouse',
  type: 'smoke',
  zone: 'Zone A',
  status: 'online',
  battery: 85
},
{
  id: 2,
  name: 'Greenhouse Alpha',
  type: 'smoke',
  zone: 'Zone B',
  status: 'online',
  battery: 42
},
{
  id: 3,
  name: 'Entrance Gate',
  type: 'occupancy',
  zone: 'Gate 1',
  status: 'online',
  battery: 95
},
{
  id: 4,
  name: 'Storage Beta',
  type: 'smoke',
  zone: 'Zone C',
  status: 'offline',
  battery: 10
}];

export function Devices() {
  const [isModalOpen, setModalOpen] = useState(false);
  const [selectedDevice, setSelectedDevice] = useState<any>(null);
  const handleAdd = () => {
    setSelectedDevice(null);
    setModalOpen(true);
  };
  const handleEdit = (device: any) => {
    setSelectedDevice(device);
    setModalOpen(true);
  };
  const getBatteryIcon = (level: number) => {
    if (level > 70) return <Battery className="w-4 h-4 text-brand-primary" />;
    if (level > 20) return <BatteryMedium className="w-4 h-4 text-amber-500" />;
    return <BatteryLow className="w-4 h-4 text-brand-alert" />;
  };
  return (
    <div className="p-4 space-y-4">
      <header className="pt-4 pb-2 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-brand-text">Devices</h1>
          <p className="text-brand-muted text-sm">
            Manage sensors and trackers
          </p>
        </div>
        <button
          onClick={handleAdd}
          className="w-10 h-10 bg-brand-primary text-white rounded-full flex items-center justify-center shadow-md hover:brightness-110 transition-colors">
          
          <Plus className="w-6 h-6" />
        </button>
      </header>

      <div className="space-y-3">
        {initialDevices.map((device) =>
        <div
          key={device.id}
          onClick={() => handleEdit(device)}
          className="bg-brand-card p-4 rounded-3xl shadow-sm border border-brand-border flex items-center gap-4 cursor-pointer hover:border-brand-primary/50 transition-colors">
          
            <div
            className={cn(
              'p-3 rounded-xl',
              device.status === 'online' ?
              'bg-brand-primary/20 text-brand-primary' :
              'bg-brand-dark text-brand-muted'
            )}>
            
              <Cpu className="w-6 h-6" />
            </div>

            <div className="flex-1 min-w-0">
              <h3 className="font-bold text-brand-text truncate">
                {device.name}
              </h3>
              <p className="text-xs text-brand-muted truncate">
                {device.zone} • {device.type}
              </p>
            </div>

            <div className="flex flex-col items-end gap-2">
              <div className="flex items-center gap-1 text-xs font-medium">
                {device.status === 'online' ?
              <span className="text-brand-primary flex items-center gap-1">
                    <Wifi className="w-3 h-3" /> Online
                  </span> :

              <span className="text-brand-muted flex items-center gap-1">
                    <WifiOff className="w-3 h-3" /> Offline
                  </span>
              }
              </div>
              <div className="flex items-center gap-1 text-xs font-medium text-brand-muted">
                {getBatteryIcon(device.battery)}
                {device.battery}%
              </div>
            </div>
          </div>
        )}
      </div>

      <DeviceManagementModal
        isOpen={isModalOpen}
        onClose={() => setModalOpen(false)}
        device={selectedDevice} />
      
    </div>);

}