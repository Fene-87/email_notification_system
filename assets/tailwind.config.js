// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require('tailwindcss/plugin')

module.exports = {
  content: [
    './js/**/*.js',
    '../lib/email_notification_system_web.ex',
    '../lib/email_notification_system_web/**/*.*ex'
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}