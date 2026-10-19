import { PaymentProvider } from './types';
import { SandboxPaymentProvider } from './sandbox-provider';
import { PaystackPaymentProvider } from './paystack-provider';

export * from './types';
export * from './sandbox-provider';
export * from './paystack-provider';

let cachedProvider: PaymentProvider | null = null;

export function getPaymentProvider(): PaymentProvider {
  if (cachedProvider) return cachedProvider;

  const paystackKey = process.env.PAYSTACK_SECRET_KEY;
  if (paystackKey && paystackKey.trim().length > 0 && !paystackKey.startsWith('mock_')) {
    cachedProvider = new PaystackPaymentProvider(paystackKey.trim());
  } else {
    cachedProvider = new SandboxPaymentProvider();
  }
  return cachedProvider;
}

export function resetPaymentProviderCache(): void {
  cachedProvider = null;
}
