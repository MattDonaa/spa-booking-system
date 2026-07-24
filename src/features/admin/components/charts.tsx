import { cn } from '@/lib/utils';

/** A single KPI tile. */
export function StatTile({
  label,
  value,
  hint,
}: {
  label: string;
  value: string;
  hint?: string;
}) {
  return (
    <div className="rounded-lg border bg-card p-4">
      <p className="text-sm text-muted-foreground">{label}</p>
      <p className="mt-1 text-2xl font-semibold">{value}</p>
      {hint && <p className="mt-0.5 text-xs text-muted-foreground">{hint}</p>}
    </div>
  );
}

export interface BarItem {
  label: string;
  value: number;
  /** Right-aligned formatted display value (defaults to the number). */
  display?: string;
}

/**
 * Horizontal bar list. Bars are scaled to the largest value. Accessible: each
 * row is labelled with its value.
 */
export function BarList({ items }: { items: BarItem[] }) {
  const max = Math.max(1, ...items.map((i) => i.value));

  if (items.length === 0) {
    return <p className="text-sm text-muted-foreground">No data.</p>;
  }

  return (
    <ul className="space-y-3">
      {items.map((item) => {
        const pct = Math.round((item.value / max) * 100);
        return (
          <li key={item.label} className="space-y-1">
            <div className="flex items-center justify-between text-sm">
              <span className="truncate">{item.label}</span>
              <span className="font-medium tabular-nums">
                {item.display ?? item.value}
              </span>
            </div>
            <div
              className="h-2 w-full overflow-hidden rounded-full bg-muted"
              role="img"
              aria-label={`${item.label}: ${item.display ?? item.value}`}
            >
              <div
                className="h-full rounded-full bg-primary"
                style={{ width: `${pct}%` }}
              />
            </div>
          </li>
        );
      })}
    </ul>
  );
}

/**
 * Compact vertical-bar series (e.g. daily revenue). Purely visual; the
 * accessible summary is provided by the caller's heading and totals.
 */
export function ColumnChart({
  data,
  formatValue,
}: {
  data: { label: string; value: number }[];
  formatValue?: (v: number) => string;
}) {
  const max = Math.max(1, ...data.map((d) => d.value));

  if (data.length === 0) {
    return <p className="text-sm text-muted-foreground">No data.</p>;
  }

  return (
    <div
      className="flex h-40 items-end gap-0.5"
      role="img"
      aria-label="Time series"
    >
      {data.map((d, i) => {
        const pct = Math.round((d.value / max) * 100);
        return (
          <div
            key={`${d.label}-${i}`}
            className="group relative flex-1"
            title={`${d.label}: ${formatValue ? formatValue(d.value) : d.value}`}
          >
            <div
              className={cn(
                'w-full rounded-t bg-primary/80 transition-colors group-hover:bg-primary',
                d.value === 0 && 'bg-muted',
              )}
              style={{ height: `${Math.max(pct, 2)}%` }}
            />
          </div>
        );
      })}
    </div>
  );
}
