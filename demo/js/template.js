/**
 * template.js — مصدر الحقيقة الهندسي لورقة الإجابة (نسخة 1)
 *
 * هذا الملف هو "العقد" بين الطباعة والقراءة:
 *  - مُولِّد PDF/الطباعة يرسم الفقاعات من الإحداثيات المذكورة هنا.
 *  - محرّك القراءة (OMR) يأخذ عيّناته من الإحداثيات نفسها.
 * لذلك أي تعديل على هذا الملف يجب أن ينعكس على نسخة Dart حرفيًا (app/lib/sheet/).
 *
 * جميع الإحداثيات بالمليمتر، بالنسبة لركن الورقة العلوي الأيسر، والمحور ص للأسفل.
 * ورقة A4 = 210 × 297 مم.
 *
 * يعمل هذا الملف في المتصفح وفي Node معًا (وحدة ES خالصة بلا تبعيات).
 */

export const SCHEMA_VERSION = 1;

/* ------------------------------------------------------------------ */
/* الثوابت الهندسية                                                    */
/* ------------------------------------------------------------------ */

export const GEO = {
  paper: { w: 210, h: 297 },

  // علامات التسجيل: 3 مربعات مصمتة + مربع حلقي (لتمييز الاتجاه حتى مع دوران 180°)
  fiducial: {
    size: 10,        // ضلع المربع (مم)
    ringHole: 6,     // ضلع الفراغ الأبيض في المربع الحلقي (مم)
    centers: {
      TL: [13, 13], TR: [197, 13], BL: [13, 284], BR: [197, 284],
    },
    kinds: { TL: 'solid', TR: 'solid', BL: 'solid', BR: 'ring' },
  },

  // المنطقة الآمنة للطباعة
  content: { x0: 24, y0: 24, x1: 186, y1: 272 },

  // ترويسة
  header: { y0: 24, y1: 86 },
  titleBlock: { x0: 90, x1: 186 },
  idBlock: { x0: 24, x1: 86 },

  // رمز الورقة: 6 فقاعات، 5 بتات لرقم الاختبار + بتة لنوع الورقة
  code: {
    count: 6,
    bits: 5,
    keyBit: 5,          // البتة رقم 5 = 1 تعني "ورقة مفتاح إجابة"
    r: 2.2,
    pitchX: 5.2,
    firstX: 148,        // مركز البتة 0 (أقصى اليمين)
    y: 76,
    labelX: 186,        // نص العنوان محاذى لليمين
  },

  // شبكة رقم الجلوس
  idGrid: {
    rows: 10,           // الأرقام 0..9
    maxCols: 8,         // حتى 8 منازل
    colPitch: 7.0,
    rowPitch: 4.7,
    bubbleR: 1.9,
    firstColX: 27.2,
    firstRowY: 41,
    boxW: 6.4,          // مستطيل الكتابة اليدوية
    boxH: 6.0,
    boxY0: 31,
    captionBaseline: 29,
  },

  // منطقة الأسئلة
  questions: {
    y0: 90,
    y1: 264,
    rowsPerCol: 10,
    colRightRight: 186,   // العمود الأول (يمينًا)
    colRightLeft: 106,
    colLeftRight: 104,    // العمود الثاني (يسارًا)
    colLeftLeft: 24,
    numberBoxW: 13,
    choiceR: 3.5,
    choiceMaxPitch: 14,
    yesnoR: 4.0,
    yesnoPitch: 20,
  },

  footer: { y: 268 },

  // نصوص الواجهة المطبوعة
  texts: {
    idCaption: 'رقم الجلوس',
    idHint: 'اكتب رقمك في المستطيلات، ثم شبّك الرقم نفسه أسفل كل عمود',
    codeCaption: 'رمز الورقة',
    instructions: [
      'ظلّل دائرة واحدة فقط لكل سؤال باستخدام قلم رصاص أو قلم جاف أسود/أزرق.',
      'أجب بنعم أو لا: ظلّل (نعم) أو (لا). وللأسئلة الموضوعية ظلّل رمز الإجابة الصحيحة.',
      'لا تكتب أو تُظلّل خارج الدوائر، واحرص على تعبئة الدائرة كاملة.',
    ],
    footer: 'لا تكتب في هذا القسم — تُقرأ الورقة آليًا',
  },
};

/** حروف الخيارات العربية (أ ب ج د هـ) */
export const OPTION_LABELS_AR = ['أ', 'ب', 'ج', 'د', 'هـ'];
/** حروف بديلة بالإنجليزية عند اختيار الأرقام/الحروف اللاتينية */
export const OPTION_LABELS_EN = ['A', 'B', 'C', 'D', 'E'];

/* ------------------------------------------------------------------ */
/* أدوات مساعدة                                                        */
/* ------------------------------------------------------------------ */

export const round2 = (v) => Math.round(v * 100) / 100;

/** قيمة رمز الورقة: رقم الاختبار (0..31) + بتة النوع */
export function codeValue(serial, isKey) {
  const s = Math.max(0, Math.min((1 << GEO.code.bits) - 1, serial | 0));
  return (s & ((1 << GEO.code.bits) - 1)) | (isKey ? (1 << GEO.code.keyBit) : 0);
}

/* ------------------------------------------------------------------ */
/* بناء القالب                                                         */
/* ------------------------------------------------------------------ */

/**
 * @param {object} spec  مواصفات الاختبار
 *   {
 *     title: string, subject: string, gradeLabel: string, teacher: string,
 *     examDate: string, serial: number (0..31), isKey: boolean,
 *     optionLabels: 'ar'|'en',
 *     questions: [{ type: 'choice'|'yesno', options: number }, ...]
 *   }
 * @returns {object} القالب الكامل (إحداثيات كل فقاعة)
 */
export function buildTemplate(spec) {
  const q = GEO.questions;
  const questions = (spec.questions || []).map((it) => ({ type: it.type, options: it.options }));
  const n = questions.length;

  const t = {
    version: SCHEMA_VERSION,
    paper: { ...GEO.paper },
    meta: {
      title: spec.title || '',
      subject: spec.subject || '',
      gradeLabel: spec.gradeLabel || '',
      teacher: spec.teacher || '',
      examDate: spec.examDate || '',
      serial: spec.serial ?? 0,
      isKey: !!spec.isKey,
      optionLabels: spec.optionLabels === 'en' ? 'en' : 'ar',
      questionCount: n,
      texts: { ...GEO.texts },
    },
    fiducials: [],
    code: { value: 0, bubbles: [] },
    digitGrid: { rows: GEO.idGrid.rows, cols: 0, bubbles: [] },
    questions: [],
    layout: { rowsPerCol: q.rowsPerCol, rowPitch: 0 },
  };

  /* --- 1) علامات التسجيل --- */
  for (const key of ['TL', 'TR', 'BL', 'BR']) {
    const [x, y] = GEO.fiducial.centers[key];
    t.fiducials.push({
      id: key, x, y, size: GEO.fiducial.size,
      kind: GEO.fiducial.kinds[key],
      hole: GEO.fiducial.kinds[key] === 'ring' ? GEO.fiducial.ringHole : 0,
    });
  }

  /* --- 2) رمز الورقة --- */
  const c = GEO.code;
  t.code.value = codeValue(t.meta.serial, t.meta.isKey);
  for (let i = 0; i < c.count; i++) {
    t.code.bubbles.push({
      x: round2(c.firstX - i * c.pitchX),
      y: c.y,
      r: c.r,
      bit: i,
      printed: (t.code.value >> i) & 1 ? 1 : 0, // للمعاينة/الطباعة فقط
    });
  }

  /* --- 3) شبكة رقم الجلوس --- */
  const g = GEO.idGrid;
  const cols = Math.max(1, Math.min(g.maxCols, spec.idDigits || g.maxCols));
  t.digitGrid.cols = cols;
  for (let col = 0; col < cols; col++) {
    for (let row = 0; row < g.rows; row++) {
      t.digitGrid.bubbles.push({
        x: round2(g.firstColX + col * g.colPitch),
        y: round2(g.firstRowY + row * g.rowPitch),
        r: g.bubbleR,
        col, row, digit: row,
      });
    }
  }
  t.digitGrid.boxes = [];
  for (let col = 0; col < cols; col++) {
    t.digitGrid.boxes.push({
      x: round2(g.firstColX + col * g.colPitch - g.boxW / 2),
      y: g.boxY0, w: g.boxW, h: g.boxH,
    });
  }

  /* --- 4) الأسئلة --- */
  const rowPitch = (q.y1 - q.y0) / q.rowsPerCol;
  t.layout.rowPitch = round2(rowPitch);
  for (let i = 0; i < n; i++) {
    const col = Math.floor(i / q.rowsPerCol);          // 0 = العمود اليمين
    const row = i % q.rowsPerCol;
    const colRight = col === 0 ? q.colRightRight : q.colLeftRight;
    const colLeft = col === 0 ? q.colRightLeft : q.colLeftLeft;
    const y = round2(q.y0 + rowPitch * (row + 0.5));
    const item = questions[i];
    const isYesNo = item.type === 'yesno';
    const k = isYesNo ? 2 : Math.max(2, Math.min(5, item.options || 4));
    const r = isYesNo ? q.yesnoR : q.choiceR;
    const maxPitch = isYesNo ? q.yesnoPitch : q.choiceMaxPitch;
    const avail = (colRight - colLeft) - 19 - 2 * r - 1;   // 19 = رقم السؤال + هامش
    const pitch = Math.min(maxPitch, avail / (k - 1));

    const bubbles = [];
    for (let o = 0; o < k; o++) {
      bubbles.push({
        x: round2(colRight - 19 - o * pitch),
        y, r, option: o,
        label: isYesNo ? (o === 0 ? 'نعم' : 'لا')
                       : (t.meta.optionLabels === 'en' ? OPTION_LABELS_EN[o] : OPTION_LABELS_AR[o]),
      });
    }

    t.questions.push({
      index: i, col, row, type: isYesNo ? 'yesno' : 'choice',
      options: k, marks: item.marks ?? 1,
      numberBox: { x: colRight - q.numberBoxW, y: round2(y - 6), w: q.numberBoxW, h: 12 },
      bubbles,
    });
  }

  return t;
}

/** قائمة مسطّحة بكل الفقاعات (لتسريع المسح في محرّك القراءة) */
export function flattenBubbles(template) {
  const out = [];
  for (const b of template.code.bubbles) out.push({ group: 'code', ...b });
  for (const b of template.digitGrid.bubbles) out.push({ group: 'digit', ...b });
  for (const q of template.questions) {
    for (const b of q.bubbles) out.push({ group: 'question', qIndex: q.index, type: q.type, ...b });
  }
  return out;
}

/** التحقّق من صلاحية مواصفات الاختبار قبل البناء */
export function validateSpec(spec) {
  const errors = [];
  const n = (spec.questions || []).length;
  if (!spec.title || !spec.title.trim()) errors.push('اسم الاختبار مطلوب');
  if (n < 1) errors.push('أضف سؤالًا واحدًا على الأقل');
  if (n > GEO.questions.rowsPerCol * 2) errors.push(`الحدّ الأقصى ${GEO.questions.rowsPerCol * 2} سؤالًا في ورقة واحدة`);
  (spec.questions || []).forEach((it, i) => {
    if (it.type === 'choice' && (it.options < 2 || it.options > 5)) {
      errors.push(`السؤال ${i + 1}: عدد الخيارات يجب أن يكون بين 2 و5`);
    }
  });
  return errors;
}

/** عدد الشرائح المطلوبة لعدد أسئلة (للتوافق المستقبلي: أكثر من ورقة) */
export function sheetCount(questionCount) {
  return Math.max(1, Math.ceil(questionCount / (GEO.questions.rowsPerCol * 2)));
}
