# ورشة Git وGitHub — البرنامج التدريبي العملي

> حزمة تدريبية كاملة (5 أوراق عمل + نماذج حلول + دليل مدرّب + مستودع تدريبي جاهز)
> لتدريب الطلبة على استخدام Git وGitHub من الصفر حتى النشر، عبر مشروع فريق حقيقي.
>
> A complete bilingual (Arabic/English) workshop package: five progressive worksheets,
> instructor solution keys, a trainer playbook, and a ready-to-use classroom repository.

---

## 1) محتويات الحزمة | What is in this package

| المجلد / Folder | المحتوى | الصيغ |
|---|---|---|
| `worksheets/` | **أوراق العمل الخمس** + دليل البرنامج (00) | PDF + HTML |
| `solutions/` | **نماذج الحلول والتقييم** لكل ورقة (للمدرّب) | PDF + HTML |
| `trainer/` | **دليل المدرّب الشامل** (تخطيط، إدارة صف، أخطاء شائعة، سكربتات إنقاذ) | PDF + HTML |
| `docx/` | النسخ القابلة للتعديل من كل ما سبق | DOCX |
| `project/` | **المستودع التدريبي** `class-team-hub` الذي ينسخه الطلبة ويعدّلونه | كود + بيانات |
| `source/` | ملفات المصدر (Markdown بصيغة مختصرة) لتعديل المحتوى | MD |
| `tools/` | أدوات توليد المستندات (PDF/DOCX) من المصادر | Python |
| `assets/` | التنسيقات، الخطوط العربية، والرسومات التوضيحية | CSS/SVG/PNG |

## 2) أوراق العمل الخمس | The five worksheets

| # | العنوان | المدة | المهام | التركيز العملي |
|---|---|---|---|---|
| 01 | التهيئة والتعريف بـ Git وGitHub | 90 د | 6 | المفاهيم، التثبيت، الحساب المهني، 2FA، SSH/PAT، أول مستودع شخصي |
| 02 | استنساخ مستودع الفريق واستكشافه | 75 د | 5 | `git clone` وبنية المشروع وتشغيل الموقع محلياً وقراءة التاريخ |
| 03 | فرعي الأول وطلب السحب الأول | 90 د | 6 | فرع → بطاقة JSON → التزام مهني → `push` → Pull Request → مراجعة زميل |
| 04 | مزامنة الفريق وكيف يرى تعديلات زملائه | 90 د | 6 | `fetch/pull`، استراتيجيات الدمج الثلاث، التراجع الآمن، تقرير الفريق |
| 05 | حل التعارضات النهائية والنشر | 120 د | 6 | تعارض سطر واحد، تعارض ملف مُولَّد، `rebase` و`--force-with-lease`، GitHub Pages |

**الخيوط البيداغوجية الخمسة المتدرّجة:** التعريف → الاستكشاف → المساهمة → المزامنة والدمج →
حل التعارض والنشر. كل ورقة تعتمد على مخرجات الورقة السابقة، وتنتهي بأدلة تسليم قابلة للتصحيح.

## 3) المشروع التدريبي: `class-team-hub`

موقع ويب ثابت (HTML + CSS + JavaScript) يعرض بطاقة تعريفية لكل طالب في الفريق.

**الفكرة التي تحقّق أهداف التدريب:**

- كل طالب يضيف **ملفاً خاصاً به** فقط: `data/members/<username>.json` ← لا تعارض مع الزملاء.
- الملف المشترك الوحيد هو `data/members-index.json` وهو **مُولَّد آلياً** ← يُعلّم الطالب
  أن بعض التعارضات تُحلّ بإعادة التوليد لا يدوياً (درس الورقة 05).
- ملف `sandbox/team-slogan.txt` مصمَّم **لإحداث تعارض مقصود** في سطر واحد — أداة تعليمية
  لا خطأ في التصميم.

```bash
cd project
node tools/build-index.mjs            # توليد الفهرس والنسخة المدمجة
node tests/validate-members.mjs       # فحص صحة بطاقات الأعضاء
python3 -m http.server 8000           # تشغيل الموقع على http://localhost:8000
```

## 4) كيف تستخدم الحزمة | How to use it

1. **اقرأ** `trainer/trainer-guide.pdf` (دليل المدرّب) — فيه تخطيط الجلسات وقوائم الإعداد.
2. **ارفع** محتوى مجلد `project/` إلى مستودع GitHub في منظمة خاصة بالورشة:
   ```bash
   cd project
   git init -b main
   git add -A && git commit -m "chore: initial commit of class-team-hub"
   git remote add origin https://github.com/<ORG>/class-team-hub.git
   git push -u origin main
   ```
3. **فعّل حماية الفرع:** `Settings ← Branches ← main ← Require a pull request before merging`.
4. **اطبع** أوراق `worksheets/*.pdf` للطلبة (كل ورقة ~9–11 صفحة A4).
5. **احتفظ** بـ `solutions/*.pdf` و`trainer/*.pdf` لنفسك — **لا توزّعها على الطلبة**.
6. **صحّح** بجدول التقييم المُجمَّع (500 نقطة) الموجود في كل نموذج حل.

## 5) تعديل المحتوى أو ترجمته | Customising & translating

المحتوى مكتوب في `source/*.md` بصيغة بسيطة، ثم يُولَّد PDF/DOCX:

```bash
python3 tools/build.py                 # بناء الكل (HTML + PDF + DOCX + الصور)
python3 tools/build.py ws1             # ورقة واحدة
python3 tools/build.py --no-docx       # بدون DOCX (أسرع)
python3 tools/build.py --no-pdf        # بدون PDF
```

**بنية أوراق العمل (واجهة التنسيق المختصرة):**

```text
:::band{ar="عنوان قسم" en="Section title"}          شريط قسم (RTL/LTR)
:::task{num="1" ar="المهمة" en="Task" time="15 دقيقة" pts="10" level="مبتدئ"} … :::
:::term{title="Terminal"}  $ git status  :::       نافذة طرفية ملوّنة
:::box{type="tip|warn|err|ok|info|rule" ar="…" en="…"} … :::   صناديق تنبيه
:::write{n=3 label="…"} :::                        أسطر كتابة للطالب
:::evidence{ar="…"} ::: :::check{ar="…"} ::: :::scale{ar="…"} :::
```

**لتغيير الهوية البصرية:** عدّل الألوان في `assets/print.css` (المتغيرات `--navy`,
`--orange` …)، والخطوط في `assets/fonts/`.

**لتغيير اسم مؤسستك:** عدّل `source/*.md` (الحقل `footer` و`kicker`) ثم أعد البناء.

## 6) الرسومات التوضيحية | Diagrams

6 رسومات SVG متجهة (قابلة لتعديل الألوان مباشرة) + نسخ PNG للـ DOCX:

`git-vs-github` · `flow-stages` (المناطق الثلاث) · `branch-merge` (دورة الفريق) ·
`pr-flow` (رحلة طلب السحب) · `data-flow` (مسار البيانات في المشروع) ·
`conflict-markers` (بنية التعارض) · `fetch-vs-pull`

## 7) ملاحظات تقنية | Technical notes

- الخطوط العربية **مدمجة محلياً** في `assets/fonts/` ← الطباعة والتصدير يعملان بلا إنترنت.
- PDF بمقاس A4 مع ترقيم صفحات تلقائي، مُولَّد عبر Chromium (نص قابل للبحث والنسخ، لا صور).
- ملفات DOCX مضبوطة على الاتجاه RTL (فقرة `bidi` + تشغيل `rtl`) وتتضمن الرسومات.
- مصادر التوليد تحتاج: Python 3 + `markdown` + `pypandoc` + `python-docx` (وكلها قابلة
  للتثبيت عبر `pip`)، مع Chromium/Puppeteer لتوليد PDF.

## 8) ترخيص الاستخدام | Licence

محتوى الحزمة مخصّص للاستخدام التعليمي والتدريبي. المشروع البرمجي داخل `project/`
مرخّص بـ MIT (انظر `project/LICENSE`).

---

## 9) خريطة سريعة للملفات | Quick file map

```text
.
├── worksheets/   ws1…ws5 + program-overview      (PDF + HTML)   ← تُطبع للطلبة
├── solutions/    solutions-ws1…ws5               (PDF + HTML)   ← للمدرّب فقط
├── trainer/      trainer-guide                   (PDF + HTML)   ← للمدرّب فقط
├── docx/         نفس المستندات بجميع أنواعها     (DOCX)         ← للتعديل
├── project/      class-team-hub — المستودع التدريبي
├── source/       مصادر Markdown
├── tools/        build.py · rasterize.mjs
└── assets/       print.css · fonts/ · img/ (SVG + PNG) · cover-hero.png
```
