import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ShieldCheck, Mail, ArrowLeft } from 'lucide-react';
export function ForgetPassword() {
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [submitted, setSubmitted] = useState(false);
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitted(true);
  };
  return (
    <div className="min-h-screen bg-black flex justify-center overflow-hidden">
      <div className="w-full max-w-md bg-brand-dark h-[100dvh] relative shadow-2xl overflow-hidden flex flex-col">
        <div className="p-4 pt-8">
          <button
            onClick={() => navigate(-1)}
            className="w-10 h-10 bg-brand-card border border-brand-border rounded-full shadow-sm flex items-center justify-center text-brand-text hover:bg-brand-border transition-colors">
            
            <ArrowLeft className="w-5 h-5" />
          </button>
        </div>

        <div className="flex-1 px-6 pt-8 flex flex-col">
          <div className="flex justify-center mb-8">
            <div className="p-4 bg-brand-card rounded-full text-brand-primary border border-brand-border shadow-[0_0_30px_rgba(157,91,101,0.15)]">
              <ShieldCheck className="w-12 h-12" />
            </div>
          </div>

          <h1 className="text-2xl font-bold text-brand-text text-center mb-2">
            Reset Password
          </h1>
          <p className="text-brand-muted text-center mb-8 text-sm">
            Enter your email address and we'll send you a link to reset your
            password.
          </p>

          {submitted ?
          <div className="bg-brand-primary/10 border border-brand-primary/30 text-brand-primary p-4 rounded-3xl text-center text-sm font-medium">
              Check your email for the reset link!
            </div> :

          <form onSubmit={handleSubmit} className="space-y-4">
              <div className="space-y-1">
                <label className="text-xs font-bold text-brand-muted uppercase pl-1">
                  Email Address
                </label>
                <div className="relative">
                  <Mail className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-brand-muted" />
                  <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="farmer@verdesense.com"
                  className="w-full pl-12 pr-4 py-3.5 bg-brand-card border border-brand-border text-brand-text rounded-full focus:outline-none focus:ring-2 focus:ring-brand-primary focus:border-transparent transition-all placeholder:text-brand-muted/50"
                  required />
                
                </div>
              </div>
              <button
              type="submit"
              className="w-full py-4 bg-brand-primary hover:brightness-110 text-brand-text font-bold rounded-full shadow-lg shadow-brand-primary/20 transition-colors mt-4">
              
                Send Reset Link
              </button>
            </form>
          }
        </div>
      </div>
    </div>);

}