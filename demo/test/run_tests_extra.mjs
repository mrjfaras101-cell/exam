/**
 * run_tests_extra.mjs — اختبارات إضافية على المحرّك:
 *   1) قراءة «ورقة المفتاح» (بتّة المفتاح + استخراج كل الإجابات)
 *   2) الأوراق المقلوبة 180° (فرض الاتجاه عبر المربع الحلقي)
 *   3) ورقة بحد أقصى الأسئلة (40 سؤالًا) — للتأكد من التخطيط الجديد
 *
 * التشغيل: node demo/test/run_tests_extra.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { detectSheet, composeNumber, DEFAULTS } from '../js/engine.js';
import { buildTemplate } from '../js/template.js';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(HERE, 'out');
let pass = 0, fail = 0;
const check = (name, cond, extra = '') => {
  if (cond) { pass++; console.log(`  ✓ ${name}`); }
  else { fail++; console.log(`  ✗ ${name} ${extra}`); }
};

function readPGM(file) {
  const buf = fs.readFileSync(file);
  let pos = 0, fields = [];
  while (fields.length < 4) {
    while ([0x20, 0x0a, 0x0d, 0x09].includes(buf[pos])) pos++;
    if (buf[pos] === 0x23) { while (buf[pos] !== 0x0a) pos++; continue; }
    let s = '';
    while (![0x20, 0x0a, 0x0d, 0x09].includes(buf[pos])) s += String.fromCharCode(buf[pos++]);
    fields.push(s);
  }
  pos++;
  const w = +fields[1], h = +fields[2];
  const gray = buf.subarray(pos, pos + w * h);
  const rgba = new Uint8ClampedArray(w * h * 4);
  for (let i = 0, q = 0; i < gray.length; i++, q += 4) {
    rgba[q] = rgba[q + 1] = rgba[q + 2] = gray[i]; rgba[q + 3] = 255;
  }
  return { rgba, w, h };
}

const template = JSON.parse(fs.readFileSync(path.join(OUT, 'template.json'), 'utf-8'));
const key = JSON.parse(fs.readFileSync(path.join(OUT, 'key.json'), 'utf-8'));

console.log('\n── 1) ورقة المفتاح ──');
{
  const p = path.join(OUT, 'keysheet.pgm');
  if (fs.existsSync(p)) {
    const { rgba, w, h } = readPGM(p);
    const r = detectSheet(rgba, w, h, template, DEFAULTS);
    const got = r.answers.map((a) => a.option);
    check('ورقة المفتاح مُتعرَّف عليها', r.ok, r.reason || '');
    check('بتّة المفتاح مضبوطة ورقم الاختبار 3',
      r.ok && r.code.isKeySheet === true && r.code.serial === key.serial && r.code.value === (key.serial | 32),
      `value=${r.code?.value} serial=${r.code?.serial}`);
    check('كل قيم المفتاح مقروءة صحيحة', JSON.stringify(got) === JSON.stringify(key.key), JSON.stringify(got));
  } else {
    check('ملف ورقة المفتاح موجود (شغّل gen_keysheet.py)', false, p);
  }
}

console.log('\n── 2) أوراق مقلوبة 180° ──');
{
  let total = 0, ok = 0;
  for (let i = 0; i < 6; i++) {
    const f = `rot_0${i}`;
    const pgm = path.join(OUT, f + '.pgm');
    if (!fs.existsSync(pgm)) continue;
    total++;
    const gt = JSON.parse(fs.readFileSync(path.join(OUT, f + '.gt.json'), 'utf-8'));
    const { rgba, w, h } = readPGM(pgm);
    const r = detectSheet(rgba, w, h, template, DEFAULTS);
    // الحالات المقصودة: «مزدوج» و«فارغ» تُقرأ بلا إجابة (null)، أما «خفيف» فتُقرأ كإجابة مع وسم مراجعة
    const nulled = (qi) => ['double', 'blank'].includes(gt.flaws?.[qi]);
    const expected = gt.answers.map((a, qi) => (nulled(qi) ? null : a));
    const got = r.ok ? r.answers.map((a, qi) => (nulled(qi) ? null : a.option)) : [];
    const ansOk = r.ok && JSON.stringify(got) === JSON.stringify(expected);
    const idOk = r.ok && composeNumber(r.digits) === +gt.studentId;
    const codeOk = r.ok && r.code.value === gt.code;
    if (ansOk && idOk && codeOk) ok++;
    else console.log(`     ↳ ${f}: ok=${r.ok} code=${r.code?.value}/${gt.code} id=${composeNumber(r.digits)}/${gt.studentId} ans=${JSON.stringify(got)} want=${JSON.stringify(expected)}`);
  }
  check(`الأوراق المقلوبة تُقرأ بالاتجاه الصحيح (${ok}/${total})`, total > 0 && ok === total);
}

console.log('\n── 3) هندسة الورقة الجديدة (نصف A4) ──');
{
  const paper = template.paper;
  check('مقاس الورقة نصف A4 (148.5 × 210 مم)', paper.w === 148.5 && paper.h === 210, JSON.stringify(paper));
  const ids = template.fiducials.map((f) => f.id).join(',');
  check('علامات التسجيل بترتيب TL,TR,BL,BR والحلقة على BR',
    template.fiducials.find((f) => f.id === 'BR').kind === 'ring' && ids.includes('TL'), ids);
}

console.log('\n── 4) حد أقصى 40 سؤالًا + ترتيب المزيج ──');
{
  const qs = [];
  for (let i = 0; i < 40; i++) qs.push({ type: i < 27 ? 'choice' : 'yesno', options: i < 27 ? 4 : 2 });
  const t = buildTemplate({ title: 'حد أقصى', serial: 5, questions: qs, idDigits: 8 });
  check('40 سؤالًا تُبنى في ورقة واحدة', t.questions.length === 40);
  check('20 صفًا في كل عمود', t.layout.rowsPerCol === 20, String(t.layout.rowsPerCol));
  const xs = t.questions[39].bubbles.map((b) => b.x);
  check('السؤال 40 في العمود الأيسر وبإحداثيات صحيحة', xs[0] > 18 && xs[0] < 71 + 20, JSON.stringify(xs));
  let minGap = 1e9;
  for (const q of t.questions) {
    const bx = q.bubbles.map((b) => b.x);
    for (let i = 1; i < bx.length; i++) minGap = Math.min(minGap, bx[i - 1] - bx[i] - 2 * q.bubbles[i].r);
  }
  check('لا تتلاصق الفقاعات (فراغ ≥ 1 مم)', minGap >= 1, `فراغ ${minGap.toFixed(2)} مم`);
}

console.log(`\n══ النتيجة: ${pass} نجح · ${fail} فشل ══`);
process.exit(fail ? 1 : 0);
