const dialog = document.querySelector('#adminDialog');
document.querySelector('#adminSignIn').addEventListener('click', () => dialog.showModal());
document.querySelector('#closeAdmin').addEventListener('click', () => dialog.close());
