---
{
  "deck": "الجلسة 05 — حل التعارضات والنشر",
  "kicker": "ورشة GIT وGITHUB — البرنامج التدريبي العملي",
  "footer": "ورشة Git وGitHub · الجلسة 05 — حل التعارضات والنشر"
}
---

:::slide{layout="title" title="حل التعارضات ونشر الموقع" subtitle="Session 05 · Merge Conflicts & GitHub Pages" kicker="ورشة GIT وGITHUB"}
:::

:::slide{title="هدف اليوم — ثلاث مهارات يطلبها سوق العمل"}
- حل التعارضات بثقة: نفهم لماذا حدث، ولا نخاف منه
- إدارة الإصدارات: وسم الإصدار الأول من المشروع
- النشر: الموقع يظهر على رابط عام يراه أي شخص
- التعارض ليس فشلاً: هو دعوة من Git لاتخاذ قرار واعٍ

:::callout{type="info"}
اليوم **الدمج** لا يُنهى إلا بعد فهمه: كل تعارض حلّيته ستشرحه في تقرير التسليم بجملة واحدة واضحة.
:::
:::

:::slide{title="متى يحدث التعارض؟"}
:::img{name="conflict-markers"}
:::

- شرطان معاً: تعديلان متوازيان + نفس الأسطر
- تعديلان في ملفين مختلفين ← لا تعارض
- تعديلان في نفس الملف لكن أسطراً مختلفة ← لا تعارض (يحدث دمج تلقائي)
- تعديلان في نفس السطر ← تعارض

:::callout{type="rule"}
حلّ التعارض = **قرار محتوى**، والجهاز يساعد لكن القرار لك ولفريقك.
:::
:::

:::slide{title="المهمة 2 — صنع تعارض متعمد داخل الفرع المشترك"}
:::code
$ git switch main && git pull --ff-only
$ git switch -c sandbox/conflict-<team>

$ nano data/site-config.json     # الفريق الأول: h1Title = "دليل صف 2026"
$ node tests/validate-members.mjs
$ git add data/site-config.json
$ git commit -m "content(config): set team headline (team A)"
$ git push -u origin sandbox/conflict-<team>
:::

- تكرار التعارض **بشكل مقصود** في بيئة آمنة هو أسرع طريق لإتقانه
- ملف `data/site-config.json` هو ميدان التدريب: يتغير بسرعة، ولن يضر الموقع
:::

:::slide{title="المهمة 3 — التعارض يظهر، ماذا أرى؟"}
:::code
$ git switch main && git pull --ff-only
$ git merge sandbox/conflict-<team>
Auto-merging data/site-config.json
CONFLICT (content): Merge conflict in data/site-config.json
Automatic merge failed; fix conflicts and then commit the result.

$ git status -sb
## main
UU data/site-config.json
:::

:::code
{
  "siteName": "دليل فريق الصف",
<<<<<<< HEAD
  "h1Title": "دليل صف 2026",
=======
  "h1Title": "دليل فريق الصف",
>>>>>>> sandbox/conflict-team-a
  "contactEmail": "team@example.com"
}
:::
:::

:::slide{title="العلامات الثلاث — ترجمتها"}
:::table
| العلامة | تعني |
| &lt;&lt;&lt;&lt;&lt;&lt;&lt; HEAD | بداية منطقة التعديل الموجود على فرعك الحالي |
| ======= | الخط الفاصل بين الرأيين |
| &gt;&gt;&gt;&gt;&gt;&gt;&gt; name | بداية تعديل الطرف الآخر |
:::

:::callout{type="err"}
❌ خطأ قاتل: ترك أي من العلامات الثلاث في الملف. المشروع لن يعمل، وهذه أسرع طريقة لرفض طلبك في المراجعة.
:::
:::

:::slide{title="المهمة 4 — القرار ثم إغلاق التعارض"}
:::code
{
  "siteName": "دليل فريق الصف",
  "h1Title": "دليل صف 2026",
  "contactEmail": "team@example.com"
}
:::

:::code
$ grep -rInE "^(<{7}|={7}|>{7})( |$)" --exclude-dir=.git .
   ← لا مخرجات = لا علامات متبقية ✔

$ node tests/validate-members.mjs
--- النتيجة / Result: 6 بطاقة، 0 خطأ، 0 تحذير ---

$ git add data/site-config.json
$ git commit -m "merge: resolve site-config headline conflict"
$ git push
:::

- القرار هنا: نريد عنوان «دليل صف 2026» — لأن الأحدث هو الأصح
- الحل الأفضل ليس «خذ رأيي»، بل **ماذا سيرى الزائر؟**
:::

:::slide{title="الأدوات البصرية تُسهّل، لا تُقرّر"}
:::table
| الأداة | القيمة عند التعارض |
| VS Code | تلوين الطرفين وأزرار Accept Current/Incoming — مع معاينة مباشرة |
| GitHub Desktop | فتح الملف في محرر والخيارات الأربعة، ثم Continue merge |
| git diff | رؤية الفرق بنص واضح قبل أي قرار |
| git mergetool | فتح أداة الفروق الثلاثية (ثلاثة أعمدة) عند الحاجة |
:::

:::callout{type="tip"}
مهما استخدمت من أدوات: **القرار قرارك**، والأداة تعرض لا تحكم. اقرأ الطرفين قبل الموافقة.
:::
:::

:::slide{title="المهمة 6 — علّم إصدارك الأول"}
:::code
$ git tag -a v1.0.0 -m "الإصدار الأول: بطاقات الفريق العشرة + صفحة الأسئلة الشائعة"
$ git push origin v1.0.0
To https://github.com/<org>/class-team-hub.git
 * [new tag]         v1.0.0 -> v1.0.0

$ git show v1.0.0 --stat --no-patch
tag v1.0.0
Tagger: Omar Al-Qasem <omar@example.com>
Date:   Tue Nov 3 11:20:14 2026 +0300

الإصدار الأول: بطاقات الفريق العشرة + صفحة الأسئلة الشائعة
:::

- الوسم **معنون** (`-a`) يحمل: من وسم، ومتى، ولماذا — لأنه مرجع رسمي للفريق
:::

:::slide{title="المهمة 7 — انشر الموقع على GitHub Pages"}
:::code
Settings → Pages
  Source:  Deploy from a branch
  Branch:  main  /  (root)
  → Save

# بعد دقيقة:
https://<org>.github.io/class-team-hub/
:::

:::callout{type="warn"}
الصفحة قد تحتاج 1–3 دقائق حتى تظهر أول مرة. حدّث الصفحة، وإن استمر الخطأ فتحقق من: اسم الفرع، ومجلد الإخراج، وأن `index.html` في الجذر.
:::

:::callout{type="ok"}
عند نجاح النشر: ضع الرابط في وصف المستودع (About → Website) وفي رسالة الالتزام النهائي.
:::
:::

:::slide{title="اختبار نهائي للفريق — «السؤال الكبير»"}
- افتح رابط الموقع من هاتف زميلك: هل تظهر البطاقات كلها؟
- نادِ ثلاثة أعضاء باسم كل واحد: هل بطاقته تظهر ببياناته الصحيحة وترتيبه الصحيح؟
- افتح `git log --oneline --graph --all` واسأل: أي عقدة جمعت عمل كل الفريق؟
- تحقق من `git tag -l` ثم `git ls-remote --tags origin`: هل الوسم على الخادم فعلاً؟

:::callout{type="info"}
الوسم المحلي وحده **لا يُرفع تلقائياً** مع `git push` — يحتاج `git push origin v1.0.0` أو `git push origin --tags`.
:::
:::

:::slide{title="ختام البرنامج الأساسي"}
- عندك الآن: مهارة يطلبها كل فريق برمجي، ومشروع حقيقي على الإنترنت باسمك
- أتقنت: الالتزام، الفرع، طلب السحب، المراجعة، المزامنة، الدمج، حل التعارض، النشر
- الخطوة التالية (اختيارية متقدمة): **الوحدة 06 — الأتمتة الاحترافية** (`ws6-automation`)
- فيها: GitHub Actions، حماية الفرع، CODEOWNERS، الإصدارات، وسجل التغييرات

:::callout{type="tip"}
هذه المهارات تُختبر في المقابلات العملية. احتفظ بمستودع المشروع في سيرتك، واربطه بحساب GitHub.
:::
:::

:::slide{title="شكراً — أسئلتكم؟"}
:::callout{type="ok"}
لا تنسَ: كل ما تعلمته اليوم يستخدمه المهندسون كل يوم في العمل الفعلي. الفرق بينك وبينهم اليوم: عدد المحاولات، لا الموهبة.
:::
:::
