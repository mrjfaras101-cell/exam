/**
 * engine.js — محرّك قراءة أوراق الإجابة (OMR) — نسخة 1
 *
 * الخوارزمية (بلا تعلّم آلي، وبلا تبعيات):
 *   1) رمادي  →  2) تصحيح الإضاءة (قسمة على تقدير الخلفية)  →  3) عتبة Otsu
 *   4) مكوّنات متّصلة  →  5) اختيار علامات التسجيل الأربع (مربّعان مصمتان + حلقي)
 *   6) تجانس (Homography) بالمليمتر  →  7) فحوص الجودة
 *   8) أخذ عيّنات قرصية داخل كل فقاعة  →  9) قرار متعدّد العتبات + ثقة
 *
 * يعمل في المتصفح وفي Node (ESM خالص، بلا canvas ولا DOM).
 */

import { flattenBubbles } from './template.js';

/* ------------------------------------------------------------------ */
/* العتبات القابلة للمعايرة                                            */
/* ------------------------------------------------------------------ */
export const DEFAULTS = {
  maxWorkWidth: 1100,     // العرض الذي تُعالَج به الصورة (توازن دقة/سرعة)
  bgRadiusFactor: 0.045,  // نصف قطر تقدير الخلفية = النسبة × العرض
  inkRatio: 0.74,         // عتبة "حبر واضح"
  softInkRatio: 0.86,     // عتبة "أثر حبر باهت" (تظليل خفيف بالقلم)
  softMinContrast: 14,    // فرق أدنى عن بياض الورق لعدّ البكسل أثرًا         // ما دون هذه النسبة من بياض الورق المحلي = حبر (نسبي: يتحمّل القلم الرصاص والورق الرمادي)
  tHigh: 0.45,            // عتبة "إجابة مؤكّدة"
  tLight: 0.18,           // عتبة "تظليل خفيف/مشكوك"
  ringInner: 0.42,        // حدود حلقة العيّنة (كنسبة من نصف قطر الفقاعة)
  ringOuter: 0.70,        //   تتجنّب الحرف المطبوع في المركز والخط المطبوع عند الحافة
  codeThreshold: 0.42,    // عتبة قراءة بتات رمز الورقة
  minPxPerMm: 3.5,        // أقل دقة مقبولة (تحتاج 4+ بكسل/مم لشبكة رقم الجلوس)
  lowPxPerMm: 5.2,        // ما دونها: نسمح بالقراءة لكن نوسم الصورة "دقة منخفضة"
  maxGlareRatio: 0.30,    // فوقها: تحذير لمعان (لا يمنع القراءة)
  warnEdgeWidthMm: 1.0,   // فوقها: تحذير "صورة غير واضحة" (لا يمنع القراءة)
  failEdgeWidthMm: 2.4,   // فوقها: رفض (ضبابية شديدة)
  maxSideSkew: 0.35,      // أقصى انحراف لنسبة الأضلاع عن A4 النظري
  minPaperCoverage: 0.12, // أدنى نسبة مساحة الورقة من الصورة
  maxComponentArea: 0.03, // أقصى مساحة مكوّن (نسبة من الصورة) ليكون مرشّحًا لعلامة تسجيل
};

/* ------------------------------------------------------------------ */
/* 1) رمادي                                                            */
/* ------------------------------------------------------------------ */
export function toGray(rgba, w, h) {
  const g = new Uint8Array(w * h);
  for (let i = 0, p = 0; i < g.length; i++, p += 4) {
    // أوزان الإضاءة المعيارية (Y تقريبًا) مع تجاهل الشفافية
    g[i] = (rgba[p] * 77 + rgba[p + 1] * 150 + rgba[p + 2] * 29) >> 8;
  }
  return g;
}

/* ------------------------------------------------------------------ */
/* 2) تصحيح الإضاءة + تنعيم خفيف (بمصفوفة المجموع التراكمي)             */
/* ------------------------------------------------------------------ */
function integral(gray, w, h) {
  const I = new Float64Array((w + 1) * (h + 1));
  for (let y = 0; y < h; y++) {
    let rowSum = 0;
    const rowOff = (y + 1) * (w + 1);
    const prevOff = y * (w + 1);
    for (let x = 0; x < w; x++) {
      rowSum += gray[y * w + x];
      I[rowOff + x + 1] = I[prevOff + x + 1] + rowSum;
    }
  }
  return I;
}

function boxBlur(gray, w, h, radius) {
  const I = integral(gray, w, h);
  const out = new Float32Array(w * h);
  const r = radius | 0;
  for (let y = 0; y < h; y++) {
    const y0 = Math.max(0, y - r), y1 = Math.min(h - 1, y + r);
    for (let x = 0; x < w; x++) {
      const x0 = Math.max(0, x - r), x1 = Math.min(w - 1, x + r);
      const a = I[y0 * (w + 1) + x0];
      const b = I[y0 * (w + 1) + x1 + 1];
      const c = I[(y1 + 1) * (w + 1) + x0];
      const d = I[(y1 + 1) * (w + 1) + x1 + 1];
      const n = (x1 - x0 + 1) * (y1 - y0 + 1);
      out[y * w + x] = (a - b - c + d) / n;
    }
  }
  return out;
}

export function illuminationCorrect(gray, w, h, opts = DEFAULTS) {
  const radius = Math.max(6, Math.round(w * opts.bgRadiusFactor));
  const bg = boxBlur(gray, w, h, radius);
  const corrected = new Uint8Array(w * h);
  for (let i = 0; i < corrected.length; i++) {
    const b = bg[i];
    // لا نضخّم الضوضاء في المناطق السوداء جدًا (خارج الورقة)
    const v = b >= 60 ? (gray[i] * 255) / b : gray[i];
    corrected[i] = v > 255 ? 255 : v < 0 ? 0 : v;
  }
  return { corrected, bg, radius };
}

/* ------------------------------------------------------------------ */
/* 3) عتبة Otsu                                                        */
/* ------------------------------------------------------------------ */
export function otsu(gray) {
  const hist = new Float64Array(256);
  for (let i = 0; i < gray.length; i++) hist[gray[i]]++;
  const total = gray.length;
  let sum = 0;
  for (let i = 0; i < 256; i++) sum += i * hist[i];
  let sumB = 0, wB = 0, best = 0, thr = 128;
  for (let t = 0; t < 256; t++) {
    wB += hist[t];
    if (wB === 0) continue;
    const wF = total - wB;
    if (wF === 0) break;
    sumB += t * hist[t];
    const mB = sumB / wB, mF = (sum - sumB) / wF;
    const between = wB * wF * (mB - mF) * (mB - mF);
    if (between > best) { best = between; thr = t; }
  }
  return thr;
}

/* ------------------------------------------------------------------ */
/* 4) المكوّنات المتّصلة (8-اتصال)                                      */
/* ------------------------------------------------------------------ */
export function connectedComponents(mask, w, h, minArea = 12) {
  const label = new Int32Array(w * h).fill(-1);
  const comps = [];
  const stack = new Int32Array(w * h);
  for (let start = 0; start < mask.length; start++) {
    if (mask[start] === 0 || label[start] !== -1) continue;
    const id = comps.length;
    let sp = 0;
    stack[sp++] = start;
    label[start] = id;
    let area = 0, minX = w, maxX = -1, minY = h, maxY = -1, sumX = 0, sumY = 0;
    while (sp > 0) {
      const p = stack[--sp];
      const x = p % w, y = (p - x) / w;
      area++;
      if (x < minX) minX = x; if (x > maxX) maxX = x;
      if (y < minY) minY = y; if (y > maxY) maxY = y;
      sumX += x; sumY += y;
      for (let dy = -1; dy <= 1; dy++) {
        const ny = y + dy;
        if (ny < 0 || ny >= h) continue;
        for (let dx = -1; dx <= 1; dx++) {
          const nx = x + dx;
          if (nx < 0 || nx >= w) continue;
          if (dx === 0 && dy === 0) continue;
          const q = ny * w + nx;
          if (mask[q] !== 0 && label[q] === -1) { label[q] = id; stack[sp++] = q; }
        }
      }
    }
    if (area >= minArea) {
      const bw = maxX - minX + 1, bh = maxY - minY + 1;
      comps.push({
        id, area, minX, maxX, minY, maxY, bw, bh,
        fill: area / (bw * bh),
        cx: sumX / area, cy: sumY / area,
      });
    }
  }
  return comps;
}

/* ------------------------------------------------------------------ */
/* 5) إيجاد علامات التسجيل الأربع                                      */
/* ------------------------------------------------------------------ */
/**
 * هندسة الورقة تُقرأ من القالب نفسه (لا ثوابت A4 صلبة):
 *  - src: إحداثيات مراكز علامات التسجيل بالمليمتر بترتيب [TL, TR, BR, BL]
 *  - pitchX/pitchY: المسافة بين المراكز أفقيًا/رأسيًا (لحساب بكسل/مم)
 *  - fid[0..3]: كائنات العلامات (لقياس حِدّة الحواف)
 * بهذا يعمل المحرّك نفسه على أي مقاس ورقة (A4، نصف A4، أي قالب مستقبلي).
 */
function templateGeo(template) {
  const list = template && template.fiducials ? template.fiducials : null;
  if (!list || list.length < 4) return null;
  const byId = {};
  for (const f of list) byId[f.id] = f;
  const order = ['TL', 'TR', 'BR', 'BL'];
  const fid = order.map((id) => byId[id]);
  if (fid.some((f) => !f)) return null;
  const pitchX = Math.abs(fid[1].x - fid[0].x);
  const pitchY = Math.abs(fid[3].y - fid[0].y);
  if (!(pitchX > 10) || !(pitchY > 10)) return null;
  return {
    fid,
    src: fid.map((f) => [f.x, f.y]),
    pitchX, pitchY,
    size: fid[0].size || 10,
  };
}

/** مساحة shoelace الموجبة = دوران باتجاه عقارب الساعة في إحداثيات y-للأسفل.
 *  تقبل النقاط بصيغة [x,y] أو كائنات مكوّنات لها cx/cy. */
function shoelace(pts) {
  const p = pts.map((q) => (Array.isArray(q) ? q : [q.cx, q.cy]));
  let s = 0;
  for (let i = 0; i < p.length; i++) {
    const [x1, y1] = p[i], [x2, y2] = p[(i + 1) % p.length];
    s += x1 * y2 - x2 * y1;
  }
  return s / 2;
}

export function findFiducials(comps, mask, w, h, opts = DEFAULTS, gray = null, geo = null) {
  const imgArea = w * h;
  const cand = comps.filter((c) => {
    if (c.area > opts.maxComponentArea * imgArea) return false;
    if (c.area < Math.max(40, 0.00003 * imgArea)) return false;
    if (c.fill < 0.35) return false;                 // الحلقة قد يكون امتلاؤها ~0.45
    const ar = c.bw / c.bh;
    if (ar < 0.5 || ar > 2.0) return false;
    return true;
  }).sort((a, b) => b.area - a.area).slice(0, 18);

  if (cand.length < 4) return { ok: false, reason: 'لم أجد علامات التسجيل — تأكّد من ظهور أركان الورقة الأربعة' };
  if (!geo) return { ok: false, reason: 'قالب الورقة غير معروف — أعد توليد القالب' };

  const ideal = geo.pitchX / geo.pitchY;
  const src = geo.src;
  let best = null;

  for (let i = 0; i < cand.length; i++) {
    for (let j = i + 1; j < cand.length; j++) {
      for (let k = j + 1; k < cand.length; k++) {
        for (let l = k + 1; l < cand.length; l++) {
          const four = [cand[i], cand[j], cand[k], cand[l]];
          const A = four.reduce((a, b) => (a.cx + a.cy <= b.cx + b.cy ? a : b));   // أعلى-يمين الصورة
          const B = four.reduce((a, b) => (a.cx - a.cy >= b.cx - b.cy ? a : b));   // أعلى-يسار
          const C = four.reduce((a, b) => (a.cx + a.cy >= b.cx + b.cy ? a : b));   // أسفل-يسار
          const D = four.reduce((a, b) => (a.cx - a.cy <= b.cx - b.cy ? a : b));   // أسفل-يمين
          if (new Set([A, B, C, D]).size !== 4) continue;
          const quadArea = Math.abs(shoelace([A, B, C, D]));
          if (quadArea < opts.minPaperCoverage * imgArea) continue;
          // العلامات الأربع مطبوعة بنفس الحجم (10×10مم) — قيد حاسم لرفض "بقعة تظليل" تتسلّل كركن
          const sides = four.map((c) => (c.bw + c.bh) / 2);
          const meanSide = sides.reduce((a, b) => a + b, 0) / 4;
          if (sides.some((sd) => sd < meanSide * 0.62 || sd > meanSide * 1.6)) continue;
          const maxA = Math.max(...four.map((c) => c.area));
          if (four.some((c) => c.area < maxA * 0.42)) continue;   // الحلقة مساحتها ≈ 0.6 من المصمت

          const sTop = dist(A, B), sBottom = dist(D, C), sLeft = dist(A, D), sRight = dist(B, C);
          if (Math.min(sTop, sBottom, sLeft, sRight) <= 4) continue;
          const skew = Math.abs((sTop + sBottom) / (sLeft + sRight) - ideal) / ideal;
          if (skew > opts.maxSideSkew) continue;
          if (Math.abs(sTop - sBottom) / Math.max(sTop, sBottom) > 0.35) continue;
          if (Math.abs(sLeft - sRight) / Math.max(sLeft, sRight) > 0.35) continue;

          // ثلاثة فروض للاتجاه: مباشر، دوران 180°، صورة معكوسة (كاميرا أمامية)
          for (const asg of [[A, B, C, D], [C, D, A, B], [B, A, D, C]]) {
            const H = solveHomography(src, asg.map((q) => [q.cx, q.cy]));
            if (!H) continue;
            const app = probeAppearance(mask, w, h, H, geo);
            const score = quadArea * Math.pow(app, 2);     // تفضيل واضح للاتجاه المؤكّد
            if (!best || score > best.score) {
              best = { score, appearance: app, corners: asg, H, quadArea };
            }
          }
        }
      }
    }
  }
  if (!best) return { ok: false, reason: 'لم أتعرّف على الورقة — افرد الورقة وصوّر أركانها الأربعة' };
  if (best.appearance < 0.75) {
    return { ok: false, reason: 'لم أتأكّد من اتجاه الورقة — أعد التصوير مع ظهور المربعات الأربعة كاملة' };
  }

  let [TL, TR, BR, BL] = best.corners;
  let H = best.H;
  let appearance = best.appearance;
  // تحسين مراكز العلامات وإعادة حساب التجانس (يرفع دقة رسم الفقاعات على الورقة)
  if (gray) {
    const pxPerMm0 = Math.hypot(TL.cx - TR.cx, TL.cy - TR.cy) / geo.pitchX;
    if (pxPerMm0 > 2) {
      const refined = [TL, TR, BR, BL].map((c) => {
        const [nx, ny] = refineCenter(gray, w, h, c.cx, c.cy, c.kind === 'ring' ? 5.0 : 6.0, pxPerMm0);
        return { ...c, cx: nx, cy: ny };
      });
      const H2 = solveHomography(geo.src, refined.map((c) => [c.cx, c.cy]));
      if (H2) {
        const app2 = probeAppearance(mask, w, h, H2, geo);
        if (app2 >= appearance - 0.08) { H = H2; appearance = app2; [TL, TR, BR, BL] = refined; }
      }
    }
  }
  return {
    ok: true, corners: [TL, TR, BR, BL], homography: H,
    appearance: Math.round(appearance * 100) / 100,
    // مساحة سالبة = صورة معكوسة أفقيًا (كاميرا أمامية بمرآة)
    mirrored: shoelace([[TL.cx, TL.cy], [TR.cx, TR.cy], [BR.cx, BR.cy], [BL.cx, BL.cy]]) < 0,
  };
}

/**
 * يفحص مظهر العلامات الأربع عند إحداثيات الورقة المعروفة:
 * ثلاثة مربعات مصمتة (مركز أسود) + مربع حلقي (مركز أبيض وحلقة سوداء).
 * هذا هو الفحص الذي يحدّد الاتجاه الصحيح للورقة ويرفض الأركان الخاطئة.
 */
function probeAppearance(mask, w, h, H, geo) {
  const darkRatioIn = (mmX, mmY, rMm) => {
    const [cx, cy] = applyH(H, mmX, mmY);
    const [ex, ey] = applyH(H, mmX + 1, mmY);
    const sc = Math.hypot(ex - cx, ey - cy);            // بكسل لكل مم
    const rad = Math.max(1.0, rMm * sc);
    let dark = 0, total = 0;
    for (let y = Math.floor(cy - rad); y <= Math.ceil(cy + rad); y++) {
      for (let x = Math.floor(cx - rad); x <= Math.ceil(cx + rad); x++) {
        if (x < 0 || y < 0 || x >= w || y >= h) continue;
        const dx = x - cx, dy = y - cy;
        if (dx * dx + dy * dy > rad * rad) continue;
        total++;
        if (mask[y * w + x]) dark++;
      }
    }
    return total ? dark / total : 0;
  };
  const solid = (x, y) => darkRatioIn(x, y, 2.4);                    // مركز المربع المصمت
  const ring = (x, y) => {
    const innerWhite = 1 - darkRatioIn(x, y, 1.3);                   // الفراغ الأبيض
    const inBand = darkRatioIn(x, y, 3.0) - darkRatioIn(x, y, 2.2);  // الحلقة السوداء (فرق قرصين)
    return Math.max(0, Math.min(1, innerWhite)) * Math.max(0, Math.min(1, inBand * 2.2));
  };
  const pos = geo.src;                                  // [TL, TR, BR, BL]
  const probes = [
    solid(pos[0][0], pos[0][1]), solid(pos[1][0], pos[1][1]),
    solid(pos[3][0], pos[3][1]), ring(pos[2][0], pos[2][1]),
  ];
  return probes.reduce((s, v) => s + v, 0) / probes.length;
}

const dist = (a, b) => Math.hypot(a.cx - b.cx, a.cy - b.cy);

/**
 * تحسين دقيق لمركز علامة التسجيل: عتبة محلية نسبية + مركز ثقل (centroid).
 * يقلّل انحياز العتبة العالمية الناتج عن تصحيح الإضاءة والظلال.
 */
function refineCenter(img, w, h, cx, cy, winMm, pxPerMm, iters = 3) {
  for (let it = 0; it < iters; it++) {
    const half = Math.max(6, Math.round(winMm * pxPerMm));
    const x0 = Math.max(0, Math.floor(cx - half)), x1 = Math.min(w - 1, Math.ceil(cx + half));
    const y0 = Math.max(0, Math.floor(cy - half)), y1 = Math.min(h - 1, Math.ceil(cy + half));
    const vals = [];
    for (let y = y0; y <= y1; y += 2) for (let x = x0; x <= x1; x += 2) vals.push(img[y * w + x]);
    if (vals.length < 20) return [cx, cy];
    const lo = percentile(vals, 5), hi = percentile(vals, 95);
    if (hi - lo < 20) return [cx, cy];
    const thr = lo + 0.5 * (hi - lo);
    let sx = 0, sy = 0, n = 0;
    for (let y = y0; y <= y1; y++) {
      for (let x = x0; x <= x1; x++) {
        if (img[y * w + x] < thr) { sx += x; sy += y; n++; }
      }
    }
    if (n < 20) return [cx, cy];
    const nx = sx / n, ny = sy / n;
    if (Math.hypot(nx - cx, ny - cy) < 0.3) { cx = nx; cy = ny; break; }
    cx = nx; cy = ny;
  }
  return [cx, cy];
}

/* ------------------------------------------------------------------ */
/* 6) التجانس (Homography)                                             */
/* ------------------------------------------------------------------ */
function solveLinear(A, b) {
  const n = b.length;
  for (let col = 0; col < n; col++) {
    let piv = col;
    for (let r = col + 1; r < n; r++) if (Math.abs(A[r][col]) > Math.abs(A[piv][col])) piv = r;
    if (Math.abs(A[piv][col]) < 1e-12) return null;
    if (piv !== col) {
      [A[piv], A[col]] = [A[col], A[piv]];
      [b[piv], b[col]] = [b[col], b[piv]];
    }
    const d = A[col][col];
    for (let c = col; c < n; c++) A[col][c] /= d;
    b[col] /= d;
    for (let r = 0; r < n; r++) {
      if (r === col) continue;
      const f = A[r][col];
      if (f === 0) continue;
      for (let c = col; c < n; c++) A[r][c] -= f * A[col][c];
      b[r] -= f * b[col];
    }
  }
  return b;
}

export function solveHomography(src, dst) {
  const A = [], b = [];
  for (let i = 0; i < 4; i++) {
    const [x, y] = src[i], u = dst[i][0], v = dst[i][1];
    A.push([x, y, 1, 0, 0, 0, -x * u, -y * u]); b.push(u);
    A.push([0, 0, 0, x, y, 1, -x * v, -y * v]); b.push(v);
  }
  const h = solveLinear(A, b);
  if (!h) return null;
  return [h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7], 1];
}

export function applyH(H, x, y) {
  const d = H[6] * x + H[7] * y + H[8];
  return [(H[0] * x + H[1] * y + H[2]) / d, (H[3] * x + H[4] * y + H[5]) / d];
}

/* ------------------------------------------------------------------ */
/* 7) فحوص الجودة                                                      */
/* ------------------------------------------------------------------ */
function percentile(arr, p) {
  const a = Float32Array.from(arr).sort();
  const idx = Math.min(a.length - 1, Math.max(0, Math.round((p / 100) * (a.length - 1))));
  return a[idx];
}

function laplacianVariance(gray, w, h, x0, y0, x1, y1, step = 2) {
  const vals = [];
  for (let y = y0 + 1; y < y1 - 1; y += step) {
    for (let x = x0 + 1; x < x1 - 1; x += step) {
      const c = gray[y * w + x];
      const l = 4 * c - gray[(y - 1) * w + x] - gray[(y + 1) * w + x] - gray[y * w + x - 1] - gray[y * w + x + 1];
      vals.push(l);
    }
  }
  if (vals.length < 10) return 0;
  let m = 0;
  for (const v of vals) m += v;
  m /= vals.length;
  let s2 = 0;
  for (const v of vals) s2 += (v - m) * (v - m);
  return s2 / vals.length;
}

/**
 * قياس "حِدّة" الصورة بمقياس مرتبط بالمهمّة: عرض الانتقال بين الحبر والورق
 * على حافة مربّع التسجيل (بالمليمتر). المطلوب: ≤ 0.8مم لتُقرأ فقاعات القطر 3.8مم.
 */
function measureEdgeWidthMm(corrected, w, h, H, pxPerMm, opts, geo) {
  const widths = [];
  const f0 = geo.fid[0];
  const cxMm = f0.x, cyMm = f0.y, size = f0.size || 10;
  for (const dy of [-0.25, 0, 0.25]) {
    const yMm = cyMm + dy * size;
    const p0 = applyH(H, cxMm - size / 2 - 2.5, yMm);
    const p1 = applyH(H, cxMm + size / 2 + 2.5, yMm);
    const n = Math.max(12, Math.round(Math.hypot(p1[0] - p0[0], p1[1] - p0[1])));
    const vals = new Float64Array(n);
    for (let i = 0; i < n; i++) {
      const t = i / (n - 1);
      const x = Math.round(p0[0] + (p1[0] - p0[0]) * t);
      const y = Math.round(p0[1] + (p1[1] - p0[1]) * t);
      vals[i] = (x >= 0 && y >= 0 && x < w && y < h) ? corrected[y * w + x] : 255;
    }
    const hi = percentile(vals, 92), lo = percentile(vals, 8);
    if (hi - lo < 25) continue;                       // تباين ضعيف جدًا
    const tDark = lo + 0.1 * (hi - lo);               // داخل الحبر
    const tLight = lo + 0.9 * (hi - lo);              // ورق أبيض
    const sampleMm = Math.hypot(p1[0] - p0[0], p1[1] - p0[1]) / (n - 1) / pxPerMm;
    // حافة الهبوط: من مستوى الورق (0.9) إلى مستوى الحبر (0.1)
    let iA = -1, iB = -1;
    for (let i = 0; i < n; i++) if (vals[i] <= tLight) { iA = i; break; }
    if (iA >= 0) for (let i = iA; i < n; i++) if (vals[i] <= tDark) { iB = i; break; }
    if (iA >= 0 && iB >= 0) widths.push((iB - iA + 1) * sampleMm);
    // حافة الصعود: من الحبر (0.1) إلى الورق (0.9)
    let iC = -1, iD = -1;
    if (iB >= 0) {
      for (let i = iB; i < n; i++) if (vals[i] >= tLight) { iC = i; break; }
      if (iC >= 0) for (let i = iC; i >= iB; i--) if (vals[i] <= tDark) { iD = i; break; }
      if (iC >= 0 && iD >= 0) widths.push((iC - iD + 1) * sampleMm);
    }
  }
  if (!widths.length) return 99;
  widths.sort((a, b) => a - b);
  return widths[Math.floor(widths.length / 2)];
}

/* ------------------------------------------------------------------ */
/* 8) أخذ العيّنات                                                     */
/* ------------------------------------------------------------------ */
function sampleBubble(corrected, rawGray, w, h, H, bubble, whiteRef, opts) {
  const [cx, cy] = applyH(H, bubble.x, bubble.y);
  const [ex, ey] = applyH(H, bubble.x + 1, bubble.y);
  const [fx, fy] = applyH(H, bubble.x, bubble.y + 1);
  const sx = Math.hypot(ex - cx, ey - cy);
  const sy = Math.hypot(fx - cx, fy - cy);
  const scale = Math.max(0.05, (sx + sy) / 2);           // بكسل لكل مم
  const rUnit = Math.max(0.6, bubble.r * scale);         // نصف قطر الفقاعة بالبكسل
  let rIn = rUnit * opts.ringInner;
  let rOut = rUnit * opts.ringOuter;
  if (rOut - rIn < 1.2) {                                // فقاعة صغيرة جدًا: قرص متوسط
    const rm = (rIn + rOut) / 2;
    rIn = Math.max(0, rm - 0.6); rOut = rm + 0.6;
  }
  const rIn2 = rIn * rIn, rOut2 = rOut * rOut;

  const x0 = Math.max(0, Math.floor(cx - rOut)), x1 = Math.min(w - 1, Math.ceil(cx + rOut));
  const y0 = Math.max(0, Math.floor(cy - rOut)), y1 = Math.min(h - 1, Math.ceil(cy + rOut));
  const outer = [];                                      // بكسل الحلقة الخارجية = بياض الورق محليًا
  let total = 0, sum = 0, glare = 0;
  const vals = [];                                       // بكسل حلقة العيّنة
  const wIn0 = rUnit * 1.2, wOut0 = rUnit * 1.5;   // خارج الدائرة المطبوعة (لا تدخل الخط المطبوع)
  for (let y = y0; y <= y1 + Math.ceil(wOut0 - rOut); y++) {
    for (let x = x0; x <= x1 + Math.ceil(wOut0 - rOut); x++) {
      if (x < 0 || y < 0 || x >= w || y >= h) continue;
      const dx = x - cx, dy = y - cy;
      const d2 = dx * dx + dy * dy;
      const i = y * w + x;
      if (d2 <= rOut2 && d2 >= rIn2) { total++; vals.push(corrected[i]); sum += corrected[i]; if (rawGray[i] > 244) glare++; }
      else if (d2 > wIn0 * wIn0 && d2 <= wOut0 * wOut0) outer.push(corrected[i]);
    }
  }
  if (total === 0) return { fill: 0, glare: 0, meanInk: 0, scale, x: cx, y: cy, total: 0 };
  // البياض المحلي: المئين 75 للحلقة الخارجية (لا يتأثر بالفقاعة نفسها ولا بالجيرة المظلّلة)
  const localWhite = outer.length >= 6 ? percentile(outer, 75) : whiteRef;
  const inkThr = Math.max(0.45 * whiteRef, Math.min(whiteRef, localWhite) * opts.inkRatio);
  const softThr = Math.min(localWhite - opts.softMinContrast, localWhite * opts.softInkRatio);
  let dark = 0, soft = 0;
  for (const v of vals) { if (v < inkThr) dark++; if (v < softThr) soft++; }
  const fill = dark / total;
  const fillSoft = soft / total;
  return {
    fill,
    fillSoft,
    glare: glare / total,
    meanInk: 1 - (sum / total) / Math.max(1, localWhite),
    localWhite, inkThr, scale, x: cx, y: cy, total,
  };
}

/* ------------------------------------------------------------------ */
/* 9) القراءة الكاملة                                                  */
/* ------------------------------------------------------------------ */
/**
 * @param {Uint8ClampedArray|Uint8Array} rgba بيانات RGBA (طولها w*h*4)
 * @param {number} w
 * @param {number} h
 * @param {object} template القالب من buildTemplate
 * @param {object} opts عتبات (DEFAULTS)
 * @param {object} mode  { expectKey: boolean } لقراءة ورقة مفتاح أو طالب
 */
export function detectSheet(rgba, w, h, template, opts = DEFAULTS, mode = {}) {
  const t0 = Date.now();
  const diag = { stage: 'start', timings: {} };
  const fail = (reason, extra = {}) => ({
    ok: false, reason, ...extra, diag,
  });

  /* 1-2) رمادي + تصحيح إضاءة */
  const gray = toGray(rgba, w, h);
  const { corrected } = illuminationCorrect(gray, w, h, opts);
  diag.timings.gray = Date.now() - t0;

  /* 3) عتبة */
  const thr = otsu(corrected);
  const mask = new Uint8Array(w * h);
  for (let i = 0; i < mask.length; i++) mask[i] = corrected[i] < thr ? 1 : 0;
  diag.otsuThreshold = thr;

  /* 4) مكوّنات متّصلة */
  const geo = templateGeo(template);
  if (!geo) return fail('قالب الورقة غير معروف — أعد توليد القالب (fiducials ناقصة)');
  const comps = connectedComponents(mask, w, h, 14);
  diag.components = comps.length;
  diag.timings.components = Date.now() - t0;

  /* 5) علامات التسجيل */
  const fid = findFiducials(comps, mask, w, h, opts, gray, geo);
  if (!fid.ok) return fail(fid.reason, { quality: {} });
  const [TL, TR, BR, BL] = fid.corners;
  diag.timings.fiducials = Date.now() - t0;

  /* 6) التجانس: مليمتر الورقة → بكسل الصورة (محسوب داخل findFiducials) */
  const H = fid.homography;
  const dst = [[TL.cx, TL.cy], [TR.cx, TR.cy], [BR.cx, BR.cy], [BL.cx, BL.cy]];
  if (!H) return fail('تعذّر حساب التجانس — أعد التقاط الصورة');

  /* 7) فحوص الجودة */
  const cornersPx = dst;
  const dTop = Math.hypot(cornersPx[0][0] - cornersPx[1][0], cornersPx[0][1] - cornersPx[1][1]);
  const dLeft = Math.hypot(cornersPx[0][0] - cornersPx[3][0], cornersPx[0][1] - cornersPx[3][1]);
  const pxPerMm = (dTop / geo.pitchX + dLeft / geo.pitchY) / 2;
  const bbox = {
    x0: Math.max(0, Math.floor(Math.min(...cornersPx.map((p) => p[0])))),
    x1: Math.min(w - 1, Math.ceil(Math.max(...cornersPx.map((p) => p[0])))),
    y0: Math.max(0, Math.floor(Math.min(...cornersPx.map((p) => p[1])))),
    y1: Math.min(h - 1, Math.ceil(Math.max(...cornersPx.map((p) => p[1])))),
  };
  const sharpness = laplacianVariance(gray, w, h, bbox.x0, bbox.y0, bbox.x1, bbox.y1, 2);
  const edgeWidthMm = measureEdgeWidthMm(corrected, w, h, H, pxPerMm, opts, geo);
  const quadArea = Math.abs(shoelace(cornersPx));
  const coverage = quadArea / (w * h);

  // مستوى البياض داخل الورقة (المئين 90 للمنطقة المصحّحة)
  const bgSamples = [];
  const stepX = Math.max(1, Math.floor((bbox.x1 - bbox.x0) / 120));
  const stepY = Math.max(1, Math.floor((bbox.y1 - bbox.y0) / 120));
  for (let y = bbox.y0; y <= bbox.y1; y += stepY)
    for (let x = bbox.x0; x <= bbox.x1; x += stepX) bgSamples.push(corrected[y * w + x]);
  const whiteRef = bgSamples.length ? percentile(bgSamples, 90) : 255;

  // نسبة اللمعان داخل الورقة
  let glarePx = 0, glareTotal = 0;
  for (let y = bbox.y0; y <= bbox.y1; y += 2) {
    for (let x = bbox.x0; x <= bbox.x1; x += 2) {
      const i = y * w + x;
      const [ux, uy] = [x, y];
      // داخل حدود الورقة فقط (تقريب: داخل مربّع الأركان)
      if (ux < bbox.x0 || ux > bbox.x1 || uy < bbox.y0 || uy > bbox.y1) continue;
      glareTotal++;
      if (gray[i] >= 252) glarePx++;
    }
  }
  const glareRatio = glareTotal ? glarePx / glareTotal : 0;

  const quality = {
    pxPerMm: Math.round(pxPerMm * 10) / 10,
    sharpness: Math.round(sharpness),
    edgeWidthMm: Math.round(edgeWidthMm * 100) / 100,
    coverage: Math.round(coverage * 100) / 100,
    whiteRef: Math.round(whiteRef),
    glareRatio: Math.round(glareRatio * 100) / 100,
    otsu: thr,
  };
  diag.quality = quality;
  diag.timings.quality = Date.now() - t0;

  if (pxPerMm < opts.minPxPerMm) return fail(`الدقة منخفضة (${quality.pxPerMm} بكسل/مم) — قرّب الكاميرا من الورقة`, { quality });
  if (edgeWidthMm > opts.failEdgeWidthMm) return fail('الصورة غير واضحة (اهتزاز/بعُد) — ثبّت يدك وأعد المحاولة', { quality });
  if (coverage < opts.minPaperCoverage) return fail('الورقة صغيرة في الإطار — املأ الإطار بالورقة', { quality });

  /* 8) أخذ العيّنات لكل الفقاعات */
  const flat = flattenBubbles(template);
  const samples = flat.map((b) => ({ b, s: sampleBubble(corrected, gray, w, h, H, b, whiteRef, opts) }));
  diag.timings.samples = Date.now() - t0;

  /* 9أ) رمز الورقة */
  const codeBits = [];
  for (const { b, s } of samples) {
    if (b.group !== 'code') continue;
    codeBits.push({ bit: b.bit, fill: s.fill, on: s.fill >= opts.codeThreshold, x: s.x, y: s.y });
  }
  codeBits.sort((a, b) => a.bit - b.bit);
  let codeVal = 0;
  for (const cb of codeBits) if (cb.on) codeVal |= (1 << cb.bit);
  const serial = codeVal & ((1 << (template.code.bits ?? 5)) - 1);   // رقم الاختبار فقط (بلا بتّة المفتاح)
  const isKeySheet = ((codeVal >> 5) & 1) === 1;
  const codeMargin = codeBits.length
    ? Math.min(...codeBits.map((cb) => Math.abs(cb.fill - opts.codeThreshold)))
    : 0;

  /* 9ب) رقم الجلوس */
  const digits = [];
  const digitIssues = [];
  const digitFills = [];
  for (let col = 0; col < template.digitGrid.cols; col++) {
    const colSamples = samples.filter(({ b }) => b.group === 'digit' && b.col === col);
    const fillsCol = new Array(template.digitGrid.rows).fill(0);
    for (const { b, s } of colSamples) fillsCol[b.row] = Math.round(s.fill * 100) / 100;
    digitFills.push(fillsCol);
    const marked = colSamples.filter(({ s }) => s.fill >= opts.tHigh);
    if (marked.length === 1) {
      digits.push({ col, digit: marked[0].b.digit, fill: marked[0].s.fill, status: 'ok' });
    } else {
      digits.push({ col, digit: null, fill: marked.length ? Math.max(...marked.map((m) => m.s.fill)) : 0, status: marked.length ? 'ambiguous' : 'empty' });
      digitIssues.push(col);
    }
  }

  /* 9ج) الإجابات */
  const answers = [];
  const flags = [];
  for (const q of template.questions) {
    const qs = samples.filter(({ b }) => b.group === 'question' && b.qIndex === q.index);
    const sorted = [...qs].sort((a, b) => b.s.fill - a.s.fill);
    const top = sorted[0];
    const second = sorted[1];
    const anyHigh = sorted.filter(({ s }) => s.fill >= opts.tHigh);
    const anyGlare = qs.some(({ s }) => s.glare > 0.5 && s.fill < opts.tHigh);
    let status = 'ok', chosen = null, reason = null;
    if (anyHigh.length === 0) {
      const softMarks = sorted.filter(({ s }) => s.fillSoft >= 0.45 && s.meanInk >= 0.05);
      if (top.s.fill >= opts.tLight) { status = 'light'; chosen = top.b.option; reason = 'تظليل خفيف'; }
      else if (softMarks.length === 1) { status = 'light'; chosen = softMarks[0].b.option; reason = 'تظليل باهت'; }
      else if (softMarks.length > 1) { status = 'ambiguous'; reason = 'أثر تظليل على أكثر من دائرة'; }
      else { status = 'blank'; chosen = null; reason = 'لم يُظلَّل'; }
    } else if (anyHigh.length === 1) {
      chosen = anyHigh[0].b.option;
      const margin = anyHigh[0].s.fill - (second ? second.s.fill : 0);
      if (margin < 0.12) { status = 'ambiguous'; reason = 'تظليل غير واضح'; }
    } else {
      status = 'ambiguous'; reason = 'أكثر من دائرة مظلّلة'; chosen = null;
    }
    if (anyGlare && status !== 'ok') reason = (reason ? reason + ' + ' : '') + 'لمعان على الفقاعة';
    const rec = {
      index: q.index, type: q.type, option: chosen, status, reason,
      fill: Math.round(top.s.fill * 100) / 100,
      fillSofts: qs.slice().sort((a, b) => a.b.option - b.b.option).map((x) => Math.round(x.s.fillSoft * 100) / 100),
      debug: qs.slice().sort((a, b) => a.b.option - b.b.option).map((x) => ({ lw: Math.round(x.s.localWhite), thr: Math.round(x.s.inkThr), mean: Math.round((1 - x.s.meanInk) * x.s.localWhite), n: x.s.total })),
      fills: qs.sort((a, b) => a.b.option - b.b.option).map(({ s }) => Math.round(s.fill * 100) / 100),
      bubbles: qs.map(({ b, s }) => ({ option: b.option, x: s.x, y: s.y })),
    };
    answers.push(rec);
    if (status !== 'ok') flags.push({ index: q.index, status, reason });
  }

  if (glareRatio > opts.maxGlareRatio) flags.push({ index: -2, status: 'glare', reason: 'لمعان قوي على الورقة — غيّر زاوية الإضاءة' });
  if (edgeWidthMm > opts.warnEdgeWidthMm) flags.push({ index: -3, status: 'blurry', reason: 'الصورة غير واضحة قليلًا — ثبّت يدك أو قرّب الكاميرا' });
  const lowRes = pxPerMm < opts.lowPxPerMm;
  if (lowRes) flags.push({ index: -1, status: 'lowres', reason: 'دقة كاميرا منخفضة (قرّب الكاميرا) — تحقّق من رقم الجلوس' });
  const weakCount = answers.filter((a) => a.status !== 'ok').length;
  const confidence = Math.max(0, Math.min(1, 1 - weakCount / Math.max(1, answers.length)));

  diag.timings.total = Date.now() - t0;
  diag.stage = 'done';

  return {
    ok: true,
    code: { value: codeVal, serial, isKeySheet, bits: codeBits, margin: Math.round(codeMargin * 100) / 100 },
    digits: digits.map((d) => d.digit),
    digitStatus: digits,
    digitIssues,
    digitFills,
    answers,
    flags,
    weakCount,
    confidence: Math.round(confidence * 100) / 100,
    quality,
    mirrored: !!fid.mirrored,
    orientationScore: Math.round((fid.appearance || 0) * 100) / 100,
    lowRes,
    homography: H,
    corners: dst,
    diag,
  };
}

/** تركيب رقم الجلوس من الأرقام المقروءة (null إن كان هناك عمود غير مقروء) */
export function composeNumber(digitList) {
  if (digitList.some((d) => d === null || d === undefined)) return null;
  return parseInt(digitList.join(''), 10);
}
