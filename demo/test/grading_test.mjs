/**
 * grading_test.mjs — اختبار وحدة قواعد التصحيح والتحليلات
 * التشغيل: node demo/test/grading_test.mjs
 */
import { scoreAttempt, classStats, analyzeQuestions, kr20 } from '../js/grading.js';

let pass = 0, fail = 0;
function check(name, cond, extra = '') {
  if (cond) { pass++; console.log(`  ✓ ${name}`); }
  else { fail++; console.log(`  ✗ ${name} ${extra}`); }
}
const near = (a, b, eps = 1e-6) => Math.abs(a - b) < eps;

const exam = {
  questions: [{ type: 'choice', options: 4, marks: 1 }, { type: 'choice', options: 4, marks: 1 },
              { type: 'yesno', options: 2, marks: 2 }, { type: 'choice', options: 4, marks: 1 }],
  key: [0, 2, 1, 3],
  cancelled: new Set(),
};

console.log('\n── التصحيح الأساسي ──');
let r = scoreAttempt([0, 2, 1, 3], exam);
check('كل الإجابات صحيحة = الدرجة الكاملة', r.score === 5 && r.total === 5, JSON.stringify(r));
check('النسبة 100%', near(r.percent, 100));

r = scoreAttempt([0, 2, 0, 3], exam);
check('خطأ واحد (بوزن 2) يُنقص الدرجة', r.score === 3 && r.wrong === 1, JSON.stringify(r));

r = scoreAttempt([0, null, 1, 3], exam);
check('السؤال الفارغ = صفر ولا خصم (المجموع 1+2+1)', r.score === 4 && r.blank === 1, JSON.stringify(r));

r = scoreAttempt([0, 2, 1, 3], exam, { negative: true, negativeFactor: 0.25 });
check('الخصم لا يطبّق على الصحيح', r.score === 5);

r = scoreAttempt([1, 1, 0, 0], exam, { negative: true, negativeFactor: 0.25 });
check('الخصم على الخطأ (0.25 لكل علامة)', near(r.score, 0) && r.wrong === 4, JSON.stringify(r));

r = scoreAttempt([0, 2, 1, 3], { ...exam, cancelled: new Set([2]) });
check('السؤال الملغى يُستثنى من الدرجة الكلية', r.total === 3 && r.score === 3, JSON.stringify(r));

console.log('\n── إحصاءات الصف ──');
const attempts = [
  { percent: 100, score: 5, answers: [0, 2, 1, 3] },
  { percent: 80, score: 4, answers: [0, 2, null, 3] },
  { percent: 60, score: 3, answers: [0, 1, 1, 2] },
  { percent: 40, score: 2, answers: [1, 2, 0, 3] },
  { percent: 20, score: 1, answers: [1, 1, 0, 2] },
  { percent: 0, score: 0, answers: [2, 3, 0, 1] },
];
const st = classStats(attempts, 60);
check('المتوسط صحيح', near(st.mean, 50));
check('الوسيط صحيح', near(st.median, 50));
check('نسبة النجاح صحيحة', near(st.passRate, 50), String(st.passRate));
check('الأعلى والأدنى', st.max === 100 && st.min === 0);
check('التوزيع 10 خانات', st.histogram.length === 10 && st.histogram.reduce((a, b) => a + b, 0) === 6);

console.log('\n── تحليل الأسئلة ──');
const matrix = attempts.map((a) => a.answers);
const an = analyzeQuestions(exam, attempts, matrix);
check('عدد الأسئلة في التحليل', an.length === 4);
check('صعوبة السؤال الأول = 3 صحاح من 6', near(an[0].difficulty, 0.5), `p=${an[0].difficulty}`);
check('معامل التمييز محسوب ضمن المجال', an.every((x) => x.discrimination >= -1 && x.discrimination <= 1));
// سؤال لا يميّز: الأعلى والأدنى بنفس الأداء
const flat = { questions: [{ type: 'choice', options: 2, marks: 1 }], key: [0], cancelled: new Set() };
const flatMatrix = [[0], [1], [0], [0], [1], [0]];   // الأداء نفسه في الأعلى والأسفل
const flatAn = analyzeQuestions(flat, attempts.map((a, i) => ({ ...a, percent: 90 - i * 10 })), flatMatrix);
check('تمييز ضعيف يُرصد', Math.abs(flatAn[0].discrimination) < 0.2 && flatAn[0].flags.includes('low_discrimination'),
  `D=${flatAn[0].discrimination} flags=${flatAn[0].flags}`);
// سؤال اختار فيه أغلب الطلاب خيارًا غير المفتاح → مؤشر خطأ في المفتاح
const tricky = { questions: [{ type: 'choice', options: 4, marks: 1 }], key: [0], cancelled: new Set() };
const tMatrix = [[1], [1], [1], [0], [1], [0]];
const tAn = analyzeQuestions(tricky, attempts.map((a, i) => ({ ...a, percent: 50 + i })), tMatrix);
check('مؤشر «راجع المفتاح» يظهر عند تركّز المشتّت', tAn[0].flags.includes('possible_key_error'), JSON.stringify(tAn[0].flags));
check('توزيع الاختيارات صحيح', tAn[0].distribution[1] === 4 && tAn[0].distribution[0] === 2);

console.log('\n── ثبات KR-20 ──');
const kr = kr20(attempts, matrix, exam);
check('KR-20 رقم صالح أو null', kr === null || (kr > -1 && kr < 1.01), String(kr));

console.log(`\n══ النتيجة: ${pass} نجح · ${fail} فشل ══`);
process.exit(fail ? 1 : 0);
