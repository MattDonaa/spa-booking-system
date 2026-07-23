/**
 * Intake feature public surface. Portals (Milestones 8–9) consume the intake
 * experience through these exports.
 */
export { DynamicIntakeForm } from '@/features/intake/components/dynamic-intake-form';
export { SignaturePad } from '@/features/intake/components/signature-pad';
export {
  getIntakeForm,
  autosaveIntake,
  submitIntake,
  recordConsent,
} from '@/features/intake/actions/intake';
export type {
  FormField,
  FormSchema,
  FormTemplate,
  IntakeForm,
  IntakeResponses,
  IntakeStatus,
} from '@/features/intake/types';
