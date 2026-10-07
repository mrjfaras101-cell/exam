---
{
  "deck": "الجلسة 04 — المزامنة والدمج",
  "kicker": "ورشة GIT وGITHUB — البرنامج التدريبي العملي",
  "footer": "ورشة Git وGitHub · الجلسة 04 — المزامنة والدمج"
}
---

:::slide{layout="title" title="مزامنة الفريق: كيف أرى تعديلات زملائي؟" subtitle="Session 04 · Sync, Merge & Undo" kicker="ورشة GIT وGITHUB"}
:::


:::notes
الزمن: عرض 10 د — تنفيذ 55 د — مناقشة تاريخ المشروع 25 د.
الهدف: مزامنة main + تجربة الاستراتيجيات الثلاث + إتقان التراجع الآمن (restore / restore --staged / amend / revert / stash / reflog).
نقاط التركيز: (1) fetch يقرأ، pull ينفّذ — والفرق خطوة واحدة. (2) القراءة في git status: ahead / behind / diverged. (3) القاعدة: rebase للفروع الشخصية، merge للمشتركة. (4) على التاريخ المشترك استخدم revert لا reset --hard.
اعرض على الشاشة جدول الحالة ← الأمر السليم، ثم اطلب من 3 متدرّبين تنفيذ حالة مختارة أمام الفصل.
الرسالة الأخيرة: التاريخ الذي يدمره إنسان لا يعود — reflog محلي فقط، فلا تبني اعتماداً عليه.
:::

:::slide{title="سؤال كل فريق مبتدئ"}
- «زميلي أضاف تعديلاً… وأنا لا أراه!» — لماذا؟
- ثلاثة أسباب شائعة: لم يرفع (`push`)، أو رفع على فرع لم يُدمج، أو نسختك لم تُحدَّث (`pull`)
- اليوم نتقن الطرف الثالث ونفهم كيف يعمل الدمج فعلاً
- ونضيف مهارة أهم: **التراجع الآمن** عندما يفسد شيء

:::callout{type="info"}
هدف اليوم ليس تنفيذ أوامر، بل **قراءة** مخرجاتها: أين أنا؟ ما الجديد؟ ما الفرق؟ من فعل هذا؟
:::
:::

:::slide{title="fetch مقابل pull — الفرق في خطوة"}
:::img{name="fetch-vs-pull"}
:::
:::

:::slide{title="المهمة 1 — اعرف أين أنت قبل أن تدمج"}
:::code
$ git switch main
$ git fetch origin
remote: Enumerating objects: 9, done.
From https://github.com/<org>/class-team-hub
   a1b2c3d..f9e8d7c  main       -> origin/main

$ git status -sb
## main...origin/main [behind 2]

$ git log --oneline HEAD..origin/main
f9e8d7c feat(members): add card for leen-docs
3c7d9e1 Merge pull request #7 from nour-dev/feature/nour-card
:::

- `behind 2` = عند الزملاء التزامان لم تجلبهما بعد
- العادة الاحترافية: افحص بـ fetch ثم اقرأ، ثم ادمج بوعي
:::

:::slide{title="حالات ستراها كثيراً"}
:::table
| الحالة في git status | المعنى | الأمر السليم |
| ahead 2 | عندك التزامات غير مرفوعة | git push |
| behind 3 | عند الزملاء التزامات لم تجلبها | git pull --ff-only |
| ahead 1, behind 3 | التاريخان افترقا | git pull --rebase |
| diverged | افتراق ثم محاولة دفع | pull --rebase ثم push |
:::

:::callout{type="tip"}
تصفية الحالة: `git status -sb` — سطر واحد يخبرك بكل شيء، قبل أي أمر آخر.
:::
:::

:::slide{title="المهمة 2 — أنواع الدمج الثلاثة"}
:::code
# 1) دمج سريع (لا عمل متبادل):
$ git merge --ff-only origin/main
Updating a1b2c3d..f9e8d7c
Fast-forward

# 2) دمج بعقدة (عمل متبادل):
$ git merge feature/omar-qa-card
Merge made by the 'ort' strategy.
 1 file changed, 9 insertions(+)

# 3) الدمج المضغوط:
$ git merge --squash feature/sara-fixes
Squash commit -- not updating HEAD
$ git commit -m "feat(ui): improve member card layout (#9)"
:::
:::

:::slide{title="أي استراتيجية نختار؟"}
:::table
| الاستراتيجية | شكل التاريخ | متى نستخدمها |
| Merge commit | فروع وعُقد واضحة | فرع طويل بمهام متعددة |
| Squash and merge | التزام واحد نظيف | فرع صغير أو إصلاحات متتابعة |
| Rebase and merge | خط مستقيم بلا عُقد | تاريخ خطّي للمراجعة |
:::

:::callout{type="rule"}
القاعدة: **rebase للفروع الشخصية فقط، merge للفروع المشتركة.** إعادة تشكيل فرع يعمل عليه زميل تُتلف عمله.
:::
:::

:::slide{title="المهمة 4 — افحص تعديلات زملائك"}
:::code
$ git log --oneline --all --graph --decorate -8   # شجرة الفريق
$ git log -p -- data/members/leen-docs.json       # تاريخ ملف واحد
$ git blame data/members/leen-docs.json           # من كتب كل سطر
$ git shortlog -sn --all                          # ترتيب المساهمين
$ git diff main..feature/x --stat                 # ما سيدخل فعلاً
:::

- سؤال: أي ملف عدّله **كل** الأعضاء؟ الجواب: `data/members-index.json`
- ولهذا هو مُولَّد آلياً: لا يُكتب يدوياً ولا يُحلّ تعارضه يدوياً
:::

:::slide{title="المهمة 5 — مختبر التراجع الآمن"}
:::table
| الحالة | الأمر الصحيح | يحذف عملاً؟ |
| تعديل غير مُلتزم | git restore &lt;file&gt; | نعم (هو المقصود) |
| ملف مُمرَّر للمرحلة خطأً | git restore --staged &lt;file&gt; | لا |
| آخر التزام لم يُرفع | git commit --amend | لا |
| التزام مرفوع خاطئ | git revert &lt;sha&gt; | لا (يعكسه) |
| تبديل فرع وعملك ناقص | git stash ثم git stash pop | لا |
| حذفت شيئاً ولا تدري | git reflog ثم switch -c rescue | لا |
:::
:::

:::slide{title="لماذا revert لا reset على التاريخ المشترك؟"}
:::code
$ git revert --no-edit 8de1e7a
[main 6f7e8d9] Revert "feat(ui): change card colors"

$ git log --oneline -3
6f7e8d9 (HEAD -> main) Revert "feat(ui): change card colors"
2b3c4d5 docs(readme): add FAQ section
8de1e7a feat(ui): change card colors
:::

- `revert` ينشئ التزاماً جديداً يعكس الأول ← التاريخ يبقى صحيحاً لكل من سحب المشروع
- `reset --hard` يحذف الالتزامات ← من بنى عليها عملاً ينهار مشروعه
:::

:::slide{title="شبكة الأمان الأخيرة: reflog"}
:::code
$ git reflog -5
6f7e8d9 HEAD@{0}: revert: Revert "feat(ui): change card colors"
2b3c4d5 HEAD@{1}: commit (amend): docs(readme): add FAQ section
1e1682a HEAD@{2}: commit: docs(readme): add faq
5aaeef2 HEAD@{3}: reset: moving to origin/main

$ git switch -c rescue 5aaeef2      # استرجاع أي حالة سابقة
:::

:::callout{type="tip"}
`reflog` سجل **محلي** لا يُرفع إلى GitHub — فهو ينقذك على جهازك، لكنه لا ينقذ زميلاً على جهاز آخر.
:::
:::

:::slide{title="المهمة 6 — نظّف فروعك بأمان"}
:::code
$ git branch --merged main        # الفروع التي اندمج عملها فعلاً
  feature/ali-card
  feature/leen-card
* main

$ git branch -d feature/ali-card feature/leen-card
Deleted branch feature/ali-card (was 1a2b3c4).

$ git fetch --prune
 - [deleted]         (none)     -> origin/feature/ali-card
:::

:::callout{type="warn"}
احذف الفروع المدموجة فقط. الفرع غير المدموج يحتاج `-D` (حذف قسري) — لا تستخدمه إلا بعد التأكد أن عملك محفوظ أو مرفوع.
:::
:::

:::slide{title="قبل الجلسة القادمة"}
- `main` عندك محدَّث ومساوٍ لـ `origin/main`
- نفّذت الدمج بالاستراتيجيات الثلاث وتعرف الفرق بينها عملياً
- جرّبت `stash` و`amend` و`revert` و`reflog`
- تقرير الفريق مملوء بالأرقام الحقيقية من المستودع
- الجلسة القادمة: **التعارضات والنشر** — سنصنع تعارضاً عن قصد ونحلّه، ثم ننشر الموقع للعالم

:::callout{type="ok"}
تذكّر: التعارض ليس خطأً. هو رسالة من Git تقول «هنا تعديلان، اختر أنت» — والجلسة القادمة تجعل هذا الاختيار سهلاً.
:::
:::
