import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";

export default defineConfig(({ mode }) => {
  const adminBuild = mode === "admin";

  return {
    plugins: [react()],
    publicDir: adminBuild ? "public-admin" : "public",
    server: {
      proxy: {
        "/supabase": {
          target: "http://127.0.0.1:15421",
          changeOrigin: true,
          ws: true,
          rewrite: (path) => path.replace(/^\/supabase/, ""),
        },
      },
    },
    build: {
      outDir: adminBuild ? "dist-admin" : "dist",
    },
    test: {
      environment: "jsdom",
      setupFiles: ["./src/test/setup.ts"],
      css: true,
      exclude: ["e2e/**", "node_modules/**", "dist/**", "dist-admin/**"],
    },
  };
});
