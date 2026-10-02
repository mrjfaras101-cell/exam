# توليد «ورقة المفتاح» المصطنعة (ورقة طالب لكن ببتّة المفتاح مضبوطة في رمز الورقة).
# تُستخدم لاختبار قراءة المفتاح آليًا ولزر «مسح ورقة المفتاح» في النسخة التجريبية.
#
# التشغيل:
#   node demo/test/dump_template.mjs
#   .venv/bin/python demo/test/gen_keysheet.py
import importlib.util
import json
import os
import random
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out')


def _load_gen_scans():
    spec = importlib.util.spec_from_file_location('gen_scans', os.path.join(HERE, 'gen_scans.py'))
    mod = importlib.util.module_from_spec(spec)
    argv_backup = sys.argv
    sys.argv = ['gen_scans.py']          # يمنع argparse من قراءة وسائطنا
    try:
        spec.loader.exec_module(mod)
    finally:
        sys.argv = argv_backup
    return mod


def main():
    gs = _load_gen_scans()
    rng = random.Random(77)
    np.random.seed(77)

    with open(os.path.join(OUT, 'template.json'), encoding='utf-8') as f:
        base = json.load(f)
    with open(os.path.join(OUT, 'key.json'), encoding='utf-8') as f:
        key = json.load(f)

    # قالب المفتاح: نفس الاختبار لكن مع بتّة المفتاح
    tpl = dict(base)
    tpl['meta'] = dict(base['meta'], isKey=True)
    code = tpl['meta']['serial'] | 32
    for b in tpl['code']['bubbles']:
        b['printed'] = (code >> b['bit']) & 1

    # الورقة المفتاح: كل إجابة صحيحة مظلَّلة إضافة إلى رقم جلوس تجريبي
    r = gs.SheetRenderer(tpl)
    r.draw_all()
    for qi, correct in enumerate(key['key']):
        r.shade(rng, tpl['questions'][qi]['bubbles'][correct], kind='pen')
    for ch_i, ch in enumerate('20260101'):
        for b in tpl['digitGrid']['bubbles']:
            if b['col'] == ch_i and b['digit'] == int(ch):
                r.shade(rng, b, kind='pen')

    flat = r.flatten()
    fid_mm = gs.template_fiducial_centers(tpl)
    photo, true_centers = gs.simulate_photo(flat, rng, fid_mm=fid_mm)
    gray = np.array(Image.fromarray(photo, 'RGB').convert('L'), dtype=np.uint8)

    gs.write_pgm(os.path.join(OUT, 'keysheet.pgm'), gray)
    Image.fromarray(photo, 'RGB').save(os.path.join(OUT, 'keysheet.jpg'), quality=88)
    gt = {
        'file': 'keysheet.pgm', 'studentId': '20260101', 'name': 'ورقة المفتاح',
        'code': code, 'answers': key['key'], 'isKey': True,
        'trueCorners': true_centers, 'rotated180': False,
    }
    with open(os.path.join(OUT, 'keysheet.gt.json'), 'w', encoding='utf-8') as f:
        json.dump(gt, f, ensure_ascii=False, indent=1)
    print(f"✓ ورقة المفتاح: رمز الورقة {code} (serial {tpl['meta']['serial']} + بتة المفتاح)")
    return 0


if __name__ == '__main__':
    sys.exit(main())
