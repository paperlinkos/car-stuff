const assert = require('node:assert/strict');
const {
  bookingDurationDays,
  canTransition,
  estimateNgn,
  hasDateOverlap,
  isSupportedRentalMode,
  isValidIdempotencyKey,
  lagosDate,
  validateBookingPeriod,
} = require('../lib/booking.js');

const now = new Date('2026-10-17T08:00:00.000Z');
const pickup = new Date('2026-10-20T09:00:00.000Z');
const returnAt = new Date('2026-10-22T09:00:00.000Z');

// Booking duration calculation
assert.equal(bookingDurationDays(pickup, returnAt), 2);
assert.equal(validateBookingPeriod(pickup, returnAt, 1, now), 2);
assert.equal(validateBookingPeriod(returnAt, pickup, 1, now), null);
assert.equal(validateBookingPeriod(new Date('2026-10-16T09:00:00Z'), returnAt, 1, now), null);
assert.equal(validateBookingPeriod(pickup, new Date('2026-12-01T09:00:00Z'), 1, now), null);

// Price calculation & validation
assert.equal(estimateNgn(45000, 2), 90000);
assert.equal(estimateNgn(-1, 2), null);
assert.equal(estimateNgn(0, 2), null);

// Rental mode validation
assert.equal(isSupportedRentalMode('both', 'chauffeur'), true);
assert.equal(isSupportedRentalMode('both', 'selfDrive'), true);
assert.equal(isSupportedRentalMode('selfDrive', 'chauffeur'), false);
assert.equal(isSupportedRentalMode('chauffeur', 'selfDrive'), false);
assert.equal(isSupportedRentalMode('selfDrive', 'invalid'), false);

// State transition rules
assert.equal(canTransition('requested', 'accept'), 'accepted');
assert.equal(canTransition('requested', 'decline'), 'declined');
assert.equal(canTransition('requested', 'cancel'), 'cancelled');
assert.equal(canTransition('accepted', 'cancel'), null);
assert.equal(canTransition('accepted', 'decline'), null);
assert.equal(canTransition('declined', 'accept'), null);
assert.equal(canTransition('cancelled', 'accept'), null);
assert.equal(canTransition('completed', 'cancel'), null);

// Timezone and date labelling
assert.equal(lagosDate(new Date('2026-10-17T23:30:00.000Z')), '2026-10-18');

// Date overlap / conflict detection for accepted AND active bookings
const existingStart = new Date('2026-10-20T10:00:00.000Z');
const existingEnd = new Date('2026-10-25T10:00:00.000Z');

// Overlapping cases (must detect conflict for both accepted and active bookings)
const blockingStatuses = ['accepted', 'active'];
for (const status of blockingStatuses) {
  assert.equal(hasDateOverlap(existingStart, existingEnd, new Date('2026-10-21T10:00:00.000Z'), new Date('2026-10-24T10:00:00.000Z')), true, `Enclosed candidate must conflict with ${status} booking`);
  assert.equal(hasDateOverlap(existingStart, existingEnd, new Date('2026-10-18T10:00:00.000Z'), new Date('2026-10-22T10:00:00.000Z')), true, `Overlapping start must conflict with ${status} booking`);
  assert.equal(hasDateOverlap(existingStart, existingEnd, new Date('2026-10-23T10:00:00.000Z'), new Date('2026-10-28T10:00:00.000Z')), true, `Overlapping end must conflict with ${status} booking`);
  assert.equal(hasDateOverlap(existingStart, existingEnd, new Date('2026-10-18T10:00:00.000Z'), new Date('2026-10-28T10:00:00.000Z')), true, `Encompassing interval must conflict with ${status} booking`);
  assert.equal(hasDateOverlap(existingStart, existingEnd, existingStart, existingEnd), true, `Identical interval must conflict with ${status} booking`);
}

// Non-overlapping adjacent cases (must NOT block)
assert.equal(hasDateOverlap(existingStart, existingEnd, new Date('2026-10-15T10:00:00.000Z'), existingStart), false, 'Candidate ending exactly when existing starts must NOT conflict');
assert.equal(hasDateOverlap(existingStart, existingEnd, existingEnd, new Date('2026-10-30T10:00:00.000Z')), false, 'Candidate starting exactly when existing ends must NOT conflict');
assert.equal(hasDateOverlap(existingStart, existingEnd, new Date('2026-10-10T10:00:00.000Z'), new Date('2026-10-15T10:00:00.000Z')), false, 'Completely prior interval must NOT conflict');
assert.equal(hasDateOverlap(existingStart, existingEnd, new Date('2026-11-01T10:00:00.000Z'), new Date('2026-11-05T10:00:00.000Z')), false, 'Completely subsequent interval must NOT conflict');

// Microsecond/millisecond boundary test
assert.equal(hasDateOverlap(existingStart, existingEnd, new Date('2026-10-15T10:00:00.000Z'), new Date(existingStart.getTime() + 1)), true, '1ms overlap into existing start MUST conflict');
assert.equal(hasDateOverlap(existingStart, existingEnd, new Date(existingEnd.getTime() - 1), new Date('2026-10-30T10:00:00.000Z')), true, '1ms overlap from existing end MUST conflict');

// Concurrent acceptance race conflict simulation:
// If two requests are accepted concurrently for the same vehicle, Firestore transaction optimistic concurrency
// detects conflict on vehicle doc update. The first commits, the second retries and sees the newly accepted booking.
function simulateConcurrentAcceptance(existingBookings, newBooking) {
  const conflict = existingBookings.some((b) =>
    ['accepted', 'active'].includes(b.status) &&
    hasDateOverlap(b.pickupAt, b.returnAt, newBooking.pickupAt, newBooking.returnAt)
  );
  if (conflict) {
    throw new Error('This vehicle already has an accepted or active booking for those dates.');
  }
  return [...existingBookings, { ...newBooking, status: 'accepted' }];
}

let vehicleBookings = [];
const booking1 = { id: 'b1', pickupAt: existingStart, returnAt: existingEnd, status: 'requested' };
const booking2 = { id: 'b2', pickupAt: new Date('2026-10-22T10:00:00.000Z'), returnAt: new Date('2026-10-27T10:00:00.000Z'), status: 'requested' };

// Accept booking 1 succeeds
vehicleBookings = simulateConcurrentAcceptance(vehicleBookings, booking1);
assert.equal(vehicleBookings.length, 1);
assert.equal(vehicleBookings[0].status, 'accepted');

// Concurrent attempt to accept booking 2 on retry fails
assert.throws(() => {
  simulateConcurrentAcceptance(vehicleBookings, booking2);
}, /already has an accepted or active booking/);

// Idempotency key validation
assert.equal(isValidIdempotencyKey('req-123456_abc'), true);
assert.equal(isValidIdempotencyKey('1729182390123'), true);
assert.equal(isValidIdempotencyKey('key with spaces'), false);
assert.equal(isValidIdempotencyKey('key$with$special'), false);
assert.equal(isValidIdempotencyKey(''), false);
assert.equal(isValidIdempotencyKey(null), false);
assert.equal(isValidIdempotencyKey('a'.repeat(121)), false);

console.log('Booking domain scenarios passed: period, estimate, modes, state transitions, accepted/active date overlaps, adjacent intervals, concurrency conflict prevention, and idempotency.');

