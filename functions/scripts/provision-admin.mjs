/*
 * One-time, operator-run admin provisioning.
 *
 * Run only from a secured machine with Application Default Credentials:
 *   GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/service-account.json \
 *     node scripts/provision-admin.mjs admin@example.com
 *
 * The service-account file must never be copied into this repository.
 */
import {applicationDefault, initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';

const email = process.argv[2]?.trim().toLowerCase();
if (!email || !email.includes('@')) {
  console.error('Usage: node scripts/provision-admin.mjs admin@example.com');
  process.exit(1);
}

initializeApp({credential: applicationDefault()});

const auth = getAuth();
const user = await auth.getUserByEmail(email);
await auth.setCustomUserClaims(user.uid, {admin: true});
console.log(`Granted the admin custom claim to ${user.uid}. The user must sign out and back in to refresh their token.`);
