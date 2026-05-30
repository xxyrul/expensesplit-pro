#!/usr/bin/env node
// tools/backfill_ocr_vendor.js
// Backfill missing vendor fields on OCR review/log documents using rawText.
// Usage:
//   node tools/backfill_ocr_vendor.js --dry-run
//   node tools/backfill_ocr_vendor.js --apply
// Requires: set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON

const admin = require('firebase-admin');

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('ERROR: Set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON path.');
  process.exit(1);
}

admin.initializeApp();
const db = admin.firestore();

const args = process.argv.slice(2);
const apply = args.includes('--apply');
const dryRun = !apply || args.includes('--dry-run');

function parseVendorFromRawText(rawText) {
  if (!rawText) return '';

  const lines = String(rawText)
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.length > 0);

  if (lines.length === 0) return '';

  const skipPatterns = [
    'receipt',
    'invoice',
    'tax',
    'cash',
    'copy',
    'duplicated',
    'store',
    'welcome',
    'hello',
    'merchant',
    'terminal',
    'pos',
    'visa',
    'mastercard',
    'change',
    'total',
    'amount',
    'date',
    'time',
    'card',
    'auth',
  ];

  for (const line of lines) {
    const lowerLine = line.toLowerCase();
    if (!/[a-zA-Z]/.test(line)) continue;

    let shouldSkip = false;
    for (const pattern of skipPatterns) {
      if (lowerLine.includes(pattern)) {
        shouldSkip = true;
        break;
      }
    }

    if (
      /\d{2,4}[\/.-]\d{2}[\/.-]\d{2,4}/.test(line) ||
      /\d{2}:\d{2}/.test(line) ||
      /[\d-]{8,}/.test(line)
    ) {
      shouldSkip = true;
    }

    if (!shouldSkip && line.length >= 3) {
      return line;
    }
  }

  return lines[0] || '';
}

async function backfillCollectionGroup(collectionId) {
  const snapshot = await db.collectionGroup(collectionId).get();
  let scanned = 0;
  let updated = 0;

  for (const doc of snapshot.docs) {
    scanned += 1;
    const data = doc.data();
    const existingVendor = data.vendor != null ? String(data.vendor).trim() : '';
    if (existingVendor) continue;

    const parsedVendor = parseVendorFromRawText(data.rawText);
    if (!parsedVendor) continue;

    if (dryRun) {
      console.log(`[dry-run] ${doc.ref.path} -> vendor="${parsedVendor}"`);
      updated += 1;
      continue;
    }

    await doc.ref.update({ vendor: parsedVendor });
    console.log(`Updated ${doc.ref.path} -> vendor="${parsedVendor}"`);
    updated += 1;
  }

  return { scanned, updated };
}

(async () => {
  const collectionIds = ['ocr_logs', 'ocr_review'];
  let totalScanned = 0;
  let totalUpdated = 0;

  for (const collectionId of collectionIds) {
    const { scanned, updated } = await backfillCollectionGroup(collectionId);
    totalScanned += scanned;
    totalUpdated += updated;
  }

  console.log(
    `${dryRun ? 'Dry run' : 'Backfill'} complete. ` +
      `Scanned: ${totalScanned}. ` +
      `Vendor fields ${dryRun ? 'to update' : 'updated'}: ${totalUpdated}.`
  );
})();