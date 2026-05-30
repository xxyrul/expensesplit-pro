#!/usr/bin/env node
// tools/repair_expenses.js
// Scan and optionally repair users/*/expenses documents where `vendor` looks numeric.
// Usage:
//   node tools/repair_expenses.js --report report.csv
//   node tools/repair_expenses.js --report report.csv --apply
// Requires: set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON

const admin = require('firebase-admin');
const fs = require('fs');
const { createObjectCsvWriter } = require('csv-writer');

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('ERROR: Set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON path.');
  process.exit(1);
}

admin.initializeApp();
const db = admin.firestore();

const args = process.argv.slice(2);
const reportIdx = args.indexOf('--report');
const reportPath = reportIdx !== -1 ? args[reportIdx + 1] : 'repair_report.csv';
const apply = args.includes('--apply');

function parseAmountFromString(s) {
  if (!s) return null;
  const cleaned = s.replace(/RM|rm|\s|\$/g, '');
  const m = cleaned.match(/[-+]?[0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{2})/);
  if (!m) return null;
  let n = m[0].replace(/,/g, '');
  n = n.replace(/·/g, '.');
  const num = parseFloat(n);
  return Number.isFinite(num) ? num : null;
}

function looksLikeNumericVendor(vendor) {
  if (!vendor) return false;
  const t = String(vendor).trim();
  if (/^[\d\.,\sRMrm\$€]+$/.test(t)) return true;
  const digits = (t.match(/\d/g) || []).length;
  const letters = (t.match(/[A-Za-z]/g) || []).length;
  return digits > 3 && letters === 0;
}

(async () => {
  const csvWriter = createObjectCsvWriter({
    path: reportPath,
    header: [
      { id: 'userId', title: 'userId' },
      { id: 'expenseId', title: 'expenseId' },
      { id: 'vendor', title: 'vendor' },
      { id: 'amount', title: 'amount' },
      { id: 'parsedAmount', title: 'parsedAmount' },
      { id: 'action', title: 'action' },
    ],
  });

  const rows = [];
  console.log('Scanning users/*/expenses...');
  const usersSnap = await db.collection('users').get();
  for (const userDoc of usersSnap.docs) {
    const uid = userDoc.id;
    const expensesRef = db.collection('users').doc(uid).collection('expenses');
    const expensesSnap = await expensesRef.get();
    for (const expDoc of expensesSnap.docs) {
      const data = expDoc.data();
      const vendor = data.vendor !== undefined && data.vendor !== null ? String(data.vendor) : '';
      const amount = data.amount !== undefined && data.amount !== null ? Number(data.amount) : null;
      if (looksLikeNumericVendor(vendor)) {
        const parsedAmount = parseAmountFromString(vendor);
        rows.push({ userId: uid, expenseId: expDoc.id, vendor, amount, parsedAmount: parsedAmount || '', action: apply ? 'will-patch' : 'report-only' });

        if (apply) {
          const update = {};
          if (parsedAmount !== null && (!amount || Math.abs(amount - parsedAmount) > 0.01)) {
            update.amount = parsedAmount;
          }
          update['metadata.originalVendor'] = vendor;
          if (amount !== null) update['metadata.originalAmount'] = amount;
          update.vendor = 'Unknown vendor (repaired)';

          await expensesRef.doc(expDoc.id).update(update);
          console.log(`Patched ${uid}/${expDoc.id}`);
        }
      }
    }
  }

  await csvWriter.writeRecords(rows);
  console.log(`Report written to ${reportPath}. ${apply ? 'Applied patches.' : 'No changes applied.'}`);
})();
