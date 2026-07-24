#!/usr/bin/env node
// ============================================================================
// Pre-deploy environment validation.
// ----------------------------------------------------------------------------
// Fails fast (exit 1) when a required environment variable is missing, before
// a build or deploy proceeds. Run in CI and locally: `npm run validate-env`.
// ============================================================================

const REQUIRED = {
  app: ['NEXT_PUBLIC_APP_URL', 'NEXT_PUBLIC_SUPABASE_URL', 'NEXT_PUBLIC_SUPABASE_ANON_KEY'],
  server: ['SUPABASE_SERVICE_ROLE_KEY'],
};

// Required only when the corresponding feature is enabled in production.
const RECOMMENDED = [
  'APP_URL',
  'PAYFAST_MERCHANT_ID',
  'PAYFAST_MERCHANT_KEY',
  'OZOW_SITE_CODE',
  'OZOW_PRIVATE_KEY',
  'EMAIL_API_KEY',
  'EMAIL_FROM_ADDRESS',
  'WHATSAPP_API_TOKEN',
  'WHATSAPP_PHONE_NUMBER_ID',
];

const missing = [];
for (const group of Object.values(REQUIRED)) {
  for (const key of group) {
    if (!process.env[key] || process.env[key].trim() === '') missing.push(key);
  }
}

const missingRecommended = RECOMMENDED.filter(
  (k) => !process.env[k] || process.env[k].trim() === '',
);

if (missingRecommended.length > 0) {
  console.warn(
    `⚠  Optional/feature env vars not set: ${missingRecommended.join(', ')}`,
  );
}

if (missing.length > 0) {
  console.error(`✖ Missing required environment variables:\n  - ${missing.join('\n  - ')}`);
  process.exit(1);
}

console.log('✓ All required environment variables are present.');
