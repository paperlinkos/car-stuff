export const bookingStatuses = [
  'requested',
  'accepted',
  'active',
  'declined',
  'cancelled',
  'completed',
] as const;
export type BookingStatus = (typeof bookingStatuses)[number];

export const rentalModes = ['selfDrive', 'chauffeur'] as const;
export type RentalMode = (typeof rentalModes)[number];

const lagosOffsetMs = 60 * 60 * 1000;
const dayMs = 24 * 60 * 60 * 1000;

export function isSupportedRentalMode(
  offered: unknown,
  selected: unknown,
): selected is RentalMode {
  if (!rentalModes.includes(selected as RentalMode)) return false;
  return offered === 'both' || offered === selected;
}

export function bookingDurationDays(pickupAt: Date, returnAt: Date): number {
  return Math.ceil((returnAt.getTime() - pickupAt.getTime()) / dayMs);
}

export function lagosDate(date: Date): string {
  return new Date(date.getTime() + lagosOffsetMs).toISOString().slice(0, 10);
}

export function validateBookingPeriod(
  pickupAt: Date,
  returnAt: Date,
  minimumDays: number,
  now = new Date(),
): number | null {
  if (!Number.isFinite(pickupAt.getTime()) || !Number.isFinite(returnAt.getTime())) {
    return null;
  }
  if (pickupAt.getTime() <= now.getTime() || returnAt.getTime() <= pickupAt.getTime()) {
    return null;
  }
  const days = bookingDurationDays(pickupAt, returnAt);
  if (days < Math.max(1, minimumDays) || days > 31) return null;
  return days;
}

export function estimateNgn(dailyRateNgn: number, days: number): number | null {
  if (!Number.isSafeInteger(dailyRateNgn) || dailyRateNgn <= 0 || days < 1) return null;
  const total = dailyRateNgn * days;
  return Number.isSafeInteger(total) ? total : null;
}

export function canTransition(
  status: BookingStatus,
  action: 'accept' | 'decline' | 'cancel',
): BookingStatus | null {
  if (status !== 'requested') return null;
  if (action === 'accept') return 'accepted';
  if (action === 'decline') return 'declined';
  return 'cancelled';
}

export function hasDateOverlap(
  pickupA: Date,
  returnA: Date,
  pickupB: Date,
  returnB: Date,
): boolean {
  return pickupA.getTime() < returnB.getTime() && returnA.getTime() > pickupB.getTime();
}

export function isValidIdempotencyKey(key: unknown): boolean {
  return (
    typeof key === 'string' &&
    key.trim().length > 0 &&
    key.trim().length <= 120 &&
    /^[A-Za-z0-9_-]+$/.test(key.trim())
  );
}
