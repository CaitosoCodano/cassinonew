import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";

// The web client talks to the Rails JSON API on the same origin:
//   - development: Vite proxies /api and /up to the Rails server on :3000,
//     which keeps session cookies and CSRF same-origin (no CORS needed).
//   - production: the built SPA is served by Rails from public/.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      "/api": { target: "http://localhost:3000", changeOrigin: true },
      "/up": { target: "http://localhost:3000", changeOrigin: true },
    },
  },
  build: {
    outDir: "dist",
    sourcemap: false,
    chunkSizeWarningLimit: 900,
  },
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["./src/test/setup.ts"],
    css: false,
  },
});