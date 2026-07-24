import { PageHeader } from '@/features/admin/components/page-header';
import { ServiceManager } from '@/features/admin/components/service-manager';
import { adminListServices } from '@/features/admin/actions/admin';

export const metadata = { title: 'Services' };

export default async function ServicesPage() {
  const result = await adminListServices();

  return (
    <div>
      <PageHeader title="Services" description="Manage the service catalog." />
      {!result.ok ? (
        <p className="text-sm text-destructive">{result.error.message}</p>
      ) : (
        <ServiceManager services={result.data} />
      )}
    </div>
  );
}
