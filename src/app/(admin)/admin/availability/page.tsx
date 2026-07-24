import { PageHeader } from '@/features/admin/components/page-header';
import { AvailabilityManager } from '@/features/admin/components/availability-manager';
import { adminListPractitioners } from '@/features/admin/actions/admin';

export const metadata = { title: 'Availability' };

export default async function AvailabilityPage() {
  const result = await adminListPractitioners();

  return (
    <div>
      <PageHeader
        title="Availability"
        description="View schedules and add time off / blocks."
      />
      {!result.ok ? (
        <p className="text-sm text-destructive">{result.error.message}</p>
      ) : (
        <AvailabilityManager practitioners={result.data} />
      )}
    </div>
  );
}
