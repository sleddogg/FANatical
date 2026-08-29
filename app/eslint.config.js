import js from "@eslint/js";
import { defineConfig, globalIgnores } from "eslint/config";
import reactHooks from "eslint-plugin-react-hooks";
import reactRefresh from "eslint-plugin-react-refresh";
import globals from "globals";
import tseslint from "typescript-eslint";

const recommendedConfigs = [
  js.configs.recommended,
  ...tseslint.configs.recommended,
  reactHooks.configs.flat.recommended,
  reactRefresh.configs.vite,
];

function warningSeverity(ruleConfig) {
  const severity = Array.isArray(ruleConfig) ? ruleConfig[0] : ruleConfig;
  if (severity === 0 || severity === "off") return ruleConfig;
  return Array.isArray(ruleConfig) ? ["warn", ...ruleConfig.slice(1)] : "warn";
}

const recommendedWarnings = Object.fromEntries(
  recommendedConfigs.flatMap((config) =>
    Object.entries(config.rules ?? {}).map(([ruleName, ruleConfig]) => [
      ruleName,
      warningSeverity(ruleConfig),
    ]),
  ),
);

export default defineConfig([
  globalIgnores(["dist", "coverage", "playwright-report", "test-results", ".wrangler"]),
  {
    files: ["**/*.{ts,tsx}"],
    extends: recommendedConfigs,
    languageOptions: {
      ecmaVersion: "latest",
      globals: {
        ...globals.browser,
        ...globals.node,
      },
    },
    linterOptions: {
      reportUnusedDisableDirectives: "warn",
    },
    rules: {
      ...recommendedWarnings,
      "@typescript-eslint/no-unused-vars": [
        "error",
        {
          argsIgnorePattern: "^_",
          caughtErrorsIgnorePattern: "^_",
          ignoreRestSiblings: true,
          varsIgnorePattern: "^_",
        },
      ],
      "no-unreachable": "error",
      "react-hooks/exhaustive-deps": "error",
      "react-hooks/rules-of-hooks": "error",
    },
  },
]);
