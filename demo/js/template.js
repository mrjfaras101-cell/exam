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
  // نصف ورقة A4: A5 طولي (يُطبع اثنان في صفحة A4 أفقية ثم تُقصّ الورقة)
  paper: { w: 148.5, h: 210 },

  // علامات التسجيل: 3 مربعات مصمتة + مربع حلقي (لتمييز الاتجاه حتى مع دوران 180°)
  fiducial: {
    size: 10,        // ضلع المربع (مم)
    ringHole: 6,     // ضلع الفراغ الأبيض في المربع الحلقي (مم)
    centers: {
      TL: [10, 10], TR: [138.5, 10], BL: [10, 200], BR: [138.5, 200],
    },
    kinds: { TL: 'solid', TR: 'solid', BL: 'solid', BR: 'ring' },
  },

  // المنطقة الآمنة للطباعة
  content: { x0: 18, y0: 18, x1: 130.5, y1: 192 },

  // ترويسة مضغوطة: كتلة العنوان يمينًا، وشبكة رقم الجلوس يسارًا
  header: { y0: 18, y1: 70.5, dividerY: 70.5, dividerX0: 18, dividerX1: 130.5 },
  titleBlock: { x0: 72, x1: 130.5 },
  idBlock: { x0: 18, x1: 70 },

  // رمز الورقة: 6 فقاعات، 5 بتات لرقم الاختبار + بتة لنوع الورقة
  code: {
    count: 6,
    bits: 5,
    keyBit: 5,          // البتة رقم 5 = 1 تعني "ورقة مفتاح إجابة"
    r: 2.0,
    pitchX: 4.8,
    firstX: 128.5,      // مركز البتة 0 (أقصى اليمين)
    y: 45,
    labelX: 100,        // نص العنوان محاذى لليمين (يسار الفقاعات)
    labelY: 46.2,
  },

  // شبكة رقم الجلوس
  idGrid: {
    rows: 10,           // الأرقام 0..9
    maxCols: 8,         // حتى 8 منازل
    colPitch: 6.2,
    rowPitch: 3.8,
    bubbleR: 1.7,
    firstColX: 21.5,
    firstRowY: 31,
    boxW: 6.0,          // مستطيل الكتابة اليدوية
    boxH: 5.2,
    boxY0: 23.5,
    captionBaseline: 21,
    captionX: 70,
    hintX: 18,
    hintY: 68,
  },

  // منطقة الأسئلة: عمودان يملأان الورقة (حتى 40 سؤالًا = 20 صفًا × عمودين)
  questions: {
    y0: 74,
    y1: 190,
    maxRowsPerCol: 20,
    maxRowPitch: 14,
    colRightRight: 130.5,   // العمود الأول (يمينًا)
    colRightLeft: 77.5,
    colLeftRight: 71,       // العمود الثاني (يسارًا)
    colLeftLeft: 18,
    numberBoxW: 9,
    numberBoxGap: 2.5,
    choiceMaxPitch: 9.3,
    yesnoMaxPitch: 12,
    minBubbleR: 2.2,
    maxBubbleR: 3.2,
    rowBubbleFactor: 0.42,  // نصف القطر = نسبة من ارتفاع الصف (لتفادي التلاصق)
  },

  footer: { y: 192 },

  // نصوص الواجهة المطبوعة
  texts: {
    idCaption: 'رقم الجلوس',
    idHint: 'اكتب رقمك في المستطيلات، ثم شبّك الرقم نفسه أسفل كل عمود',
    codeCaption: 'رمز الورقة',
    instructions: [
      'ظلّل دائرة واحدة لكل سؤال بقلم رصاص أو قلم جاف أسود/أزرق.',
      'دائرة = رمز الإجابة الصحيحة، ونعم/لا كما هو مطلوب في السؤال.',
      'لا تكتب خارج الدوائر، ولا تُظلّل أكثر من دائرة واحدة.',
    ],
    footer: 'نصف ورقة A4 · لا تكتب في هذا القسم — تُقرأ الورقة آليًا',
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

/**
 * يبني قائمة الأسئلة بترتيب مطبوع واضح:
 *   • أسئلة «ضع دائرة» أولًا (كلها متتالية)
 *   • أسئلة «نعم أو لا» آخر الورقة (كلها متتالية)
 * سبب الترتيب: ذاكرة الطالب تنتقل مرة واحدة من نمط إلى آخر، ويقلّ الخطأ في
 * تعبئة الورقة؛ كما يسهل على المعلم تصحيح النوعين بصريًا عند المراجعة.
 */
export function planQuestions({ count, kind = 'choice', options = 4 }) {
  const n = Math.max(1, Math.min(GEO.questions.maxRowsPerCol * 2, count | 0));
  const out = [];
  if (kind === 'yesno') {
    for (let i = 0; i < n; i++) out.push({ type: 'yesno', options: 2, marks: 1 });
    return out;
  }
  if (kind === 'mix') {
    // عدد أسئلة نعم/لا = ثلث العدد تقريبًا (سؤال واحد لكل ثلاثة على الأقل)
    const yesNo = Math.max(1, Math.min(n - 1, Math.round(n / 3)));
    const choice = n - yesNo;
    for (let i = 0; i < choice; i++) out.push({ type: 'choice', options, marks: 1 });
    for (let i = 0; i < yesNo; i++) out.push({ type: 'yesno', options: 2, marks: 1 });
    return out;
  }
  for (let i = 0; i < n; i++) out.push({ type: 'choice', options, marks: 1 });
  return out;
}

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

  /* --- 4) الأسئلة: عدد الصفوف والأعمدة يُحسب من عدد الأسئلة --- */
  const total = Math.max(1, n);
  const availH = q.y1 - q.y0;
  const rowsPerCol = Math.max(1, Math.min(q.maxRowsPerCol, Math.ceil(total / 2)));
  const rowPitch = Math.min(q.maxRowPitch, availH / rowsPerCol);
  // نُوسّط كتلة الأسئلة رأسيًا حين لا تملأ الورقة
  const yStart = round2(q.y0 + Math.max(0, (availH - rowsPerCol * rowPitch) / 2));
  const bubbleR = round2(Math.max(q.minBubbleR, Math.min(q.maxBubbleR, rowPitch * q.rowBubbleFactor)));
  t.layout.rowsPerCol = rowsPerCol;
  t.layout.rowPitch = round2(rowPitch);
  t.layout.yStart = yStart;
  t.layout.bubbleR = bubbleR;
  t.layout.columns = 2;

  for (let i = 0; i < n; i++) {
    const col = Math.floor(i / rowsPerCol);          // 0 = العمود اليمين
    const row = i % rowsPerCol;
    const colRight = col === 0 ? q.colRightRight : q.colLeftRight;
    const colLeft = col === 0 ? q.colRightLeft : q.colLeftLeft;
    const y = round2(yStart + rowPitch * (row + 0.5));
    const item = questions[i];
    const isYesNo = item.type === 'yesno';
    const k = isYesNo ? 2 : Math.max(2, Math.min(5, item.options || 4));
    const r = isYesNo ? bubbleR : bubbleR;
    const xFirst = round2(colRight - (q.numberBoxW + q.numberBoxGap) - r);
    const maxPitch = isYesNo ? q.yesnoMaxPitch : q.choiceMaxPitch;
    const avail = Math.max(4, (xFirst - r) - colLeft - 1.5);
    const pitch = Math.min(maxPitch, avail / (k - 1));

    const bubbles = [];
    for (let o = 0; o < k; o++) {
      bubbles.push({
        x: round2(xFirst - o * pitch),
        y, r, option: o,
        label: isYesNo ? (o === 0 ? 'نعم' : 'لا')
                       : (t.meta.optionLabels === 'en' ? OPTION_LABELS_EN[o] : OPTION_LABELS_AR[o]),
      });
    }

    t.questions.push({
      index: i, col, row, type: isYesNo ? 'yesno' : 'choice',
      options: k, marks: item.marks ?? 1,
      numberBox: {
        x: round2(colRight - q.numberBoxW),
        y: round2(y - rowPitch * 0.42),
        w: q.numberBoxW,
        h: round2(rowPitch * 0.84),
      },
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
  if (n > GEO.questions.maxRowsPerCol * 2) errors.push(`الحدّ الأقصى ${GEO.questions.maxRowsPerCol * 2} سؤالًا في ورقة واحدة`);
  (spec.questions || []).forEach((it, i) => {
    if (it.type === 'choice' && (it.options < 2 || it.options > 5)) {
      errors.push(`السؤال ${i + 1}: عدد الخيارات يجب أن يكون بين 2 و5`);
    }
  });
  return errors;
}

/** عدد الشرائح المطلوبة لعدد أسئلة (للتوافق المستقبلي: أكثر من ورقة) */
export function sheetCount(questionCount) {
  return Math.max(1, Math.ceil(questionCount / (GEO.questions.maxRowsPerCol * 2)));
}
