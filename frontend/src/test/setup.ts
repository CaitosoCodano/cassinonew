import "@testing-library/jest-dom/vitest";
import { cleanup } from "@testing-library/react";
import { afterEach, vi } from "vitest";

// Ensure each test starts clean.
afterEach(() => {
  cleanup();
  vi.clearAllMocks();
});