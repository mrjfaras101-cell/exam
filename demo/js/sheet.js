/**
 * sheet.js — رسم ورقة الإجابة على canvas من نفس القالب الهندسي (template.js)
 * يُستخدم للمعاينة، والطباعة (100%)، وتنزيل صورة الورقة.
 */


const AR_FONT = "'Cairo', sans-serif";

/**
 * @param {HTMLCanvasElement} canvas
 * @param {object} template القالب من buildTemplate
 * @param {number} pxPerMm دقة الرسم (مثلاً 3.2 للمعاينة)
 */
export function renderSheet(canvas, template, pxPerMm = 3.2) {
  const paperW = template.paper?.w ?? 148.5;
  const paperH = template.paper?.h ?? 210;
  const W = Math.round(paperW * pxPerMm), H = Math.round(paperH * pxPerMm);
  canvas.width = W; canvas.height = H;
  const c = canvas.getContext('2d');
  const mm = (v) => v * pxPerMm;

  c.fillStyle = '#ffffff';
  c.fillRect(0, 0, W, H);
  c.strokeStyle = '#c9d3d2'; c.lineWidth = 1;
  c.strokeRect(0.5, 0.5, W - 1, H - 1);

  /* --- علامات التسجيل --- */
  for (const f of template.fiducials) {
    const half = f.size / 2;
    c.fillStyle = '#111';
    c.fillRect(mm(f.x - half), mm(f.y - half), mm(f.size), mm(f.size));
    if (f.kind === 'ring') {
      const h = f.hole / 2;
      c.fillStyle = '#fff';
      c.fillRect(mm(f.x - h), mm(f.y - h), mm(f.hole), mm(f.hole));
    }
  }

  /* --- رمز الورقة --- */
  for (const b of template.code.bubbles) {
    c.beginPath(); c.arc(mm(b.x), mm(b.y), mm(b.r), 0, Math.PI * 2);
    if (b.printed) { c.fillStyle = '#111'; c.fill(); }
    else { c.strokeStyle = '#111'; c.lineWidth = Math.max(1, mm(0.3)); c.stroke(); }
  }

  /* --- شبكة رقم الجلوس --- */
  c.strokeStyle = '#333'; c.lineWidth = Math.max(1, mm(0.28));
  for (const bx of template.digitGrid.boxes || []) {
    c.strokeRect(mm(bx.x), mm(bx.y), mm(bx.w), mm(bx.h));
  }
  c.fillStyle = '#555';
  c.font = `${Math.max(7, mm(2.2))}px ${AR_FONT}`;
  c.textAlign = 'center'; c.textBaseline = 'middle';
  for (const b of template.digitGrid.bubbles) {
    c.beginPath(); c.arc(mm(b.x), mm(b.y), mm(b.r), 0, Math.PI * 2);
    c.strokeStyle = '#333'; c.lineWidth = Math.max(1, mm(0.22)); c.stroke();
    c.fillText(String(b.digit), mm(b.x), mm(b.y) + mm(0.1));
  }

  /* --- نصوص الترويسة (كتلة عنوان يمين + شبكة الجلوس يسار) --- */
  const m = template.meta;
  const right = mm(130.5);
  c.textAlign = 'right'; c.textBaseline = 'alphabetic';
  c.fillStyle = '#0b1a18';
  c.font = `700 ${mm(4.6)}px ${AR_FONT}`;
  c.fillText(m.title || 'اختبار', right, mm(27));
  c.font = `400 ${mm(3.3)}px ${AR_FONT}`;
  c.fillText([m.subject, m.gradeLabel].filter(Boolean).join('  —  '), right, mm(35));
  c.font = `400 ${mm(2.6)}px ${AR_FONT}`;
  c.fillStyle = '#333';
  c.fillText(`التاريخ: ${m.examDate || '—'}    المعلم: ${m.teacher || '—'}`, right, mm(39.5));

  c.fillStyle = '#444'; c.font = `400 ${mm(2.2)}px ${AR_FONT}`;
  m.texts.instructions.forEach((t, i) => c.fillText(t, right, mm(55.5 + i * 4.5)));

  c.strokeStyle = '#999'; c.lineWidth = 1;
  c.beginPath(); c.moveTo(mm(18), mm(70.5)); c.lineTo(mm(130.5), mm(70.5)); c.stroke();
  c.fillStyle = '#555'; c.font = `400 ${mm(2.2)}px ${AR_FONT}`;
  c.textAlign = 'right';
  c.fillText(m.texts.codeCaption, mm(100), mm(46.2));

  // رقم الجلوس: العنوان + التلميح
  c.fillStyle = '#0b1a18'; c.font = `700 ${mm(2.9)}px ${AR_FONT}`;
  c.textAlign = 'right';
  c.fillText(m.texts.idCaption, mm(70), mm(21));
  c.fillStyle = '#555'; c.font = `400 ${mm(1.9)}px ${AR_FONT}`;
  c.textAlign = 'left';
  c.fillText(m.texts.idHint, mm(18), mm(68));

  /* --- الأسئلة --- */
  c.textAlign = 'center';
  for (const q of template.questions) {
    const nb = q.numberBox;
    c.strokeStyle = '#8a9a98'; c.lineWidth = 1;
    c.strokeRect(mm(nb.x), mm(nb.y), mm(nb.w), mm(nb.h));
    c.fillStyle = '#0b1a18'; c.font = `700 ${mm(Math.min(3.0, nb.h * 0.55))}px ${AR_FONT}`;
    c.fillText(String(q.index + 1), mm(nb.x + nb.w / 2), mm(nb.y + nb.h / 2) + mm(0.2));

    for (const b of q.bubbles) {
      c.beginPath(); c.arc(mm(b.x), mm(b.y), mm(b.r), 0, Math.PI * 2);
      c.strokeStyle = '#222'; c.lineWidth = Math.max(1, mm(0.3)); c.stroke();
      c.fillStyle = '#333';
      c.font = `400 ${mm(Math.min(q.type === 'yesno' ? 2.6 : 2.5, b.r * 0.95))}px ${AR_FONT}`;
      c.fillText(b.label, mm(b.x), mm(b.y) + mm(0.15));
    }
  }

  /* --- التذييل --- */
  c.fillStyle = '#666'; c.font = `400 ${mm(2.4)}px ${AR_FONT}`;
  c.textAlign = 'center';
  c.fillText(`${m.texts.footer}  ·  رمز الورقة ${m.serial}${m.isKey ? ' (مفتاح)' : ''}`, mm(paperW / 2), mm(192));

  return canvas;
}

/** طباعة الورقة بمقياس 100% — **نسختان في كل صفحة A4 أفقية** مع خط قصّ في المنتصف */
export function printSheet(canvas, title = 'ورقة الإجابة') {
  const w = window.open('', '_blank');
  if (!w) { alert('المتصفح منع نافذة الطباعة — اسمح بالنوافذ المنبثقة.'); return; }
  const data = canvas.toDataURL('image/png');
  w.document.write(`<!DOCTYPE html><html dir="rtl" lang="ar"><head><meta charset="utf-8">
  <title>${title}</title>
  <style>
    @page { size: A4 landscape; margin: 0; }
    html,body { margin:0; padding:0; background:#fff; }
    .sheet { width: 148.5mm; height: 210mm; display: block; }
    .spread { display: flex; flex-direction: row; }
    .cut { width: 0.2mm; height: 210mm; background: #bbb; }
    .noprint { font-family: sans-serif; padding: 8mm; direction: rtl; font-size: 3.4mm; line-height: 1.6 }
    @media print { .noprint { display: none } }
  </style></head><body>
  <div class="noprint">
    <b>تعليمات:</b> اختر مقياس <b>100%</b> (أو «الحجم الفعلي») — لا تستخدم «ملاءمة الصفحة».
    الصفحة تحتوي <b>نسختين</b> من ورقة نصف A4: اقصصها من الخط الرمادي في المنتصف.
    تأكّد من ظهور المربّعات السوداء في الأركان الأربعة كاملة قبل التوزيع.
  </div>
  <div class="spread">
    <img class="sheet" src="${data}">
    <div class="cut"></div>
    <img class="sheet" src="${data}">
  </div>
  <script>window.addEventListener('load', () => window.print());</script>
  </body></html>`);
  w.document.close();
}

/** تنزيل الورقة كصورة PNG عالية الدقة */
export function downloadSheet(template, filename = 'answer-sheet.png') {
  const cv = document.createElement('canvas');
  renderSheet(cv, template, 12);      // دقة عالية (12 بكسل/مم)
  const a = document.createElement('a');
  a.href = cv.toDataURL('image/png');
  a.download = filename;
  a.click();
}

/** يحمّل الخط العربي قبل أول رسم حتى لا تظهر النصوص بخط بديل */
export async function ensureFonts() {
  if (!document.fonts) return;
  try {
    await Promise.all([
      document.fonts.load("400 16px 'Cairo'"),
      document.fonts.load("700 16px 'Cairo'"),
    ]);
    await document.fonts.ready;
  } catch (e) { /* نكمل بأي حال */ }
}
