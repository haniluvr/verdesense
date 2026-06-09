module.exports = {
  content: [
  './index.html',
  './src/**/*.{js,ts,jsx,tsx}'
],
  theme: {
    extend: {
      colors: {
        brand: {
          dark: '#1A0B0E',
          card: '#2A161A',
          border: '#4a2b33',
          primary: '#9d5b65',
          text: '#f3e8ea',
          muted: '#a38c91',
          alert: '#ef4444', // Brighter red for actual alerts
        }
      }
    },
  },
  plugins: [],
}