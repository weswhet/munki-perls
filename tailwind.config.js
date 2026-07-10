/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./site/**/*.{html,js}'],
  corePlugins: {
    preflight: false
  },
  prefix: 'tw-',
  theme: {
    extend: {
      colors: {
        ink: '#241f1a',
        paper: '#f3ecde',
        orange: '#c94c19',
        faded: '#70675d'
      },
      fontFamily: {
        serif: ['Georgia', 'Times New Roman', 'serif'],
        mono: ['Menlo', 'Monaco', 'Courier New', 'monospace']
      },
      letterSpacing: {
        poster: '-0.055em'
      }
    }
  },
  plugins: []
};
