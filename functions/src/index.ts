import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';

admin.initializeApp();

const BATCH_LIMIT = 500;

type OcrLearningData = Record<string, unknown>;

export const syncOcrLearning = onDocumentWritten('ocr_learning/{ruleId}', async (event) => {
  const after = event.data?.after;
  if (!after || !after.exists) {
    console.log('ocr_learning document deleted; skipping sync.');
    return;
  }

  const before = event.data?.before;
  const afterData = after.data() as OcrLearningData;
  const beforeData = before?.exists ? (before.data() as OcrLearningData) : null;

  if (beforeData && JSON.stringify(beforeData) === JSON.stringify(afterData)) {
    console.log('No meaningful change detected in ocr_learning; skipping sync.');
    return;
  }

  const ruleId = event.params.ruleId as string;
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