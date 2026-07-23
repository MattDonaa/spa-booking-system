import { CalendarCheck, ShieldCheck, Sparkles } from 'lucide-react';

import { ThemeToggle } from '@/components/theme-toggle';
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card';

const highlights = [
  {
    icon: CalendarCheck,
    title: 'Effortless Booking',
    description:
      'Real-time availability with no double bookings, ever. Reserve a slot in seconds.',
  },
  {
    icon: ShieldCheck,
    title: 'Private & Compliant',
    description:
      'Medical intake and personal data protected end-to-end, POPIA-compliant by design.',
  },
  {
    icon: Sparkles,
    title: 'A Calm Experience',
    description:
      'A fast, mobile-first experience from discovery to your appointment.',
  },
];

export default function HomePage() {
  return (
    <main className="min-h-dvh">
      <header className="border-b">
        <div className="container flex h-16 items-center justify-between">
          <span className="text-lg font-semibold tracking-tight">Serenity</span>
          <ThemeToggle />
        </div>
      </header>

      <section className="container flex flex-col items-center py-20 text-center">
        <span className="rounded-full border bg-secondary px-4 py-1.5 text-sm font-medium text-secondary-foreground">
          Foundation ready · v1.0
        </span>
        <h1 className="mt-6 max-w-2xl text-balance text-4xl font-bold tracking-tight sm:text-5xl">
          Day Spa &amp; Wellness Booking, done properly.
        </h1>
        <p className="mt-4 max-w-xl text-pretty text-lg text-muted-foreground">
          The production-grade platform for discovering services, booking
          appointments, and managing your wellness journey.
        </p>
      </section>

      <section className="container grid gap-6 pb-24 md:grid-cols-3">
        {highlights.map(({ icon: Icon, title, description }) => (
          <Card key={title}>
            <CardHeader>
              <Icon className="size-8 text-primary" aria-hidden />
              <CardTitle className="text-xl">{title}</CardTitle>
              <CardDescription>{description}</CardDescription>
            </CardHeader>
            <CardContent />
          </Card>
        ))}
      </section>
    </main>
  );
}
