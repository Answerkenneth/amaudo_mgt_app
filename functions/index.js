const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

const SMTP_HOST = defineSecret("SMTP_HOST");
const SMTP_PORT = defineSecret("SMTP_PORT");
const SMTP_USER = defineSecret("SMTP_USER");
const SMTP_PASS = defineSecret("SMTP_PASS");
const MAIL_FROM = defineSecret("MAIL_FROM");

const PHONE_INDEX = "phoneIndex";
const EMAIL_INDEX = "emailIndex";
const USERS = "users";
const RECOVERY_LOGS = "recoveryLogs";

function normalizePhone(value) {
  return String(value || "").trim().replace(/[\s\-()]/g, "");
}

function normalizeEmail(value) {
  return String(value || "").trim().toLowerCase();
}

function looksLikeEmail(value) {
  return String(value || "").includes("@");
}

function generateTempPassword() {
  // 12 characters, high entropy, avoids visually ambiguous characters.
  const alphabet =
    "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789";
  const bytes = require("crypto").randomBytes(12);
  let result = "";
  for (let i = 0; i < 12; i++) {
    result += alphabet[bytes[i] % alphabet.length];
  }
  return result;
}

/**
 * Callable — no auth required (a logged-out user must be able to
 * request recovery). Always resolves with a generic {success:true}
 * regardless of whether an account was found, to avoid confirming or
 * denying account existence to the caller.
 */
exports.requestPasswordReset = onCall(
  { secrets: [SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, MAIL_FROM] },
  async (request) => {
    const rawIdentifier = request.data && request.data.identifier;
    if (!rawIdentifier) {
      throw new HttpsError("invalid-argument", "An identifier is required.");
    }

    const isEmail = looksLikeEmail(rawIdentifier);
    const normalized = isEmail
      ? normalizeEmail(rawIdentifier)
      : normalizePhone(rawIdentifier);
    const indexCollection = isEmail ? EMAIL_INDEX : PHONE_INDEX;

    const db = admin.firestore();
    const indexDoc = await db.collection(indexCollection).doc(normalized).get();

    if (!indexDoc.exists) {
      return { success: true };
    }

    const { uid, authEmail } = indexDoc.data();
    if (!uid || !authEmail) {
      return { success: true };
    }

    const userDoc = await db.collection(USERS).doc(uid).get();
    const realEmail = userDoc.exists ? userDoc.data().email : null;

    if (!realEmail) {
      // No email on file — self-service reset is not possible for
      // this account. The client shows a generic message either way,
      // so we simply do not send anything here.
      return { success: true };
    }

    let resetLink;
    try {
      resetLink = await admin.auth().generatePasswordResetLink(authEmail);
    } catch (err) {
      // Do not leak internal errors to the caller.
      return { success: true };
    }

    const transporter = nodemailer.createTransport({
      host: SMTP_HOST.value(),
      port: Number(SMTP_PORT.value()),
      secure: Number(SMTP_PORT.value()) === 465,
      auth: {
        user: SMTP_USER.value(),
        pass: SMTP_PASS.value(),
      },
    });

    await transporter.sendMail({
      from: MAIL_FROM.value(),
      to: realEmail,
      subject: "Reset your Amaudo password",
      text:
        "We received a request to reset your Amaudo account password.\n\n" +
        "Click the link below to choose a new password:\n" +
        resetLink +
        "\n\nIf you did not request this, you can safely ignore this email.",
      html:
        `<p>We received a request to reset your Amaudo account password.</p>` +
        `<p><a href="${resetLink}">Click here to choose a new password</a></p>` +
        `<p>If you did not request this, you can safely ignore this email.</p>`,
    });

    return { success: true };
  }
);

/**
 * Callable — requires the caller to carry the custom claim
 * admin === true. That claim is set exclusively via the local
 * scripts/setAdminClaim.js script, run manually with a service
 * account credential — never through this app or any client code.
 */
exports.adminInitiateRecovery = onCall(async (request) => {
  if (!request.auth || request.auth.token.admin !== true) {
    throw new HttpsError(
      "permission-denied",
      "You are not authorized to perform this action."
    );
  }

  const rawIdentifier = request.data && request.data.identifier;
  if (!rawIdentifier) {
    throw new HttpsError("invalid-argument", "An identifier is required.");
  }

  const isEmail = looksLikeEmail(rawIdentifier);
  const normalized = isEmail
    ? normalizeEmail(rawIdentifier)
    : normalizePhone(rawIdentifier);
  const indexCollection = isEmail ? EMAIL_INDEX : PHONE_INDEX;

  const db = admin.firestore();
  const indexDoc = await db.collection(indexCollection).doc(normalized).get();

  if (!indexDoc.exists) {
    throw new HttpsError("not-found", "No matching account was found.");
  }

  const { uid } = indexDoc.data();
  const tempPassword = generateTempPassword();

  await admin.auth().updateUser(uid, { password: tempPassword });

  await db.collection(USERS).doc(uid).update({
    mustChangePassword: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await db.collection(RECOVERY_LOGS).add({
    targetUid: uid,
    initiatedByUid: request.auth.uid,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

   return { tempPassword };
});

// New appointment/care-request/admission/discharge/reminder push +
// in-app notifications — kept in its own file since it's a
// self-contained, unrelated feature area from password recovery
// above; merged into this file's exports so Firebase discovers it.
Object.assign(module.exports, require("./notifications"));