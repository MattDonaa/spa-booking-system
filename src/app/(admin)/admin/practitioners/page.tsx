import { PageHeader } from '@/features/admin/components/page-header';
import { PractitionerManager } from '@/features/admin/components/practitioner-manager';
import { adminListPractitioners } from '@/features/admin/actions/admin';

export const metadata = { title: 'Practitioners' };

export default async function PractitionersPage() {
  const result = await adminListPractitioners();

  return (
    <div>
      <PageHeader
        title="Practitioners"
        description="Manage practitioner profiles and availability status."
      />
      {!result.ok ? (
        <p className="text-sm text-destructive">{result.error.message}</p>
      ) : result.data.length === 0 ? (
        <p className="text-sm text-muted-foreground">
          No practitioners yet. Practitioner accounts are created via sign-up
          with the practitioner role.
        </p>
      ) : (
        <PractitionerManager practitioners={result.data} />
      )}
    </div>
  );
}
