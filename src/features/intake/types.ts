/**
 * Intake feature types.
 *
 * Form templates are dynamic: a template's `schema` is an ordered array of
 * field definitions, and responses are keyed by each field's `key`. These
 * types mirror the shape produced/consumed by the PostgreSQL intake RPCs.
 */

export type FieldType =
  | 'text'
  | 'textarea'
  | 'number'
  | 'date'
  | 'select'
  | 'radio'
  | 'checkbox'
  | 'boolean';

export interface FieldOption {
  label: string;
  value: string;
}

export interface FormField {
  key: string;
  label: string;
  type: FieldType;
  required?: boolean;
  help?: string;
  placeholder?: string;
  /** For select / radio / checkbox (multi) fields. */
  options?: FieldOption[];
}

export type FormSchema = FormField[];

export type FormType = 'medical_intake' | 'consent' | 'general_intake';

export interface FormTemplate {
  id: string;
  name: string;
  slug: string;
  version: number;
  form_type: FormType;
  schema: FormSchema;
}

export type IntakeStatus = 'pending' | 'in_progress' | 'completed';

/**
 * A single field's response value. Checkbox groups produce string[]; boolean
 * fields produce boolean; everything else produces string.
 */
export type ResponseValue = string | string[] | boolean | null;

export type IntakeResponses = Record<string, ResponseValue>;

export interface IntakeForm {
  intake_form_id: string;
  booking_id: string;
  status: IntakeStatus;
  is_medical: boolean;
  submitted_at: string | null;
  template: FormTemplate;
  responses: IntakeResponses;
}

/** Field-level validation errors returned by submit_intake_form. */
export interface FieldError {
  key: string;
  message: string;
}
