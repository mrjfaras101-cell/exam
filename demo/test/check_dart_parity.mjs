/**
 * check_dart_parity.mjs — يتحقّق أن هندسة Dart (app/lib/vision/template.dart)
 * مطابقة تمامًا لهندسة JS (demo/js/template.js) التي تُختبر فعليًا هنا.
 *
 * السبب: كود Dart لا يُشغَّل في بيئة التطوير هذه، وهذا الفحص يمنع انحراف
 * القيم بين النسختين (وهو أخطر خطأ ممكن: ورقة تُطبع بإحداثيات وتُقرأ بأخرى).
 *
 * التشغيل: node demo/test/check_dart_parity.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildTemplate, GEO } from '../js/template.js';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const DART = path.join(HERE, '..', '..', 'app', 'lib', 'vision', 'template.dart');

const src = fs.readFileSync(DART, 'utf-8');

// استخراج كل الأعداد المُسمّاة: `idColPitch = 6.2, idRowPitch = 3.8, idR = 1.7`
const dart = {};
for (const m of src.matchAll(/([A-Za-z_]\w*)\s*=\s*(-?\d+(?:\.\d+)?)/g)) {
  dart[m[1]] = parseFloat(m[2]);
}
// علامات التسجيل في Dart مصفوفة مصفوفات: [10, 10], [138.5, 10], ...
const fidBlock = src.slice(src.indexOf('kFiducialCenters'), src.indexOf(']', src.indexOf('kFiducialCenters') + 200));
const fidNums = [...fidBlock.matchAll(/(-?\d+(?:\.\d+)?)/g)].map((m) => parseFloat(m[1]));
const dartFid = [];
for (let i = 0; i + 1 < fidNums.length; i += 2) dartFid.push([fidNums[i], fidNums[i + 1]]);

const tpl = buildTemplate({
  title: 'parity',
  serial: 3,
  idDigits: 8,
  questions: Array.from({ length: 40 }, (_, i) => ({ type: i < 27 ? 'choice' : 'yesno', options: 4 })),
});

let pass = 0, fail = 0;
const eq = (name, a, b) => {
  const same = Math.abs(Number(a) - Number(b)) < 1e-6;
  if (same) { pass++; } else { fail++; console.log(`  ✗ ${name}: Dart=${a} ≠ JS=${b}`); }
};

// الورقة وعلامات التسجيل
eq('kPaperW', dart.kPaperW, GEO.paper.w);
eq('kPaperH', dart.kPaperH, GEO.paper.h);
eq('kFiducialSize', dart.kFiducialSize, GEO.fiducial.size);
eq('kFiducialHole', dart.kFiducialHole, GEO.fiducial.ringHole);
eq('kFiducialPitchXMm', dart.kFiducialPitchXMm, Math.abs(GEO.fiducial.centers.TR[0] - GEO.fiducial.centers.TL[0]));
eq('kFiducialPitchYMm', dart.kFiducialPitchYMm, Math.abs(GEO.fiducial.centers.BL[1] - GEO.fiducial.centers.TL[1]));
eq('kRingIndex', dart.kRingIndex, 2);          // BR في ترتيب [TL,TR,BR,BL]
eq('kHeaderDividerY', dart.kHeaderDividerY, GEO.header.dividerY);
eq('kHeaderRight', dart.kHeaderRight, GEO.content.x1);
eq('kHeaderLeft', dart.kHeaderLeft, GEO.content.x0);
eq('kMaxQuestions', dart.kMaxQuestions, GEO.questions.maxRowsPerCol * 2);

// علامات التسجيل: نفس الإحداثيات ونفس ترتيب العناصر في القالب
const fidOrder = ['TL', 'TR', 'BR', 'BL'];
fidOrder.forEach((id, i) => {
  const jsFid = tpl.fiducials.find((f) => f.id === id);
  eq(`fiducial ${id} x`, dartFid[i][0], jsFid.x);
  eq(`fiducial ${id} y`, dartFid[i][1], jsFid.y);
});

// رمز الورقة
eq('codeCount', dart.codeCount, GEO.code.count);
eq('codeBits', dart.codeBits, GEO.code.bits);
eq('codeKeyBit', dart.codeKeyBit, GEO.code.keyBit);
eq('codeR', dart.codeR, GEO.code.r);
eq('codePitch', dart.codePitch, GEO.code.pitchX);
eq('codeFirstX', dart.codeFirstX, GEO.code.firstX);
eq('codeY', dart.codeY, GEO.code.y);
eq('codeLabelX', dart.codeLabelX, GEO.code.labelX);
eq('codeLabelY', dart.codeLabelY, GEO.code.labelY);

// شبكة رقم الجلوس
for (const [d, j] of [
  ['idRows', GEO.idGrid.rows], ['idMaxCols', GEO.idGrid.maxCols],
  ['idColPitch', GEO.idGrid.colPitch], ['idRowPitch', GEO.idGrid.rowPitch],
  ['idR', GEO.idGrid.bubbleR], ['idFirstColX', GEO.idGrid.firstColX],
  ['idFirstRowY', GEO.idGrid.firstRowY], ['idBoxW', GEO.idGrid.boxW],
  ['idBoxH', GEO.idGrid.boxH], ['idBoxY', GEO.idGrid.boxY0],
  ['idCaptionX', GEO.idGrid.captionX], ['idCaptionY', GEO.idGrid.captionBaseline],
  ['idHintX', GEO.idGrid.hintX], ['idHintY', GEO.idGrid.hintY],
]) eq(d, dart[d], j);

// الأسئلة
for (const [d, j] of [
  ['qY0', GEO.questions.y0], ['qY1', GEO.questions.y1],
  ['maxRowsPerCol', GEO.questions.maxRowsPerCol], ['maxRowPitch', GEO.questions.maxRowPitch],
  ['colRightRight', GEO.questions.colRightRight], ['colRightLeft', GEO.questions.colRightLeft],
  ['colLeftRight', GEO.questions.colLeftRight], ['colLeftLeft', GEO.questions.colLeftLeft],
  ['numberBoxW', GEO.questions.numberBoxW], ['numberBoxGap', GEO.questions.numberBoxGap],
  ['choiceMaxPitch', GEO.questions.choiceMaxPitch], ['yesNoMaxPitch', GEO.questions.yesnoMaxPitch],
  ['minBubbleR', GEO.questions.minBubbleR], ['maxBubbleR', GEO.questions.maxBubbleR],
  ['rowBubbleFactor', GEO.questions.rowBubbleFactor], ['footerY', GEO.footer.y],
]) eq(d, dart[d], j);

// قيم محسوبة فعليًا في JS (20 صفًا، 40 سؤالًا) — يجب أن تُطابق قيم Dart المشتقّة
eq('rowsPerCol (محسوب)', 20, tpl.layout.rowsPerCol);
eq('rowPitch (محسوب)', (GEO.questions.y1 - GEO.questions.y0) / 20, tpl.layout.rowPitch);

console.log(`\n══ مطابقة هندسة Dart ↔ JS: ${pass} نجح · ${fail} فشل ══`);
if (fail) {
  console.log('⚠ عدّل القيم في app/lib/vision/template.dart أو demo/js/template.js حتى تتطابق.');
}
process.exit(fail ? 1 : 0);
