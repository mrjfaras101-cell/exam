---
{
  "deck": "الجلسة 03 — الفرع وطلب السحب",
  "kicker": "ورشة GIT وGITHUB — البرنامج التدريبي العملي",
  "footer": "ورشة Git وGitHub · الجلسة 03 — الفرع وطلب السحب"
}
---

:::slide{layout="title" title="فرعي الأول وطلب السحب الأول" subtitle="Session 03 · Branch & Pull Request" kicker="ورشة GIT وGITHUB"}
:::

:::slide{title="لماذا نمنع العمل على main؟"}
- `main` هي النسخة التي يعتمد عليها الجميع
- العمل المباشر عليها يعني: لا مراجعة، ولا فرصة للتصحيح، وانهيار المشروع عند أول خطأ
- الفرع يمنحك مساحة آمنة للتجربة
- طلب السحب يمنح الفريق فرصة الفحص قبل الدمج

:::callout{type="err"}
مخالفة اليوم: الدفع المباشر إلى main. حماية الفرع سترفضه، وستخصم درجات التقييم — لأن المراجعة مهارة مقصودة هنا لا إجراء شكلي.
:::
:::

:::slide{title="رحلة طلب السحب"}
:::img{name="pr-flow"}
:::
:::

:::slide{title="دورة العمل في الفريق"}
:::img{name="branch-merge"}
:::
:::

:::slide{title="المهمة 2 — أنشئ فرعك باسم صحيح"}
:::code
$ git switch main && git pull --ff-only      # ← لا تبدأ قبل هذه الخطوة
$ git switch -c feature/<username>-card
Switched to a new branch 'feature/omar-qa-card'

$ git branch
  main
* feature/omar-qa-card

$ git branch --show-current
feature/omar-qa-card
:::

:::table
| ✔ اسم صحيح | ✘ اسم خطأ | السبب |
| feature/omar-qa-card | my-branch | لا يدل على صاحبه ولا موضوعه |
| docs/leen-readme-faq | test | غامض ومكرر |
| fix/sara-search-filter | sara/new/final/2 | مسارات وتسمية فوضوية |
:::
:::

:::slide{title="المهمة 3 — اكتب بطاقتك"}
:::code
$ cp data/members/00-template.json data/members/<username>.json
:::

:::code
{
  "fullName": "عمر القاسم",
  "github": "omar-qa",
  "role": "مختبر QA",
  "favoriteCommand": "git log --oneline --graph --all",
  "message": "أبحث عن الأخطاء قبل أن يجدها المستخدم، وأثبت كل إصلاح بمخرجات واضحة.",
  "tags": ["Testing", "JavaScript"],
  "joinedAt": "2026-10-06"
}
:::

:::callout{type="err"}
ممنوع: بريد إلكتروني، رقم هاتف، عنوان، كلمة مرور. الفحص التلقائي يرفض الملف، وقد يُطلب منك حذف الالتزام وإعادة العمل.
:::
:::

:::slide{title="المهمة 3 — ولّد الفهرس ثم افحص"}
:::code
$ node tools/build-index.mjs
[build-index] ✔ تم توليد الفهرس: 6 بطاقة.
   • ali-h                 مطوّر
   • nour-dev              مصمّم
   • omar-qa               مختبر QA

$ node tests/validate-members.mjs
=== فحص بطاقات الأعضاء / Validating member cards ===
--- النتيجة / Result: 6 بطاقة، 0 خطأ، 0 تحذير ---
:::

:::callout{type="warn"}
إن ظهر خطأ: اقرأ **أول سطر خطأ فقط**، أصلحه، ثم أعد التشغيل. لا تُكمل قبل أن تصبح النتيجة `0 خطأ`.
:::
:::

:::slide{title="المهمة 4 — التزم برسالة مهنية"}
:::code
$ git status -sb
## feature/omar-qa-card
 M data/members-bundle.js
 M data/members-index.json
?? data/members/omar-qa.json

$ git add data/members/omar-qa.json data/members-index.json data/members-bundle.js
$ git commit -m "feat(members): add card for omar-qa"
[feature/omar-qa-card 89f5cff] feat(members): add card for omar-qa
 3 files changed, 25 insertions(+), 2 deletions(-)
:::

:::table
| ✔ رسالة مقبولة | ✘ رسالة مرفوضة |
| feat(members): add card for omar-qa | update |
| fix(ui): correct card alignment | changes |
| docs(readme): add FAQ section | final / done / asdf |
:::
:::

:::slide{title="المهمة 4 — ارفع فرعك"}
:::code
$ git push -u origin feature/omar-qa-card
remote:
remote: Create a pull request for 'feature/omar-qa-card' on GitHub by visiting:
remote:      https://github.com/<org>/class-team-hub/pull/new/feature/omar-qa-card
remote:
To https://github.com/<org>/class-team-hub.git
 * [new branch]      feature/omar-qa-card -> feature/omar-qa-card
branch 'feature/omar-qa-card' set up to track 'origin/feature/omar-qa-card'.
:::

- الرابط الذي ظهر في المخرجات هو بوابة طلب السحب — لا تنسخه، بل افتحه
- `-u` تختصر عليك: بعدها يكفي `git push` و`git pull` بلا أسماء
:::

:::slide{title="المهمة 5 — افتح طلب السحب واملأه"}
- العنوان بنفس صيغة رسالة الالتزام: `feat(members): add card for omar-qa`
- ماذا تغيّر: ملف بطاقتي + إعادة توليد الفهرس
- الأدلة: الصق مخرجات `node tests/validate-members.mjs`
- الربط: `Closes #12` ليُغلق طلبك المهمة تلقائياً عند الدمج
- Reviewers: اختر زميلاً · Assignees: نفسك

:::callout{type="rule"}
لا تضغط Merge بنفسك. الدمج بعد موافقة المراجع — هذا هو الفرق بين «رفعت كوداً» و«عملت في فريق».
:::
:::

:::slide{title="كيف تكتب مراجعة يستفيد منها زميلك؟"}
:::cols
- «الحقل `favoriteCommand` لا يبدأ بـ git، هل تصححه؟»
- «هل تريد إضافة وسم JavaScript أيضاً؟»
- «ممتاز، البطاقة تظهر بشكل نظيف ✔»
- اقتراح تحسين واحد واضح
---
- «كودك خاطئ»
- «افعله بشكل صحيح»
- «موافق» بلا تفصيل
- أي تعليق على الشخص لا على العمل
:::
:::

:::slide{title="المهمة 6 — استجب للملاحظات"}
:::code
# المراجع طلب إضافة وسم JavaScript:
$ nano data/members/omar-qa.json
$ node tests/validate-members.mjs
--- النتيجة / Result: 6 بطاقة، 0 خطأ، 0 تحذير ---

$ git add data/members/omar-qa.json
$ git commit -m "fix(members): add JavaScript tag per review feedback"
$ git push
   89f5cff..3c7d9e1  feature/omar-qa-card -> feature/omar-qa-card
:::

:::callout{type="tip"}
لاحظ: **نفس طلب السحب** تحدّث تلقائياً — لا تفتح طلباً جديداً. الطلب يعرض كل ما على فرعك حتى لحظة الدمج.
:::
:::

:::slide{title="أخطاء متوقعة اليوم"}
:::table
| الخطأ | الحل |
| fatal: not a git repository | أنت خارج مجلد المشروع — افحص pwd |
| fatal: invalid reference | اسم الفرع خطأ، أو تحاول الانتقال إلى فرع غير موجود |
| ! [rejected] non-fast-forward | فرعك قديم: git pull --rebase ثم push |
| nothing to commit | نسيت git add قبل الالتزام |
| لم يظهر الرابط على GitHub | نسيت git push أو أخطأت اسم الفرع |
:::
:::

:::slide{title="قبل الجلسة القادمة"}
- بطاقتك على فرع مرفوع، وطلب سحب مفتوح بوصف كامل
- راجعت طلب سحب زميل بملاحظة مكتوبة محددة
- ردّيت على ملاحظة وصلتك (بتصحيح أو شرح مقنع)
- الجلسة القادمة: **مزامنة الفريق والدمج** — كيف ترى تعديلات زملائك وكيف تعمل الاستراتيجيات الثلاث

:::callout{type="ok"}
سؤال للتفكير: زر الدمج على GitHub فيه ثلاثة خيارات (Merge / Squash / Rebase). أيّها تختار ولماذا؟ ستجيب عملياً في الجلسة القادمة.
:::
:::
