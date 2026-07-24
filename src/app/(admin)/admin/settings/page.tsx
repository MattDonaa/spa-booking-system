import { PageHeader } from '@/features/admin/components/page-header';
import { SettingsForm } from '@/features/admin/components/settings-form';
import { getBusinessSettings } from '@/features/admin/actions/admin';
import type { BusinessSettings } from '@/features/admin/types';

export const metadata = { title: 'Settings' };

export default async function SettingsPage() {
  const result = await getBusinessSettings();

  return (
    <div>
      <PageHeader
        title="Business settings"
        description="Global booking and business configuration."
      />
      {!result.ok ? (
        <p className="text-sm text-destructive">{result.error.message}</p>
      ) : (
        <SettingsForm settings={result.data as BusinessSettings} />
      )}
    </div>
  );
}
