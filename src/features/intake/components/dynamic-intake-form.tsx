'use client';

import { Loader2 } from 'lucide-react';
import { useState, useTransition } from 'react';

import { Button } from '@/components/ui/button';
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from '@/components/ui/card';
import { autosaveIntake, submitIntake } from '@/features/intake/actions/intake';
import { FieldRenderer } from '@/features/intake/components/field-renderer';
import { useAutosave } from '@/features/intake/hooks/use-autosave';
import {
  buildResponsesValidator,
  initialResponses,
} from '@/features/intake/schemas';
import type {
  FieldError,
  IntakeForm,
  IntakeResponses,
  ResponseValue,
} from '@/features/intake/types';

interface DynamicIntakeFormProps {
  form: IntakeForm;
  /** Called after a successful submission. */
  onSubmitted?: () => void;
}

const statusLabel: Record<string, string> = {
  idle: '',
  saving: 'Saving…',
  saved: 'Saved',
  error: 'Save failed — retrying on next change',
};

/**
 * Renders a template's fields, autosaves responses (debounced), validates on
 * the client, and finalizes via the submit RPC. The database re-validates and
 * remains the source of truth.
 */
export function DynamicIntakeForm({
  form,
  onSubmitted,
}: DynamicIntakeFormProps) {
  const [responses, setResponses] = useState<IntakeResponses>(() =>
    initialResponses(form.template.schema, form.responses),
  );
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [completed, setCompleted] = useState(form.status === 'completed');
  const [isSubmitting, startSubmit] = useTransition();

  const { schedule, status } = useAutosave<IntakeResponses>((value) =>
    autosaveIntake(form.intake_form_id, value),
  );

  const disabled = completed || isSubmitting;

  function update(key: string, value: ResponseValue) {
    const next = { ...responses, [key]: value };
    setResponses(next);
    if (errors[key]) {
      setErrors((prev) => {
        const { [key]: _removed, ...rest } = prev;
        return rest;
      });
    }
    schedule(next);
  }

  function handleSubmit() {
    setSubmitError(null);
    const validator = buildResponsesValidator(form.template.schema);
    const parsed = validator.safeParse(responses);

    if (!parsed.success) {
      const fieldErrors: Record<string, string> = {};
      for (const issue of parsed.error.issues) {
        const key = String(issue.path[0] ?? '');
        if (key && !fieldErrors[key]) fieldErrors[key] = issue.message;
      }
      setErrors(fieldErrors);
      return;
    }

    startSubmit(async () => {
      const result = await submitIntake(form.intake_form_id, responses);
      if (result.ok) {
        setCompleted(true);
        onSubmitted?.();
        return;
      }
      if (result.error.fields) {
        // The server returns `fields` as an array of {key, message}.
        setErrors((prev) => ({
          ...prev,
          ...normalizeServerFields(result.error.fields),
        }));
      }
      setSubmitError(result.error.message);
    });
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>{form.template.name}</CardTitle>
        <CardDescription>
          {form.is_medical
            ? 'Your medical information is encrypted and visible only to your practitioner.'
            : 'Please complete the form below.'}
        </CardDescription>
      </CardHeader>

      <CardContent className="space-y-6">
        {completed ? (
          <p className="text-sm text-muted-foreground">
            This form has been submitted. Thank you.
          </p>
        ) : (
          form.template.schema.map((field) => (
            <FieldRenderer
              key={field.key}
              field={field}
              value={responses[field.key] ?? null}
              error={errors[field.key]}
              disabled={disabled}
              onChange={(value) => update(field.key, value)}
            />
          ))
        )}
      </CardContent>

      {!completed && (
        <CardFooter className="flex items-center justify-between">
          <span
            className="text-xs text-muted-foreground"
            aria-live="polite"
            role="status"
          >
            {statusLabel[status]}
          </span>
          <div className="flex items-center gap-3">
            {submitError && (
              <span className="text-xs text-destructive">{submitError}</span>
            )}
            <Button onClick={handleSubmit} disabled={disabled}>
              {isSubmitting && <Loader2 className="animate-spin" />}
              Submit
            </Button>
          </div>
        </CardFooter>
      )}
    </Card>
  );
}

/** Server may return `fields` as [{key,message}] — normalize to a map. */
function normalizeServerFields(fields: unknown): Record<string, string> {
  if (!Array.isArray(fields)) return {};
  const out: Record<string, string> = {};
  for (const item of fields as FieldError[]) {
    if (item?.key && item?.message) out[item.key] = item.message;
  }
  return out;
}
