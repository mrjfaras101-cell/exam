/**
 * dump_template.mjs — يُصدّر القالب الهندسي + بيانات الطلاب التجريبيين إلى JSON
 * ليستخدمها مولّد الأوراق المصطنعة (Python) واختبارات المحرّك.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildTemplate, validateSpec } from '../js/template.js';
import { SAMPLE_EXAM, SAMPLE_STUDENTS, SAMPLE_KEY } from '../js/sample_exam.js';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(HERE, 'out');
fs.mkdirSync(OUT, { recursive: true });

const errors = validateSpec(SAMPLE_EXAM);
if (errors.length) {
  console.error('مواصفات غير صالحة:', errors);
  process.exit(1);
}

const template = buildTemplate(SAMPLE_EXAM);
fs.writeFileSync(path.join(OUT, 'template.json'), JSON.stringify(template, null, 1), 'utf-8');
fs.writeFileSync(path.join(OUT, 'students.json'), JSON.stringify(SAMPLE_STUDENTS, null, 1), 'utf-8');
fs.writeFileSync(path.join(OUT, 'key.json'), JSON.stringify({
  serial: SAMPLE_EXAM.serial, key: SAMPLE_KEY, templateVersion: template.version,
}, null, 1), 'utf-8');

const bubbles = template.code.bubbles.length + template.digitGrid.bubbles.length +
  template.questions.reduce((s, q) => s + q.bubbles.length, 0);
console.log(`القالب: ${template.questions.length} سؤالًا، ${bubbles} فقاعة، رمز الورقة = ${template.code.value}`);
