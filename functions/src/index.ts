import {initializeApp} from 'firebase-admin/app';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {auth} from 'firebase-functions/v1';
import {HttpsError, onCall} from 'firebase-functions/v2/https';

initializeApp();
const db = getFirestore();
type RequestedRole = 'owner' | 'driver';
const requestedRoles: readonly RequestedRole[] = ['owner', 'driver'];

export const createUserProfile = auth.user().onCreate(async (user) => {
  await db.collection('users').doc(user.uid).create({
    id: user.uid, displayName: user.displayName ?? '', email: user.email ?? null,
    phoneNumber: user.phoneNumber ?? null, roles: ['customer'],
    createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
  });
});

// A request does not activate a role; a staff review is required later.
export const requestRoleActivation = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  const requestedRole = request.data?.requestedRole as RequestedRole | undefined;
  if (!requestedRole || !requestedRoles.includes(requestedRole)) throw new HttpsError('invalid-argument', 'requestedRole must be owner or driver.');
  const ref = db.collection('verificationRequests').doc();
  await ref.create({id: ref.id, userId: request.auth.uid, verificationType: requestedRole, status: 'pending', createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()});
  await db.collection('auditLogs').add({action: 'role_activation_requested', actorId: request.auth.uid, subjectId: ref.id, metadata: {requestedRole}, createdAt: FieldValue.serverTimestamp()});
  return {requestId: ref.id, status: 'pending'};
});

export const setActivatedRoles = onCall(async (request) => {
  if (!request.auth?.token.admin) throw new HttpsError('permission-denied', 'Staff access required.');
  const {userId, roles} = request.data ?? {};
  if (typeof userId !== 'string' || !Array.isArray(roles) || !roles.every((role) => ['customer', 'owner', 'driver'].includes(role))) throw new HttpsError('invalid-argument', 'Invalid userId or roles.');
  await db.collection('users').doc(userId).update({roles, updatedAt: FieldValue.serverTimestamp()});
  await db.collection('auditLogs').add({action: 'roles_updated', actorId: request.auth.uid, subjectId: userId, metadata: {roles}, createdAt: FieldValue.serverTimestamp()});
  return {userId, roles};
});
