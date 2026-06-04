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

export const sendDailyFinancialNudge = functions.pubsub.schedule('0 9 * * *')
  .timeZone('Asia/Kuala_Lumpur')
  .onRun(async (context) => {
    const db = admin.firestore();
    const messaging = admin.messaging();

    let tipMessage = 'Stay on top of your finances!';
    let tipCategory = 'wisdom';
    let isDynamic = false;

    const apiKey = process.env.GEMINI_API_KEY;
    if (apiKey) {
      try {
        const { GoogleGenAI } = require('@google/genai');
        const ai = new GoogleGenAI({ apiKey: apiKey });
        const prompt = `Generate a short, engaging, and professional financial tip or nudge for a budgeting app user. Keep the tip text under 150 characters. 
Choose one of the following categories:
- 'saving': tips on saving money, budgeting, checking recurring subscriptions.
- 'security': tips on security, avoiding sharing OTPs, protecting identity.
- 'wisdom': general financial tips, budgeting principles like the 50/30/20 rule, settling balances early.
- 'positive_reinforcement': celebrating consistent tracking, positive reinforcement.

Return the response as a JSON object with 'message' and 'category' fields.`;

        const response = await ai.models.generateContent({
          model: 'gemini-2.0-flash',
          contents: prompt,
          config: {
            responseMimeType: 'application/json',
          }
        });

        if (response.text) {
          const parsed = JSON.parse(response.text.trim());
          if (parsed.message && parsed.category) {
            tipMessage = parsed.message;
            tipCategory = parsed.category;
            isDynamic = true;
            console.log(`Generated dynamic tip via Gemini: ${tipMessage} (${tipCategory})`);

            // Save the newly generated tip to the daily_tips collection
            await db.collection('daily_tips').add({
              message: tipMessage,
              category: tipCategory,
              priority: 2,
              isActive: true,
              display_date: new Date().toISOString().split('T')[0],
              generatedAt: FieldValue.serverTimestamp(),
            });
          }
        }
      } catch (err) {
        console.error('Error generating dynamic tip with Gemini:', err);
      }
    }

    if (!isDynamic) {
      console.log('Using fallback tip from database...');
      const tipsSnapshot = await db.collection('daily_tips').where('isActive', '==', true).get();
      if (!tipsSnapshot.empty) {
        const tips = tipsSnapshot.docs.map(doc => doc.data());
        const randomTip = tips[Math.floor(Math.random() * tips.length)];
        tipMessage = randomTip.message || tipMessage;
        tipCategory = randomTip.category || tipCategory;
        console.log(`Successfully fetched fallback tip: ${tipMessage}`);
      } else {
        console.log('No active tips found in daily_tips database. Using default fallback.');
      }
    }

    // Fetch users
    const usersSnapshot = await db.collection('users').get();
    
    // Collect FCM Tokens
    const tokens: string[] = [];
    usersSnapshot.forEach(userDoc => {
      const userData = userDoc.data();
      // Check if daily tips are enabled (default to true if missing/undefined)
      if (userData.isDailyTipsEnabled !== false) {
        if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
          tokens.push(...userData.fcmTokens);
        }
      }
    });

    if (tokens.length === 0) {
      console.log('No eligible users/tokens found.');
      return null;
    }

    // Send multicast message via FCM
    try {
      const response = await messaging.sendEachForMulticast({
        tokens,
        notification: {
          title: '💡 ExpenseSplit Pro',
          body: tipMessage,
        },
        data: {
          category: tipCategory,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'budget_alerts',
            priority: 'high',
            defaultSound: true,
          },
        },
      });
      console.log(`Successfully sent daily nudge. Success count: ${response.successCount}`);
    } catch (error) {
      console.error('Error sending daily nudge:', error);
    }
    
    return null;
  });

export const seedDailyTips = functions.https.onRequest(async (req, res) => {
  try {
    const db = admin.firestore();
    const tips = [
      { message: "Small leaks sink a great ship. Have you checked your recurring subscriptions this month?", category: "saving", priority: 1, isActive: true, generatedAt: admin.firestore.FieldValue.serverTimestamp() },
      { message: "Security first! Ensure you never share your ExpenseSplit Pro OTP with anyone.", category: "security", priority: 1, isActive: true, generatedAt: admin.firestore.FieldValue.serverTimestamp() },
      { message: "Awesome progress! Keeping track consistently is the secret to successful budgeting.", category: "positive_reinforcement", priority: 2, isActive: true, generatedAt: admin.firestore.FieldValue.serverTimestamp() },
      { message: "The 50/30/20 rule: 50% to needs, 30% to wants, 20% to savings. Adjust your tags to see if you're on track!", category: "wisdom", priority: 2, isActive: true, generatedAt: admin.firestore.FieldValue.serverTimestamp() },
      { message: "Splitting bills frequently? Make sure to settle up pending balances early to avoid financial friction.", category: "wisdom", priority: 3, isActive: true, generatedAt: admin.firestore.FieldValue.serverTimestamp() }
    ];

    const batch = db.batch();
    tips.forEach(tip => {
      const docRef = db.collection('daily_tips').doc();
      batch.set(docRef, tip);
    });
    
    await batch.commit();
    res.send("Seeded 5 daily tips successfully!");
  } catch (err: any) {
    res.status(500).send("Error seeding daily tips: " + err.message);
  }
});

export const generateNewDailyTip = functions.https.onRequest(async (req, res) => {
  const db = admin.firestore();
  let tipMessage = 'Stay on top of your finances!';
  let tipCategory = 'wisdom';

  const apiKey = process.env.GEMINI_API_KEY;
  if (apiKey) {
    try {
      const { GoogleGenAI } = require('@google/genai');
      const ai = new GoogleGenAI({ apiKey: apiKey });
      const prompt = `Generate a short, engaging, and professional financial tip or nudge for a budgeting app user. Keep the tip text under 150 characters. 
Choose one of the following categories:
- 'saving': tips on saving money, budgeting, checking recurring subscriptions.
- 'security': tips on security, avoiding sharing OTPs, protecting identity.
- 'wisdom': general financial tips, budgeting principles like the 50/30/20 rule, settling balances early.
- 'positive_reinforcement': celebrating consistent tracking, positive reinforcement.

Return the response as a JSON object with 'message' and 'category' fields.`;

      const response = await ai.models.generateContent({
        model: 'gemini-2.0-flash',
        contents: prompt,
        config: {
          responseMimeType: 'application/json',
        }
      });

      if (response.text) {
        const parsed = JSON.parse(response.text.trim());
        if (parsed.message && parsed.category) {
          tipMessage = parsed.message;
          tipCategory = parsed.category;
          
          await db.collection('daily_tips').add({
            message: tipMessage,
            category: tipCategory,
            priority: 2,
            isActive: true,
            display_date: new Date().toISOString().split('T')[0],
            generatedAt: FieldValue.serverTimestamp(),
          });

          res.json({ status: "success", message: tipMessage, category: tipCategory });
          return;
        }
      }
    } catch (err: any) {
      console.error('Error generating dynamic tip with Gemini:', err);
    }
  }

  // Fallback to random seeded tip
  try {
    const tipsSnapshot = await db.collection('daily_tips').where('isActive', '==', true).get();
    if (!tipsSnapshot.empty) {
      const tips = tipsSnapshot.docs.map(doc => doc.data());
      const randomTip = tips[Math.floor(Math.random() * tips.length)];
      tipMessage = randomTip.message || tipMessage;
      tipCategory = randomTip.category || tipCategory;

      await db.collection('daily_tips').add({
        message: tipMessage,
        category: tipCategory,
        priority: 2,
        isActive: true,
        display_date: new Date().toISOString().split('T')[0],
        generatedAt: FieldValue.serverTimestamp(),
      });

      res.json({ status: "fallback", message: tipMessage, category: tipCategory });
    } else {
      res.status(500).send("No tips found.");
    }
  } catch (err: any) {
    res.status(500).send("Error: " + err.message);
  }
});

