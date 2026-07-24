import { describe, expect, it } from 'vitest';

import { unwrapRpc } from '@/lib/rpc';

describe('unwrapRpc', () => {
  it('returns ok with data for a successful envelope', () => {
    const result = unwrapRpc<{ id: string }>(
      { ok: true, data: { id: 'abc' } },
      null,
    );
    expect(result.ok).toBe(true);
    if (result.ok) expect(result.data.id).toBe('abc');
  });

  it('maps an error envelope to a failed Result', () => {
    const result = unwrapRpc(
      { ok: false, error: { code: 'FORBIDDEN', message: 'nope' } },
      null,
    );
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe('FORBIDDEN');
      expect(result.error.message).toBe('nope');
    }
  });

  it('treats a transport error as INTERNAL', () => {
    const result = unwrapRpc(null, { message: 'connection reset' });
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error.code).toBe('INTERNAL');
  });

  it('treats an empty response as INTERNAL', () => {
    const result = unwrapRpc(null, null);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error.code).toBe('INTERNAL');
  });

  it('passes through field-level validation errors', () => {
    const result = unwrapRpc(
      {
        ok: false,
        error: {
          code: 'VALIDATION',
          message: 'bad',
          fields: { name: ['required'] },
        },
      },
      null,
    );
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error.fields?.name).toEqual(['required']);
  });
});
