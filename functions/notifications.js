const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

const db = admin.firestore();
const messaging = admin.messaging();

const USERS = "users";
const APPOINTMENTS = "appointments";
const CARE_REQUESTS = "careRequests";
const PATIENTS = "patients";
const NOTIFICATIONS = "notifications";
const ROLE_SLOTS = "roleSlots";

/**
 * Single source of truth for "notify a user": writes the in-app
 * notification doc the existing bell UI already reads (same
 * collection/schema, untouched) AND sends an FCM push to every
 * token on file for that user. Stale tokens (uninstalled app,
 * cleared data, etc.) are pruned as they're discovered. Never
 * throws — a notification failure must never fail the write that
 * triggered it.
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
    console.error("notifyUser: failed to write notification doc", err);
  }

  try {
    const userDoc = await db.collection(USERS).doc(uid).get();
    const tokens = userDoc.exists ? userDoc.data().fcmTokens || [] : [];
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
      apns: { payload: { aps: { sound: "default" } } },
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
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...staleTokens),
      });
    }
  } catch (err) {
    console.error("notifyUser: failed to send push", err);
  }
}

/** uid of whoever currently holds a singleton privileged role. */
async function uidForRole(role) {
  const doc = await db.collection(ROLE_SLOTS).doc(role).get();
  return doc.exists ? doc.data().uid : null;
}

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

    // Director approved -> Admin + CMHP Coordinator can now accept.
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
            body: "A care request is ready to be accepted.",
            data: { careRequestId: requestId },
          })
        )
      );
    }

    // Accepted -> notify the patient.
    if (before.status !== "accepted" && after.status === "accepted") {
      await notifyUser(after.patientUid, {
        type: "careRequest",
        title: "Your care request was accepted",
        body: `A ${after.acceptedByRole || "practitioner"} has been assigned to your care.`,
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

// ---------------------------------------------------------------------
// Appointment/medication reminders: 3 days before, 1 day before,
// day-of (8:00 AM local-server-time), and 4 hours before. Runs every
// 15 minutes; remindersSent on each appointment doc is how a
// reminder is guaranteed to fire at most once, and is exactly what
// makes "completed/administered/cancelled/missed stops future
// reminders" work — this query only ever looks at status == 'scheduled'.
// A brand-new medication appointment is a brand-new document with an
// empty remindersSent, so it automatically starts its own cycle.
// ---------------------------------------------------------------------
const REMINDER_OFFSETS = [
  { key: "3d", ms: 3 * 24 * 60 * 60 * 1000 },
  { key: "1d", ms: 1 * 24 * 60 * 60 * 1000 },
  { key: "4h", ms: 4 * 60 * 60 * 1000 },
];

exports.sendAppointmentReminders = onSchedule(
  { schedule: "every 15 minutes", timeoutSeconds: 300 },
  async () => {
    const now = Date.now();
    const snap = await db
      .collection(APPOINTMENTS)
      .where("status", "==", "scheduled")
      .get();

    for (const doc of snap.docs) {
      const appt = doc.data();
      const scheduledAt = appt.scheduledAt && appt.scheduledAt.toDate
        ? appt.scheduledAt.toDate()
        : null;
      if (!scheduledAt) continue;

      const alreadySent = appt.remindersSent || [];
      const isMedication = appt.type === "medication";

      const dayOf = new Date(scheduledAt);
      dayOf.setHours(8, 0, 0, 0);

      const dueReminders = [];

      for (const offset of REMINDER_OFFSETS) {
        const fireAt = scheduledAt.getTime() - offset.ms;
        if (!alreadySent.includes(offset.key) && fireAt <= now) {
          dueReminders.push(offset.key);
        }
      }
      if (!alreadySent.includes("dayof") && dayOf.getTime() <= now) {
        dueReminders.push("dayof");
      }

      if (!dueReminders.length) continue;

      await notifyUser(appt.patientUid, {
        type: "appointment",
        title: isMedication ? "Medication reminder" : "Appointment reminder",
        body: appt.purpose || "",
        data: { appointmentId: doc.id },
      });

      await doc.ref.update({
        remindersSent: admin.firestore.FieldValue.arrayUnion(...dueReminders),
      });
    }
  }
);