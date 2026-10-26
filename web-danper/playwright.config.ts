import { defineConfig, devices } from "@playwright/test";
import { chromiumPath } from "./scripts/browser-path.mjs";
const local = chromiumPath();
export default defineConfig({
  testDir: "tests/ui",
  timeout: 45000,
  workers: 1,
  use: {
    baseURL: "http://127.0.0.1:5189",
    launchOptions: {
      ...(local ? { executablePath: local } : {}),
    },
  },
  projects: [
    { name: "desktop", use: { viewport: { width: 1440, height: 1000 } } },
    {
      name: "mobile",
      use: { ...devices["iPhone 13"], defaultBrowserType: "chromium" },
    },
  ],
  webServer: {
    command: "npm run dev -- --port 5189 --strictPort",
    url: "http://127.0.0.1:5189",
    reuseExistingServer: !process.env.CI,
    env: {
      VITE_FIREBASE_API_KEY: "",
      VITE_FIREBASE_PROJECT_ID: "",
      VITE_AUTHORIZED_UID: "",
      VITE_CLOUD_WRITES_ENABLED: "false",
    },
  },
  reporter: [
    ["list"],
    ["json", { outputFile: "test-results/ui-results.json" }],
  ],
});
