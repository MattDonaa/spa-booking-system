import { expect, test } from '@playwright/test';

/**
 * Authentication and access-control flows.
 */
test.describe('authentication', () => {
  test('login page renders the sign-in form', async ({ page }) => {
    await page.goto('/login');
    await expect(
      page.getByRole('heading', { name: /welcome back/i }),
    ).toBeVisible();
    await expect(page.getByLabel('Email')).toBeVisible();
    await expect(page.getByLabel('Password')).toBeVisible();
  });

  test('signup page renders the registration form', async ({ page }) => {
    await page.goto('/signup');
    await expect(page.getByLabel('Full name')).toBeVisible();
    await expect(
      page.getByRole('button', { name: /create account/i }),
    ).toBeVisible();
  });

  test('unauthenticated access to the portal redirects to login', async ({
    page,
  }) => {
    await page.goto('/portal');
    await expect(page).toHaveURL(/\/login/);
  });

  test('unauthenticated access to admin redirects to login', async ({
    page,
  }) => {
    await page.goto('/admin');
    await expect(page).toHaveURL(/\/login/);
  });

  test('invalid credentials show an error', async ({ page }) => {
    await page.goto('/login');
    await page.getByLabel('Email').fill('nobody@example.com');
    await page.getByLabel('Password').fill('wrong-password');
    await page.getByRole('button', { name: /sign in/i }).click();
    await expect(page.getByRole('alert')).toContainText(/invalid/i);
  });
});
