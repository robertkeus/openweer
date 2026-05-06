// ESLint flat config for the OpenWeer web app.
// Focused on correctness rules that strict TS doesn't already cover:
// React hook usage, JSX a11y, and a small set of high-signal stylistic rules.
import js from "@eslint/js";
import tseslint from "typescript-eslint";
import reactHooks from "eslint-plugin-react-hooks";
import jsxA11y from "eslint-plugin-jsx-a11y";
import globals from "globals";

export default [
  {
    ignores: [
      "build/**",
      ".react-router/**",
      "node_modules/**",
      "coverage/**",
      "public/**",
    ],
  },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ["app/**/*.{ts,tsx}", "tests/**/*.{ts,tsx}"],
    plugins: {
      "react-hooks": reactHooks,
      "jsx-a11y": jsxA11y,
    },
    languageOptions: {
      ecmaVersion: 2024,
      sourceType: "module",
      globals: {
        ...globals.browser,
        ...globals.node,
      },
      parserOptions: {
        ecmaFeatures: { jsx: true },
      },
    },
    rules: {
      ...reactHooks.configs.recommended.rules,
      ...jsxA11y.flatConfigs.recommended.rules,
      // The audit's whole point: strict TS already forbids `any`; keep that here too.
      "@typescript-eslint/no-explicit-any": "error",
      "@typescript-eslint/no-unused-vars": [
        "error",
        { argsIgnorePattern: "^_", varsIgnorePattern: "^_" },
      ],
      // react-hooks v7 introduced opinionated rules that fire on patterns this
      // codebase already uses intentionally (initial-state effects, Math.random
      // for SVG ids). Surface them as warnings so they're visible without
      // blocking CI on otherwise-correct code.
      "react-hooks/set-state-in-effect": "warn",
      "react-hooks/purity": "warn",
      // Tests stub event handlers and unused setup args; soften where it hurts.
      "no-empty-pattern": "off",
    },
  },
  {
    files: ["tests/**/*.{ts,tsx}", "app/**/*.test.{ts,tsx}"],
    rules: {
      "@typescript-eslint/no-explicit-any": "off",
    },
  },
];
