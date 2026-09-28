/**
 * Amaudo push notifications:
 * - Every notification is written to Firestore's `notifications`
 *   collection (so the in-app bell/list has a durable record) AND
 *   sent as a high-priority FCM push in the same call.
 * - onXCreated/onXUpdated triggers cover the app's real events
 *   (new appointment, new care request, care request approved/
 *   accepted, admission, discharge, discharge requested).
 * - sendNotification is a callable you can invoke for any other
 *   event that doesn't have a dedicated trigger yet, without adding
 *   a new function every time.
 */

const { setGlobalOptions } = require("firebase-functions");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

// For cost control — see comment in the original scaffold. Per-
// function limit, not a global cap on total concurrent notifications.
setGlobalOptions({ maxInstances: 10 });

const db = admin.firestore();
const messaging = admin.messaging();

const USERS = "users";
const NOTIFICATIONS = "notifications";
const APPOINTMENTS = "appointments";
const CARE_REQUESTS = "careRequests";
const PATIENTS = "patients";
const ROLE_SLOTS = "roleSlots";

/**
 * Single source of truth for "notify a user": writes a doc to
 * `notifications` (recipientUid/type/title/body/read/createdAt) AND
 * sends a HIGH-PRIORITY FCM push to every token on file for that
 * user (users/{uid}.fcmToken — see FcmService on the client). Stale
 * tokens are pruned as they're discovered. Never throws — a
 * notification failure must never fail whatever triggered it.
 *
 * @param {string} uid
 * @param {{type:string,title:string,body:string,data?:Record<string,unknown>}} payload
 */
async function notifyUser(uid, { type, title, body, data }) {
  if (!uid) return;

  try {
    await db.collection(NOTIFICATIONS).add({
      recipientUid: uid,
      type,
      title,
      body,
      read: false,
      // Persisted so the in-app notification list can deep link a
      // tap to the exact related record (see NotificationRouter on
      // the client) — previously this was only ever sent as part of
      // the FCM push payload and was lost for the Firestore-backed
      // bell/list UI.
      data: data || {},
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    logger.error("notifyUser: failed to write notification doc", err);
  }

  try {
    const userDoc = await db.collection(USERS).doc(uid).get();
    if (!userDoc.exists) return;

    const single = userDoc.data().fcmToken;
    const tokens = single ? [single] : [];
    if (!tokens.length) return;

    // `type` travels alongside the related-record id(s) in the FCM
    // data payload so a tap on the system-tray/background push can
    // be routed client-side the same way an in-app notification tap
    // is — without it the client would know WHICH record but not
    // WHAT KIND of record it is.
    const stringData = { type: String(type) };
    Object.entries(data || {}).forEach(([k, v]) => {
      stringData[k] = String(v);
    });

    const response = await messaging.sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: stringData,
      android: { priority: "high" },
      apns: {
        headers: { "apns-priority": "10" },
        payload: { aps: { sound: "default", "content-available": 1 } },
      },
    });

    const staleTokens = [];
    response.responses.forEach((r, i) => {
      const code = r.error && r.error.code;
      if (
        !r.success &&
        (code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-registration-token")
      ) {
        staleTokens.push(tokens[i]);
      }
    });
    if (staleTokens.length) {
      await db.collection(USERS).doc(uid).update({
        fcmToken: admin.firestore.FieldValue.delete(),
      });
    }
  } catch (err) {
    logger.error("notifyUser: failed to send push", err);
  }
}

/** uid of whoever currently holds a singleton privileged role. */
async function uidForRole(role) {
  const doc = await db.collection(ROLE_SLOTS).doc(role).get();
  return doc.exists ? doc.data().uid : null;
}

// ---------------------------------------------------------------------
// Generic callable — for any event that doesn't have (or doesn't yet
// need) its own dedicated trigger below. Caller must be authenticated;
// swap/extend the permission check to whatever fits a given call site.
// ---------------------------------------------------------------------
exports.sendNotification = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  const { recipientUid, type, title, body, data } = request.data || {};
  if (!recipientUid || !type || !title || !body) {
    throw new HttpsError(
      "invalid-argument",
      "recipientUid, type, title, and body are required."
    );
  }
  await notifyUser(recipientUid, { type, title, body, data });
  return { success: true };
});

// ---------------------------------------------------------------------
// New appointment (clinical or medication) -> notify the patient.
// ---------------------------------------------------------------------
exports.onAppointmentCreated = onDocumentCreated(
  `${APPOINTMENTS}/{appointmentId}`,
  async (event) => {
    const appt = event.data.data();
    const isMedication = appt.type === "medication";
    await notifyUser(appt.patientUid, {
      type: "appointment",
      title: isMedication
        ? "New medication appointment scheduled"
        : "New appointment scheduled",
      body: appt.purpose || "",
      data: { appointmentId: event.params.appointmentId },
    });
  }
);
// ---------------------------------------------------------------------
// ADDED: appointment outcome notification
// Appointment outcome recorded (AppointmentService.recordOutcome) ->
// notify the patient. Covers both a clinical appointment being
// completed/missed and a medication appointment being marked
// administered/not administered — the only "appointment change"
// event this app actually has; there is no reschedule or
// cancellation workflow in the client to hook into.
// ---------------------------------------------------------------------
exports.onAppointmentUpdated = onDocumentUpdated(
  `${APPOINTMENTS}/{appointmentId}`,
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (before.status !== "scheduled" || after.status === "scheduled") return;

    const isMedication = after.type === "medication";
    const completed = after.status === "completed";

    let title;
    if (isMedication) {
      title = completed ? "Medication administered" : "Medication not administered";
    } else {
      title = completed ? "Appointment completed" : "Appointment missed";
    }

    await notifyUser(after.patientUid, {
      type: "appointment",
      title,
      body: after.purpose || "",
      data: { appointmentId: event.params.appointmentId },
    });
  }
);
// ---------------------------------------------------------------------
// New care request -> notify the Director (singleton privileged role).
// ---------------------------------------------------------------------
exports.onCareRequestCreated = onDocumentCreated(
  `${CARE_REQUESTS}/{requestId}`,
  async (event) => {
    const request = event.data.data();
    const directorUid = await uidForRole("director");
    if (!directorUid) return;
    await notifyUser(directorUid, {
      type: "careRequest",
      title: "New care request submitted",
      body: request.reason || "",
      data: { careRequestId: event.params.requestId },
    });
  }
);

// ---------------------------------------------------------------------
// Care request status changes -> notify whoever needs to act/know.
// ---------------------------------------------------------------------
exports.onCareRequestUpdated = onDocumentUpdated(
  `${CARE_REQUESTS}/{requestId}`,
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const requestId = event.params.requestId;

    if (
      before.directorDecision !== "approved" &&
      after.directorDecision === "approved"
    ) {
      const [adminUid, cmhpUid] = await Promise.all([
        uidForRole("admin"),
        uidForRole("cmhpCoordinator"),
      ]);
      const targets = [adminUid, cmhpUid].filter(Boolean);
      await Promise.all(
        targets.map((uid) =>
          notifyUser(uid, {
            type: "careRequest",
            title: "Care request approved by Director",
            body: "Assign patient to a nurse or doctor.",
            data: { careRequestId: requestId },
          })
        )
      );
    }
          if (before.status !== "accepted" && after.status === "accepted") {
      await notifyUser(after.patientUid, {
        type: "careRequest",
        title: "Your care request was accepted",
        body: `A ${after.acceptedByRole || "practitioner"} has been assigned to your care.`,
        data: { careRequestId: requestId },
      });
     // ADDED: referral notification
// Director sent the patient-facing referral.
if (!before.directorReferralSent && after.directorReferralSent) {
  await notifyUser(after.patientUid, {
    type: "careRequest",
    title: "A referral has been sent for your care request",
    body: "The Director has sent a referral note for your care request.",
    data: {
      careRequestId: requestId,
    },
  });
}

// ADDED: review notification
// Director shared the internal review with Admin.
if (!before.reviewSentToAdmin && after.reviewSentToAdmin) {
  const adminUid = await uidForRole("admin");

  await notifyUser(adminUid, {
    type: "careRequest",
    title: "Director shared a review note",
    body: "The Director shared a review note on a care request for your input.",
    data: {
      careRequestId: requestId,
    },
  });
}

// Director shared the internal review with CMHP Coordinator.
if (!before.reviewSentToCmhp && after.reviewSentToCmhp) {
  const cmhpUid = await uidForRole("cmhpCoordinator");

  await notifyUser(cmhpUid, {
    type: "careRequest",
    title: "Director shared a review note",
    body: "The Director shared a review note on a care request for your input.",
    data: {
      careRequestId: requestId,
    },
  });
}

// Director shared the internal review with CHP.
if (!before.reviewSentToChp && after.reviewSentToChp) {
  const chpUid = await uidForRole("chp");

  await notifyUser(chpUid, {
    type: "careRequest",
    title: "Director shared a review note",
    body: "The Director shared a review note on a care request for your input.",
    data: {
      careRequestId: requestId,
    },
  });
}
      // ADDED: practitioner acceptance notification
      // The practitioner side of the same event was previously
      // unnotified — whether they self-accepted (acceptRequest) or
      // were assigned by Admin/CMHP Coordinator (assignPractitioner),
      // both paths land here as the same status transition. A
      // self-accept already gets an in-app confirmation, so this is
      // a harmless no-op reminder in that case and the only signal
      // at all in the assigned case.
      if (after.acceptedByUid) {
        await notifyUser(after.acceptedByUid, {
          type: "careRequest",
          title: "A care request has been assigned to you",
          body: "Review the patient's concern and record your next-step decision.",
          data: { careRequestId: requestId },
        });
      }
    }
  }
  
);
// ---------------------------------------------------------------------
// ADDED: CHP message notification
// A CHP sends a review or referral SUGGESTION to the Director
// (chpSendMessageToDirector) -> notify the Director. Deliberately
// separate from the Director's own review/referral above — this is
// the CHP-initiated side of the conversation.
// ---------------------------------------------------------------------
exports.onCareRequestChpMessageCreated = onDocumentCreated(
  `${CARE_REQUESTS}/{requestId}/chpMessages/{messageId}`,
  async (event) => {
    const message = event.data.data();
    const requestId = event.params.requestId;
    const directorUid = await uidForRole("director");
    if (!directorUid) return;
    const isReferral = message.messageType === "referral";
    await notifyUser(directorUid, {
      type: "careRequest",
      title: isReferral
        ? "New referral suggestion from CHP"
        : "New review suggestion from CHP",
      body: message.text || "",
      data: { careRequestId: requestId },
    });
  }
);

// ---------------------------------------------------------------------
// ADDED: feedback notification
// Admin/CMHP Coordinator <-> Director feedback exchange on a shared
// review note (submitReviewFeedback) -> notify whichever side didn't
// author this entry. The same subcollection carries both directions,
// distinguished by authorRole.
// ---------------------------------------------------------------------
exports.onCareRequestFeedbackCreated = onDocumentCreated(
  `${CARE_REQUESTS}/{requestId}/directorFeedback/{feedbackId}`,
  async (event) => {
    const feedback = event.data.data();
    const requestId = event.params.requestId;
    const authorRole = feedback.authorRole;

    if (authorRole === "director") {
      const requestDoc = await db.collection(CARE_REQUESTS).doc(requestId).get();
      const request = requestDoc.exists ? requestDoc.data() : {};
      const [adminUid, cmhpUid] = await Promise.all([
        request.reviewSentToAdmin ? uidForRole("admin") : null,
        request.reviewSentToCmhp ? uidForRole("cmhpCoordinator") : null,
      ]);
      const targets = [adminUid, cmhpUid].filter(Boolean);
      await Promise.all(
        targets.map((uid) =>
          notifyUser(uid, {
            type: "careRequest",
            title: "Director replied to your feedback",
            body: feedback.feedbackText || "",
            data: { careRequestId: requestId },
          })
        )
      );
    } else {
      const directorUid = await uidForRole("director");
      if (!directorUid) return;
      await notifyUser(directorUid, {
        type: "careRequest",
        title: "New feedback on a shared care request review",
        body: feedback.feedbackText || "",
        data: { careRequestId: requestId },
      });
    }
  }
);
// ---------------------------------------------------------------------
// Admission / discharge / discharge-request events on a patient record.
// ---------------------------------------------------------------------
exports.onPatientRecordUpdated = onDocumentUpdated(
  `${PATIENTS}/{patientUid}`,
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    const patientUid = event.params.patientUid;

    if (before.status !== "admitted" && after.status === "admitted") {
      await notifyUser(patientUid, {
        type: "admission",
        title: "You have been admitted",
        body: after.amaudoFacility
          ? `Admitted at ${after.amaudoFacility}.`
          : "Your admission has been recorded.",
        data: { patientUid },
      });
    }

    if (before.status !== "discharged" && after.status === "discharged") {
      await notifyUser(patientUid, {
        type: "discharge",
        title: "You have been discharged",
        body: after.dischargeSummary || "Your discharge has been recorded.",
        data: { patientUid },
      });
    }

    if (!before.dischargeRequested && after.dischargeRequested) {
      const [chpUid, cmhpUid] = await Promise.all([
        uidForRole("chp"),
        uidForRole("cmhpCoordinator"),
      ]);
      const targets = [chpUid, cmhpUid].filter(Boolean);
      await Promise.all(
        targets.map((uid) =>
          notifyUser(uid, {
            type: "discharge",
            title: "Discharge approval requested",
            body: "A patient discharge is awaiting your approval.",
            data: { patientUid },
          })
        )
      );
    }
  }
);