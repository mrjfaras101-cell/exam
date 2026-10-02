/**
 * sample_exam.js — بيانات الاختبار التجريبي المشترك بين التطبيق واختبارات المحرّك
 * اختبار قصير: 10 أسئلة (6 «أضع دائرة» + 4 «نعم/لا») — القالب الافتراضي في الورقة A4.
 */

export const SAMPLE_EXAM = {
  title: 'اختبار قصير — الجبر',
  subject: 'الرياضيات',
  gradeLabel: 'الصف السابع / أ',
  teacher: 'أ. محمد',
  examDate: '2026-10-05',
  serial: 3,          // رقم الاختبار (0..31) — يُطبع في رمز الورقة
  idDigits: 8,
  optionLabels: 'ar',
  questions: [
    { type: 'choice', options: 4 },
    { type: 'choice', options: 4 },
    { type: 'yesno' },
    { type: 'choice', options: 4 },
    { type: 'choice', options: 4 },
    { type: 'yesno' },
    { type: 'choice', options: 4 },
    { type: 'yesno' },
    { type: 'choice', options: 4 },
    { type: 'yesno' },
  ],
};

/** مفتاح الإجابة النموذجي (رقم الخيار، ويظهر «نعم=0 / لا=1» في أسئلة نعم/لا) */
export const SAMPLE_KEY = [2, 0, 1, 3, 0, 1, 1, 0, 2, 1];

/**
 * طلاب تجريبيون: كل طالب له رقم جلوس وإجاباته، مع "عيوب" مقصودة لاختبار الحالات الحدّية.
 *  ok     : تظليل سليم
 *  light  : تظليل خفيف (قلم رصاص)
 *  double : تظليل خيارين
 *  blank  : متروك
 */
export const SAMPLE_STUDENTS = [
  {
    id: '20260101', name: 'أحمد', answers: [2, 0, 1, 3, 0, 1, 1, 0, 2, 1], flaws: {}, ink: 'pen',
  },
  {
    id: '20260102', name: 'ريم', answers: [2, 0, 0, 3, 1, 1, 1, 0, 2, 0], flaws: { 4: 'light' }, ink: 'pencil',
  },
  {
    id: '20260103', name: 'يوسف', answers: [1, 0, 1, 3, 0, 1, 2, 1, 2, 1], flaws: { 6: 'double' }, ink: 'pen',
  },
  {
    id: '20260104', name: 'سارة', answers: [2, 3, 1, 0, 0, 1, 1, 0, 2, 1], flaws: { 9: 'blank', 1: 'light' }, ink: 'pencil',
  },
  {
    id: '20260105', name: 'عمر', answers: [2, 0, 1, 2, 0, 0, 1, 0, 3, 1], flaws: {}, ink: 'pen',
  },
  {
    id: '20260106', name: 'ليان', answers: [3, 1, 0, 3, 0, 1, 1, 0, 2, 1], flaws: { 0: 'light' }, ink: 'pencil',
  },
];

/** إجابات الطالب كما هي في العيّنة (مع مراعاة العيوب) */
export function studentMarks(st) {
  const m = {};
  st.answers.forEach((a, i) => {
    if (st.flaws[i] === 'blank') return;
    if (st.flaws[i] === 'double') {
      const other = (a + 1) % (SAMPLE_EXAM.questions[i].type === 'yesno' ? 2 : 4);
      m[i] = [a, other];
      return;
    }
    m[i] = [a];
  });
  return m;
}
