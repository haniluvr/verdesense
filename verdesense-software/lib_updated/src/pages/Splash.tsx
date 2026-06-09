import React, { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { ShieldCheck } from 'lucide-react';
import { motion } from 'framer-motion';
export function Splash() {
  const navigate = useNavigate();
  useEffect(() => {
    const timer = setTimeout(() => {
      navigate('/onboarding');
    }, 2500);
    return () => clearTimeout(timer);
  }, [navigate]);
  return (
    <div className="min-h-screen bg-black flex justify-center overflow-hidden">
      <div className="w-full max-w-md bg-brand-dark h-[100dvh] relative shadow-2xl overflow-hidden flex flex-col items-center justify-center text-brand-text">
        <motion.div
          initial={{
            scale: 0.8,
            opacity: 0
          }}
          animate={{
            scale: 1,
            opacity: 1
          }}
          transition={{
            type: 'spring',
            damping: 20,
            stiffness: 100
          }}
          className="flex flex-col items-center">
          
          <div className="p-6 bg-brand-card rounded-full border border-brand-border mb-6 shadow-[0_0_40px_rgba(157,91,101,0.2)]">
            <ShieldCheck className="w-20 h-20 text-brand-primary" />
          </div>
          <h1 className="text-4xl font-bold tracking-tight">VerdeSense</h1>
          <p className="text-brand-muted mt-2 font-medium">
            Smart Farm Monitoring
          </p>
        </motion.div>

        <motion.div
          className="absolute bottom-12 flex space-x-2"
          initial={{
            opacity: 0
          }}
          animate={{
            opacity: 1
          }}
          transition={{
            delay: 1
          }}>
          
          <div
            className="w-2 h-2 bg-brand-primary rounded-full animate-bounce"
            style={{
              animationDelay: '0ms'
            }} />
          
          <div
            className="w-2 h-2 bg-brand-primary rounded-full animate-bounce"
            style={{
              animationDelay: '150ms'
            }} />
          
          <div
            className="w-2 h-2 bg-brand-primary rounded-full animate-bounce"
            style={{
              animationDelay: '300ms'
            }} />
          
        </motion.div>
      </div>
    </div>);

}