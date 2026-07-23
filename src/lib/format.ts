/**
 * Shared display formatters. Monetary amounts are stored as integer minor
 * units (cents) throughout the system.
 */

export function formatMoney(cents: number, currency = 'ZAR'): string {
  return new Intl.NumberFormat('en-ZA', {
    style: 'currency',
    currency,
  }).format((cents ?? 0) / 100);
}

export function formatDateTime(value: string | Date): string {
  const date = typeof value === 'string' ? new Date(value) : value;
  return new Intl.DateTimeFormat('en-ZA', {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(date);
}

export function formatDate(value: string | Date): string {
  const date = typeof value === 'string' ? new Date(value) : value;
  return new Intl.DateTimeFormat('en-ZA', { dateStyle: 'medium' }).format(date);
}

/** Human-readable label for a status enum value (e.g. pending_hold → Pending Hold). */
export function humanizeStatus(status: string): string {
  return status
    .split('_')
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(' ');
}
