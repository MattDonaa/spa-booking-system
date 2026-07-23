import { z } from 'zod';

import type {
  FormField,
  FormSchema,
  IntakeResponses,
  ResponseValue,
} from '@/features/intake/types';

/**
 * Zod schema for a single field definition — used to validate that a template's
 * stored schema is well-formed before it is rendered.
 */
export const fieldOptionSchema = z.object({
  label: z.string().min(1),
  value: z.string().min(1),
});

export const formFieldSchema = z.object({
  key: z
    .string()
    .min(1)
    .regex(/^[a-z0-9_]+$/i, 'Field keys must be alphanumeric/underscore.'),
  label: z.string().min(1),
  type: z.enum([
    'text',
    'textarea',
    'number',
    'date',
    'select',
    'radio',
    'checkbox',
    'boolean',
  ]),
  required: z.boolean().optional(),
  help: z.string().optional(),
  placeholder: z.string().optional(),
  options: z.array(fieldOptionSchema).optional(),
});

export const formSchemaSchema = z.array(formFieldSchema);

/**
 * Build a Zod validator for a set of responses from a dynamic template schema.
 * This mirrors the server-side `validate_intake` required-field check so the
 * client can validate before submitting, while the database remains the
 * authority.
 */
export function buildResponsesValidator(schema: FormSchema) {
  const shape: Record<string, z.ZodTypeAny> = {};

  for (const field of schema) {
    let base: z.ZodTypeAny;

    switch (field.type) {
      case 'checkbox':
        base = z.array(z.string());
        if (field.required) {
          base = (base as z.ZodArray<z.ZodString>).min(
            1,
            `${field.label} is required.`,
          );
        }
        break;
      case 'boolean':
        base = z.boolean();
        if (field.required) {
          base = (base as z.ZodBoolean).refine(
            (v) => v === true,
            `${field.label} is required.`,
          );
        }
        break;
      default: {
        let s = z.string();
        if (field.required) s = s.min(1, `${field.label} is required.`);
        base = field.required ? s : s.optional().or(z.literal(''));
      }
    }

    shape[field.key] = base;
  }

  return z.object(shape).passthrough();
}

/** Default empty value for a field, used to initialize the form state. */
export function defaultValueFor(field: FormField): ResponseValue {
  switch (field.type) {
    case 'checkbox':
      return [];
    case 'boolean':
      return false;
    default:
      return '';
  }
}

/** Build an initial responses object from a schema and any saved responses. */
export function initialResponses(
  schema: FormSchema,
  saved: IntakeResponses = {},
): IntakeResponses {
  const out: IntakeResponses = {};
  for (const field of schema) {
    out[field.key] =
      field.key in saved ? saved[field.key]! : defaultValueFor(field);
  }
  return out;
}
