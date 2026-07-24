import { describe, expect, it } from 'vitest';

import {
  buildResponsesValidator,
  defaultValueFor,
  initialResponses,
} from '@/features/intake/schemas';
import type { FormSchema } from '@/features/intake/types';

const schema: FormSchema = [
  { key: 'name', label: 'Name', type: 'text', required: true },
  { key: 'notes', label: 'Notes', type: 'textarea' },
  {
    key: 'allergies',
    label: 'Allergies',
    type: 'checkbox',
    required: true,
    options: [
      { label: 'Nuts', value: 'nuts' },
      { label: 'Latex', value: 'latex' },
    ],
  },
  { key: 'consent', label: 'I consent', type: 'boolean', required: true },
];

describe('defaultValueFor', () => {
  it('returns type-appropriate empties', () => {
    expect(defaultValueFor(schema[0]!)).toBe('');
    expect(defaultValueFor(schema[2]!)).toEqual([]);
    expect(defaultValueFor(schema[3]!)).toBe(false);
  });
});

describe('initialResponses', () => {
  it('seeds every field, preferring saved values', () => {
    const result = initialResponses(schema, { name: 'Ada' });
    expect(result.name).toBe('Ada');
    expect(result.notes).toBe('');
    expect(result.allergies).toEqual([]);
    expect(result.consent).toBe(false);
  });
});

describe('buildResponsesValidator', () => {
  const validator = buildResponsesValidator(schema);

  it('rejects missing required fields', () => {
    const parsed = validator.safeParse({
      name: '',
      allergies: [],
      consent: false,
    });
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      const keys = parsed.error.issues.map((i) => i.path[0]);
      expect(keys).toContain('name');
      expect(keys).toContain('allergies');
      expect(keys).toContain('consent');
    }
  });

  it('accepts a fully completed form', () => {
    const parsed = validator.safeParse({
      name: 'Ada',
      notes: '',
      allergies: ['nuts'],
      consent: true,
    });
    expect(parsed.success).toBe(true);
  });
});
