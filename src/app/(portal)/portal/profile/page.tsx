import { ProfileForm } from '@/features/portal/components/profile-form';
import { getMyProfile } from '@/features/portal/actions/portal';

export const metadata = { title: 'Profile' };

export default async function ProfilePage() {
  const result = await getMyProfile();

  if (!result.ok) {
    return <p className="text-sm text-destructive">{result.error.message}</p>;
  }

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-semibold">Profile</h1>
      <ProfileForm profile={result.data} />
    </div>
  );
}
