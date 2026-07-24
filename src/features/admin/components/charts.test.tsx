import { render } from '@testing-library/react';
import { axe } from 'vitest-axe';
import { describe, expect, it } from 'vitest';

import { BarList, StatTile } from '@/features/admin/components/charts';

describe('StatTile', () => {
  it('renders label and value', () => {
    const { getByText } = render(<StatTile label="Revenue" value="R 1 000" />);
    expect(getByText('Revenue')).toBeInTheDocument();
    expect(getByText('R 1 000')).toBeInTheDocument();
  });

  it('has no accessibility violations', async () => {
    const { container } = render(<StatTile label="Bookings" value="12" />);
    expect(await axe(container)).toHaveNoViolations();
  });
});

describe('BarList', () => {
  it('renders each item with an accessible label', () => {
    const { getByLabelText } = render(
      <BarList
        items={[
          { label: 'Massage', value: 10, display: '10' },
          { label: 'Facial', value: 4, display: '4' },
        ]}
      />,
    );
    expect(getByLabelText('Massage: 10')).toBeInTheDocument();
    expect(getByLabelText('Facial: 4')).toBeInTheDocument();
  });

  it('shows an empty state with no data', () => {
    const { getByText } = render(<BarList items={[]} />);
    expect(getByText('No data.')).toBeInTheDocument();
  });
});
