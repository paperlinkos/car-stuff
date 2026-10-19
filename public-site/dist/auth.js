import {firebaseConfig} from './firebase-config.js';

const dialog = document.querySelector('#accountDialog');
const status = document.querySelector('#accountStatus');
const form = document.querySelector('#accountForm');
const mode = document.querySelector('#accountMode');
const reset = document.querySelector('#resetPassword');
const submit = document.querySelector('#accountSubmit');
let creating = false;
let auth;
let functions;

document.querySelector('#openAccount')?.addEventListener('click', () => dialog.showModal());
document.querySelector('[data-close-account]')?.addEventListener('click', () => dialog.close());

function setStatus(message, error = false) {
  status.textContent = message;
  status.style.color = error ? '#9b2e1d' : '';
}
function setMode() {
  submit.textContent = creating ? 'Create account' : 'Sign in';
  mode.textContent = creating ? 'I already have an account' : 'Create an account';
  document.querySelector('#accountName').closest('label').hidden = !creating;
}

if (!firebaseConfig) {
  form.querySelectorAll('input, button').forEach((element) => { element.disabled = true; });
  mode.disabled = true;
  reset.disabled = true;
  setStatus('Account access needs Firebase Web configuration before it can be enabled. No account has been created here.', true);
} else {
  const [{initializeApp}, authSdk, functionsSdk] = await Promise.all([
    import('https://www.gstatic.com/firebasejs/11.0.2/firebase-app.js'),
    import('https://www.gstatic.com/firebasejs/11.0.2/firebase-auth.js'),
    import('https://www.gstatic.com/firebasejs/11.0.2/firebase-functions.js'),
  ]);
  const app = initializeApp(firebaseConfig);
  auth = authSdk.getAuth(app);
  functions = functionsSdk.getFunctions(app);
  authSdk.onAuthStateChanged(auth, (user) => {
    setStatus(user ? `Signed in as ${user.email}. Customer access is active; role requests are reviewed by administrators.` : 'Sign in or create a customer account.');
    reset.hidden = Boolean(user);
  });
  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    const email = document.querySelector('#accountEmail').value.trim();
    const password = document.querySelector('#accountPassword').value;
    submit.disabled = true;
    try {
      if (creating) {
        const name = document.querySelector('#accountName').value.trim();
        const credential = await authSdk.createUserWithEmailAndPassword(auth, email, password);
        await authSdk.updateProfile(credential.user, {displayName: name});
        await authSdk.sendEmailVerification(credential.user);
        setStatus('Account created. Check your email for verification. Your secure customer profile is being created.');
      } else {
        await authSdk.signInWithEmailAndPassword(auth, email, password);
      }
    } catch (error) {
      setStatus(error.message || 'We could not complete that request.', true);
    } finally { submit.disabled = false; }
  });
  mode.addEventListener('click', () => { creating = !creating; setMode(); });
  reset.addEventListener('click', async () => {
    const email = document.querySelector('#accountEmail').value.trim();
    if (!email) return setStatus('Enter your email address before requesting a reset.', true);
    try {
      await authSdk.sendPasswordResetEmail(auth, email);
      setStatus('A password-reset link has been sent if this account exists.');
    } catch (error) { setStatus(error.message || 'We could not send a reset link.', true); }
  });
}
setMode();
void functions;
