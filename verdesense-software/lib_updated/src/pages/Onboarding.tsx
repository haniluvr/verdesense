import React, { useState, createElement } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { Flame, Users, BellRing, ChevronRight } from 'lucide-react';
import { cn } from '../lib/utils';
const slides = [
{
  id: 'fire-guard',
  title: '24/7 Fire Guard',
  description:
  'Quickly senses smoke or flames from a distance to stop fires early and protect your harvest.',
  icon: Flame,
  color: 'text-brand-alert',
  bgColor: 'bg-brand-alert/10 border border-brand-alert/20'
},
{
  id: 'smart-tracker',
  title: 'Smart Tracker',
  description:
  'Keeps track of how many people enter or leave the storage building for safety during emergencies.',
  icon: Users,
  color: 'text-blue-400',
  bgColor: 'bg-blue-900/20 border border-blue-500/20'
},
{
  id: 'real-time-alerts',
  title: 'Real-Time Alerts',
  description:
  'Sends an instant alert to your mobile phone so you can monitor the farm from anywhere.',
  icon: BellRing,
  color: 'text-brand-primary',
  bgColor: 'bg-brand-primary/10 border border-brand-primary/20'
}];

export function Onboarding() {
  const navigate = useNavigate();
  const [currentIndex, setCurrentIndex] = useState(0);
  const [direction, setDirection] = useState(0);
  const slideVariants = {
    enter: (direction: number) => ({
      x: direction > 0 ? 1000 : -1000,
      opacity: 0
    }),
    center: {
      zIndex: 1,
      x: 0,
      opacity: 1
    },
    exit: (direction: number) => ({
      zIndex: 0,
      x: direction < 0 ? 1000 : -1000,
      opacity: 0
    })
  };
  const swipeConfidenceThreshold = 10000;
  const swipePower = (offset: number, velocity: number) => {
    return Math.abs(offset) * velocity;
  };
  const paginate = (newDirection: number) => {
    if (currentIndex + newDirection < 0) return;
    if (currentIndex + newDirection >= slides.length) {
      navigate('/login');
      return;
    }
    setDirection(newDirection);
    setCurrentIndex(currentIndex + newDirection);
  };
  return (
    <div className="min-h-screen bg-black flex justify-center overflow-hidden">
      <div className="w-full max-w-md bg-brand-dark h-[100dvh] relative shadow-2xl overflow-hidden flex flex-col">
        {/* Skip Button */}
        <div className="absolute top-0 left-0 right-0 p-6 flex justify-end z-50">
          <button
            onClick={() => navigate('/login')}
            className="text-sm font-bold text-brand-muted hover:text-brand-text transition-colors">
            
            Skip
          </button>
        </div>

        {/* Slides Container */}
        <div className="flex-1 relative flex items-center justify-center">
          <AnimatePresence initial={false} custom={direction}>
            <motion.div
              key={currentIndex}
              custom={direction}
              variants={slideVariants}
              initial="enter"
              animate="center"
              exit="exit"
              transition={{
                x: {
                  type: 'spring',
                  stiffness: 300,
                  damping: 30
                },
                opacity: {
                  duration: 0.2
                }
              }}
              drag="x"
              dragConstraints={{
                left: 0,
                right: 0
              }}
              dragElastic={1}
              onDragEnd={(e, { offset, velocity }) => {
                const swipe = swipePower(offset.x, velocity.x);
                if (swipe < -swipeConfidenceThreshold) {
                  paginate(1);
                } else if (swipe > swipeConfidenceThreshold) {
                  paginate(-1);
                }
              }}
              className="absolute inset-0 flex flex-col items-center justify-center p-8 text-center">
              
              <div
                className={cn(
                  'w-32 h-32 rounded-full flex items-center justify-center mb-8',
                  slides[currentIndex].bgColor
                )}>
                
                {createElement(slides[currentIndex].icon, {
                  className: cn('w-16 h-16', slides[currentIndex].color)
                })}
              </div>
              <h2 className="text-3xl font-bold text-brand-text mb-4">
                {slides[currentIndex].title}
              </h2>
              <p className="text-brand-muted leading-relaxed">
                {slides[currentIndex].description}
              </p>
            </motion.div>
          </AnimatePresence>
        </div>

        {/* Bottom Controls */}
        <div className="p-8 pb-12 flex flex-col items-center gap-8 z-50 bg-gradient-to-t from-brand-dark via-brand-dark to-transparent">
          {/* Dots */}
          <div className="flex gap-2">
            {slides.map((_, index) =>
            <div
              key={index}
              className={cn(
                'h-2 rounded-full transition-all duration-300',
                index === currentIndex ?
                'w-8 bg-brand-primary' :
                'w-2 bg-brand-border'
              )} />

            )}
          </div>

          {/* Next/Start Button */}
          <button
            onClick={() => paginate(1)}
            className="w-full py-4 bg-brand-primary hover:brightness-110 text-brand-text font-bold rounded-full shadow-lg shadow-brand-primary/20 transition-all flex items-center justify-center gap-2 active:scale-[0.98]">
            
            {currentIndex === slides.length - 1 ? 'Get Started' : 'Next'}
            {currentIndex !== slides.length - 1 &&
            <ChevronRight className="w-5 h-5" />
            }
          </button>
        </div>
      </div>
    </div>);

}