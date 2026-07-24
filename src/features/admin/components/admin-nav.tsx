'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

import { cn } from '@/lib/utils';

const links = [
  { href: '/admin', label: 'Dashboard', exact: true },
  { href: '/admin/calendar', label: 'Calendar' },
  { href: '/admin/bookings', label: 'Bookings' },
  { href: '/admin/practitioners', label: 'Practitioners' },
  { href: '/admin/services', label: 'Services' },
  { href: '/admin/rooms', label: 'Rooms' },
  { href: '/admin/availability', label: 'Availability' },
  { href: '/admin/payments', label: 'Payments' },
  { href: '/admin/forms', label: 'Forms' },
  { href: '/admin/reports', label: 'Reports' },
  { href: '/admin/notifications', label: 'Notifications' },
  { href: '/admin/audit', label: 'Audit' },
  { href: '/admin/settings', label: 'Settings' },
];

export function AdminNav() {
  const pathname = usePathname();
  return (
    <nav className="flex gap-1 overflow-x-auto" aria-label="Admin">
      {links.map(({ href, label, exact }) => {
        const active = exact ? pathname === href : pathname.startsWith(href);
        return (
          <Link
            key={href}
            href={href}
            aria-current={active ? 'page' : undefined}
            className={cn(
              'whitespace-nowrap rounded-md px-3 py-2 text-sm font-medium transition-colors',
              active
                ? 'bg-secondary text-secondary-foreground'
                : 'text-muted-foreground hover:bg-muted hover:text-foreground',
            )}
          >
            {label}
          </Link>
        );
      })}
    </nav>
  );
}
