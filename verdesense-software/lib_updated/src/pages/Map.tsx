import React, { useEffect, useState, Fragment } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Circle } from 'react-leaflet';
import { useAppStore } from '../store/useAppStore';
import { MapPin, AlertTriangle } from 'lucide-react';
import L from 'leaflet';
import { motion } from 'framer-motion';
// Fix for default marker icons in React-Leaflet
delete (L.Icon.Default.prototype as any)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl:
  'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
  iconUrl:
  'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
  shadowUrl:
  'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png'
});
// Custom icons
const createCustomIcon = (color: string) =>
L.divIcon({
  className: 'custom-icon',
  html: `<div style="background-color: ${color}; width: 24px; height: 24px; border-radius: 50%; border: 3px solid white; box-shadow: 0 2px 5px rgba(0,0,0,0.3);"></div>`,
  iconSize: [24, 24],
  iconAnchor: [12, 12]
});
const safeIcon = createCustomIcon('#9d5b65'); // brand-primary
const alertIcon = createCustomIcon('#ef4444'); // brand-alert
const FARM_CENTER: [number, number] = [36.7783, -119.4179]; // Example coordinates (California)
const ZONES = [
{
  id: 1,
  name: 'Main Warehouse',
  pos: [36.7783, -119.4179] as [number, number],
  radius: 50,
  isDangerZone: true
},
{
  id: 2,
  name: 'Greenhouse Alpha',
  pos: [36.7795, -119.416] as [number, number],
  radius: 40,
  isDangerZone: false
},
{
  id: 3,
  name: 'Greenhouse Beta',
  pos: [36.777, -119.419] as [number, number],
  radius: 40,
  isDangerZone: false
}];

export function MapView() {
  const isAlertActive = useAppStore((state) => state.isAlertActive);
  const [mapReady, setMapReady] = useState(false);
  useEffect(() => {
    // Small delay to ensure container is sized before rendering map
    const timer = setTimeout(() => setMapReady(true), 100);
    return () => clearTimeout(timer);
  }, []);
  return (
    <div className="h-full flex flex-col relative">
      {/* Overlay Header */}
      <div className="absolute top-0 left-0 right-0 z-[400] p-4 pointer-events-none">
        <div className="bg-brand-card/90 backdrop-blur-sm shadow-lg rounded-3xl p-4 border border-brand-border pointer-events-auto flex items-center justify-between">
          <div>
            <h2 className="font-bold text-brand-text flex items-center gap-2">
              <MapPin className="w-5 h-5 text-brand-primary" />
              Farm Overview
            </h2>
            <p className="text-xs text-brand-muted mt-1">
              Live sensor locations
            </p>
          </div>
          {isAlertActive &&
          <motion.div
            initial={{
              opacity: 0,
              scale: 0.8
            }}
            animate={{
              opacity: 1,
              scale: 1
            }}
            className="bg-brand-alert/20 text-brand-alert border border-brand-alert/50 px-3 py-1.5 rounded-full text-xs font-bold flex items-center gap-1">
            
              <AlertTriangle className="w-4 h-4" />
              DANGER ZONE
            </motion.div>
          }
        </div>
      </div>

      {/* Map Container */}
      <div className="flex-1 bg-brand-dark z-0">
        {mapReady &&
        <MapContainer
          center={FARM_CENTER}
          zoom={16}
          style={{
            height: '100%',
            width: '100%',
            backgroundColor: '#1A0B0E'
          }}
          zoomControl={false}>
          
            <TileLayer
            attribution='&copy; <a href="https://carto.com/">Carto</a>'
            url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png" />
          

            {ZONES.map((zone) => {
            const isAlerting = isAlertActive && zone.isDangerZone;
            return (
              <Fragment key={zone.id}>
                  <Circle
                  center={zone.pos}
                  radius={zone.radius}
                  pathOptions={{
                    color: isAlerting ? '#ef4444' : '#9d5b65',
                    fillColor: isAlerting ? '#ef4444' : '#9d5b65',
                    fillOpacity: isAlerting ? 0.4 : 0.2,
                    weight: 2
                  }} />
                
                  <Marker
                  position={zone.pos}
                  icon={isAlerting ? alertIcon : safeIcon}>
                  
                    <Popup className="dark-popup">
                      <div className="font-semibold text-slate-800">
                        {zone.name}
                      </div>
                      <div className="text-xs text-slate-500">
                        Status: {isAlerting ? 'FIRE DETECTED' : 'Safe'}
                      </div>
                    </Popup>
                  </Marker>
                </Fragment>);

          })}
          </MapContainer>
        }
      </div>
    </div>);

}