// ============================================================================
// Gateway factory: resolves a PaymentProvider to its concrete implementation.
// The Edge Functions depend only on the PaymentGateway interface.
// ============================================================================
import { OzowGateway } from './ozow.ts';
import { PayfastGateway } from './payfast.ts';
import type { PaymentGateway, PaymentProvider } from './types.ts';

export function getGateway(provider: string): PaymentGateway {
  switch (provider) {
    case 'payfast':
      return new PayfastGateway();
    case 'ozow':
      return new OzowGateway();
    default:
      throw new Error(`Unsupported payment provider: ${provider}`);
  }
}

export function isPaymentProvider(value: string): value is PaymentProvider {
  return value === 'payfast' || value === 'ozow';
}
