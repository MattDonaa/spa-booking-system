'use client';

import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { cn } from '@/lib/utils';
import type { FormField, ResponseValue } from '@/features/intake/types';

interface FieldRendererProps {
  field: FormField;
  value: ResponseValue;
  error?: string;
  disabled?: boolean;
  onChange: (value: ResponseValue) => void;
}

/**
 * Renders a single dynamic form field based on its type. Controlled: value and
 * onChange are owned by the parent form.
 */
export function FieldRenderer({
  field,
  value,
  error,
  disabled,
  onChange,
}: FieldRendererProps) {
  const id = `field-${field.key}`;
  const describedBy = error
    ? `${id}-error`
    : field.help
      ? `${id}-help`
      : undefined;

  return (
    <div className="space-y-2">
      {field.type !== 'boolean' && (
        <Label htmlFor={id}>
          {field.label}
          {field.required && <span className="text-destructive"> *</span>}
        </Label>
      )}

      {renderControl()}

      {field.help && !error && (
        <p id={`${id}-help`} className="text-xs text-muted-foreground">
          {field.help}
        </p>
      )}
      {error && (
        <p id={`${id}-error`} className="text-xs text-destructive">
          {error}
        </p>
      )}
    </div>
  );

  function renderControl() {
    const invalid = Boolean(error);
    const ring = invalid
      ? 'border-destructive focus-visible:ring-destructive'
      : '';

    switch (field.type) {
      case 'textarea':
        return (
          <Textarea
            id={id}
            value={String(value ?? '')}
            placeholder={field.placeholder}
            disabled={disabled}
            aria-invalid={invalid}
            aria-describedby={describedBy}
            className={ring}
            onChange={(e) => onChange(e.target.value)}
          />
        );

      case 'select':
        return (
          <select
            id={id}
            value={String(value ?? '')}
            disabled={disabled}
            aria-invalid={invalid}
            aria-describedby={describedBy}
            className={cn(
              'flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:opacity-50',
              ring,
            )}
            onChange={(e) => onChange(e.target.value)}
          >
            <option value="">Select…</option>
            {field.options?.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
        );

      case 'radio':
        return (
          <div
            className="space-y-1"
            role="radiogroup"
            aria-describedby={describedBy}
          >
            {field.options?.map((o) => (
              <label key={o.value} className="flex items-center gap-2 text-sm">
                <input
                  type="radio"
                  name={id}
                  value={o.value}
                  checked={value === o.value}
                  disabled={disabled}
                  onChange={() => onChange(o.value)}
                  className="size-4"
                />
                {o.label}
              </label>
            ))}
          </div>
        );

      case 'checkbox': {
        const arr = Array.isArray(value) ? value : [];
        return (
          <div className="space-y-1" aria-describedby={describedBy}>
            {field.options?.map((o) => (
              <label key={o.value} className="flex items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  value={o.value}
                  checked={arr.includes(o.value)}
                  disabled={disabled}
                  onChange={(e) =>
                    onChange(
                      e.target.checked
                        ? [...arr, o.value]
                        : arr.filter((v) => v !== o.value),
                    )
                  }
                  className="size-4"
                />
                {o.label}
              </label>
            ))}
          </div>
        );
      }

      case 'boolean':
        return (
          <label className="flex items-center gap-2 text-sm">
            <input
              id={id}
              type="checkbox"
              checked={value === true}
              disabled={disabled}
              aria-invalid={invalid}
              aria-describedby={describedBy}
              onChange={(e) => onChange(e.target.checked)}
              className="size-4"
            />
            {field.label}
            {field.required && <span className="text-destructive"> *</span>}
          </label>
        );

      case 'number':
        return (
          <Input
            id={id}
            type="number"
            inputMode="decimal"
            value={String(value ?? '')}
            placeholder={field.placeholder}
            disabled={disabled}
            aria-invalid={invalid}
            aria-describedby={describedBy}
            className={ring}
            onChange={(e) => onChange(e.target.value)}
          />
        );

      case 'date':
        return (
          <Input
            id={id}
            type="date"
            value={String(value ?? '')}
            disabled={disabled}
            aria-invalid={invalid}
            aria-describedby={describedBy}
            className={ring}
            onChange={(e) => onChange(e.target.value)}
          />
        );

      default:
        return (
          <Input
            id={id}
            type="text"
            value={String(value ?? '')}
            placeholder={field.placeholder}
            disabled={disabled}
            aria-invalid={invalid}
            aria-describedby={describedBy}
            className={ring}
            onChange={(e) => onChange(e.target.value)}
          />
        );
    }
  }
}
