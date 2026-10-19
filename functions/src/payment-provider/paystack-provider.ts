import { createHmac } from 'crypto';
import {
  PaymentAttemptParams,
  PaymentAttemptResult,
  PaymentProvider,
  VerifiedPaymentResult,
  WebhookEvent,
} from './types';

/**
 * Paystack Payment Provider for Nigeria.
 * Conforms to Paystack's official API specifications:
 * - Currency: NGN (API accepts amount in kobo, 1 NGN = 100 kobo)
 * - Signatures: HMAC-SHA512 with secret key
 * - Secret key stored server-side only in PAYSTACK_SECRET_KEY
 */
export class PaystackPaymentProvider implements PaymentProvider {
  readonly name = 'paystack';
  private readonly secretKey: string;
  private readonly baseUrl = 'https://api.paystack.co';

  constructor(secretKey = process.env.PAYSTACK_SECRET_KEY || '') {
    this.secretKey = secretKey;
  }

  async createPaymentAttempt(params: PaymentAttemptParams): Promise<PaymentAttemptResult> {
    if (!this.secretKey) {
      throw new Error('PAYSTACK_SECRET_KEY is not configured in server environment.');
    }

    // Convert NGN to kobo
    const amountInKobo = Math.round(params.amountNgn * 100);

    const response = await fetch(`${this.baseUrl}/transaction/initialize`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.secretKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email: params.customerEmail,
        amount: amountInKobo,
        currency: 'NGN',
        reference: params.reference,
        metadata: {
          bookingId: params.bookingId,
          customerId: params.customerId,
          ...params.metadata,
        },
      }),
    });

    if (!response.ok) {
      const errBody = await response.text();
      throw new Error(`Paystack transaction initialization failed (${response.status}): ${errBody}`);
    }

    const data = (await response.json()) as {
      status: boolean;
      message: string;
      data: {
        authorization_url: string;
        access_code: string;
        reference: string;
      };
    };

    if (!data.status || !data.data?.authorization_url) {
      throw new Error(`Paystack API returned error: ${data.message}`);
    }

    return {
      reference: data.data.reference,
      authorizationUrl: data.data.authorization_url,
      accessCode: data.data.access_code,
      provider: 'paystack',
      status: 'pending',
    };
  }

  verifyWebhookSignature(payload: string | Buffer, signature: string, secret = this.secretKey): boolean {
    if (!signature || !secret) return false;
    const body = typeof payload === 'string' ? payload : payload.toString('utf8');
    const hash = createHmac('sha512', secret).update(body).digest('hex');
    return hash === signature;
  }

  parseWebhookEvent(payload: unknown): WebhookEvent | null {
    if (!payload || typeof payload !== 'object') return null;
    const p = payload as Record<string, unknown>;
    const event = typeof p.event === 'string' ? p.event : '';
    const data = p.data as Record<string, unknown> | undefined;
    if (!data || typeof data.reference !== 'string') return null;

    let status: 'successful' | 'failed' | 'abandoned' = 'failed';
    const rawStatus = typeof data.status === 'string' ? data.status.toLowerCase() : '';
    if (rawStatus === 'success') status = 'successful';
    else if (rawStatus === 'abandoned') status = 'abandoned';

    const koboAmount = typeof data.amount === 'number' ? data.amount : 0;
    const amountNgn = Math.round(koboAmount / 100);

    const customer = data.customer as Record<string, unknown> | undefined;
    const customerEmail = typeof customer?.email === 'string' ? customer.email : undefined;

    return {
      event,
      reference: data.reference,
      status,
      amountNgn,
      currency: 'NGN',
      customerEmail,
      paidAt: typeof data.paid_at === 'string' ? new Date(data.paid_at) : new Date(),
      providerTransactionId: typeof data.id === 'number' ? String(data.id) : undefined,
      metadata: data.metadata as Record<string, unknown> | undefined,
      rawEvent: payload,
    };
  }

  async verifyPayment(reference: string): Promise<VerifiedPaymentResult> {
    if (!this.secretKey) {
      throw new Error('PAYSTACK_SECRET_KEY is not configured in server environment.');
    }

    const response = await fetch(`${this.baseUrl}/transaction/verify/${encodeURIComponent(reference)}`, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${this.secretKey}`,
      },
    });

    if (!response.ok) {
      const err = await response.text();
      throw new Error(`Paystack verification failed (${response.status}): ${err}`);
    }

    const res = (await response.json()) as {
      status: boolean;
      data?: {
        status: string;
        amount: number;
        currency: string;
        paid_at: string;
        id: number;
        gateway_response: string;
        channel: string;
      };
    };

    if (!res.status || !res.data) {
      return {
        reference,
        status: 'failed',
        amountPaidNgn: 0,
        currency: 'NGN',
        paidAt: null,
      };
    }

    const d = res.data;
    let status: 'successful' | 'failed' | 'abandoned' = 'failed';
    if (d.status === 'success') status = 'successful';
    else if (d.status === 'abandoned') status = 'abandoned';

    return {
      reference,
      status,
      amountPaidNgn: Math.round((d.amount ?? 0) / 100),
      currency: 'NGN',
      paidAt: d.paid_at ? new Date(d.paid_at) : null,
      providerTransactionId: String(d.id),
      gatewayResponse: d.gateway_response,
      channel: d.channel,
      rawData: d,
    };
  }
}
