import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Layout } from './components/Layout';
import { Dashboard } from './pages/Dashboard';
import { MapView } from './pages/Map';
import { Logs } from './pages/Logs';
import { Settings } from './pages/Settings';
import { Splash } from './pages/Splash';
import { Analytics } from './pages/Analytics';
import { Devices } from './pages/Devices';
import { Profile } from './pages/Profile';
import { EditProfile } from './pages/EditProfile';
import { UserManagement } from './pages/UserManagement';
import { ForgetPassword } from './pages/ForgetPassword';
import { Onboarding } from './pages/Onboarding';
import { Login } from './pages/Login';
import { useScreenInit } from './useScreenInit';
export function App() {
  useScreenInit();
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/splash" element={<Splash />} />
        <Route path="/onboarding" element={<Onboarding />} />
        <Route path="/login" element={<Login />} />
        <Route path="/forgot-password" element={<ForgetPassword />} />
        <Route path="/" element={<Layout />}>
          <Route index element={<Dashboard />} />
          <Route path="map" element={<MapView />} />
          <Route path="devices" element={<Devices />} />
          <Route path="profile" element={<Profile />} />
          <Route path="analytics" element={<Analytics />} />
          <Route path="logs" element={<Logs />} />
          <Route path="settings" element={<Settings />} />
          <Route path="edit-profile" element={<EditProfile />} />
          <Route path="user-management" element={<UserManagement />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>);

}