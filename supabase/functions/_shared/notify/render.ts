// ============================================================================
// Template rendering: interpolate {{placeholder}} tokens from a payload.
// ============================================================================

export function render(
  template: string,
  payload: Record<string, unknown>,
): string {
  return template.replace(/\{\{\s*([a-z0-9_]+)\s*\}\}/gi, (_match, key) => {
    const value = payload[key];
    return value === undefined || value === null ? '' : String(value);
  });
}
