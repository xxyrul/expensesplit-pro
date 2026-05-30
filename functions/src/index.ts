import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';
import * as functions from 'firebase-functions';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

admin.initializeApp();

const BATCH_LIMIT = 500;

type OcrLearningData = Record<string, unknown>;

export const syncOcrLearning = functions.firestore
  .document('ocr_learning/{ruleId}')
  .onWrite(async (change, context) => {
  const after = change.after;
  if (!after || !after.exists) {
    console.log('ocr_learning document deleted; skipping sync.');
    return;
  }

  const before = change.before;
  const afterData = after.data() as OcrLearningData;
  const beforeData = before?.exists ? (before.data() as OcrLearningData) : null;

  if (beforeData && JSON.stringify(beforeData) === JSON.stringify(afterData)) {
    console.log('No meaningful change detected in ocr_learning; skipping sync.');
    return;
  }

  const ruleId = context.params.ruleId as string;
  const db = admin.firestore();
  const usersRef = db.collection('users');

  let lastDocId: string | null = null;
  let batchNumber = 0;

  try {
    while (true) {
      let query = usersRef.orderBy(admin.firestore.FieldPath.documentId()).limit(BATCH_LIMIT);
      if (lastDocId) {
        query = query.startAfter(lastDocId);
      }

      const usersSnap = await query.get();
      if (usersSnap.empty) {
        break;
      }

      const batch = db.batch();
      for (const userDoc of usersSnap.docs) {
        const vendorRuleRef = usersRef.doc(userDoc.id).collection('vendor_catalog').doc(ruleId);

        batch.set(
          vendorRuleRef,
          {
            ...afterData,
            _syncedFromGlobal: true,
            _syncedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }

      await batch.commit();
      batchNumber += 1;
      console.log(`Committed batch #${batchNumber} for rule ${ruleId} (${usersSnap.size} users).`);

      lastDocId = usersSnap.docs[usersSnap.docs.length - 1].id;
      if (usersSnap.size < BATCH_LIMIT) {
        break;
      }
    }

    console.log(`Completed sync for ocr_learning/${ruleId}.`);
  } catch (error) {
    console.error(`Failed to sync ocr_learning/${ruleId}:`, error);
    throw error;
  }
  });

export const sendSystemBroadcast = onDocumentCreated(
  {
    document: 'system_broadcasts/{docId}',
    region: 'asia-southeast1',
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.error(`Missing broadcast snapshot for ${event.params.docId}.`);
      return;
    }

    const data = snapshot.data() as Record<string, unknown>;
    const message = (data.message as string | undefined)?.trim();

    if (!message) {
      await snapshot.ref.update({
        status: 'failed',
        errorDetails: 'Missing message field.',
      });
      return;
    }

    try {
      const messageId = await admin.messaging().send({
        topic: 'global_broadcast',
        notification: {
          title: 'ExpenseSplit Pro Alert',
          body: message,
        },
      });

      console.log(
        `Sent system broadcast ${event.params.docId} to global_broadcast: ${messageId}`
      );

      await snapshot.ref.update({
        status: 'sent',
        sentAt: FieldValue.serverTimestamp(),
        messageId,
      });
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      console.error(`Failed to send system broadcast ${event.params.docId}:`, error);
      await snapshot.ref.update({
        status: 'failed',
        errorDetails: errorMessage,
      });
    }
  }
);
