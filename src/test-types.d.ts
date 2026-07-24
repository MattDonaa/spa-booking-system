// Ambient type augmentation registering the vitest-axe accessibility matcher
// on vitest's expect (the matcher is wired up in vitest.setup.ts).
import 'vitest';

declare module 'vitest' {
  interface Assertion {
    toHaveNoViolations(): void;
  }
  interface AsymmetricMatchersContaining {
    toHaveNoViolations(): void;
  }
}
