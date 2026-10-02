# توليد أوراق إجابة مصطنعة "مصوّرة بالجوال" لاختبار محرّك القراءة.
# يستخدم نفس القالب الهندسي الذي يستخدمه التطبيق (يُصدّره dump_template.mjs)
# حتى لا يختلف ما يُختبر عمّا سيُطبع فعليًا.
#
# التشغيل:
#   node demo/test/dump_template.mjs            # يكتب out/template.json
#   .venv/bin/python demo/test/gen_scans.py     # يولّد الأوراق
import json
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out')
FONTS = os.path.join(HERE, '..', 'assets', 'fonts')

PPMM = 8.0          # بكسل لكل مم في الرسم المسطّح
TEMPLATE_PATH = os.path.join(OUT, 'template.json')

# مقاس الورقة يُقرأ من القالب نفسه (يعمل مع A4 أو نصف A4 أو أي قالب مستقبلي)
if os.path.exists(TEMPLATE_PATH):
    with open(TEMPLATE_PATH, encoding='utf-8') as _f:
        _TPL_HEAD = json.load(_f)
    PAGE_W = _TPL_HEAD['paper']['w']
    PAGE_H = _TPL_HEAD['paper']['h']
else:
    PAGE_W, PAGE_H = 148.5, 210   # الافتراضي: نصف ورقة A4 (A5 طولي)
FLAT_W, FLAT_H = int(PAGE_W * PPMM), int(PAGE_H * PPMM)


def template_fiducial_centers(tpl):
    """مراكز علامات التسجيل بترتيب محرّك الكشف: [TL, TR, BR, BL]."""
    by_id = {f['id']: f for f in tpl['fiducials']}
    return [(by_id[k]['x'], by_id[k]['y']) for k in ('TL', 'TR', 'BR', 'BL')]


# ------------------------------------------------------------------ #
# أدوات هندسية                                                        #
# ------------------------------------------------------------------ #
def homography(src, dst):
    """مصفوفة 3×3 تحوّل src → dst (أربع نقاط)."""
    A, b = [], []
    for (x, y), (u, v) in zip(src, dst):
        A.append([x, y, 1, 0, 0, 0, -x * u, -y * u]); b.append(u)
        A.append([0, 0, 0, x, y, 1, -x * v, -y * v]); b.append(v)
    h = np.linalg.solve(np.array(A, dtype=float), np.array(b, dtype=float))
    return np.array([[h[0], h[1], h[2]], [h[3], h[4], h[5]], [h[6], h[7], 1.0]])


# ------------------------------------------------------------------ #
# رسم الورقة المسطّحة                                                 #
# ------------------------------------------------------------------ #
class SheetRenderer:
    def __init__(self, tpl):
        self.t = tpl
        self.img = Image.new('L', (FLAT_W, FLAT_H), 255)
        self.d = ImageDraw.Draw(self.img)
        self.font_reg = ImageFont.truetype(os.path.join(FONTS, 'Cairo-Regular.ttf'), 30)
        self.font_bold = ImageFont.truetype(os.path.join(FONTS, 'Cairo-Bold.ttf'), 42)
        self.font_small = ImageFont.truetype(os.path.join(FONTS, 'Cairo-Regular.ttf'), 24)
        self.font_tiny = ImageFont.truetype(os.path.join(FONTS, 'Cairo-Regular.ttf'), 17)
        self.font_digit = ImageFont.truetype(os.path.join(FONTS, 'Cairo-Regular.ttf'), 11)
        self.font_bubble = ImageFont.truetype(os.path.join(FONTS, 'Cairo-Regular.ttf'), 17)

    def mm(self, v):
        return v * PPMM

    _font_cache = {}

    def font_cached(self, px):
        """خط بحجم بكسل محدّد مع تخزين مؤقت (تُقاس أحجام الخطوط من نصف قطر الفقاعة)."""
        px = int(px)
        if px not in self._font_cache:
            self._font_cache[px] = ImageFont.truetype(
                os.path.join(FONTS, 'Cairo-Regular.ttf'), px)
        return self._font_cache[px]

    def draw_all(self):
        self.draw_fiducials()
        self.draw_code()
        self.draw_id_grid()
        self.draw_header_text()
        self.draw_questions()
        return self.img

    def draw_fiducials(self):
        for f in self.t['fiducials']:
            half = f['size'] / 2
            self.d.rectangle(
                [self.mm(f['x'] - half), self.mm(f['y'] - half),
                 self.mm(f['x'] + half), self.mm(f['y'] + half)],
                fill=0)
            if f['kind'] == 'ring':
                h = f['hole'] / 2
                self.d.rectangle(
                    [self.mm(f['x'] - h), self.mm(f['y'] - h),
                     self.mm(f['x'] + h), self.mm(f['y'] + h)],
                    fill=255)

    def draw_code(self):
        for b in self.t['code']['bubbles']:
            box = [self.mm(b['x'] - b['r']), self.mm(b['y'] - b['r']),
                   self.mm(b['x'] + b['r']), self.mm(b['y'] + b['r'])]
            if b['printed']:
                self.d.ellipse(box, fill=0)
            else:
                self.d.ellipse(box, outline=0, width=3)

    def draw_id_grid(self):
        for box in self.t['digitGrid'].get('boxes', []):
            self.d.rectangle([self.mm(box['x']), self.mm(box['y']),
                              self.mm(box['x'] + box['w']), self.mm(box['y'] + box['h'])],
                             outline=0, width=3)
        for b in self.t['digitGrid']['bubbles']:
            box = [self.mm(b['x'] - b['r']), self.mm(b['y'] - b['r']),
                   self.mm(b['x'] + b['r']), self.mm(b['y'] + b['r'])]
            self.d.ellipse(box, outline=0, width=2)
            self.d.text((self.mm(b['x']), self.mm(b['y'])), str(b['digit']),
                        font=self.font_digit, fill=95, anchor='mm')

    def draw_header_text(self):
        t = self.t
        m = t['meta']
        g = t['layout']
        right = 130.5      # حافة كتلة العنوان (يمينًا)
        cx = t['paper']['w'] / 2
        # العنوان (يمين كتلة العنوان)
        self.d.text((self.mm(right), self.mm(26)), m['title'], font=self.font_bold, fill=0, anchor='ra')
        line2 = f"{m['subject']}  —  {m['gradeLabel']}"
        self.d.text((self.mm(right), self.mm(33.5)), line2, font=self.font_reg, fill=0, anchor='ra')
        line3 = f"التاريخ: {m['examDate']}    المعلم: {m['teacher']}"
        self.d.text((self.mm(right), self.mm(38.5)), line3, font=self.font_small, fill=0, anchor='ra')
        # رمز الورقة (الفقاعات مرسومة في draw_code) + عنوانه يسار الفقاعات
        self.d.text((self.mm(100), self.mm(46.2)), m['texts']['codeCaption'], font=self.font_tiny, fill=50, anchor='rm')
        for i, txt in enumerate(m['texts']['instructions'][:3]):
            self.d.text((self.mm(right), self.mm(55.5 + i * 4.5)), txt, font=self.font_tiny, fill=50, anchor='ra')
        # خط الفصل بين الترويسة والأسئلة
        self.d.line([self.mm(18), self.mm(70.5), self.mm(130.5), self.mm(70.5)], fill=120, width=2)
        # رقم الجلوس
        self.d.text((self.mm(70), self.mm(21)), m['texts']['idCaption'], font=self.font_small, fill=0, anchor='ra')
        self.d.text((self.mm(18), self.mm(68)), m['texts']['idHint'], font=self.font_digit, fill=60, anchor='ls')
        # تذييل
        self.d.text((self.mm(cx), self.mm(192)), m['texts']['footer'], font=self.font_tiny, fill=70, anchor='ma')

    def draw_questions(self):
        for q in self.t['questions']:
            nb = q['numberBox']
            self.d.rectangle([self.mm(nb['x']), self.mm(nb['y']),
                              self.mm(nb['x'] + nb['w']), self.mm(nb['y'] + nb['h'])],
                             outline=140, width=2)
            cx = self.mm(nb['x'] + nb['w'] / 2)
            cy = self.mm(nb['y'] + nb['h'] / 2)
            self.d.text((cx, cy), str(q['index'] + 1), font=self.font_reg, fill=0, anchor='mm')
            label_px = max(9, int(q['bubbles'][0]['r'] * 0.95 * PPMM))
            font_label = self.font_cached(label_px)
            for b in q['bubbles']:
                box = [self.mm(b['x'] - b['r']), self.mm(b['y'] - b['r']),
                       self.mm(b['x'] + b['r']), self.mm(b['y'] + b['r'])]
                self.d.ellipse(box, outline=0, width=3)
                self.d.text((self.mm(b['x']), self.mm(b['y'])), b['label'],
                            font=font_label, fill=95, anchor='mm')

    # ---- تظليل إجابات الطالب ----
    def shade(self, rng, bubble, kind='pen'):
        """رسم تظليل يشبه خط الطالب (غير مثالي) حسب نوع القلم/الضغط."""
        cx, cy = self.mm(bubble['x']), self.mm(bubble['y'])
        rad = self.mm(bubble['r'] * 2 * 0.42)
        if kind == 'light':
            color, n, rad = rng.randint(132, 162), 3, rad * 0.82
        elif kind == 'pencil':
            color, n = rng.randint(88, 126), 5
        elif kind == 'heavy':
            color, n, rad = rng.randint(0, 18), 6, rad * 1.06
        else:
            color, n = rng.randint(18, 46), 5
        for _ in range(n):
            dx = rng.uniform(-0.24, 0.24) * rad
            dy = rng.uniform(-0.24, 0.24) * rad
            rr = rad * rng.uniform(0.55, 0.88)
            self.d.ellipse([cx + dx - rr, cy + dy - rr, cx + dx + rr, cy + dy + rr], fill=color)

    def flatten(self):
        return self.img


# ------------------------------------------------------------------ #
# محاكاة تصوير الجوال                                                 #
# ------------------------------------------------------------------ #
def desk_background(rng, w, h):
    base = np.zeros((h, w, 3), dtype=np.float32)
    tone = np.array([rng.uniform(140, 190), rng.uniform(135, 185), rng.uniform(125, 175)], dtype=np.float32)
    base[:, :] = tone
    # خشونة خفيفة
    noise = np.random.normal(0, 4.0, (h, w, 1)).astype(np.float32)
    base += noise
    return base


def simulate_photo(flat: Image.Image, rng, out_w=1100, out_h=1450, hard=False, fid_mm=None):
    """يحوّل ورقة مسطّحة إلى "صورة جوال": منظور + إضاءة + ظل + ضبابية + ضوضاء + JPEG."""
    # 1) أبعاد الورقة في الإطار (تُغطّي 72%–88% من العرض)
    cover = rng.uniform(0.72, 0.88) if not hard else rng.uniform(0.62, 0.80)
    scale = (out_w * cover) / FLAT_W
    sw, sh = FLAT_W * scale, FLAT_H * scale
    # مستطيل مركزي مضطرب + دوران بسيط
    cx, cy = out_w / 2 + rng.uniform(-0.03, 0.03) * out_w, out_h / 2 + rng.uniform(-0.03, 0.03) * out_h
    rot = np.deg2rad(rng.uniform(-12, 12) if not hard else rng.uniform(-25, 25))
    persp = rng.uniform(0.01, 0.05) if not hard else rng.uniform(0.05, 0.11)

    def place(u, v):
        # u,v في [-0.5, 0.5]
        x = u * sw
        y = v * sh
        x *= (1 + persp * v * 2)          # تضييق تدريجي = منظور
        y *= (1 + persp * u * 0.5)
        xr = x * np.cos(rot) - y * np.sin(rot)
        yr = x * np.sin(rot) + y * np.cos(rot)
        return cx + xr, cy + yr

    src_corners = [(0, 0), (FLAT_W, 0), (FLAT_W, FLAT_H), (0, FLAT_H)]
    dst_corners = [place(-0.5, -0.5), place(0.5, -0.5), place(0.5, 0.5), place(-0.5, 0.5)]
    H = homography(src_corners, dst_corners)          # flat → out
    Hi = np.linalg.inv(H)                             # out → flat (ما تحتاجه PIL)
    Hi = Hi / Hi[2, 2]                                # PIL يفترض أن مقام المعادلة = 1 بالضبط
    coeffs = (Hi[0, 0], Hi[0, 1], Hi[0, 2], Hi[1, 0], Hi[1, 1], Hi[1, 2], Hi[2, 0], Hi[2, 1])

    warped = flat.convert('L').transform((out_w, out_h), Image.PERSPECTIVE, coeffs,
                                         resample=Image.BICUBIC, fillcolor=255)
    mask = Image.new('L', (FLAT_W, FLAT_H), 255).transform((out_w, out_h), Image.PERSPECTIVE, coeffs,
                                                           resample=Image.BICUBIC, fillcolor=0)

    page = np.array(warped, dtype=np.float32)
    alpha = (np.array(mask, dtype=np.float32) / 255.0)[..., None]
    desk = desk_background(rng, out_w, out_h)
    comp = page[..., None] * alpha + desk * (1 - alpha)

    # 2) إضاءة غير منتظمة + ظل ناعم
    yy, xx = np.mgrid[0:out_h, 0:out_w].astype(np.float32)
    gx = rng.uniform(-0.30, 0.30) / out_w
    gy = rng.uniform(-0.30, 0.30) / out_h
    light = 1.0 + gx * (xx - out_w / 2) + gy * (yy - out_h / 2)
    shadow_cx, shadow_cy = rng.uniform(0, out_w), rng.uniform(0, out_h)
    rx, ry = rng.uniform(0.3, 0.7) * out_w, rng.uniform(0.3, 0.7) * out_h
    d2 = ((xx - shadow_cx) / rx) ** 2 + ((yy - shadow_cy) / ry) ** 2
    shadow = 1.0 - (0.22 if not hard else 0.38) * np.exp(-d2 * 1.6)
    comp *= (light * shadow)[..., None]

    # 3) ضبابية + تصغير + ضوضاء
    img = Image.fromarray(np.clip(comp, 0, 255).astype(np.uint8), 'RGB')
    img = img.filter(ImageFilter.GaussianBlur(rng.uniform(0.8, 1.6) if not hard else rng.uniform(1.4, 2.6)))
    img = img.resize((out_w, out_h), Image.LANCZOS)
    arr = np.array(img, dtype=np.float32)
    arr += np.random.normal(0, rng.uniform(2.0, 5.0), arr.shape)
    # 4) آثار JPEG حقيقية (حفظ + إعادة قراءة) عند جودة منخفضة
    tmp = os.path.join(OUT, '_tmp.jpg')
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), 'RGB').save(
        tmp, quality=rng.randint(62, 85) if not hard else rng.randint(45, 65))
    img = Image.open(tmp).convert('RGB')
    arr = np.array(img, dtype=np.float32)

    # المواضع الحقيقية لمراكز علامات التسجيل (لقياس خطأ التعرّف) — TL,TR,BR,BL
    fids = fid_mm or [(13, 13), (197, 13), (197, 284), (13, 284)]
    true_centers = []
    for (mx, my) in fids:
        x, y = H[0, 0] * mx * PPMM + H[0, 1] * my * PPMM + H[0, 2], H[1, 0] * mx * PPMM + H[1, 1] * my * PPMM + H[1, 2]
        wgt = H[2, 0] * mx * PPMM + H[2, 1] * my * PPMM + H[2, 2]
        true_centers.append([round(x / wgt, 2), round(y / wgt, 2)])
    return arr.astype(np.uint8), true_centers


def write_pgm(path, gray):
    h, w = gray.shape
    with open(path, 'wb') as f:
        f.write(f'P5\n{w} {h}\n255\n'.encode())
        f.write(gray.tobytes())


def normalize_student(st):
    """مفاتيح JSON تصبح نصوصًا — نعيدها أرقامًا للاستخدام الداخلي."""
    st = dict(st)
    st['flaws'] = {int(k): v for k, v in (st.get('flaws') or {}).items()}
    return st


def build_sheet(tpl, student, rng):
    student = normalize_student(student)
    r = SheetRenderer(tpl)
    img = r.draw_all()
    # تظليل رقم الجلوس
    for ch_i, ch in enumerate(str(student['id'])):
        digit = int(ch)
        for b in tpl['digitGrid']['bubbles']:
            if b['col'] == ch_i and b['digit'] == digit:
                r.shade(rng, b, kind=student.get('ink', 'pen'))
    # تظليل الإجابات
    for qi, opts in student_marks(student, tpl).items():
        for oi, opt in enumerate(opts):
            q = tpl['questions'][qi]
            b = q['bubbles'][opt]
            kind = 'light' if (student['flaws'].get(qi) == 'light') else ('heavy' if len(opts) > 1 and oi == 1 else student.get('ink', 'pen'))
            r.shade(rng, b, kind=kind)
    return r.flatten()


def student_marks(st, tpl):
    """الإجابات كما ستُرسم: رقم السؤال → قائمة الخيارات المظلّلة."""
    st = normalize_student(st)
    marks = {}
    for qi, a in enumerate(st['answers']):
        flaw = st['flaws'].get(qi)
        if flaw == 'blank':
            continue
        if flaw == 'double':
            n = tpl['questions'][qi]['options']
            marks[qi] = [a, (a + 1) % n]
        else:
            marks[qi] = [a]
    return marks


def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('--count', type=int, default=8)
    ap.add_argument('--seed', type=int, default=20261002)
    ap.add_argument('--hard', action='store_true')
    ap.add_argument('--keep', action='store_true', help='لا تحذف الملفات القديمة')
    ap.add_argument('--rotate180', type=str, default='', help='فهارس أوراق تُقلب 180° (مثال: 2,4)')
    ap.add_argument('--prefix', type=str, default='scan', help='بادئة أسماء الملفات')
    args = ap.parse_args()

    rng = random.Random(args.seed)
    np.random.seed(args.seed)
    os.makedirs(OUT, exist_ok=True)

    with open(os.path.join(OUT, 'template.json'), encoding='utf-8') as f:
        tpl = json.load(f)
    with open(os.path.join(OUT, 'students.json'), encoding='utf-8') as f:
        students = json.load(f)

    fid_mm = template_fiducial_centers(tpl)
    rot = {int(v) for v in args.rotate180.split(',') if v.strip().isdigit()}
    manifest = []
    for i in range(min(args.count, len(students))):
        st = students[i]
        flat = build_sheet(tpl, st, rng)
        if i in rot:
            flat = flat.rotate(180)
        photo, true_centers = simulate_photo(flat, rng, hard=args.hard, fid_mm=fid_mm)
        gray = np.array(Image.fromarray(photo, 'RGB').convert('L'), dtype=np.uint8)
        name = f"{args.prefix}_{i:02d}"
        write_pgm(os.path.join(OUT, name + '.pgm'), gray)
        Image.fromarray(photo, 'RGB').save(os.path.join(OUT, name + '.jpg'), quality=88)
        gt = {
            'file': name + '.pgm', 'studentId': st['id'], 'name': st['name'],
            'code': tpl['meta']['serial'] | (32 if tpl['meta']['isKey'] else 0),
            'answers': [a for a in st['answers']],
            'marks': {str(k): v for k, v in student_marks(st, tpl).items()},
            'flaws': st['flaws'],
            'trueCorners': true_centers,
            'rotated180': i in rot,
        }
        with open(os.path.join(OUT, name + '.gt.json'), 'w', encoding='utf-8') as f:
            json.dump(gt, f, ensure_ascii=False, indent=1)
        manifest.append(gt)
        print(f"  ✓ {name}: طالب {st['id']} — {st['name']} ({'صعب' if args.hard else 'عادي'})")

    tmp = os.path.join(OUT, '_tmp.jpg')
    if os.path.exists(tmp):
        os.remove(tmp)
    with open(os.path.join(OUT, 'manifest.json'), 'w', encoding='utf-8') as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)
    print(f"تم توليد {len(manifest)} ورقة في {OUT}")


if __name__ == '__main__':
    sys.exit(main())
