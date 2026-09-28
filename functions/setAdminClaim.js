/**
 * ONE-TIME LOCAL SCRIPT — never deployed, never bundled in the app.
 *
 * Grants the `admin: true` custom claim to a specific, already-existing
 * Firebase Auth user, so they can use the AdminRecoveryScreen in the app.
 *
 * Usage:
 *   1. Download a service account key from
 *      Firebase Console > Project Settings > Service Accounts >
 *      Generate new private key. Save it OUTSIDE version control,
 *      e.g. as functions/scripts/serviceAccountKey.json (already
 *      covered by the .gitignore below — do not commit it).
 *   2. Run:  node setAdminClaim.js <uid>
 *   3. The user must sign out and back in for the new claim to take
 *      effect in their ID token.
 */

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const uid = process.argv[2];

if (!uid) {
  console.error("Usage: node setAdminClaim.js <uid>");
  process.exit(1);
}

admin
  .auth()
  .setCustomUserClaims(uid, { admin: true })
  .then(() => {
    console.log(`Success: ${uid} now has admin: true.`);
    process.exit(0);
  })
  .catch((err) => {
    console.error("Failed to set custom claim:", err);
    process.exit(1);
  });