/**
 * run_tests.mjs — اختبار تكاملي لمحرّك القراءة على أوراق مصطنعة "مصوّرة".
 *
 * التشغيل:
 *   node demo/test/dump_template.mjs && .venv/bin/python demo/test/gen_scans.py --count 8 && node demo/test/run_tests.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { detectSheet, composeNumber, DEFAULTS } from '../js/engine.js';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(HERE, 'out');

function readPGM(file) {
  const buf = fs.readFileSync(file);
  // ترويسة P5: بأسطر نصية ثم بيانات ثنائية
  let pos = 0, fields = [];
  while (fields.length < 4) {
    // تخطّي التعليقات والمسافات
    while (buf[pos] === 0x20 || buf[pos] === 0x0a || buf[pos] === 0x0d || buf[pos] === 0x09) pos++;
    if (buf[pos] === 0x23) { while (buf[pos] !== 0x0a) pos++; continue; }
    let s = '';
    while (![0x20, 0x0a, 0x0d, 0x09].includes(buf[pos])) s += String.fromCharCode(buf[pos++]);
    fields.push(s);
  }
  pos++;
  const [, w, h] = fields.map((f, i) => (i === 0 ? f : parseInt(f, 10)));
  const gray = buf.subarray(pos, pos + w * h);
  const rgba = new Uint8ClampedArray(w * h * 4);
  for (let i = 0, p = 0; i < gray.length; i++, p += 4) {
    rgba[p] = rgba[p + 1] = rgba[p + 2] = gray[i];
    rgba[p + 3] = 255;
  }
  return { rgba, w, h };
}

const template = JSON.parse(fs.readFileSync(path.join(OUT, 'template.json'), 'utf-8'));
const manifest = JSON.parse(fs.readFileSync(path.join(OUT, 'manifest.json'), 'utf-8'));
const opts = { ...DEFAULTS };

let stats = {
  sheets: 0, ok: 0, codeOk: 0, idOk: 0,
  cleanTotal: 0, cleanOk: 0,
  lightTotal: 0, lightOk: 0,
  doubleTotal: 0, doubleOk: 0,
  blankTotal: 0, blankOk: 0,
  ms: [],
  idMarkedMin: 1, idSpuriousMax: 0, cornerErr: [], rotated: [],
};
const problems = [];
const fillStats = { correctMin: 1, wrongMax: 0, emptyMax: 0 };

for (const gt of manifest) {
  stats.sheets++;
  const { rgba, w, h } = readPGM(path.join(OUT, gt.file));
  const r = detectSheet(rgba, w, h, template, opts);
  const label = `${gt.file} (${gt.name} / ${gt.studentId})`;

  if (!r.ok) {
    problems.push(`${label}: فشل — ${r.reason}`);
    continue;
  }
  stats.ok++;
  stats.ms.push(r.diag.timings.total);

  const gtCode = gt.code;
  const codeOk = r.code.value === gtCode;
  if (codeOk) stats.codeOk++; else problems.push(`${label}: رمز الورقة مقروء ${r.code.value} بدل ${gtCode}`);

  if (gt.rotated180) stats.rotated.push(gt.file);
  if (gt.trueCorners && r.corners && !gt.rotated180) {
    let maxErr = 0;
    gt.trueCorners.forEach((tc, i) => {
      const d = Math.hypot(tc[0] - r.corners[i][0], tc[1] - r.corners[i][1]);
      maxErr = Math.max(maxErr, d);
    });
    stats.cornerErr.push(maxErr);
  }

  const num = composeNumber(r.digits);
  const idOk = String(num) === String(gt.studentId);
  if (idOk) stats.idOk++; else problems.push(`${label}: رقم الجلوس ${num} بدل ${gt.studentId} (${JSON.stringify(r.digits)})`);

  const line = [];
  gt.answers.forEach((ans, qi) => {
    const flaw = gt.flaws[String(qi)] || 'ok';
    const a = r.answers[qi];
    const fills = a.fills;
    const best = Math.max(...fills);
    if (flaw === 'ok') {
      stats.cleanTotal++;
      const good = a.status === 'ok' && a.option === ans;
      if (good) stats.cleanOk++;
      else problems.push(`${label} س${qi + 1}: قرأ ${a.option} (${a.status}) بدل ${ans} — توزيع ${fills.join('/')}`);
      if (good) fillStats.correctMin = Math.min(fillStats.correctMin, a.fill);
    } else if (flaw === 'light') {
      stats.lightTotal++;
      const good = ['light', 'ok'].includes(a.status) && (a.option === null || a.option === ans);
      if (good) stats.lightOk++;
      else problems.push(`${label} س${qi + 1}: تظليل خفيف قُرئ ${a.option} (${a.status}) — توزيع ${fills.join('/')}`);
    } else if (flaw === 'double') {
      stats.doubleTotal++;
      const good = a.status === 'ambiguous';
      if (good) stats.doubleOk++;
      else problems.push(`${label} س${qi + 1}: تظليل مزدوج لم يُكتشف (${a.status}/${a.option}) — توزيع ${fills.join('/')}`);
    } else if (flaw === 'blank') {
      stats.blankTotal++;
      const good = a.status === 'blank';
      if (good) stats.blankOk++;
      else problems.push(`${label} س${qi + 1}: فراغ لم يُكتشف (${a.status}/${a.option}) — توزيع ${fills.join('/')}`);
    }
    // إحصاء فصل التظليل عن الفراغ
    const correctFill = fills[ans];
    const partner = (ans + 1) % fills.length;
    const others = fills.filter((_, i) => i !== ans && !(flaw === 'double' && i === partner));
    if (flaw === 'ok') fillStats.wrongMax = Math.max(fillStats.wrongMax, ...others);
    if (flaw === 'blank' || flaw === 'double') fillStats.emptyMax = Math.max(fillStats.emptyMax, ...others);
    if (flaw === 'ok' && correctFill < 0.6) line.push(`س${qi + 1}:${correctFill}`);
  });

  const flagTxt = r.flags.length ? ` — مراجعة: ${r.flags.map((f) => f.index + 1).join(',')}` : '';
  console.log(`✓ ${label} | دقة ${r.quality.pxPerMm}px/mm | ثقة ${r.confidence} | ${r.diag.timings.total}ms${flagTxt}${line.length ? ' | تظليل ضعيف: ' + line.join(',') : ''}`);
}

const avg = (a) => (a.length ? a.reduce((s, v) => s + v, 0) / a.length : 0);
const pct = (a, b) => (b ? ((100 * a) / b).toFixed(1) + '%' : '—');

console.log('\n══════════════ النتيجة ══════════════');
console.log(`أوراق مقروءة      : ${stats.ok}/${stats.sheets}`);
console.log(`رمز الورقة        : ${stats.codeOk}/${stats.ok}`);
console.log(`رقم الجلوس        : ${stats.idOk}/${stats.ok}`);
console.log(`تظليل سليم صحيح   : ${stats.cleanOk}/${stats.cleanTotal}  (${pct(stats.cleanOk, stats.cleanTotal)})`);
console.log(`تظليل خفيف        : ${stats.lightOk}/${stats.lightTotal}`);
console.log(`تظليل مزدوج       : ${stats.doubleOk}/${stats.doubleTotal}`);
console.log(`أسئلة فارغة       : ${stats.blankOk}/${stats.blankTotal}`);
console.log(`متوسط زمن الورقة  : ${avg(stats.ms).toFixed(0)}ms`);
console.log(`فصل التظليل       : أقل تظليل صحيح=${fillStats.correctMin.toFixed(2)} · أعلى فقاعة خطأ=${fillStats.wrongMax.toFixed(2)} · أعلى فقاعة فارغة=${fillStats.emptyMax.toFixed(2)}`);
console.log(`شبكة رقم الجلوس   : أقل خانة صحيحة=${stats.idMarkedMin.toFixed(2)} · أعلى خانة غير مقصودة=${stats.idSpuriousMax.toFixed(2)}`);
if (stats.cornerErr.length) console.log(`خطأ تعرّف الأركان  : أقصى=${Math.max(...stats.cornerErr).toFixed(1)}px · متوسط=${avg(stats.cornerErr).toFixed(1)}px`);
if (stats.rotated.length) console.log(`أوراق مقلوبة 180°   : ${stats.rotated.length} (قُرئت بنجاح: ${stats.rotated.filter(f => !problems.some(p => p.startsWith(f))).length})`);

if (problems.length) {
  console.log(`\nمشاكل (${problems.length}):`);
  problems.slice(0, 40).forEach((p) => console.log('  ✗ ' + p));
}

const pass = stats.ok === stats.sheets && stats.codeOk === stats.ok && stats.idOk === stats.ok &&
  stats.cleanOk === stats.cleanTotal && stats.doubleOk === stats.doubleTotal && stats.blankOk === stats.blankTotal;
console.log(pass ? '\n✅ نجحت جميع الاختبارات' : '\n❌ توجد إخفاقات — راجع القائمة أعلاه');
process.exit(pass ? 0 : 1);
