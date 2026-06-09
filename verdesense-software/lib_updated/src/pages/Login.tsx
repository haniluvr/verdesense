import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { ShieldCheck, Mail, Lock, ArrowRight } from 'lucide-react';
export function Login() {
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const handleLogin = (e: React.FormEvent) => {
    e.preventDefault();
    // In a real app, authenticate here. For now, go straight to dashboard.
    navigate('/');
  };
  return (
    <div className="min-h-screen bg-black flex justify-center overflow-hidden">
      <div className="w-full max-w-md bg-brand-dark h-[100dvh] relative shadow-2xl overflow-hidden flex flex-col">
        <div className="flex-1 px-6 pt-16 flex flex-col">
          <div className="flex justify-center mb-6">
            <div className="p-4 bg-brand-card rounded-full text-brand-primary border border-brand-border shadow-[0_0_30px_rgba(157,91,101,0.15)]">
              <ShieldCheck className="w-16 h-16" />
            </div>
          </div>

          <h1 className="text-3xl font-bold text-brand-text text-center mb-2">
            Welcome Back
          </h1>
          <p className="text-brand-muted text-center mb-10 text-sm">
            Sign in to monitor your farm with VerdeSense
          </p>

          <form onSubmit={handleLogin} className="space-y-5">
            <div className="space-y-1.5">
              <label className="text-xs font-bold text-brand-muted uppercase tracking-wider pl-1">
                Email Address
              </label>
              <div className="relative">
                <Mail className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-brand-muted" />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="farmer@verdesense.com"
                  className="w-full pl-12 pr-4 py-3.5 bg-brand-card border border-brand-border text-brand-text rounded-full focus:outline-none focus:ring-2 focus:ring-brand-primary focus:border-transparent transition-all shadow-sm placeholder:text-brand-muted/50"
                  required />
                
              </div>
            </div>

            <div className="space-y-1.5">
              <label className="text-xs font-bold text-brand-muted uppercase tracking-wider pl-1">
                Password
              </label>
              <div className="relative">
                <Lock className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-brand-muted" />
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  className="w-full pl-12 pr-4 py-3.5 bg-brand-card border border-brand-border text-brand-text rounded-full focus:outline-none focus:ring-2 focus:ring-brand-primary focus:border-transparent transition-all shadow-sm placeholder:text-brand-muted/50"
                  required />
                
              </div>
            </div>

            <div className="flex justify-end pt-1">
              <Link
                to="/forgot-password"
                className="text-sm font-bold text-brand-primary hover:brightness-110 transition-colors">
                
                Forgot Password?
              </Link>
            </div>

            <button
              type="submit"
              className="w-full py-4 mt-4 bg-brand-primary hover:brightness-110 text-brand-text font-bold rounded-full shadow-lg shadow-brand-primary/20 transition-all flex items-center justify-center gap-2 active:scale-[0.98]">
              
              Sign In
              <ArrowRight className="w-5 h-5" />
            </button>
          </form>
        </div>

        <div className="p-6 text-center">
          <p className="text-sm text-brand-muted">
            Don't have an account?{' '}
            <button className="font-bold text-brand-primary hover:brightness-110 transition-colors">
              Contact Admin
            </button>
          </p>
        </div>
      </div>
    </div>);

}