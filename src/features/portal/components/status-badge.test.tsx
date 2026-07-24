import { render } from '@testing-library/react';
import { axe } from 'vitest-axe';
import { describe, expect, it } from 'vitest';

import { StatusBadge } from '@/features/portal/components/status-badge';

describe('StatusBadge', () => {
  it('renders a humanized label', () => {
    const { getByText } = render(<StatusBadge status="pending_hold" />);
    expect(getByText('Pending Hold')).toBeInTheDocument();
  });

  it('renders payment statuses', () => {
    const { getByText } = render(
      <StatusBadge status="succeeded" kind="payment" />,
    );
    expect(getByText('Succeeded')).toBeInTheDocument();
  });

  it('has no accessibility violations', async () => {
    const { container } = render(<StatusBadge status="confirmed" />);
    const results = await axe(container);
    expect(results).toHaveNoViolations();
  });
});
