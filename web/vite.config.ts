import { reactRouter } from "@react-router/dev/vite";
import tailwindcss from "@tailwindcss/vite";
import { defineConfig } from "vite";

const apiTarget = process.env.OPENWEER_API_URL ?? "http://127.0.0.1:8000";

export default defineConfig({
  plugins: [tailwindcss(), reactRouter()],
  resolve: {
    tsconfigPaths: true,
  },
  server: {
    proxy: {
      "/api": { target: apiTarget, changeOrigin: true },
      "/tiles": { target: apiTarget, changeOrigin: true },
    },
  },
});
