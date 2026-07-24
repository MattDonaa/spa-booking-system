import { expect, test } from '@playwright/test';

/**
 * Basic smoke tests for the public marketing page.
 */
test.describe('public site', () => {
  test('home page renders the hero and highlights', async ({ page }) => {
    await page.goto('/');
    await expect(
      page.getByRole('heading', { name: /done properly/i }),
    ).toBeVisible();
    await expect(page.getByText(/Effortless Booking/i)).toBeVisible();
    await expect(page.getByText(/Private & Compliant/i)).toBeVisible();
  });

  test('theme toggle is present and operable', async ({ page }) => {
    await page.goto('/');
    const toggle = page.getByRole('button', { name: /switch to .* theme/i });
    await expect(toggle).toBeVisible();
    await toggle.click();
  });

  test('unknown routes render the 404 page', async ({ page }) => {
    const response = await page.goto('/this-route-does-not-exist');
    expect(response?.status()).toBe(404);
    await expect(page.getByText(/page not found/i)).toBeVisible();
  });
});
