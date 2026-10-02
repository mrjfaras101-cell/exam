/**
 * grading.js — قواعد التصحيح والتحليلات التعليمية (منطق خالص قابل للاختبار)
 * نفس القواعد المنقولة إلى Dart في app/lib/domain/grading.dart
 */

/**
 * درجة محاولة واحدة.
 * @param {number[]} answers إجابة الطالب لكل سؤال (فهرس الخيار أو null)
 * @param {object} exam { questions:[{marks}], key:[], cancelled:Set<number> }
 * @param {object} settings { negative:boolean, negativeFactor:0.25 }
 */
export function scoreAttempt(answers, exam, settings = {}) {
  const canceled = exam.cancelled || new Set();
  const key = exam.key || [];
  let score = 0, correct = 0, wrong = 0, blank = 0, total = 0;
  const perQuestion = [];
  exam.questions.forEach((q, i) => {
    const marks = q.marks ?? 1;
    if (canceled.has(i)) { perQuestion.push({ index: i, state: 'cancelled', marks: 0 }); return; }
    total += marks;
    const a = answers[i];
    if (a === null || a === undefined) { blank++; perQuestion.push({ index: i, state: 'blank', marks: 0 }); return; }
    if (a === key[i]) { score += marks; correct++; perQuestion.push({ index: i, state: 'correct', marks }); }
    else {
      wrong++;
      const penalty = settings.negative ? (settings.negativeFactor ?? 0.25) * marks : 0;
      score -= penalty;
      perQuestion.push({ index: i, state: 'wrong', marks: -penalty });
    }
  });
  const finalScore = Math.max(0, score);
  return {
    score: finalScore, total, correct, wrong, blank, perQuestion,
    percent: total ? (finalScore / total) * 100 : 0,
  };
}

/** إحصاءات الصف */
export function classStats(attempts, passPercent = 60) {
  const percents = attempts.map((a) => a.percent).filter((p) => Number.isFinite(p));
  if (!percents.length) return { count: 0 };
  const sorted = [...percents].sort((a, b) => a - b);
  const mean = percents.reduce((s, v) => s + v, 0) / percents.length;
  const median = sorted.length % 2 ? sorted[(sorted.length - 1) / 2]
    : (sorted[sorted.length / 2 - 1] + sorted[sorted.length / 2]) / 2;
  const q = (p) => sorted[Math.min(sorted.length - 1, Math.floor(p * sorted.length))];
  return {
    count: percents.length, mean, median, min: sorted[0], max: sorted[sorted.length - 1],
    passRate: (percents.filter((p) => p >= passPercent).length / percents.length) * 100,
    q1: q(0.25), q3: q(0.75),
    histogram: Array.from({ length: 10 }, (_, i) => percents.filter((p) => (i === 9 ? p >= 90 && p <= 100 : p >= i * 10 && p < (i + 1) * 10)).length),
  };
}

/**
 * تحليل الأسئلة: معامل الصعوبة، معامل التمييز، توزيع الاختيارات، ومؤشرات الخلل.
 * @param {number[][]} answerMatrix إجابات الطلاب [طالب][سؤال]
 */
export function analyzeQuestions(exam, attempts, answerMatrix, cancelled = new Set()) {
  const key = exam.key || [];
  const scored = attempts.map((a, i) => ({ ...a, idx: i })).sort((a, b) => b.percent - a.percent);
  const k = Math.max(1, Math.round(scored.length * 0.27));
  const top = scored.slice(0, k).map((s) => s.idx);
  const bottom = scored.slice(-k).map((s) => s.idx);

  return exam.questions.map((q, i) => {
    if (cancelled.has(i)) return { index: i, cancelled: true };
    const nOpt = q.type === 'yesno' ? 2 : q.options;
    const valid = answerMatrix.map((r) => r[i]).filter((v) => v !== null && v !== undefined);
    const correctN = valid.filter((v) => v === key[i]).length;
    const p = valid.length ? correctN / valid.length : 0;
    const pT = top.length ? top.filter((ti) => answerMatrix[ti][i] === key[i]).length / top.length : 0;
    const pB = bottom.length ? bottom.filter((bi) => answerMatrix[bi][i] === key[i]).length / bottom.length : 0;
    const D = pT - pB;
    const distribution = Array.from({ length: nOpt }, (_, o) => valid.filter((v) => v === o).length);
    const distractors = distribution.map((v, o) => ({ option: o, count: v, share: valid.length ? v / valid.length : 0, isKey: o === key[i] }));
    const strongestDistractor = distractors.filter((d) => !d.isKey).reduce((a, b) => (b.count > a.count ? b : a), { count: 0, share: 0, option: -1 });
    const flags = [];
    if (p < 0.2) flags.push('difficulty_very_hard');
    if (p > 0.95) flags.push('difficulty_very_easy');
    if (D < 0.2) flags.push('low_discrimination');
    if (strongestDistractor.share > 0.4) flags.push('possible_key_error');
    return {
      index: i, cancelled: false, answered: valid.length, correct: correctN,
      difficulty: p, discrimination: D, distribution, distractors, flags,
    };
  });
}

/** تعليق عربي مختصر على مؤشرات السؤال */
export const FLAG_LABELS = {
  difficulty_very_hard: 'صعب جدًا',
  difficulty_very_easy: 'سهل جدًا (لا يميّز)',
  low_discrimination: 'تمييز ضعيف',
  possible_key_error: 'راجع المفتاح أو صياغة السؤال',
};

/** معامل ثبات KR-20 (اختياري للتقارير المتقدّمة) */
export function kr20(attempts, answerMatrix, exam) {
  const items = analyzeQuestions(exam, attempts, answerMatrix).filter((q) => !q.cancelled);
  if (!items.length || !answerMatrix.length) return null;
  const p = items.map((q) => q.difficulty);
  const pq = p.reduce((s, v) => s + v * (1 - v), 0);
  const totals = attempts.map((a) => a.rawScore ?? a.score);
  const mean = totals.reduce((s, v) => s + v, 0) / totals.length;
  const variance = totals.reduce((s, v) => s + (v - mean) ** 2, 0) / totals.length;
  if (variance === 0) return null;
  const k = items.length;
  return (k / (k - 1)) * (1 - pq / variance);
}
