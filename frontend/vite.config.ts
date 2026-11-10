import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// In dev the SPA and Rails share one origin: Vite proxies /api and /auth to
// Rails, keeping the Host header so OAuth callbacks come back to :5173.
const apiTarget = process.env.VITE_API_TARGET ?? 'http://localhost:3000'
const proxy = { target: apiTarget, changeOrigin: false }

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    // Lets other containers on the dev network (e.g. a headless browser) load the app.
    allowedHosts: ['frontend'],
    proxy: { '/api': proxy, '/auth': proxy },
    // Bind mounts from Windows into Docker don't deliver file events.
    watch: process.env.VITE_USE_POLLING ? { usePolling: true, interval: 300 } : undefined,
  },
})
