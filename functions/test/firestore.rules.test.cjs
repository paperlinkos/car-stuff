const fs = require('node:fs');
const assert = require('node:assert/strict');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  collection,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
} = require('firebase/firestore');

let env;
const profile = (id, roles = ['customer']) => ({
  id,
  displayName: 'Ada Okafor',
  email: `${id}@example.test`,
  phoneNumber: null,
  profileImageUrl: null,
  accountStatus: 'active',
  roles,
  createdAt: new Date(),
  updatedAt: new Date(),
});

async function seed() {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/alice'), profile('alice'));
    await setDoc(doc(db, 'users/bob'), profile('bob', ['customer', 'owner']));
    await setDoc(doc(db, 'roleRequests/request-a'), {
      id: 'request-a', userId: 'alice', requestedRole: 'owner',
      status: 'pending', createdAt: new Date(), updatedAt: new Date(),
    });
    await setDoc(doc(db, 'vehicles/draft-b'), {
      ownerId: 'bob', make: 'Toyota', model: 'RAV4', year: 2022,
      category: 'SUV', transmission: 'Automatic', fuelType: 'Petrol',
      seats: 5, colour: 'Black', registrationNumber: 'ABC-123',
      description: 'Well maintained vehicle', rentalMode: 'selfDrive',
      dailyRateNgn: 45000, minimumRentalDays: 1, pickupArea: 'Wuse II',
      photoPaths: [], status: 'draft', createdAt: new Date(), updatedAt: new Date(),
    });
    await setDoc(doc(db, 'vehicleDocuments/document-b'), {
      ownerId: 'bob', listingId: 'draft-b', type: 'ownership', storagePath: 'private',
    });
    await setDoc(doc(db, 'bookings/booking-a'), {
      id: 'booking-a', customerId: 'alice', ownerId: 'bob', vehicleId: 'approved-b',
      status: 'requested', rentalMode: 'selfDrive', pickupArea: 'Wuse II',
      pickupAt: new Date('2026-11-03T09:00:00Z'), returnAt: new Date('2026-11-05T09:00:00Z'),
      pricing: {dailyRateNgn: 45000, durationDays: 2, estimateNgn: 90000, currency: 'NGN'},
      vehicleSnapshot: {make: 'Toyota', model: 'RAV4'}, createdAt: new Date(), updatedAt: new Date(),
    });
    await setDoc(doc(db, 'bookings/booking-c'), {
      id: 'booking-c', customerId: 'charlie', ownerId: 'other-owner', vehicleId: 'approved-c',
      status: 'accepted', rentalMode: 'chauffeur', pickupArea: 'Jabi',
      pickupAt: new Date('2026-11-10T09:00:00Z'), returnAt: new Date('2026-11-11T09:00:00Z'),
      pricing: {dailyRateNgn: 80000, durationDays: 1, estimateNgn: 80000, currency: 'NGN'},
      vehicleSnapshot: {make: 'Lexus', model: 'ES'}, createdAt: new Date(), updatedAt: new Date(),
    });
    await setDoc(doc(db, 'payments/payment-a'), {
      id: 'payment-a', customerId: 'alice', ownerId: 'bob', bookingId: 'booking-a',
      amountNgn: 90000, status: 'pending', currency: 'NGN', createdAt: new Date(),
    });
    await setDoc(doc(db, 'payments/payment-c'), {
      id: 'payment-c', customerId: 'charlie', ownerId: 'other-owner', bookingId: 'booking-c',
      amountNgn: 80000, status: 'successful', currency: 'NGN', createdAt: new Date(),
    });
    await setDoc(doc(db, 'payouts/payout-b'), {
      id: 'payout-b', ownerId: 'bob', amountNgn: 50000, status: 'requested',
      currency: 'NGN', requestedAt: new Date(),
    });
    await setDoc(doc(db, 'financialLedger/entry-b'), {
      id: 'entry-b', accountId: 'owner_bob', amountNgn: 50000, direction: 'credit',
      entryType: 'owner_credit', currency: 'NGN', createdAt: new Date(),
    });
    await setDoc(doc(db, 'financialLedger/entry-b-pending'), {
      id: 'entry-b-pending', accountId: 'payout_pending_bob', amountNgn: 50000, direction: 'credit',
      entryType: 'payout_hold', currency: 'NGN', createdAt: new Date(),
    });
    await setDoc(doc(db, 'securityDeposits/deposit-a'), {
      id: 'deposit-a', customerId: 'alice', ownerId: 'bob', bookingId: 'booking-a',
      amountNgn: 20000, status: 'held', currency: 'NGN', createdAt: new Date(),
    });
    await setDoc(doc(db, 'refunds/refund-a'), {
      id: 'refund-a', requestedBy: 'alice', authorizedBy: 'admin', bookingId: 'booking-a',
      amountNgn: 15000, status: 'completed', currency: 'NGN', createdAt: new Date(),
    });
  });
}

async function run() {
  env = await initializeTestEnvironment({
    projectId: 'demo-mota-phase2',
    firestore: {rules: fs.readFileSync('../firestore.rules', 'utf8')},
  });
  await seed();
  const unauthenticated = env.unauthenticatedContext().firestore();
  const alice = env.authenticatedContext('alice').firestore();
  const bob = env.authenticatedContext('bob').firestore();
  const admin = env.authenticatedContext('admin', {admin: true}).firestore();

  await assertFails(getDoc(doc(unauthenticated, 'users/alice')));
  await assertSucceeds(getDoc(doc(alice, 'users/alice')));
  await assertSucceeds(updateDoc(doc(alice, 'users/alice'), {
    displayName: 'Ada E. Okafor', updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(alice, 'users/alice'), {
    roles: ['customer', 'owner'], updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(alice, 'roleRequests/request-a'), {
    status: 'approved', updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(bob, 'roleRequests/request-a'), {
    status: 'approved', updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(getDocs(collection(admin, 'roleRequests')));
  await assertFails(updateDoc(doc(alice, 'users/alice'), {
    email: 'changed@example.test', updatedAt: serverTimestamp(),
  }));
  const newDraft = {ownerId: 'alice', make: 'Honda', model: 'Civic', year: 2020, category: 'Sedan', transmission: 'Automatic', fuelType: 'Petrol', seats: 5, colour: 'Grey', registrationNumber: 'CUS-1', description: 'Draft', rentalMode: 'selfDrive', dailyRateNgn: 30000, minimumRentalDays: 1, pickupArea: 'Jabi', photoPaths: [], status: 'draft'};
  await assertFails(setDoc(doc(alice, 'vehicles/customer-draft'), newDraft));
  await assertSucceeds(setDoc(doc(bob, 'vehicles/owner-draft'), {
    ...newDraft, ownerId: 'bob', registrationNumber: 'OWN-1',
  }));
  await assertSucceeds(updateDoc(doc(bob, 'vehicles/draft-b'), {colour: 'Blue'}));
  await assertFails(updateDoc(doc(alice, 'vehicles/draft-b'), {colour: 'Red'}));
  await assertFails(updateDoc(doc(bob, 'vehicles/draft-b'), {status: 'approved'}));
  await assertFails(updateDoc(doc(bob, 'vehicles/draft-b'), {status: 'submitted'}));
  await assertFails(getDoc(doc(unauthenticated, 'vehicles/draft-b')));
  await assertFails(getDoc(doc(unauthenticated, 'vehicleDocuments/document-b')));
  await assertSucceeds(getDoc(doc(admin, 'vehicleDocuments/document-b')));
  await assertFails(getDoc(doc(unauthenticated, 'bookings/booking-a')));
  await assertSucceeds(getDoc(doc(alice, 'bookings/booking-a')));
  await assertSucceeds(getDoc(doc(bob, 'bookings/booking-a')));
  await assertFails(getDoc(doc(alice, 'bookings/booking-c')));
  await assertFails(getDoc(doc(bob, 'bookings/booking-c')));
  await assertFails(updateDoc(doc(alice, 'bookings/booking-a'), {status: 'accepted'}));
  await assertFails(updateDoc(doc(bob, 'bookings/booking-a'), {status: 'accepted'}));
  await assertFails(setDoc(doc(alice, 'bookings/client-booking'), {status: 'accepted'}));

  // Phase 6: Financial security controls
  // 1. Payments access & mutation controls
  await assertSucceeds(getDoc(doc(alice, 'payments/payment-a')));
  await assertSucceeds(getDoc(doc(bob, 'payments/payment-a')));
  await assertFails(getDoc(doc(alice, 'payments/payment-c')));
  await assertFails(getDoc(doc(unauthenticated, 'payments/payment-a')));
  await assertFails(updateDoc(doc(alice, 'payments/payment-a'), {status: 'successful'}));
  await assertFails(setDoc(doc(alice, 'payments/client-payment'), {amountNgn: 1000}));

  // 2. Payouts access & mutation controls
  await assertSucceeds(getDoc(doc(bob, 'payouts/payout-b')));
  await assertFails(getDoc(doc(alice, 'payouts/payout-b')));
  await assertSucceeds(getDoc(doc(admin, 'payouts/payout-b')));
  await assertFails(updateDoc(doc(bob, 'payouts/payout-b'), {status: 'approved'}));
  await assertFails(setDoc(doc(bob, 'payouts/client-payout'), {amountNgn: 50000}));

  // 3. Financial ledger privacy & mutation controls
  await assertSucceeds(getDoc(doc(bob, 'financialLedger/entry-b')));
  await assertFails(getDoc(doc(alice, 'financialLedger/entry-b')));
  await assertSucceeds(getDoc(doc(bob, 'financialLedger/entry-b-pending')));
  await assertFails(getDoc(doc(alice, 'financialLedger/entry-b-pending')));
  await assertSucceeds(getDoc(doc(admin, 'financialLedger/entry-b')));
  await assertFails(setDoc(doc(bob, 'financialLedger/client-entry'), {amountNgn: 999999}));

  // 4. Security deposits and refunds access & mutation controls
  await assertSucceeds(getDoc(doc(alice, 'securityDeposits/deposit-a')));
  await assertSucceeds(getDoc(doc(bob, 'securityDeposits/deposit-a')));
  await assertFails(updateDoc(doc(alice, 'securityDeposits/deposit-a'), {status: 'released'}));
  await assertSucceeds(getDoc(doc(alice, 'refunds/refund-a')));
  await assertFails(setDoc(doc(alice, 'refunds/client-refund'), {amountNgn: 1000}));

  console.log('Rules scenarios passed: profile, owner listing, private document, booking privacy, protected booking fields, and financial security controls.');
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}).finally(async () => {
  if (env) await env.cleanup();
});
