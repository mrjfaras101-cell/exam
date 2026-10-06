---
{
  "badge_n": "06",
  "badge_l": "ورقة متقدمة",
  "kicker": "ورشة Git وGitHub — وحدة إتقان اختيارية",
  "title": "الأتمتة وحماية الجودة وحماية الفرع",
  "en_title": "Workshop 6 · Automation, Quality Gates & Branch Protection",
  "meta": [
    ["المدة / Duration", "100 دقيقة"],
    ["المستوى / Level", "متقدم — بعد إتمام الأوراق 01–05"],
    ["المتطلبات / Prerequisites", "بطاقة مدموجة + صلاحية في المستودع"],
    ["المخرجات / Deliverable", "فحص أخضر + إصدار v1.0.0 + حماية فرع"],
    ["المهام / Tasks", "6 مهام"],
    ["الدرجة / Points", "100 نقطة"]
  ],
  "footer": "ورشة Git وGitHub · ورقة عمل 06 — الأتمتة وسير العمل الاحترافي",
  "en_footer": "Git & GitHub Workshop · Worksheet 06 — Automation"
}
---

:::band{ar="الفكرة: اجعل الآلة تحرس المشروع بدلاً منك" en="The idea: let the machine guard the project"}
:::

:::bi
حتى الآن كان الفحص يحدث بعد أن يرفع الطالب، وبجهد بشري. في الفرق الحقيقية، **الآلة تفحص
قبل الإنسان**: عند كل طلب سحب يبدأ سير عمل آلي (GitHub Actions) يشغّل الفحوص، وإن فشلت
لا يُسمح بالدمج. النتيجة: المراجع البشري يقرأ الكود والتصميم، لا الأخطاء الميكانيكية.
هذه الورقة تحوّل مشروع فريقك من «مشروع طلابي» إلى **مشروع هندسي منضبط**.
---EN---
Until now, checking happened after a push and by human effort. Real teams let the machine
check first: every pull request triggers an automated workflow, and a failing check blocks the
merge. Reviewers then read design, not typos.
:::

:::goal{ar="أهداف التعلّم" en="Learning objectives"}
- فهم ما هي **CI** (التكامل المستمر) ولماذا لا تُقبل المشاريع المهنية بدونها.
- قراءة ملف سير عمل GitHub Actions بفهم: الأحداث (`on`)، المهام (`jobs`)، الخطوات (`steps`).
- تشغيل **نفس** الفحوص محلياً قبل الرفع بـ `node tools/ci-local.mjs`.
- **اختبار الفحص نفسه**: التأكد أن الفحص يفشل فعلاً عند وجود خلل (الفحص الذي لا يفشل أبداً = لا فحص).
- فهم حماية الفرع (Branch protection) و`CODEOWNERS`: من يراجع أي ملف، وما شروط الدمج.
- إصدار نسخة بالوسوم الدلالية (SemVer) + Release على GitHub + تحديث `CHANGELOG.md`.
:::

:::box{type="rule" ar="المبدأ الذي ستخرج به من هذه الورقة" en="The takeaway principle"}
**الجودة لا تُطلَب بالكلام، بل تُبنى في المسار.** لا تقل للفريق «افحصوا قبل الرفع»، بل
اجعل الفحص شرطاً تقنياً يمنع الدمج. هذا الفرق بين فريق يعتمد على ذاكرة الناس، وفريق
يعتمد على نظام.
:::

:::band{type="alt" ar="الجزء الأول · فهم الأتمتة" en="Part 1 · Understanding automation"}
:::

## ما هي الفحوص الآلية (CI)؟

:::bi
CI اختصار **Continuous Integration** (التكامل المستمر): كل تعديل يُدمج تلقائياً مع فحص
آلي فوري. في GitHub يُنفَّذ ذلك عبر **GitHub Actions**، وهو خادم يعمل عند أحداث محددة
(فتح طلب سحب، دفع، جدولة زمنية) ويشغّل خطوات مرتبة تُسمّى «سير عمل» (workflow).
---EN---
CI means Continuous Integration: every change is verified automatically. On GitHub this is
GitHub Actions — a server that runs a workflow of ordered steps when chosen events occur.
:::

<figure class="dia"><img src="../assets/img/ci-flow.svg" alt="مسار الفحص الآلي"><figcaption>شكل 1: من دفع الطالب إلى قرار الدمج — من يفحص ومتى <span class="en">— push → CI → verdict → merge</span></figcaption></figure>

:::task{num="1" ar="اقرأ سير العمل في مشروعك" en="Read the workflow in your project" time="15 دقيقة" level="متقدم" pts="12" tools=".github/workflows/validate.yml"}
**الهدف:** أن تعرف بالضبط ما سيحدث على الخادم عندما ترفع تعديلك.

**الخطوة 1 — اقرأ الملف:**

:::term{title="Terminal — فتح سير العمل"}
$ cat .github/workflows/validate.yml
name: validate

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  validate:
    name: فحص البطاقات والفهرس
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: "20"
      - run: node tools/build-index.mjs --check
      - run: node tests/validate-members.mjs
      - run: |
          if grep -rInE "^(<{7}|={7}|>{7})( |$)" --exclude-dir=.git . ; then
            echo "::error::يوجد تعارض غير محلول"
            exit 1
          fi
:::

**الخطوة 2 — املأ جدول التحليل:**

| المفتاح في الملف | معناه | القيمة عندك |
|---|---|---|
| `name` | اسم سير العمل الظاهر في تبويب Actions | ……………………… |
| `on:` | الأحداث التي تُشغّله | ……………………… |
| `jobs:` | المهام التي تُنفَّذ | ……………………… |
| `runs-on` | نظام التشغيل على خادم GitHub | ……………………… |
| `steps` | الخطوات بالترتيب | عددها: ……… |
| `actions/checkout` | …………………… | — |
| `actions/setup-node` | …………………… | — |

:::box{type="info" ar="لماذا يوجد خادم كامل لكل فحص؟" en="Why a whole server per check?"}
لأن GitHub يمنح كل تشغيل **جهازاً جديداً نظيفاً** (Ubuntu)، يستنسخ عليه مستودعك، ثم ينفّذ
الخطوات. هذه ميزة مهمة: النتيجة لا تتأثر بجهازك ولا بإعداداتك — «يعمل عندي» ليست حجة.
:::

:::evidence{ar="دليل المطلوب" en="Evidence"}
- الأحداث الثلاثة التي تُشغّل الفحص: ………………………………………………………
- عدد الخطوات: ………… — وما تفعله `actions/checkout` في جملة: ………………………………
:::

:::task{num="2" ar="شغّل الفحص نفسه محلياً" en="Run the very same checks locally" time="12 دقيقة" level="متوسط" pts="15" tools="tools/ci-local.mjs"}

:::bi
لأن انتظار الخادم يستهلك الوقت، أضفنا في المشروع محاكياً محلياً ينفّذ **نفس** الخطوات:
`node tools/ci-local.mjs`. درّب نفسك على تشغيله قبل **كل** `git push`.
---EN---
Waiting for the server wastes time, so the project ships a local mirror of the CI steps.
Run it before every push.
:::

:::term{title="Terminal — الفحص المحلي على فرع نظيف"}
$ git switch main
$ git pull --ff-only
$ git switch -c feature/<username>-card

# … أضف بطاقتك ثم ولّد الفهرس:
$ node tools/build-index.mjs

$ node tools/ci-local.mjs

=== فحص محلي يشبه GitHub Actions / Local CI simulation ===

▸ الفهرس مُحدَّث / index up to date … ✔ نجح
    [build-index] ✓ الفهرس محدَّث بالفعل.
▸ بطاقات الأعضاء صحيحة / member cards valid … ✔ نجح
    --- النتيجة / Result: 3 بطاقة، 0 خطأ، 0 تحذير ---
▸ لا علامات تعارض / no conflict markers … ✔ نجح

────────────────────────────────────────────────────────────
✔ كل الفحوص نجحت — آمن للرفع (git push) / All checks passed.
────────────────────────────────────────────────────────────
:::

:::box{type="tip" ar="اجعلها عادة واحدة" en="One habit to build"}
أمر واحد يحمي سمعتك كمطوّر:
```bash
node tools/ci-local.mjs && git push
```
بفضل `&&` لن يُنفَّذ الرفع إن فشل الفحص. هذا سطر واحد يمنع 90% من طلبات السحب الحمراء.
:::

:::evidence{ar="دليل المطلوب" en="Evidence"}
الصق مخرجات `node tools/ci-local.mjs` على فرعك (يجب أن تكون كلها ✔):

```




```
اذكر أسماء الفحوص الثلاثة بالترتيب: …………………………………………………………
:::

:::band{ar="الجزء الثاني · اكسر ثم أصلح" en="Part 2 · Break it, then fix it"}
:::

:::task{num="3" ar="اكسر المشروع عن قصد وشاهد الفحص يفشل" en="Break it on purpose and watch the check fail" time="20 دقيقة" level="متقدم" pts="18" tools="git|ci-local|GitHub Actions"}
**الهدف:** أن ترى بأنفسك أن الحماية تعمل فعلاً — وهذا أهم درس في الأتمتة.

:::bi
**قاعدة مهنية:** الفحص الذي لا يفشل أبداً أسوأ من عدم وجود فحص، لأنه يمنحك ثقة زائفة.
لذلك عند كتابة أي فحص، **جرّبه على حالة معطوبة عن قصد** أولاً، وتأكد أنه يرفضها.
---EN---
A check that never fails is worse than no check — it gives false confidence. Always test your
check against a deliberately broken case first.
:::

**الخطوة 1 — جرّب ثلاث حالات معطوبة، واحدة واحدة:**

:::term{title="Terminal — الحالة 1: فهرس قديم (بطاقة غير مُفهرسة)"}
$ cp data/members/00-template.json data/members/test-bad.json
# املأه سريعاً بأي بيانات صحيحة، ثم لا تولّد الفهرس:
$ node tools/ci-local.mjs

▸ الفهرس مُحدَّث / index up to date … ✘ فشل
    [build-index] ✗ الفهرس غير محدَّث. شغّل: node tools/build-index.mjs
▸ بطاقات الأعضاء صحيحة / member cards valid … ✘ فشل
      ✗ data/members-index.json: البطاقة "test-bad.json" غير مُفهرسة
    --- النتيجة / Result: 4 بطاقة، 1 خطأ، 0 تحذير ---
▸ لا علامات تعارض / no conflict markers … ✔ نجح

✘ 2 من 3 فحص فشل — لا ترفع قبل الإصلاح.      (exit=1)
:::

:::term{title="Terminal — الحالة 2: بطاقة بمحتوى مخالف"}
$ rm data/members/test-bad.json && node tools/build-index.mjs >/dev/null
# عدّل بطاقتك عن قصد: أمر لا يبدأ بـ git، ورسالة قصيرة
$ node tools/ci-local.mjs

▸ بطاقات الأعضاء صحيحة / member cards valid … ✘ فشل
      ✗ omar-qa.json: اسم مستخدم غير صالح / invalid username: "Omar_QA"
      ⚠ omar-qa.json: دور غير معتاد / unusual role: "سوبرمان"
      ✗ omar-qa.json: الامر المفضل يجب ان يبدا بـ "git "
      ✗ omar-qa.json: tags يجب أن تكون مصفوفة / tags must be an array
      ✗ sara-design.json: طول الرسالة 5 — يجب أن يكون بين 10 و140 حرفاً
    --- النتيجة / Result: 4 بطاقة، 5 خطأ، 2 تحذير ---
:::

:::term{title="Terminal — الحالة 3: علامات تعارض باقية بعد دمج"}
$ printf 'شعار الفريق\n<<<<<<< HEAD\nسارة\n=======\nعمر\n>>>>>>> feature/omar-slogan\n' > sandbox/team-slogan.txt
$ node tools/ci-local.mjs

▸ لا علامات تعارض / no conflict markers … ✘ فشل
    ./sandbox/team-slogan.txt:2:<<<<<<< HEAD
    ./sandbox/team-slogan.txt:4:=======
    ./sandbox/team-slogan.txt:6:>>>>>>> feature/omar-slogan
    ↳ الحل المقترح: ابحث عن <<<<<<< واحذف العلامات واترك النتيجة الصحيحة

✘ 1 من 3 فحص فشل — لا ترفع قبل الإصلاح.      (exit=1)
:::

:::box{type="warn" ar="درس عميق: كيف يخدعك فحص ضعيف؟" en="A deeper lesson: how a weak check fools you"}
الفحص أعلاه استخدم في الإصدار الأول من المشروع نمط بحث غير دقيق:
`grep -rInE "^(<<<<<<<|>>>>>>>|=======)$"` — ونتيجته أنه **كان يمرّ بنجاح** رغم وجود
علامات تعارض حقيقية، لأن العلامات الفعلية تكون `<<<<<<< HEAD` (مع اسم الفرع بعدها)،
ولأن البحث كان محدوداً بامتدادات ملفات معيّنة فأهمل `sandbox/team-slogan.txt`.
**النتيجة:** فحص يجتاز حالة معطوبة = ثقة زائفة. الدرس: اختبر فحصك على حالة مكسورة،
ووسّع نطاقه ليشمل كل الملفات النصية:
```bash
grep -rInE "^(<{7}|={7}|>{7})( |$)" --exclude-dir=.git --exclude-dir=node_modules .
```
:::

**الخطوة 2 — ارفع الفرع المعطوب وافتح طلب سحب، وشاهد النتيجة على GitHub:**

:::term{title="GitHub — ما تراه في صفحة طلب السحب"}
✘ All checks have failed
   1 failing check
   validate / فحص البطاقات والفهرس (pull_request) — Failing after 14s   [Details]

▣ Merging is blocked
   Required statuses must pass before merging.
:::

:::evidence{ar="دليل المطلوب" en="Evidence"}
املأ جدول الحالات الثلاث التي جرّبتها (الصق السطر الأول من كل فشل):

| الحالة المعطوبة | الفحص الذي فشل | أول سطر من رسالة الفشل |
|---|---|---|
| فهرس قديم | ……………………… | ……………………… |
| بطاقة مخالفة | ……………………… | ……………………… |
| علامات تعارض | ……………………… | ……………………… |

- رابط تشغيل الفحص الفاشل على GitHub (`Actions`) : …………………………………………
- الصق صورة شاشة أو نص ما ظهر فيbox «Merging is blocked»: …………………………………………
:::

:::task{num="4" ar="أصلح حتى يصبح الفحص أخضر" en="Fix it until the check is green" time="15 دقيقة" level="متوسط" pts="15" tools="ci-local|git push"}

**الخطوة 1 — أصلح الأخطاء الثلاثة:**

| الخطأ | الإصلاح الصحيح |
|---|---|
| فهرس قديم | `node tools/build-index.mjs` ثم `git add data/members-index.json data/members-bundle.js` |
| بطاقة مخالفة | افتح الملف وصحّح الحقل المشار إليه في الرسالة، ثم أعد الفحص |
| علامات تعارض | احذف الأسطر الثلاثة للعلامات ودمج النص الصحيح، ثم `git add` |

:::term{title="Terminal — الفحص بعد الإصلاح"}
$ node tools/build-index.mjs
[build-index] ✓ تم توليد الفهرس: 4 بطاقة.
   • ali-h                  مطوّر

$ node tools/ci-local.mjs
▸ الفهرس مُحدَّث … ✔ نجح
▸ بطاقات الأعضاء صحيحة … ✔ نجح
▸ لا علامات تعارض … ✔ نجح
✔ كل الفحوص نجحت — آمن للرفع (git push) / All checks passed.    (exit=0)

$ git add -A
$ git commit -m "fix(members): correct card fields and regenerate index"
$ git push
   89f5cff..3c7d9e1  feature/omar-qa-card -> feature/omar-qa-card
:::

**الخطوة 2 — تحقق من النتيجة على GitHub:**

:::term{title="GitHub — بعد الدفع"}
✔ All checks have passed
   1 successful check
   validate / فحص البطاقات والفهرس (pull_request) — Successful in 12s   [Details]

● This branch has no conflicts with the base branch.
   Merging can be performed automatically.
:::

:::box{type="tip" ar="مهارة تُقيَّم عليها" en="A graded skill"}
لاحظ أن الفحص يحمل **نفس الاسم** قبل الإصلاح وبعده (`validate / فحص البطاقات والفهرس`)،
لكن حالته تغيّرت من ✘ إلى ✔. لذلك لا يُقبل في المشاريع المهنية قول «الفحص كان يعطي خطأ»
بلا لقطة أو رابط — الدليل هو تبويب `Checks` في طلب السحب.
:::

:::evidence{ar="دليل المطلوب" en="Evidence"}
- الصق مخرجات `node tools/ci-local.mjs` بعد الإصلاح (كل الفحوص ✔):

```



```
- رابط الفحص الناجح على GitHub: ………………………………………………………………
- كم استغرق الفحص على الخادم؟ ………… ثانية — وعلى جهازك؟ ………… ثانية
:::

:::band{type="violet" ar="الجزء الثالث · حماية الفرع والإصدارات" en="Part 3 · Protection & releases"}
:::

:::task{num="5" ar="حماية الفرع وملّاك الكود" en="Branch protection and code owners" time="18 دقيقة" level="متقدم" pts="15" tools="Settings|CODEOWNERS"}

:::bi
حماية الفرع تعني: «لا يمكن الكتابة في `main` إلا عبر طلب سحب مستوفٍ للشروط». أما
`CODEOWNERS` فيعني: «هذا الملف لا يُعدَّل بلا مراجعة صاحبه». معاً يحوّلان الاتفاقات
الشفهية إلى قواعد يفرضها GitHub نفسه.
---EN---
Branch protection turns agreements into enforced rules: no direct writes to main, only PRs
that satisfy the conditions. CODEOWNERS routes each path to the right reviewer.
:::

**الخطوة 1 — افحص قواعد الحماية المطلوبة:**

:::term{title="GitHub — Settings ← Branches ← main"}
✔ Require a pull request before merging
     ✔ Require approvals: 1
     ✔ Dismiss stale pull request approvals when new commits are pushed
✔ Require status checks to pass before merging
     → الفحص المطلوب: validate / فحص البطاقات والفهرس
✔ Require conversation resolution before merging
✔ Do not allow bypassing the above settings
☐ Allow force pushes            ← يجب أن يبقى معطّلاً دائماً
☐ Allow deletions               ← يبقى معطّلاً
:::

**الخطوة 2 — اقرأ `CODEOWNERS` واربطه بالتجربة:**

:::term{title="Terminal — محتوى ملف ملّاك الكود"}
$ cat .github/CODEOWNERS
# الملفات المشتركة الحساسة → قائد الفريق
/data/site-config.json      @you-instructor
/js/                        @you-instructor
/css/                       @you-instructor
/tools/                     @you-instructor
/tests/                     @you-instructor
/.github/                   @you-instructor
/docs/                      @you-instructor
*                           @you-instructor
/data/members/              @you-instructor
:::

**جرّب عملياً:** افتح فرعاً وعدّل ملفاً مشتركاً (`js/app.js` مثلاً — تعديل تعليق فقط)،
ثم ارفعه وافتح طلب سحب، ولاحظ أن GitHub أضاف المراجع المذكور تلقائياً.

:::term{title="GitHub — ما يظهر في طلب السحب"}
Reviewers
  @you-instructor  —  Awaiting review  (requested automatically by CODEOWNERS)
:::

| الملف / المسار | من يراجعه إلزامياً؟ | لماذا؟ |
|---|---|---|
| `js/` و`css/` | ……………………… | ……………………… |
| `data/members/<username>.json` | ……………………… | ……………………… |
| `data/site-config.json` | ……………………… | ……………………… |
| `tools/` و`tests/` | ……………………… | ……………………… |

:::box{type="err" ar="لا تُعطّل الحماية لإكمال عملك" en="Never disable protection to get unblocked"}
أشهر خطأ: طالب عالق الفحص عنده فيعطّل حماية `main` «مؤقتاً» ثم ينسى. النتيجة: مشروع
بلا حماية ودَين تقني أمني. الحل الصحيح: أصلح السبب، أو استخدم استثناءً موثقاً من
المدرّب (Bypass) يُسجَّل في سجل المستودع ويُعاد فوراً.
:::

:::evidence{ar="دليل المطلوب" en="Evidence"}
- هل حماية الفرع مفعّلة على `main`؟ ☐ نعم ☐ لا
- الفحوص المطلوبة للدمج (Required checks): ……………………………………………………
- من يراجع الملفات المشتركة حسب `CODEOWNERS`؟ ……………………………………………………
- الصق لقطة/وصفاً لطلب سحب ظهر فيه المراجع مضافاً تلقائياً: …………………………………………
:::

:::task{num="6" ar="أصدر نسعة v1.0.0: وسم + Release + سجل تغييرات" en="Release v1.0.0: tag, release notes, changelog" time="15 دقيقة" level="متقدم" pts="15" tools="git tag|GitHub Releases|CHANGELOG"}

**الخطوة 1 — أنشئ وسم الإصدار (Annotated tag):**

:::term{title="Terminal — الوسم والإصدار"}
$ git switch main
$ git pull --ff-only
$ git log --oneline -4
e20b664 (HEAD -> main) Merge pull request #32 from ali-h/feature/ali-card
eb1df06 feat(members): add card for ali-h
388e173 feat(members): add card for leen-docs
ccbdca2 chore: initial commit of class-team-hub

$ git tag -a v1.0.0 -m "الإصدار الأول: موقع دليل فريق الصف مع 4 بطاقات وسير تحقق تلقائي"
$ git tag -l
v1.0.0

$ git describe --tags
v1.0.0

$ git push origin main
Everything up-to-date

$ git push origin v1.0.0
To https://github.com/school-git-workshop/class-team-hub.git
 * [new tag]         v1.0.0 -> v1.0.0
:::

:::box{type="warn" ar="الوسوم لا تُرفع مع الفروع!" en="Tags are not pushed with branches"}
`git push` يرفع الالتزامات فقط. الوسم يحتاج `git push origin v1.0.0` أو `git push origin
--tags` لرفع كل الوسوم. وهذا أشهر سبب لسؤال: «أنشأت الوسم ولا يظهر على GitHub».
:::

**الخطوة 2 — أنشئ Release على GitHub:**

```text
من صفحة المستودع: Releases ← Draft a new release
Choose a tag: v1.0.0        Target: main
Release title: v1.0.0 — دليل فريق الصف
Describe this release (ملاحظات الإصدار):

  ## الإضافات
  - موقع دليل فريق الصف مع بطاقة لكل عضو.
  - فحص تلقائي للبطاقات والفهرس عند كل طلب سحب.
  - حماية فرع main وملّاك الكود (CODEOWNERS).

  ## الإصلاحات
  - تصحيح نطاق فحص علامات التعارض ليشمل كل الملفات النصية.

  ## ملاحظات الترقية
  - لا يوجد تغيير يكسر التوافق.
```

**الخطوة 3 — أنشئ وسم إصدار ثانٍ ثم افحص الفرق:**

:::term{title="Terminal — وسم لاحق ووصفه"}
$ git tag -a v1.1.0 -m "ميزة الفلترة بالوسوم"
$ git tag -n1
v1.0.0          الإصدار الأول: موقع دليل فريق الصف مع 4 بطاقات وسير تحقق تلقائي
v1.1.0          ميزة الفلترة بالوسوم

$ git push origin v1.1.0
 * [new tag]         v1.1.0 -> v1.1.0

$ git ls-remote --tags origin
1105c78548ddcafca65f03d9ea10f58ecddd0d15        refs/tags/v1.0.0
e20b6644b539bbb22200dde76ea5e5015d826b86        refs/tags/v1.0.0^{}
:::

**أكمل `CHANGELOG.md`:** انقل ما تحت `[Unreleased]` إلى قسم الإصدار بتاريخه، وابدأ قسماً
جديداً فارغاً. هذا ما يفعله أي فريق محترف عند كل إصدار.

:::evidence{ar="دليل المطلوب" en="Evidence"}
- اسم الإصدار: `v……………………` — رابط الإصدار على GitHub: …………………………………………
- الصق مخرجات `git tag -n1`:

```
$ git tag -n1


```
- الصق قسم الإصدار من `CHANGELOG.md` بعد التحديث: …………………………………………
- هل ظهر الوسم على GitHub بعد الدفع؟ ☐ نعم ☐ لا — وإن لا، فما الأمر الذي كان ناقصاً؟ …………
:::

:::band{type="green" ar="أسئلة تحقّق ختامية" en="Final knowledge checks"}
:::

**س1.** ما الفرق بين «حماية الفرع» و«فحص CI» من حيث ما يمنعه كل واحد منهما؟

:::write{n=3 label="إجابتك / Your answer"}
:::

**س2.** طالب قال: «الفحص يمرّ دائماً، إذاً مشروعنا سليم». ما الخلل المنطقي في عبارته؟ وكيف تختبر الفحص؟

:::write{n=3 label="إجابتك / Your answer"}
:::

**س3.** ما الفرق بين وسم بسيط (`git tag v1.0.0`) ووسم مع تعليق (`git tag -a v1.0.0 -m "…"`)؟ وأيّهما يُستحسن للإصدارات؟

:::write{n=3 label="إجابتك / Your answer"}
:::

**س4.** ما فائدة أن يمنع المشروع «الدفع القسري» (Allow force pushes) على `main`؟

:::write{n=3 label="إجابتك / Your answer"}
:::

:::check{ar="قائمة الفحص النهائية" en="Final checklist"}
- [ ] قرأت `validate.yml` وأعرف أحداثه وعدد خطواته
- [ ] شغّلت `node tools/ci-local.mjs` قبل الرفع وأصبحت كل الفحوص ✔
- [ ] جرّبت ثلاث حالات معطوبة وتأكدت أن الفحص يفشل فيها فعلاً
- [ ] أصلحت الأخطاء حتى صار الفحص أخضر على GitHub (وبرابط دليل)
- [ ] حماية الفرع مفعّلة، والفحص المطلوب للدمج محدَّد
- [ ] `CODEOWNERS` مطبَّق، ولاحظت المراجع يُضاف تلقائياً
- [ ] أصدرت `v1.0.0` مع ملاحظات إصدار، وحدّثت `CHANGELOG.md`
:::

:::scale{label="تقييم ذاتي للوحدة المتقدمة / Self-assessment"}
:::

:::evidence{ar="بطاقة التسليم" en="Submission card"}
| البند | القيمة |
|---|---|
| رابط تشغيل ناجح في Actions | `…………………………………` |
| رابط تشغيل فاشل (الحالة المعطوبة) | `…………………………………` |
| رابط الإصدار | `…………………………………` |
| هل أنشأت فرعاً للتجربة (تجربة الجودة)؟ | ☐ نعم ☐ لا |
| أصعب فحص فهمته ولماذا؟ | ………………………………… |
| الوقت المستغرق | ………… |
:::

:::box{type="ok" ar="ما بعد الأتمتة؟" en="What comes after automation"}
أصبح مشروعك الآن: بطاقات موثّقة، وفحص آلي، وحماية فرع، وإصدار مرقّم. الخطوة التالية
مهنياً هي **المراقبة والتحسين**: قياس زمن الفحص، وتقليل تكرار الأعطال بنوع واحد (مثل
خطأ JSON)، وإضافة فحص جديد لكل عطل يتكرر مرتين — هذا هو جوهر التحسين المستمر
(Continuous Improvement).
:::

:::badge{ar="أتممت الوحدة المتقدمة — مستوى عمل الفريق الهندسي ✓" type="green"}
:::
