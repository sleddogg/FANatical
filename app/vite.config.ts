import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";

export default defineConfig(({ mode }) => {
  const adminBuild = mode === "admin";

  return {
    plugins: [react()],
    publicDir: adminBuild ? "public-admin" : "public",
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
