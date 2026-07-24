import AxeBuilder from '@axe-core/playwright';
import { expect, test } from '@playwright/test';

/**
 * Automated accessibility checks on the public pages. Authenticated pages are
 * covered by the component-level a11y tests (Vitest + vitest-axe) and can be
 * extended here once a seeded test account is available.
 */
const publicPages = ['/', '/login', '/signup'];

for (const path of publicPages) {
  test(`${path} has no critical accessibility violations`, async ({ page }) => {
    await page.goto(path);
    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa'])
      .analyze();

    const serious = results.violations.filter(
      (v) => v.impact === 'serious' || v.impact === 'critical',
    );
    expect(serious, JSON.stringify(serious, null, 2)).toEqual([]);
  });
}
