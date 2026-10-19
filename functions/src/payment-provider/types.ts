export type PaymentStatus =
  | 'pending'
  | 'successful'
  | 'failed'
  | 'abandoned'
  | 'expired';

export interface PaymentAttemptParams {
  readonly bookingId: string;
  readonly customerId: string;
  readonly customerEmail: string;
  readonly amountNgn: number;
  readonly currency: 'NGN';
  readonly reference: string;
  readonly metadata?: Record<string, unknown>;
}

export interface PaymentAttemptResult {
  readonly reference: string;
  readonly authorizationUrl: string;
  readonly accessCode?: string;
  readonly provider: 'paystack' | 'sandbox';
  readonly status: PaymentStatus;
}

export interface VerifiedPaymentResult {
  readonly reference: string;
  readonly status: PaymentStatus;
  readonly amountPaidNgn: number;
  readonly currency: 'NGN';
  readonly paidAt: Date | null;
  readonly providerTransactionId?: string;
  readonly gatewayResponse?: string;
  readonly channel?: string;
  readonly rawData?: unknown;
}

export interface WebhookEvent {
  readonly event: string;
  readonly reference: string;
  readonly status: PaymentStatus;
  readonly amountNgn: number;
  readonly currency: 'NGN';
  readonly customerEmail?: string;
  readonly paidAt?: Date;
  readonly providerTransactionId?: string;
  readonly metadata?: Record<string, unknown>;
  readonly rawEvent: unknown;
}

export interface PaymentProvider {
  readonly name: string;
  createPaymentAttempt(params: PaymentAttemptParams): Promise<PaymentAttemptResult>;
  verifyWebhookSignature(payload: string | Buffer, signature: string, secret: string): boolean;
  parseWebhookEvent(payload: unknown): WebhookEvent | null;
  verifyPayment(reference: string): Promise<VerifiedPaymentResult>;
}
