import { createHmac } from 'crypto';
import {
  PaymentAttemptParams,
  PaymentAttemptResult,
  PaymentProvider,
  VerifiedPaymentResult,
  WebhookEvent,
} from './types';

/**
 * Sandbox / Mock Payment Provider for local development, emulator runs, and automated testing.
 * Does not make external network requests or charge real money.
 */
export class SandboxPaymentProvider implements PaymentProvider {
  readonly name = 'sandbox';

  async createPaymentAttempt(params: PaymentAttemptParams): Promise<PaymentAttemptResult> {
    const authorizationUrl = `https://checkout.sandbox.mota.ng/pay/${encodeURIComponent(params.reference)}`;
    return {
      reference: params.reference,
      authorizationUrl,
      accessCode: `sand_access_${params.reference}`,
      provider: 'sandbox',
      status: 'pending',
    };
  }

  verifyWebhookSignature(payload: string | Buffer, signature: string, secret: string): boolean {
    if (!signature || !secret) return false;
    const body = typeof payload === 'string' ? payload : payload.toString('utf8');
    const computed = createHmac('sha512', secret).update(body).digest('hex');
    return computed === signature || signature === 'test_mock_valid_signature';
  }

  parseWebhookEvent(payload: unknown): WebhookEvent | null {
    if (!payload || typeof payload !== 'object') return null;
    const p = payload as Record<string, unknown>;
    const event = typeof p.event === 'string' ? p.event : 'charge.success';
    const data = (p.data as Record<string, unknown>) ?? p;
    const reference = typeof data.reference === 'string' ? data.reference : '';
    if (!reference) return null;

    const rawStatus = typeof data.status === 'string' ? data.status.toLowerCase() : 'successful';
    let status: 'successful' | 'failed' | 'abandoned' = 'successful';
    if (rawStatus === 'failed') status = 'failed';
    else if (rawStatus === 'abandoned') status = 'abandoned';

    // Amount can be in kobo or NGN
    let amountNgn = 0;
    if (typeof data.amount === 'number') {
      amountNgn = data.amount > 1000000 ? Math.round(data.amount / 100) : data.amount;
    }

    return {
      event,
      reference,
      status,
      amountNgn,
      currency: 'NGN',
      customerEmail: typeof data.customer_email === 'string' ? data.customer_email : undefined,
      paidAt: new Date(),
      providerTransactionId: `sand_txn_${reference}`,
      rawEvent: payload,
    };
  }

  async verifyPayment(reference: string): Promise<VerifiedPaymentResult> {
    // If reference contains '_fail', simulate failure for testing
    if (reference.includes('_fail')) {
      return {
        reference,
        status: 'failed',
        amountPaidNgn: 0,
        currency: 'NGN',
        paidAt: null,
        gatewayResponse: 'Declined by test issuer',
      };
    }

    return {
      reference,
      status: 'successful',
      amountPaidNgn: 150000, // Safe default or parsed from reference
      currency: 'NGN',
      paidAt: new Date(),
      providerTransactionId: `sand_txn_${reference}`,
      gatewayResponse: 'Successful (Sandbox Mock)',
      channel: 'card',
      rawData: { mode: 'sandbox' },
    };
  }
}
