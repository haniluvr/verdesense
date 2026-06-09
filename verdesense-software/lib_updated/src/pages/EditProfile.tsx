import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, User, Mail, Phone, Camera } from 'lucide-react';
export function EditProfile() {
  const navigate = useNavigate();
  const [name, setName] = useState('John Farmer');
  const [email, setEmail] = useState('john@verdesense.com');
  const [phone, setPhone] = useState('+1 (555) 123-4567');
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    navigate('/profile');
  };
  return (
    <div className="p-4 space-y-6">
      <header className="pt-4 pb-2 flex items-center gap-4">
        <button
          onClick={() => navigate(-1)}
          className="w-10 h-10 bg-brand-card border border-brand-border rounded-full shadow-sm flex items-center justify-center text-brand-text hover:bg-brand-border transition-colors">
          
          <ArrowLeft className="w-5 h-5" />
        </button>
        <h1 className="text-2xl font-bold text-brand-text">Edit Profile</h1>
      </header>

      <div className="flex justify-center">
        <div className="relative">
          <div className="w-24 h-24 bg-brand-primary/20 rounded-full flex items-center justify-center text-brand-primary border border-brand-primary/30">
            <User className="w-12 h-12" />
          </div>
          <button className="absolute bottom-0 right-0 w-8 h-8 bg-brand-primary text-brand-text rounded-full flex items-center justify-center shadow-md border-2 border-brand-dark">
            <Camera className="w-4 h-4" />
          </button>
        </div>
      </div>

      <form onSubmit={handleSubmit} className="space-y-5">
        <div className="space-y-1.5">
          <label className="text-xs font-bold text-brand-muted uppercase pl-1">
            Full Name
          </label>
          <div className="relative">
            <User className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-brand-muted" />
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full pl-12 pr-4 py-3.5 bg-brand-card border border-brand-border text-brand-text rounded-full focus:outline-none focus:ring-2 focus:ring-brand-primary focus:border-transparent transition-all" />
            
          </div>
        </div>

        <div className="space-y-1.5">
          <label className="text-xs font-bold text-brand-muted uppercase pl-1">
            Email Address
          </label>
          <div className="relative">
            <Mail className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-brand-muted" />
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full pl-12 pr-4 py-3.5 bg-brand-card border border-brand-border text-brand-text rounded-full focus:outline-none focus:ring-2 focus:ring-brand-primary focus:border-transparent transition-all" />
            
          </div>
        </div>

        <div className="space-y-1.5">
          <label className="text-xs font-bold text-brand-muted uppercase pl-1">
            Phone Number
          </label>
          <div className="relative">
            <Phone className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-brand-muted" />
            <input
              type="tel"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              className="w-full pl-12 pr-4 py-3.5 bg-brand-card border border-brand-border text-brand-text rounded-full focus:outline-none focus:ring-2 focus:ring-brand-primary focus:border-transparent transition-all" />
            
          </div>
        </div>

        <button
          type="submit"
          className="w-full py-4 mt-4 bg-brand-primary hover:brightness-110 text-brand-text font-bold rounded-full shadow-lg shadow-brand-primary/20 transition-colors">
          
          Save Changes
        </button>
      </form>
    </div>);

}