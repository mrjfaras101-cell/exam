# دليل المساهمة | Contributing guide

## 1) قبل أن تبدأ / Before you start

```bash
git switch main
git pull --ff-only
git switch -c feature/<github-username>-<short-topic>
```

أمثلة على أسماء الفروع / branch naming:
- `feature/sara-card` — إضافة بطاقة
- `docs/omar-readme-faq` — تحديث التوثيق
- `fix/leen-search-filter` — إصلاح خطأ

## 2) قواعد الالتزام / Commit rules

صيغة Conventional Commits:

```
<type>(<scope>): <short description>
```

| type | الاستخدام / Use for |
|---|---|
| `feat` | ميزة جديدة / new feature |
| `fix` | إصلاح خطأ / bug fix |
| `docs` | توثيق فقط / documentation |
| `style` | تنسيقات لا تغيّر السلوك / formatting |
| `refactor` | إعادة هيكلة بلا تغيير سلوك |
| `chore` | مهام صيانة (فهرس، إعدادات) |
| `test` | إضافة أو تعديل اختبارات |

أمثلة صحيحة:
```
feat(members): add card for sara-dev
fix(ui): correct RTL alignment in member card
docs(readme): add troubleshooting section
```

أمثلة خاطئة: `update`, `changes`, `final`, `work`, `asdf`.

## 3) قبل الدفع / Before pushing

```bash
node tests/validate-members.mjs      # يجب أن ينجح بدون أخطاء
git status                           # تأكد أنك لا ترفع ملفات غريبة
git diff main..HEAD --stat           # راجع ما ستغيّره فعلاً
```

## 3.5) الفحص التلقائي (CI) / Automated checks

كل طلب سحب يشغّل تلقائياً الفحوص التالية على GitHub. **لا يُدمج طلب بفحص فاشل:**

```bash
node tools/build-index.mjs --check
node tests/validate-members.mjs
grep -rInE "^(<{7}|={7}|>{7})( |$)" --exclude-dir=.git .   # لا علامات تعارض
```

شغّلها محلياً بنفس الترتيب قبل الرفع — أرخص من انتظار GitHub ثم التصحيح.

## 4) طلب السحب / Pull request

- العنوان بنفس صيغة رسالة الالتزام.
- املأ قالب طلب السحب كاملاً.
- اربط المشكلة: `Closes #12`.
- اطلب مراجعة من زميل واحد على الأقل.

## 5) الدمج / Merge

- استخدام **Squash and merge** للفروع الصغيرة (بطاقة واحدة = التزام واحد نظيف).
- لا تدمج قبل أن يصبح الفحص التلقائي ✅ أخضر جميع البنود.
- لا تدمج فرعك بنفسك قبل حصولك على موافقة مراجع واحد.
- بعد الدمج: احذف الفرع وحدّث `main`.

```bash
git switch main
git pull --prune
git branch -d feature/<your-branch>
```

## 5.5) الإصدارات / Releases

نصدر نسخة عند كل معلم مهم في المشروع:

```bash
git switch main && git pull
git tag -a v1.1.0 -m "feat: tag filtering for member cards"
git push origin v1.1.0
```

ثم أنشئ إصداراً على GitHub (تبويب Releases) مع ملاحظات مختصرة، وحدّث `CHANGELOG.md`.

## 6) قواعد لا تُخالف / Never do this

1. لا `git push --force` على `main` أو على فرع زميل.
2. لا تعدّل ملفاً لا يخص مهمتك في نفس الفرع.
3. لا ترفع كلمات مرور أو رموز وصول (tokens) أو ملفات `.env`.
4. لا تحذف ملفات زملائك ولا تعطّل الاختبارات لإخفاء خطأ.
