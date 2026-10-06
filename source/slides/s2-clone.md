---
{
  "deck": "الجلسة 02 — الاستنساخ والاستكشاف",
  "kicker": "ورشة GIT وGITHUB — البرنامج التدريبي العملي",
  "footer": "ورشة Git وGitHub · الجلسة 02 — الاستنساخ والاستكشاف"
}
---

:::slide{layout="title" title="استنساخ مستودع الفريق واستكشافه" subtitle="Session 02 · Clone & Explore" kicker="ورشة GIT وGITHUB"}
:::

:::slide{title="مشروعنا: دليل فريق الصف"}
- موقع ويب بسيط: بطاقة تعريفية لكل طالب في الفريق
- HTML + CSS + JavaScript + ملفات بيانات JSON
- لا يحتاج تثبيت أي برنامج — يعمل بالمتصفح
- لماذا اخترناه؟ لأنه يعلّم التعاون بلا مشاكل بيئات التطوير

:::callout{type="tip"}
المشروع مُصمَّم بحيث **لا يتعارض** عمل الطلاب: كل طالب له ملف بطاقة خاص باسمه.
:::
:::

:::slide{title="بنية المشروع — أين بطاقتي؟"}
:::code{size="12"}
class-team-hub/
├── index.html              الصفحة الرئيسية
├── css/style.css           التنسيقات
├── js/app.js               يقرأ البيانات ويبني البطاقات
├── data/
│   ├── site-config.json    إعدادات الموقع المشتركة
│   ├── members-index.json  فهرس أسماء البطاقات (مُولَّد آلياً)
│   └── members/            بطاقة واحدة لكل طالب ← ملفك هنا
├── sandbox/                مختبر تمارين التعارض
├── tools/build-index.mjs   إعادة توليد الفهرس
└── tests/validate-members.mjs   فحص صحة البطاقات
:::
:::

:::slide{title="المهمة 1 — استنسخ المستودع"}
:::code
$ cd ~/projects
$ git clone https://github.com/<org>/class-team-hub.git
Cloning into 'class-team-hub'...
remote: Enumerating objects: 87, done.
Unpacking objects: 100% (87/87), done.

$ cd class-team-hub
$ git remote -v
origin  https://github.com/<org>/class-team-hub.git (fetch)
origin  https://github.com/<org>/class-team-hub.git (push)
:::

:::callout{type="warn"}
لا تستخدم زر Download ZIP! النسخة المضغوطة بلا مجلد `.git`، فلن تستطيع الالتزام ولا الرفع، وستظهر لك `fatal: not a git repository`.
:::
:::

:::slide{title="ماذا يجلب الاستنساخ فعلاً؟"}
- كل الملفات، وليس الملفات الحالية فقط
- **كل** الالتزامات في التاريخ (يمكنك رؤية ما فعله زملاؤك قبل أسبوع)
- كل الفروع الموجودة على الخادم
- الربط بالخادم باسم `origin`
- الإعدادات في مجلد `.git` — لا تحذفه ولا تعدّله يدوياً

:::callout{type="info"}
اختبار سريع: `ls -a` — إن لم ترَ `.git` فأنت لست داخل مستودع.
:::
:::

:::slide{title="مسارات البيانات: من ملفك إلى الشاشة"}
:::img{name="data-flow"}
:::
:::

:::slide{title="المهمة 3 — شغّل الموقع"}
:::code
# الطريقة الأسرع (موصى بها):
$ cd ~/projects/class-team-hub
$ python3 -m http.server 8000
Serving HTTP on 0.0.0.0 port 8000 ...

# افتح المتصفح على:  http://localhost:8000
# للإيقاف: Ctrl+C
:::

- الملف الذي يعطي العنوان والوصف: `data/site-config.json`
- الملف الذي يعطي قائمة البطاقات: `data/members-index.json`
- الطريقة البديلة: Live Server من VS Code (يمين على index.html)

:::callout{type="warn"}
فتح الملف بالنقر المزدوج (file://) قد يفشل لأن المتصفح يمنع قراءة ملفات JSON محلياً لأسباب أمنية. الحل: خادم محلي كما أعلاه.
:::
:::

:::slide{title="المهمة 5 — اقرأ تاريخ فريقك"}
:::code
$ git log --oneline --graph --all --decorate
*   a1b2c3d (HEAD -> main, origin/main) Merge pull request #7 from nour/card
|\
| * 9f8e7d6 feat(members): add card for nour-dev
|/
*   5e6f7a8 Merge pull request #6 from ali-h/card
|\
| * 1a2b3c4 feat(members): add card for ali-h
|/
* 8de1e7a chore: initial commit of class-team-hub

$ git shortlog -sn
     4  nour-dev
     3  ali-h
     1  Workshop Instructor
:::
:::

:::slide{title="المهمة 5 — من عدّل ماذا؟"}
:::code
$ git log -p -- data/members/leen-docs.json     # تاريخ ملف واحد بالتفصيل
$ git blame data/members/leen-docs.json         # من كتب كل سطر
f9e8d7c9 (leen-docs 2026-10-06 11:02:40) 1) {
f9e8d7c9 (leen-docs 2026-10-06 11:02:40) 2)   "fullName": "لينا حدّاد",
:::

- سؤال: أي ملف عدّله **كل** الأعضاء؟ ولماذا؟
- الجواب: `data/members-index.json` — لأنه يسجّل قائمة البطاقات، فيتغير مع كل بطاقة جديدة
- وهذا سبب جعله **مُولَّداً آلياً**: لا نكتبه بيدنا ولا نحلّ تعارضه يدوياً

:::callout{type="rule"}
القاعدة القادمة: الملف المُولَّد يُعاد توليده — `node tools/build-index.mjs`
:::
:::

:::slide{title="خطأ شائع اليوم"}
:::code
$ git add data/members/mycards.json
fatal: pathspec 'data/members/mycards.json' did not match any files
:::

هذه الرسالة تعني أن **الملف غير موجود** في المكان الذي كتبته. الأسباب الشائعة:
- خطأ مطبعي في الاسم
- لم تحفظ الملف فعلاً في المحرر
- أنت في مجلد مختلف — افحص بـ `pwd` و`ls data/members/`

:::callout{type="tip"}
git يخبرك بالحقيقة: لا يوجد ملف بهذا المسار. اقرأ الرسالة قبل أن تسأل أحداً.
:::
:::

:::slide{title="قبل الجلسة القادمة"}
- الموقع يعمل على جهازك ولديك دليل (صورة أو خادم يعمل)
- تعرف مكان ملف بطاقتك: `data/members/<username>.json`
- قرأت `git log --graph` وحدّدت أكثر الأعضاء مساهمة
- الجلسة القادمة: **فرعك الأول وطلب السحب الأول** — ستضيف بطاقتك فعلاً

:::callout{type="ok"}
تذكّر: لا عمل على main. كل تعديل — ولو سطراً — يبدأ من فرع خاص بك.
:::
:::
