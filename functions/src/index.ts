import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';
import {
  onDocumentWritten,
  onDocumentCreated,
} from 'firebase-functions/v2/firestore';
import { onRequest, onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';

admin.initializeApp();

// Genkit removed

const BATCH_LIMIT = 500;

type OcrLearningData = Record<string, unknown>;

// ─── syncOcrLearning (v2) ────────────────────────────────────────────────────
export const syncOcrLearning = onDocumentWritten(
  {
    document: 'ocr_learning/{ruleId}',
    region: 'asia-southeast1',
    secrets: [],
  },
  async (event) => {
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
  }
);

// ─── sendSystemBroadcast (v2) ─────────────────────────────────────────────────
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

// ─── Rule-Based Tip Generator ───────────────────────────────────────────────────
function generateRuleBasedTip(): { message: string, category: string } {
  const categories = ['saving', 'security', 'wisdom', 'positive_reinforcement'];
  const category = categories[Math.floor(Math.random() * categories.length)];
  
  let message = '';
  switch (category) {
    case 'saving':
      const savingTips = [
        "Review your recurring subscriptions today to find hidden savings.",
        "A simple home-cooked meal instead of eating out can save you up to RM 50 this week.",
        "Consider using the 50/30/20 rule to structure your monthly budget."
      ];
      message = savingTips[Math.floor(Math.random() * savingTips.length)];
      break;
    case 'security':
      const securityTips = [
        "Never share your OTP with anyone. ExpenseSplit Pro will never ask for it.",
        "Check your transaction history weekly to spot any unauthorized charges early.",
        "Keep your banking passwords updated every 6 months for maximum security."
      ];
      message = securityTips[Math.floor(Math.random() * securityTips.length)];
      break;
    case 'positive_reinforcement':
      const positiveTips = [
        "Great job keeping track of your expenses! Consistency is the key to financial freedom.",
        "Every receipt you log gets you one step closer to mastering your budget.",
        "You're doing fantastic! Logging small expenses helps catch leaks before they sink the ship."
      ];
      message = positiveTips[Math.floor(Math.random() * positiveTips.length)];
      break;
    default:
      const wisdomTips = [
        "Pay yourself first: try putting 10% of your allowance into savings immediately.",
        "Don't let small daily expenses add up invisibly. Track every coffee and snack.",
        "A budget is telling your money where to go instead of wondering where it went."
      ];
      message = wisdomTips[Math.floor(Math.random() * wisdomTips.length)];
      break;
  }
  return { message, category };
}

// ─── sendDailyFinancialNudge (v2 scheduler) ───────────────────────────────────
export const sendDailyFinancialNudge = onSchedule(
  {
    schedule: '0 9,21 * * *',
    timeZone: 'Asia/Kuala_Lumpur',
    secrets: ['GEMINI_API_KEY'],
  },
  async (_event) => {
    const db = admin.firestore();
    const messaging = admin.messaging();

    let tipMessage = 'Stay on top of your finances!';
    let tipCategory = 'wisdom';
    let isDynamic = false;

    try {
      const generated = generateRuleBasedTip();
      tipMessage = generated.message;
      tipCategory = generated.category;
      isDynamic = true;
      console.log(`Generated dynamic rule-based tip: ${tipMessage} (${tipCategory})`);

      await db.collection('daily_tips').add({
        message: tipMessage,
        category: tipCategory,
        priority: 2,
        isActive: true,
        display_date: new Date().toISOString().split('T')[0],
        generatedAt: FieldValue.serverTimestamp(),
      });
    } catch (err) {
      console.error('Error generating rule-based tip:', err);
    }

    if (!isDynamic) {
      console.log('Using fallback tip from database...');
      const tipsSnapshot = await db.collection('daily_tips').where('isActive', '==', true).get();
      if (!tipsSnapshot.empty) {
        const tips = tipsSnapshot.docs.map((doc) => doc.data());
        const randomTip = tips[Math.floor(Math.random() * tips.length)];
        tipMessage = randomTip.message || tipMessage;
        tipCategory = randomTip.category || tipCategory;
        console.log(`Successfully fetched fallback tip: ${tipMessage}`);
      } else {
        console.log('No active tips found in daily_tips database. Using default fallback.');
      }
    }

    const usersSnapshot = await db.collection('users').get();
    const tokens: string[] = [];
    usersSnapshot.forEach((userDoc) => {
      const userData = userDoc.data();
      if (userData.isDailyTipsEnabled !== false) {
        if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
          tokens.push(...userData.fcmTokens);
        }
      }
    });

    if (tokens.length === 0) {
      console.log('No eligible users/tokens found.');
      return;
    }

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
  }
);

// ─── seedDailyTips (v2 https) ─────────────────────────────────────────────────
export const seedDailyTips = onRequest(async (_req, res) => {
  try {
    const db = admin.firestore();
    const tips = [
      { message: 'Small leaks sink a great ship. Have you checked your recurring subscriptions this month?', category: 'saving', priority: 1, isActive: true, generatedAt: FieldValue.serverTimestamp() },
      { message: 'Security first! Ensure you never share your ExpenseSplit Pro OTP with anyone.', category: 'security', priority: 1, isActive: true, generatedAt: FieldValue.serverTimestamp() },
      { message: 'Awesome progress! Keeping track consistently is the secret to successful budgeting.', category: 'positive_reinforcement', priority: 2, isActive: true, generatedAt: FieldValue.serverTimestamp() },
      { message: "The 50/30/20 rule: 50% to needs, 30% to wants, 20% to savings. Adjust your tags to see if you're on track!", category: 'wisdom', priority: 2, isActive: true, generatedAt: FieldValue.serverTimestamp() },
      { message: 'Splitting bills frequently? Make sure to settle up pending balances early to avoid financial friction.', category: 'wisdom', priority: 3, isActive: true, generatedAt: FieldValue.serverTimestamp() },
    ];

    const batch = db.batch();
    tips.forEach((tip) => {
      const docRef = db.collection('daily_tips').doc();
      batch.set(docRef, tip);
    });

    await batch.commit();
    res.send('Seeded 5 daily tips successfully!');
  } catch (err: any) {
    res.status(500).send('Error seeding daily tips: ' + err.message);
  }
});

// ─── generateNewDailyTip (v2 https) ───────────────────────────────────────────
export const generateNewDailyTip = onRequest(
  { secrets: ['GEMINI_API_KEY'] },
  async (_req, res) => {
    const db = admin.firestore();
    let tipMessage = 'Stay on top of your finances!';
    let tipCategory = 'wisdom';

    try {
      const generated = generateRuleBasedTip();
      tipMessage = generated.message;
      tipCategory = generated.category;

      await db.collection('daily_tips').add({
        message: tipMessage,
        category: tipCategory,
        priority: 2,
        isActive: true,
        display_date: new Date().toISOString().split('T')[0],
        generatedAt: FieldValue.serverTimestamp(),
      });

      res.json({ status: 'success', message: tipMessage, category: tipCategory });
      return;
    } catch (err: any) {
      console.error('Error generating rule-based tip:', err);
    }

    try {
      const tipsSnapshot = await db.collection('daily_tips').where('isActive', '==', true).get();
      if (!tipsSnapshot.empty) {
        const tips = tipsSnapshot.docs.map((doc) => doc.data());
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

        res.json({ status: 'fallback', message: tipMessage, category: tipCategory });
      } else {
        res.status(500).send('No tips found.');
      }
    } catch (err: any) {
      res.status(500).send('Error: ' + err.message);
    }
  }
);

// ─── Helper ───────────────────────────────────────────────────────────────────
function calculateVelocity(spent: number, limit: number): string {
  const today = new Date().getDate();
  const daysInMonth = new Date(new Date().getFullYear(), new Date().getMonth() + 1, 0).getDate();
  const monthProgress = today / daysInMonth;
  const budgetProgress = spent / limit;

  if (budgetProgress > monthProgress + 0.1) return 'High - spending faster than time elapsed';
  if (budgetProgress < monthProgress - 0.1) return 'Low - spending slower than time elapsed';
  return 'On Track';
}

// ─── generateDailyInsight (v2 callable) ───────────────────────────────────────
export const generateDailyInsight = onCall(
  { secrets: ['GEMINI_API_KEY'] },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Requires authentication.');

    const db = admin.firestore();
    const userId = request.auth.uid;
    const data = request.data;
    const todayStr = data?.dateStr || new Date().toISOString().split('T')[0];

    try {
      const userDoc = await db.collection('users').doc(userId).get();
      const userData = userDoc.data() || {};

      const currentMonthSpent = data?.currentMonthSpent ?? (userData.currentMonthSpent || 0);
      const monthlyBudget = data?.monthlyBudget ?? (userData.monthlyBudget || 3000);
      const lastMonthSpent = userData.lastMonthSpent || 0;

      const payload = {
        currentMonthSpent,
        monthlyBudget,
        lastMonthSpent,
        velocity: calculateVelocity(currentMonthSpent, monthlyBudget),
        dayOfMonth: new Date().getDate(),
      };

      let insightText = '';
      if (payload.velocity.includes('High')) {
        insightText = `You've spent RM ${payload.currentMonthSpent.toFixed(0)} so far, which is faster than expected. Try slowing down for the rest of the month to stay within your RM ${payload.monthlyBudget.toFixed(0)} limit!`;
      } else if (payload.velocity.includes('Low')) {
        insightText = `Great pacing! At RM ${payload.currentMonthSpent.toFixed(0)}, you're spending slower than time elapsed. Keep it up!`;
      } else {
        insightText = `You're exactly on track with RM ${payload.currentMonthSpent.toFixed(0)} spent. Maintain this balanced spending pattern.`;
      }

      const insightData = {
        insight: insightText,
        date: todayStr,
        generatedAt: FieldValue.serverTimestamp(),
        usedBudget: currentMonthSpent,
        totalBudget: monthlyBudget,
      };

      await db
        .collection('users')
        .doc(userId)
        .collection('daily_insights')
        .doc(todayStr)
        .set(insightData);

      return insightData;
    } catch (error) {
      console.error('Failed to generate insight:', error);
      throw new HttpsError('internal', 'AI Generation failed');
    }
  }
);

// analyzeReceiptText has been removed. Client apps use offline local parsing.

// ─── adminManageUser (v2 callable) ────────────────────────────────────────────
export const adminManageUser = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Requires authentication.');
  }

  // Verify the caller is an Admin from Firestore
  const callerDoc = await admin.firestore().collection('users').doc(request.auth.uid).get();
  if (callerDoc.data()?.role !== 'Admin') {
    throw new HttpsError('permission-denied', 'Caller must be an admin.');
  }

  const { action, targetUid, isActive } = request.data;
  if (!targetUid || !action) {
    throw new HttpsError('invalid-argument', 'Missing targetUid or action.');
  }

  const db = admin.firestore();

  try {
    if (action === 'delete') {
      try {
        await admin.auth().deleteUser(targetUid);
      } catch (authError: any) {
        // If the user is already deleted from Auth, proceed to clean up Firestore
        if (authError.code !== 'auth/user-not-found') {
          throw authError;
        }
      }
      
      await admin.firestore().collection('users').doc(targetUid).delete();
      return { success: true, message: `Deleted user ${targetUid}` };
    } else if (action === 'toggleStatus') {
      // 1. Update Firebase Auth status
      const newStatus = !isActive;
      await admin.auth().updateUser(targetUid, { disabled: !newStatus });
      // 2. Update Firestore
      await db.collection('users').doc(targetUid).update({ isActive: newStatus });
      return { status: 'success', message: `User status updated to ${newStatus ? 'Active' : 'Deactivated'}.` };
    } else {
      throw new HttpsError('invalid-argument', 'Invalid action specified.');
    }
  } catch (error) {
    console.error(`Failed to execute adminManageUser (${action}) for ${targetUid}:`, error);
    throw new HttpsError('internal', 'An error occurred while managing the user.');
  }
});
