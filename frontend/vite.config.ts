import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// In local dev, proxy /api to the FastAPI backend so the frontend can use
// relative URLs (matching the nginx reverse-proxy setup used in Docker).
export default defineConfig({
  plugins: [react()],
  server: {
    host: true,
    port: 5173,
    proxy: {
      "/api": {
        target: process.env.VITE_PROXY_TARGET || "http://localhost:8000",
        changeOrigin: true,
      },
    },
  },
});
