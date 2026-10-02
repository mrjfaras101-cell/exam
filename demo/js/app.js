/**
 * app.js — منطق النموذج الحي لتطبيق «مُصحِّح»
 * تشغيل كامل: إنشاء اختبار → طباعة الورقة → مفتاح الإجابة → تصحيح بالكاميرا → النتائج والتحليل.
 * كل القراءة تتم على الجهاز بمحرّك engine.js (نفس خوارزمية تطبيق Flutter).
 */
import { buildTemplate, validateSpec, planQuestions } from './template.js';
import { detectSheet, composeNumber, DEFAULTS } from './engine.js';
import { renderSheet, printSheet, downloadSheet, ensureFonts } from './sheet.js';
import { SAMPLE_EXAM, SAMPLE_KEY } from './sample_exam.js';
import { scoreAttempt as scoreCore, classStats, analyzeQuestions, FLAG_LABELS } from './grading.js';

/* ================================================================== */
/* الحالة                                                              */
/* ================================================================== */
const LS_KEY = 'musahhih.v1';
const $ = (s) => document.querySelector(s);
const $$ = (s) => Array.from(document.querySelectorAll(s));

const seedExam = () => ({
  id: 'demo',
  name: SAMPLE_EXAM.title,
  subject: SAMPLE_EXAM.subject,
  gradeLabel: SAMPLE_EXAM.gradeLabel,
  teacher: SAMPLE_EXAM.teacher,
  examDate: SAMPLE_EXAM.examDate,
  serial: SAMPLE_EXAM.serial,
  idDigits: SAMPLE_EXAM.idDigits,
  optionLabels: 'ar',
  questions: SAMPLE_EXAM.questions.map((q) => ({ ...q, marks: 1 })),
  key: SAMPLE_KEY.slice(),
  createdAt: Date.now(),
});

let state = {
  exams: [seedExam()],
  activeId: 'demo',
  results: {},            // examId → [result]
  students: {},           // رقم الجلوس → الاسم
  manual: {},             // examId → { studentNumber: { qIndex: option|null } }
  cancelled: {},          // examId → [فهارس أسئلة ملغاة]
  settings: { tHigh: DEFAULTS.tHigh, tLight: DEFAULTS.tLight, inkRatio: DEFAULTS.inkRatio, negative: false, pass: 60 },
};
try {
  const saved = JSON.parse(localStorage.getItem(LS_KEY) || 'null');
  if (saved && saved.exams?.length) state = { ...state, ...saved, settings: { ...state.settings, ...(saved.settings || {}) } };
} catch (e) { /* تجاهل */ }
const save = () => { try { localStorage.setItem(LS_KEY, JSON.stringify(state)); } catch (e) {} };

const activeExam = () => state.exams.find((e) => e.id === state.activeId) || state.exams[0];
const opt = () => ({ ...DEFAULTS, tHigh: state.settings.tHigh, tLight: state.settings.tLight, inkRatio: state.settings.inkRatio });
const resultsOf = (id = state.activeId) => state.results[id] || (state.results[id] = []);

function templateFor(exam, isKey = false) {
  return buildTemplate({ ...exam, questions: exam.questions, isKey, idDigits: exam.idDigits });
}

/* ================================================================== */
/* أدوات واجهة                                                        */
/* ================================================================== */
let toastTimer = null;
function toast(msg, ms = 2200) {
  const t = $('#toast');
  t.textContent = msg; t.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { t.hidden = true; }, ms);
}
const AR = (n) => String(n);

let current = 'home';
function go(screen, opts = {}) {
  current = screen;
  $$('.screen').forEach((s) => { s.hidden = s.dataset.screen !== screen; });
  $$('.tab').forEach((b) => b.classList.toggle('active', b.dataset.tab === screen));
  const titles = { home: 'مُصحِّح', exam: 'تفاصيل الاختبار', key: 'مفتاح الإجابة', sheet: 'الورقة والطباعة', scan: 'التصحيح بالكاميرا', results: 'النتائج والتحليل', settings: 'الإعدادات' };
  $('#appTitle').textContent = titles[screen] || 'مُصحِّح';
  $('#btnBack').hidden = ['home', 'settings'].includes(screen) && screen !== 'exam';
  $('#btnBack').hidden = screen === 'home';
  window.scrollTo({ top: 0 });
  render(screen, opts);
}

function render(screen, opts = {}) {
  if (screen === 'home') renderHome();
  if (screen === 'exam') renderExam();
  if (screen === 'key') renderKey();
  if (screen === 'sheet') renderSheetScreen(opts.role || 'student');
  if (screen === 'scan') renderScan();
  if (screen === 'results') renderResults();
  if (screen === 'settings') renderSettings();
}

/* ================================================================== */
/* الرئيسية                                                            */
/* ================================================================== */
function renderHome() {
  const list = $('#examList');
  $('#chipExams').textContent = `${state.exams.length} اختبار`;
  const total = Object.values(state.results).reduce((s, r) => s + r.length, 0);
  $('#chipScanned').textContent = `${total} ورقة مُصحّحة`;

  list.innerHTML = '';
  for (const ex of state.exams) {
    const res = state.results[ex.id] || [];
    const card = document.createElement('div');
    card.className = 'card';
    card.innerHTML = `
      <div class="grow">
        <h4>${ex.name}</h4>
        <p>${[ex.subject, ex.gradeLabel].filter(Boolean).join(' · ')} — ${ex.questions.length} سؤالًا</p>
        <p class="muted">رمز الورقة: ${ex.serial} · مفتاح: ${(ex.key || []).filter((k) => k !== null && k !== undefined).length}/${ex.questions.length}</p>
      </div>
      <span class="pill">${res.length} نتيجة</span>`;
    card.onclick = () => { state.activeId = ex.id; save(); go('exam'); };
    list.appendChild(card);
  }
  if (!state.exams.length) list.innerHTML = '<div class="card empty">لا توجد اختبارات — أنشئ اختبارًا</div>';
}

/* ================================================================== */
/* تفاصيل الاختبار                                                     */
/* ================================================================== */
function renderExam() {
  const ex = activeExam();
  $('#exTitle').textContent = ex.name;
  $('#exMeta').textContent = [ex.subject, ex.gradeLabel, ex.examDate].filter(Boolean).join(' · ');
  $('#exSerial').textContent = `رمز ${ex.serial}`;

  const res = resultsOf(ex.id);
  const answered = (ex.key || []).filter((k) => k !== null && k !== undefined).length;
  const avg = res.length ? (res.reduce((s, r) => s + r.percent, 0) / res.length).toFixed(0) : '—';
  $('#exStats').innerHTML = `
    <div class="stat"><b>${ex.questions.length}</b><span>سؤال</span></div>
    <div class="stat"><b>${answered}</b><span>مفتاح مُدخل</span></div>
    <div class="stat"><b>${res.length ? avg + '%' : '—'}</b><span>متوسط الصف</span></div>`;

  const ql = $('#questionList');
  ql.innerHTML = '';
  ex.questions.forEach((q, i) => {
    const k = ex.key?.[i];
    const labels = q.type === 'yesno' ? ['نعم', 'لا'] : (ex.optionLabels === 'en' ? ['A', 'B', 'C', 'D', 'E'] : ['أ', 'ب', 'ج', 'د', 'هـ']);
    const row = document.createElement('div');
    row.className = 'q-row';
    row.innerHTML = `<span class="q-num">${i + 1}</span>
      <span class="q-type">${q.type === 'yesno' ? 'نعم / لا' : `دائرة · ${q.options} خيارات`}</span>
      <span class="q-ans ${k === null || k === undefined ? 'none' : ''}">${k === null || k === undefined ? 'لم يُحدَّد' : labels[k]}</span>`;
    ql.appendChild(row);
  });
}

/* ================================================================== */
/* مفتاح الإجابة                                                       */
/* ================================================================== */
function renderKey() {
  const ex = activeExam();
  const grid = $('#keyGrid');
  grid.innerHTML = '';
  ex.questions.forEach((q, i) => {
    const labels = q.type === 'yesno' ? ['نعم', 'لا'] : (ex.optionLabels === 'en' ? ['A', 'B', 'C', 'D', 'E'] : ['أ', 'ب', 'ج', 'د', 'هـ']);
    const row = document.createElement('div');
    row.className = 'key-row';
    row.innerHTML = `<span class="q-num">${i + 1}</span>`;
    const bs = document.createElement('div');
    bs.className = 'bubbles';
    labels.slice(0, q.type === 'yesno' ? 2 : q.options).forEach((lb, oi) => {
      const b = document.createElement('button');
      b.className = 'bub' + (q.type === 'yesno' ? ' yes' : '') + (ex.key?.[i] === oi ? ' on' : '');
      b.textContent = lb;
      b.onclick = () => {
        ex.key[i] = ex.key[i] === oi ? null : oi;
        save(); renderKey(); renderExam();
      };
      bs.appendChild(b);
    });
    row.appendChild(bs);
    grid.appendChild(row);
  });
  const answered = (ex.key || []).filter((k) => k !== null && k !== undefined).length;
  $('#keyStatus').textContent = `${answered} / ${ex.questions.length} مُجاب`;
  $('#btnSaveKey').disabled = answered !== ex.questions.length;
}

/* ================================================================== */
/* الورقة والطباعة                                                     */
/* ================================================================== */
let sheetRole = 'student';
function renderSheetScreen(role = sheetRole) {
  sheetRole = role;
  $$('#sheetSeg .seg-btn').forEach((b) => b.classList.toggle('active', b.dataset.role === role));
  const ex = activeExam();
  const tpl = templateFor(ex, role === 'key');
  ensureFonts().then(() => renderSheet($('#sheetCanvas'), tpl, 3.2));
}

/* ================================================================== */
/* التصحيح بالكاميرا                                                   */
/* ================================================================== */
let stream = null, scanTimer = null, torchOn = false, lastFrames = [], busy = false, lastOverlay = null;

// الورقة «تحتاج مراجعة» فقط إذا كان فيها وسم يخصّ سؤالًا (index >= 0) أو رقم جلوس غير مقروء.
// الوسوم العامة (-1 دقة منخفضة، -2 لمعان، -3 اهتزاز) ملاحظات جودة تُعرض دون أن تُزحم قائمة المراجعة.
function needsReview(r) {
  return (r.flags || []).some((f) => f.index >= 0) || r.studentNumber === null;
}

function renderScan() {
  $('#reviewCount').textContent = resultsOf().filter(needsReview).length;
  renderReviewList();
}

function renderReviewList() {
  const list = $('#reviewList');
  const items = resultsOf().filter(needsReview);
  list.innerHTML = '';
  if (!items.length) {
    list.innerHTML = '<div class="card empty">لا توجد أوراق تحتاج مراجعة ✓</div>';
    return;
  }
  for (const r of items) {
    const card = document.createElement('div');
    card.className = 'card';
    card.innerHTML = `<div class="grow"><h4>${r.studentNumber ?? 'رقم غير مقروء'}</h4>
      <p>${(r.flags || []).filter((f) => f.index >= 0).map((f) => `س${f.index + 1}: ${f.reason}`).join(' · ') || 'رقم جلوس غير مقروء'}</p>
      ${(r.flags || []).some((f) => f.index < 0) ? `<p class="an-meta">${(r.flags || []).filter((f) => f.index < 0).map((f) => '⚠ ' + f.reason).join(' · ')}</p>` : ''}</div>
      <span class="pill">${r.score.toFixed(1)}</span>`;
    card.onclick = () => showResultCard(r, true);
    list.appendChild(card);
  }
}

async function startCamera() {
  try {
    stream = await navigator.mediaDevices.getUserMedia({
      video: { facingMode: { ideal: 'environment' }, width: { ideal: 1920 }, height: { ideal: 1440 } },
      audio: false,
    });
    const v = $('#video');
    v.srcObject = stream;
    await v.play();
    $('#btnStartCam').textContent = '⏸ إيقاف الكاميرا';
    $('#btnStartCam').dataset.on = '1';
    loopScan();
  } catch (e) {
    toast('تعذّر فتح الكاميرا: ' + (e.message || e.name) + ' — استخدم «من صورة/أوراق جاهزة».');
  }
}
function stopCamera() {
  clearTimeout(scanTimer); scanTimer = null;
  if (stream) { stream.getTracks().forEach((t) => t.stop()); stream = null; }
  $('#btnStartCam').textContent = '▶ تشغيل الكاميرا';
  $('#btnStartCam').dataset.on = '';
}

function grabFrame(maxWidth = DEFAULTS.maxWorkWidth) {
  const v = $('#video');
  if (!v.videoWidth) return null;
  const scale = Math.min(1, maxWidth / v.videoWidth);
  const w = Math.round(v.videoWidth * scale), h = Math.round(v.videoHeight * scale);
  const cv = document.createElement('canvas');
  cv.width = w; cv.height = h;
  const c = cv.getContext('2d', { willReadFrequently: true });
  c.drawImage(v, 0, 0, w, h);
  return { data: c.getImageData(0, 0, w, h).data, w, h };
}

function loopScan() {
  if (!stream) return;
  scanTimer = setTimeout(async () => {
    if (!busy) {
      busy = true;
      try {
        const f = grabFrame();
        if (f) {
          const tpl = templateFor(activeExam());
          const r = detectSheet(f.data, f.w, f.h, tpl, opt());
          lastOverlay = { r, fw: f.w, fh: f.h };
          drawOverlay(f.w, f.h);
          handleReading(r);
        }
      } catch (e) { console.warn(e); }
      busy = false;
    }
    loopScan();
  }, 380);
}

/** منطق الالتقاط التلقائي: قراءتان متتاليتان متطابقتان + ثبات المواضع */
function handleReading(r) {
  const box = document.querySelector('.camera-box');
  const hud = $('#hudMsg');
  if (!r.ok) {
    box.classList.remove('ready');
    hud.textContent = r.reason || 'وجّه الكاميرا نحو الورقة…';
    lastFrames = [];
    return;
  }
  const sig = JSON.stringify([r.digits, r.answers.map((a) => a.option)]);
  const prev = lastFrames[lastFrames.length - 1];
  lastFrames.push({ sig, corners: r.corners });
  if (lastFrames.length > 3) lastFrames.shift();

  const stable = lastFrames.length >= 2 && lastFrames[lastFrames.length - 1].sig === lastFrames[lastFrames.length - 2].sig;
  const cornerMove = prev
    ? Math.max(...r.corners.map((c, i) => Math.hypot(c[0] - prev.corners[i][0], c[1] - prev.corners[i][1]))) / r.quality.pxPerMm
    : 99;
  const qFlags = r.flags.filter((f) => f.index >= 0).length;
  const flagsTxt = qFlags ? `⚠️ ${qFlags} موضع للمراجعة` : '✓ قراءة واضحة';
  hud.innerHTML = `${r.code.isKeySheet ? 'ورقة مفتاح' : `رقم ${composeNumber(r.digits) ?? '؟'}`} · ${flagsTxt} · دقة ${r.quality.pxPerMm}px/mm`;

  box.classList.toggle('ready', stable && cornerMove < 12);
  if (stable && cornerMove < 12) {
    capture(r);
    lastFrames = [];
  }
}

function capture(r) {
  const ex = activeExam();
  const studentNumber = composeNumber(r.digits);
  if (r.code.isKeySheet) {
    const key = r.answers.map((a) => a.option);
    if (key.every((k) => k !== null)) {
      ex.key = key; save(); toast('تم تحديث مفتاح الإجابة من الورقة الممسوحة ✓');
    } else {
      toast('ورقة المفتاح غير مكتملة — بعض الإجابات غير مقروءة');
    }
    return;
  }
  if (studentNumber === null) { toast('رقم الجلوس غير مقروء — أدخله يدويًا'); }
  const existing = resultsOf(ex.id).find((x) => x.studentNumber === studentNumber && studentNumber !== null);
  const result = scoreAttempt(r, ex, studentNumber);
  if (existing) {
    Object.assign(existing, result, { rescan: true });
    toast(`الطالب ${studentNumber} مُسجَّل سابقًا — حُدِّثت النتيجة`);
  } else {
    resultsOf(ex.id).push(result);
  }
  save();
  showResultCard(result, false);
  renderScan();
}

/** يحوّل قراءة المحرّك إلى نتيجة مع درجة (يستخدم وحدة التصحيح القابلة للاختبار) */
function scoreAttempt(r, ex, studentNumber) {
  const answers = r.answers.map((a) => a.option);
  const graded = scoreCore(answers, {
    questions: ex.questions,
    key: ex.key || [],
    cancelled: new Set(state.cancelled[ex.id] || []),
  }, { negative: state.settings.negative, negativeFactor: 0.25 });
  return {
    studentNumber,
    name: state.students[studentNumber] || null,
    answers,
    correct: graded.correct, wrong: graded.wrong, blank: graded.blank,
    score: graded.score, total: graded.total, percent: graded.percent,
    perQuestion: graded.perQuestion,
    flags: r.flags || [],
    confidence: r.confidence ?? 1,
    quality: r.quality || null,
    code: r.code || null,
    scannedAt: Date.now(),
  };
}

function showResultCard(r, allowEdit) {
  const box = $('#lastResult');
  box.hidden = false;
  const cls = r.percent >= 80 ? '' : r.percent >= 50 ? 'mid' : 'low';
  const chips = r.answers.map((a, i) => {
    const good = a === activeExam().key?.[i];
    const flagged = (r.flags || []).some((f) => f.index === i);
    const lbl = a === null ? '—' : String(a + 1);
    return `<span class="q-chip ${flagged ? 'flag' : good ? 'ok' : 'bad'}" data-q="${i}">${i + 1}:${lbl}</span>`;
  }).join('');
  box.innerHTML = `
    <div class="rc-head">
      <div class="score-ring ${cls}">${r.score.toFixed(1)}<small>/${r.total}</small></div>
      <div class="grow"><h4 style="margin:0">${r.name || 'طالب'} ${r.studentNumber ? `— ${r.studentNumber}` : ''}</h4>
      <p class="muted small">صحيح ${r.correct} · خطأ ${r.wrong} · فارغ ${r.blank} · ثقة ${(r.confidence * 100).toFixed(0)}%</p></div>
      <span class="pill">${r.percent.toFixed(0)}%</span>
    </div>
    <div class="q-chips">${chips}</div>
    ${allowEdit ? '<p class="muted small" style="margin:8px 0 0">المس أي سؤال لتغيير إجابته يدويًا (سيُعاد حساب الدرجة).</p>' : ''}`;
  if (allowEdit) {
    box.querySelectorAll('.q-chip').forEach((ch) => {
      ch.onclick = () => {
        const i = +ch.dataset.q;
        const q = activeExam().questions[i];
        const max = q.type === 'yesno' ? 2 : q.options;
        const cur = r.answers[i];
        r.answers[i] = cur === null || cur >= max - 1 ? (cur === null ? 0 : null) : cur + 1;
        const fresh = scoreAttempt({ answers: r.answers.map((o) => ({ option: o })), flags: r.flags, confidence: r.confidence, quality: r.quality, code: r.code }, activeExam(), r.studentNumber);
        Object.assign(r, fresh);
        save(); showResultCard(r, true); renderResults();
      };
    });
  }
}

/** رسم التراكب فوق الفيديو: الأركان + الفقاعات بلون نسبة الامتلاء */
function drawOverlay(fw, fh) {
  const cv = $('#overlay');
  cv.width = fw; cv.height = fh;
  const c = cv.getContext('2d');
  c.clearRect(0, 0, fw, fh);
  if (!lastOverlay?.r?.ok) return;
  const { r } = lastOverlay;

  c.lineWidth = Math.max(2, fw / 300);
  c.strokeStyle = '#34d399';
  c.beginPath();
  r.corners.forEach((p, i) => (i ? c.lineTo(p[0], p[1]) : c.moveTo(p[0], p[1])));
  c.closePath(); c.stroke();

  for (const a of r.answers) {
    for (const b of a.bubbles || []) {
      const f = a.fills?.[b.option] ?? 0;
      c.strokeStyle = f >= 0.45 ? '#22c55e' : f >= 0.18 ? '#f59e0b' : 'rgba(255,255,255,.35)';
      c.beginPath(); c.arc(b.x, b.y, fw / 90, 0, Math.PI * 2); c.stroke();
    }
  }
}

/* ================================================================== */
/* تصحيح دفعة صور (من ملفات أو الأوراق التجريبية)                       */
/* ================================================================== */
async function processImageSource(src, name = '') {
  const img = new Image();
  img.crossOrigin = 'anonymous';
  img.src = src;
  await img.decode();
  const scale = Math.min(1, DEFAULTS.maxWorkWidth / img.naturalWidth);
  const w = Math.round(img.naturalWidth * scale), h = Math.round(img.naturalHeight * scale);
  const cv = document.createElement('canvas'); cv.width = w; cv.height = h;
  const c = cv.getContext('2d', { willReadFrequently: true });
  c.drawImage(img, 0, 0, w, h);
  const data = c.getImageData(0, 0, w, h).data;
  const tpl = templateFor(activeExam());
  const r = detectSheet(data, w, h, tpl, opt());
  return { r, w, h };
}

async function correctBatch(sources, labels = []) {
  const ex = activeExam();
  const hud = $('#hudMsg');
  let done = 0, failed = 0;
  for (let i = 0; i < sources.length; i++) {
    hud.textContent = `جارٍ التصحيح… ${i + 1}/${sources.length}`;
    await new Promise((res) => setTimeout(res, 10));
    try {
      const { r } = await processImageSource(sources[i], labels[i]);
      if (!r.ok) { failed++; toast(`${labels[i] || 'ورقة ' + (i + 1)}: ${r.reason}`, 3000); continue; }
      if (r.code.isKeySheet) {
        if (r.answers.every((a) => a.option !== null)) { ex.key = r.answers.map((a) => a.option); toast('مفتاح الإجابة محدَّث من ورقة المفتاح ✓'); }
        continue;
      }
      const num = composeNumber(r.digits);
      const result = scoreAttempt(r, ex, num);
      const existing = resultsOf(ex.id).findIndex((x) => x.studentNumber === num && num !== null);
      if (existing >= 0) resultsOf(ex.id)[existing] = result; else resultsOf(ex.id).push(result);
      done++;
    } catch (e) { failed++; }
  }
  hud.textContent = `تمّت معالجة ${done} ورقة${failed ? ` · فشل ${failed}` : ''}`;
  save();
  renderScan();
  if (done) { toast(`تم تصحيح ${done} ورقة ✓`) ; go('results'); }
}

async function correctDemoSet() {
  const man = await (await fetch('assets/samples/manifest.json')).json();
  const keys = man.scans.map((s) => KEY_NAMES[s.studentId]);
  man.scans.forEach((s) => { if (KEY_NAMES[s.studentId]) state.students[s.studentId] = KEY_NAMES[s.studentId]; });
  save();
  await correctBatch(man.scans.map((s) => 'assets/samples/' + s.file), man.scans.map((s) => s.name));
}

const KEY_NAMES = { 20260101: 'أحمد', 20260102: 'ريم', 20260103: 'يوسف', 20260104: 'سارة', 20260105: 'عمر', 20260106: 'ليان' };

async function loadKeySheet() {
  const { r } = await processImageSource('assets/samples/keysheet.jpg', 'keysheet');
  if (r.ok && r.code.isKeySheet) {
    const key = r.answers.map((a) => a.option);
    if (key.every((k) => k !== null)) {
      activeExam().key = key; save(); renderKey(); renderExam();
      toast('تم قراءة مفتاح الإجابة من ورقة الممسوحة ✓');
    } else toast('بعض فقرات المفتاح غير مقروءة — أكملها يدويًا');
  } else {
    toast(r.ok ? 'هذه ليست ورقة مفتاح (رمز الورقة لا يحمل بتّة المفتاح)' : r.reason);
  }
}

/* ================================================================== */
/* النتائج والتحليل                                                    */
/* ================================================================== */
function renderResults() {
  const ex = activeExam();
  const res = resultsOf(ex.id);
  const answeredQ = ex.questions.map((_, i) => i).filter((i) => !(state.cancelled[ex.id] || []).includes(i));
  const total = answeredQ.reduce((s, i) => s + (ex.questions[i].marks ?? 1), 0);

  // إحصاءات الصف
  const st = classStats(res, state.settings.pass);
  $('#classStats').innerHTML = `
    <div class="stat"><b>${res.length}</b><span>ورقة</span></div>
    <div class="stat"><b>${st.count ? st.mean.toFixed(1) + '%' : '—'}</b><span>المتوسط</span></div>
    <div class="stat"><b>${st.count ? st.median.toFixed(0) + '%' : '—'}</b><span>الوسيط</span></div>
    <div class="stat"><b>${st.count ? st.max.toFixed(0) + '%' : '—'}</b><span>الأعلى</span></div>
    <div class="stat"><b>${st.count ? st.min.toFixed(0) + '%' : '—'}</b><span>الأدنى</span></div>
    <div class="stat"><b>${st.count ? st.passRate.toFixed(0) + '%' : '—'}</b><span>نسبة النجاح</span></div>`;

  // جدول
  const tb = $('#resultTable tbody');
  tb.innerHTML = '';
  [...res].sort((a, b) => (a.studentNumber ?? 1e9) - (b.studentNumber ?? 1e9)).forEach((r) => {
    const tr = document.createElement('tr');
    const state_ = needsReview(r) ? 'review' : 'ok';
    tr.innerHTML = `<td>${r.studentNumber ?? '—'}</td><td>${r.name || '—'}</td>
      <td><b>${r.score.toFixed(1)}</b>/${r.total}</td><td>${r.percent.toFixed(1)}%</td>
      <td><span class="status-dot s-${state_}"></span>${state_ === 'ok' ? 'سليم' : state_ === 'review' ? 'مراجعة' : 'رقم مفقود'}</td>
      <td>›</td>`;
    tr.onclick = () => showResultCard(r, true);
    tb.appendChild(tr);
  });

  // تحليل الأسئلة (وحدة التحليلات)
  const al = $('#analysisList');
  al.innerHTML = '';
  if (!res.length) { al.innerHTML = '<div class="card empty">لا توجد نتائج بعد</div>'; return; }
  const analysis = analyzeQuestions(ex, res, res.map((r) => r.answers), new Set(state.cancelled[ex.id] || []));
  analysis.forEach((an) => {
    const i = an.index;
    if (an.cancelled) {
      al.insertAdjacentHTML('beforeend', `<div class="an-row"><div class="an-top"><b>سؤال ${i + 1}</b>
        <span class="muted">ملغى — لا يُحسب</span></div>
        <div style="margin-top:8px"><button class="btn ghost small" data-cancel="${i}">إعادة احتساب</button></div></div>`);
      return;
    }
    const distSum = an.distribution.reduce((a, b) => a + b, 0) || 1;
    al.insertAdjacentHTML('beforeend', `
      <div class="an-row">
        <div class="an-top"><b>سؤال ${i + 1}</b>
          <span class="muted small">${ex.questions[i].type === 'yesno' ? 'نعم/لا' : 'دائرة'}</span>
          <span class="pill" style="margin-inline-start:auto">صحيح ${(an.difficulty * 100).toFixed(0)}%</span></div>
        <div class="an-bar">${an.distribution.map((v, o) => `<i style="width:${(v / distSum) * 100}%;background:${o === ex.key?.[i] ? 'var(--ok)' : 'var(--danger)'}"></i>`).join('')}</div>
        <div class="an-meta">
          <span>صعوبة p = ${an.difficulty.toFixed(2)}</span>
          <span>تمييز D = ${an.discrimination.toFixed(2)}</span>
          <span>توزيع: ${an.distribution.join(' / ')}</span>
        </div>
        ${an.flags.length ? `<div class="an-meta" style="color:var(--warn)">⚠ ${an.flags.map((f) => FLAG_LABELS[f] || f).join(' · ')}</div>` : ''}
        <div style="margin-top:8px"><button class="btn ghost small" data-cancel="${i}">إلغاء السؤال</button></div>
      </div>`);
  });
  al.querySelectorAll('[data-cancel]').forEach((b) => {
    b.onclick = () => {
      const i = +b.dataset.cancel;
      const arr = state.cancelled[ex.id] || (state.cancelled[ex.id] = []);
      const at = arr.indexOf(i);
      if (at >= 0) arr.splice(at, 1); else arr.push(i);
      // إعادة حساب كل النتائج
      resultsOf(ex.id).forEach((r) => {
        const fresh = scoreAttempt({ answers: r.answers.map((o) => ({ option: o })), flags: r.flags, confidence: r.confidence, quality: r.quality, code: r.code }, ex, r.studentNumber);
        Object.assign(r, fresh);
      });
      save(); renderResults();
    };
  });
}

function exportCsv() {
  const ex = activeExam();
  const res = resultsOf(ex.id);
  if (!res.length) { toast('لا توجد نتائج للتصدير'); return; }
  const head = ['رقم الجلوس', 'الاسم', 'الدرجة', 'من', 'النسبة', ...ex.questions.map((_, i) => `س${i + 1}`)];
  const rows = res.map((r) => [r.studentNumber ?? '', r.name ?? '', r.score.toFixed(2), r.total, r.percent.toFixed(1),
    ...r.answers.map((a) => (a === null ? '' : a + 1))]);
  const csv = '\uFEFF' + [head, ...rows].map((r) => r.map((v) => `"${String(v).replace(/"/g, '""')}"`).join(',')).join('\r\n');
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }));
  a.download = `${ex.name}-results.csv`;
  a.click();
}

/* ================================================================== */
/* الإعدادات                                                           */
/* ================================================================== */
function renderSettings() {
  const s = state.settings;
  $('#inTHigh').value = s.tHigh; $('#vTHigh').textContent = s.tHigh.toFixed(2);
  $('#inTLight').value = s.tLight; $('#vTLight').textContent = s.tLight.toFixed(2);
  $('#inInk').value = s.inkRatio; $('#vInk').textContent = s.inkRatio.toFixed(2);
  $('#inNeg').checked = !!s.negative;
  $('#inPass').value = s.pass;
}

/* ================================================================== */
/* إنشاء اختبار                                                        */
/* ================================================================== */
function newExamDialog() {
  const name = prompt('اسم الاختبار:', 'اختبار جديد');
  if (!name) return;
  const gradeLabel = prompt('الصف / الشعبة:', 'الصف السابع / أ') || '';
  const countStr = prompt('عدد الأسئلة (1–40):', '12');
  const count = Math.max(1, Math.min(40, parseInt(countStr, 10) || 12));
  const mix = prompt('نوع الأسئلة: اكتب «دائرة» أو «نعم-لا» أو «مزيج»', 'مزيج') || 'مزيج';
  const optsStr = prompt('عدد خيارات أسئلة الدائرة (2–5):', '4');
  const options = Math.max(2, Math.min(5, parseInt(optsStr, 10) || 4));

  const kind = mix.includes('نعم') ? 'yesno' : (mix.includes('مزيج') ? 'mix' : 'choice');
  const questions = planQuestions({ count, kind, options });
  const serial = (state.exams.length + 3) % 32;
  const ex = {
    id: 'ex' + Date.now(), name, subject: '', gradeLabel, teacher: '', examDate: new Date().toISOString().slice(0, 10),
    serial, idDigits: 8, optionLabels: 'ar', questions, key: questions.map(() => null), createdAt: Date.now(),
  };
  const errs = validateSpec({ title: name, questions });
  if (errs.length) { toast(errs[0]); return; }
  state.exams.push(ex);
  state.activeId = ex.id;
  save();
  toast('تم إنشاء الاختبار — أدخل مفتاح الإجابة ثم اطبع الورقة');
  go('exam');
}

/* ================================================================== */
/* ربط الأحداث                                                         */
/* ================================================================== */
function bind() {
  $('#btnNewExam').onclick = newExamDialog;
  $('#btnSettings').onclick = () => go('settings');
  $('#btnBack').onclick = () => go(current === 'exam' ? 'home' : current === 'key' || current === 'sheet' ? 'exam' : 'home');
  $$('.tab').forEach((b) => (b.onclick = () => go(b.dataset.tab)));

  $$('[data-go]').forEach((b) => (b.onclick = () => go(b.dataset.go)));
  $('#btnSaveKey').onclick = () => { save(); toast('تم حفظ مفتاح الإجابة ✓'); go('exam'); };
  $('#btnScanKey').onclick = () => { startCamera(); toast('وجّه الكاميرا نحو «ورقة المفتاح»'); };
  $('#btnDemoKey').onclick = () => loadKeySheet().catch((e) => toast('تعذّر تحميل المفتاح: ' + e.message));

  $$('#sheetSeg .seg-btn').forEach((b) => (b.onclick = () => renderSheetScreen(b.dataset.role)));
  $('#btnPrint').onclick = () => printSheet($('#sheetCanvas'), activeExam().name);
  $('#btnDownload').onclick = () => downloadSheet(templateFor(activeExam(), sheetRole === 'key'), `${activeExam().name}-${sheetRole}.png`);

  $('#btnStartCam').onclick = () => ($('#btnStartCam').dataset.on ? stopCamera() : startCamera());
  $('#btnManual').onclick = () => {
    const f = grabFrame();
    if (!f) { toast('شغّل الكاميرا أولًا'); return; }
    const r = detectSheet(f.data, f.w, f.h, templateFor(activeExam()), opt());
    if (r.ok) capture(r); else toast(r.reason, 3000);
  };
  $('#btnTorch').onclick = async () => {
    const track = stream?.getVideoTracks?.()[0];
    if (!track) { toast('شغّل الكاميرا أولًا'); return; }
    try { torchOn = !torchOn; await track.applyConstraints({ advanced: [{ torch: torchOn }] }); }
    catch (e) { toast('هذا الجهاز لا يدعم إضاءة الكاميرا'); }
  };
  $('#btnFromFile').onclick = () => {
    const p = prompt('اكتب «تجريبي» لتصحيح 6 أوراق جاهزة، أو «ملفات» لاختيار صور من جهازك', 'تجريبي');
    if (!p) return;
    if (p.includes('تجريبي')) correctDemoSet().catch((e) => toast('خطأ: ' + e.message));
    else $('#fileInput').click();
  };
  $('#fileInput').onchange = async (ev) => {
    const files = Array.from(ev.target.files || []);
    if (!files.length) return;
    const srcs = await Promise.all(files.map((f) => new Promise((res) => {
      const fr = new FileReader();
      fr.onload = () => res(fr.result);
      fr.readAsDataURL(f);
    })));
    await correctBatch(srcs, files.map((f) => f.name));
  };
  $('#btnFinish').onclick = () => go('results');
  $('#btnExportCsv').onclick = exportCsv;
  $('#btnClearResults').onclick = () => {
    if (confirm('حذف كل نتائج هذا الاختبار؟')) { state.results[state.activeId] = []; save(); renderResults(); }
  };

  const bindRange = (id, key, out) => {
    $(id).oninput = (e) => {
      state.settings[key] = parseFloat(e.target.value);
      $(out).textContent = state.settings[key].toFixed(2);
      save();
    };
  };
  bindRange('#inTHigh', 'tHigh', '#vTHigh');
  bindRange('#inTLight', 'tLight', '#vTLight');
  bindRange('#inInk', 'inkRatio', '#vInk');
  $('#inNeg').onchange = (e) => { state.settings.negative = e.target.checked; save(); };
  $('#inPass').onchange = (e) => { state.settings.pass = parseInt(e.target.value, 10) || 60; save(); };
  $('#btnReset').onclick = () => { localStorage.removeItem(LS_KEY); location.reload(); };
}

/* ================================================================== */
/* الإقلاع                                                             */
/* ================================================================== */
(async function main() {
  bind();
  await ensureFonts();
  go('home');
  if (location.hash === '#scan') go('scan');
})();
