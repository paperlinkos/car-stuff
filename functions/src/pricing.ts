export interface PlatformPricingConfig {
  readonly version: string;
  readonly effectiveDate: string;
  readonly currency: 'NGN';
  /** Commission rate as a percentage, e.g. 15 for 15% */
  readonly commissionPercentage: number;
  /** Optional fixed transaction or platform fee in NGN, 0 if disabled */
  readonly fixedFeeNgn: number;
  /** Rounding policy for calculated amounts */
  readonly roundingPolicy: 'round' | 'ceil' | 'floor';
  /** Security deposit configuration */
  readonly depositPolicy: {
    readonly required: boolean;
    readonly defaultAmountNgn: number;
  };
}

export interface PricingBreakdown {
  readonly dailyRateNgn: number;
  readonly durationDays: number;
  readonly grossRentalNgn: number;
  readonly platformCommissionNgn: number;
  readonly platformFixedFeeNgn: number;
  readonly totalPlatformFeeNgn: number;
  readonly ownerNetEarningsNgn: number;
  readonly depositNgn: number;
  readonly customerTotalNgn: number;
  readonly currency: 'NGN';
  readonly configVersion: string;
}

/**
 * Standard development default configuration.
 * Clearly labeled as development default for local testing and prototype runs.
 */
export const DEFAULT_PRICING_CONFIG: PlatformPricingConfig = {
  version: '2026.1-dev-default',
  effectiveDate: '2026-10-17',
  currency: 'NGN',
  commissionPercentage: 15, // 15% marketplace commission
  fixedFeeNgn: 0, // Disabled by default
  roundingPolicy: 'round',
  depositPolicy: {
    required: false, // Default deposit is 0 unless explicitly configured
    defaultAmountNgn: 0,
  },
};

export function isValidPricingConfig(config: unknown): config is PlatformPricingConfig {
  if (!config || typeof config !== 'object') return false;
  const c = config as Record<string, unknown>;
  if (typeof c.version !== 'string' || !c.version.trim()) return false;
  if (typeof c.effectiveDate !== 'string' || !c.effectiveDate.trim()) return false;
  if (c.currency !== 'NGN') return false;
  if (
    typeof c.commissionPercentage !== 'number' ||
    !Number.isFinite(c.commissionPercentage) ||
    c.commissionPercentage < 0 ||
    c.commissionPercentage > 100
  ) {
    return false;
  }
  if (
    typeof c.fixedFeeNgn !== 'number' ||
    !Number.isSafeInteger(c.fixedFeeNgn) ||
    c.fixedFeeNgn < 0
  ) {
    return false;
  }
  if (!['round', 'ceil', 'floor'].includes(c.roundingPolicy as string)) {
    return false;
  }
  const dp = c.depositPolicy as Record<string, unknown> | undefined;
  if (!dp || typeof dp.required !== 'boolean' || typeof dp.defaultAmountNgn !== 'number' || dp.defaultAmountNgn < 0) {
    return false;
  }
  return true;
}

function applyRounding(val: number, policy: 'round' | 'ceil' | 'floor'): number {
  switch (policy) {
    case 'ceil':
      return Math.ceil(val);
    case 'floor':
      return Math.floor(val);
    case 'round':
    default:
      return Math.round(val);
  }
}

/**
 * Calculates a complete, immutable financial breakdown for a vehicle rental.
 * Runs in trusted backend logic.
 *
 * @param dailyRateNgn - The verified listing daily rate snapshot
 * @param durationDays - The calculated booking duration (1..31 days)
 * @param config - The server platform pricing configuration
 * @param depositOverrideNgn - Optional deposit override for specific rental modes (e.g. high-value self-drive)
 */
export function calculatePricingBreakdown(
  dailyRateNgn: number,
  durationDays: number,
  config: PlatformPricingConfig = DEFAULT_PRICING_CONFIG,
  depositOverrideNgn?: number
): PricingBreakdown | null {
  if (!isValidPricingConfig(config)) return null;
  if (!Number.isSafeInteger(dailyRateNgn) || dailyRateNgn <= 0) return null;
  if (!Number.isSafeInteger(durationDays) || durationDays < 1 || durationDays > 31) return null;

  const grossRentalNgn = dailyRateNgn * durationDays;
  if (!Number.isSafeInteger(grossRentalNgn)) return null;

  const rawCommission = grossRentalNgn * (config.commissionPercentage / 100);
  const platformCommissionNgn = applyRounding(rawCommission, config.roundingPolicy);
  const platformFixedFeeNgn = config.fixedFeeNgn;
  const totalPlatformFeeNgn = platformCommissionNgn + platformFixedFeeNgn;

  const ownerNetEarningsNgn = Math.max(0, grossRentalNgn - totalPlatformFeeNgn);

  let depositNgn = config.depositPolicy.required ? config.depositPolicy.defaultAmountNgn : 0;
  if (depositOverrideNgn != null && Number.isSafeInteger(depositOverrideNgn) && depositOverrideNgn >= 0) {
    depositNgn = depositOverrideNgn;
  }

  const customerTotalNgn = grossRentalNgn + depositNgn;

  return {
    dailyRateNgn,
    durationDays,
    grossRentalNgn,
    platformCommissionNgn,
    platformFixedFeeNgn,
    totalPlatformFeeNgn,
    ownerNetEarningsNgn,
    depositNgn,
    customerTotalNgn,
    currency: 'NGN',
    configVersion: config.version,
  };
}
