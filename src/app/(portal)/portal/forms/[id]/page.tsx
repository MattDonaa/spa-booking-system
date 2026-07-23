import { notFound } from 'next/navigation';

import { DynamicIntakeForm, getIntakeForm } from '@/features/intake';

export const metadata = { title: 'Intake form' };

export default async function IntakeFormPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const result = await getIntakeForm(id);

  if (!result.ok) {
    if (
      result.error.code === 'NOT_FOUND' ||
      result.error.code === 'FORBIDDEN'
    ) {
      notFound();
    }
    return <p className="text-sm text-destructive">{result.error.message}</p>;
  }

  return (
    <div className="mx-auto max-w-2xl">
      <DynamicIntakeForm form={result.data} />
    </div>
  );
}
