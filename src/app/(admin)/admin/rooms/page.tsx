import { PageHeader } from '@/features/admin/components/page-header';
import { RoomManager } from '@/features/admin/components/room-manager';
import { adminListRooms } from '@/features/admin/actions/admin';

export const metadata = { title: 'Rooms' };

export default async function RoomsPage() {
  const result = await adminListRooms();

  return (
    <div>
      <PageHeader title="Rooms" description="Manage treatment rooms." />
      {!result.ok ? (
        <p className="text-sm text-destructive">{result.error.message}</p>
      ) : (
        <RoomManager rooms={result.data} />
      )}
    </div>
  );
}
