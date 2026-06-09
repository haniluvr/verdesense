import { create } from 'zustand';

export type LogType = 'alert' | 'occupancy' | 'system';

export interface LogEvent {
  id: string;
  type: LogType;
  message: string;
  timestamp: Date;
}

interface AppState {
  isAlertActive: boolean;
  occupancy: number;
  logs: LogEvent[];
  alarmEnabled: boolean;
  notificationsEnabled: boolean;
  isNotificationsOpen: boolean;

  triggerAlert: () => void;
  resolveAlert: () => void;
  updateOccupancy: (newCount: number) => void;
  toggleAlarm: () => void;
  toggleNotifications: () => void;
  setNotificationsOpen: (isOpen: boolean) => void;
  addLog: (log: Omit<LogEvent, 'id' | 'timestamp'>) => void;
}

const initialLogs: LogEvent[] = [
{
  id: '1',
  type: 'system',
  message: 'System initialized',
  timestamp: new Date(Date.now() - 86400000)
},
{
  id: '2',
  type: 'occupancy',
  message: 'Occupancy increased to 3',
  timestamp: new Date(Date.now() - 3600000)
},
{
  id: '3',
  type: 'occupancy',
  message: 'Occupancy decreased to 2',
  timestamp: new Date(Date.now() - 1800000)
}];


export const useAppStore = create<AppState>((set) => ({
  isAlertActive: false,
  occupancy: 2,
  logs: initialLogs,
  alarmEnabled: true,
  notificationsEnabled: true,
  isNotificationsOpen: false,

  triggerAlert: () =>
  set((state) => {
    if (state.isAlertActive) return state;
    const newLog: LogEvent = {
      id: Math.random().toString(36).substring(7),
      type: 'alert',
      message: 'FIRE DETECTED in Zone A (Storage)',
      timestamp: new Date()
    };
    return {
      isAlertActive: true,
      logs: [newLog, ...state.logs]
    };
  }),

  resolveAlert: () =>
  set((state) => {
    if (!state.isAlertActive) return state;
    const newLog: LogEvent = {
      id: Math.random().toString(36).substring(7),
      type: 'system',
      message: 'Alert resolved by user',
      timestamp: new Date()
    };
    return {
      isAlertActive: false,
      logs: [newLog, ...state.logs]
    };
  }),

  updateOccupancy: (newCount) =>
  set((state) => {
    const newLog: LogEvent = {
      id: Math.random().toString(36).substring(7),
      type: 'occupancy',
      message: `Occupancy changed to ${newCount}`,
      timestamp: new Date()
    };
    return {
      occupancy: newCount,
      logs: [newLog, ...state.logs]
    };
  }),

  toggleAlarm: () => set((state) => ({ alarmEnabled: !state.alarmEnabled })),
  toggleNotifications: () =>
  set((state) => ({ notificationsEnabled: !state.notificationsEnabled })),
  setNotificationsOpen: (isOpen) => set({ isNotificationsOpen: isOpen }),

  addLog: (log) =>
  set((state) => ({
    logs: [
    {
      ...log,
      id: Math.random().toString(36).substring(7),
      timestamp: new Date()
    },
    ...state.logs]

  }))
}));