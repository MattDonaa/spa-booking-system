import { describe, expect, it } from 'vitest';

import {
  formatDate,
  formatDateTime,
  formatMoney,
  humanizeStatus,
} from '@/lib/format';

describe('formatMoney', () => {
  it('formats cents as ZAR currency', () => {
    const result = formatMoney(100000);
    expect(result).toContain('1');
    expect(result).toContain('000');
    expect(result).toMatch(/R/); // ZAR symbol
  });

  it('handles zero and defaults', () => {
    expect(formatMoney(0)).toMatch(/0/);
  });

  it('respects an explicit currency', () => {
    expect(formatMoney(5000, 'USD')).toMatch(/\$|US/);
  });
});

describe('humanizeStatus', () => {
  it('title-cases underscored enum values', () => {
    expect(humanizeStatus('pending_hold')).toBe('Pending Hold');
    expect(humanizeStatus('no_show')).toBe('No Show');
    expect(humanizeStatus('confirmed')).toBe('Confirmed');
  });
});

describe('date formatters', () => {
  it('formats a date and datetime without throwing', () => {
    const iso = '2026-07-24T09:30:00.000Z';
    expect(typeof formatDate(iso)).toBe('string');
    expect(typeof formatDateTime(iso)).toBe('string');
    expect(formatDate(iso).length).toBeGreaterThan(0);
  });
});
