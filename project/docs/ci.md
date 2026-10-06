# الأتمتة في المشروع | Project automation

## 1) الفحص التلقائي (CI) — `.github/workflows/validate.yml`

يعمل هذا الملف تلقائياً على GitHub في ثلاث حالات:

| الحدث / Event | متى يقع | ما يفحصه |
|---|---|---|
| `pull_request` إلى `main` | عند فتح أو تحديث طلب سحب | الفهرس محدَّث + البطاقات صحيحة + لا علامات تعارض |
| `push` إلى `main` | بعد الدمج | نفس الفحوص على النسخة النهائية |
| `workflow_dispatch` | يدوياً من تبويب Actions | نفس الفحوص عند الحاجة |

### ما يفحصه بالتفصيل

```bash
node tools/build-index.mjs --check     # هل الفهرس يطابق ملفات البطاقات فعلاً؟
node tests/validate-members.mjs        # الحقول الإلزامية، اسم المستخدم، طول الرسالة، منع البيانات الحساسة
grep -rInE "^(<{7}|={7}|>{7})( |$)" --exclude-dir=.git .   # آثار تعارض دُمجت بالخطأ
```

**:الحكم / The verdict:** إذا فشل أي فحص، يظهر ❌ بجانب اسم الفحص في طلب السحب ولا يُسمح
بالدمج (إن كانت حماية الفرع تطلب نجاح الفحوص). إذا نجحت كلها يظهر ✅ أخضر.

### تشغيل نفس الفحوص محلياً قبل الرفع (وفّر وقت المراجع)

```bash
node tools/build-index.mjs --check
node tests/validate-members.mjs
git diff --check
```

> نصيحة: اجعل هذه الأسطر الثلاثة عادة قبل كل `git push`. الطالب الذي يفحص محلياً لا
> يُفاجأ بفحص أحمر على GitHub، ولا يُعطّل مراجعة زملائه.

## 2) مُلّاك الكود — `.github/CODEOWNERS`

يحدّد هذا الملف **من يجب أن يراجع أي ملف**. عند فتح طلب سحب يعدّل ملفاً مشتركاً، يضيف
GitHub صاحب الملف في قائمة المراجعين تلقائياً.

| الملف / المسار | المالك | لماذا؟ |
|---|---|---|
| `data/site-config.json` | قائد الفريق | إعدادات الموقع يراها كل الزوار |
| `js/` و`css/` | قائد الفريق | كود الواجهة يؤثر على كل البطاقات |
| `tools/` و`tests/` | قائد الفريق | أدوات الفحص تحمي جودة الجميع |
| `docs/` | قائد الفريق | التوثيق مصدر مشترك |
| `data/members/<username>.json` | الطالب نفسه | كل طالب مسؤول عن بطاقته وحدها |

## 3) حماية الفرع — Branch protection

`Settings ← Branches ← Add branch protection rule` ثم اختر الفرع `main` وفعّل:

- ✅ **Require a pull request before merging** (واحد مراجع على الأقل)
- ✅ **Require approvals: 1**
- ✅ **Dismiss stale pull request approvals when new commits are pushed**
- ✅ **Require status checks to pass before merging** ← اختر الفحص: `validate / فحص البطاقات والفهرس`
- ✅ **Require conversation resolution before merging**
- ✅ **Do not allow bypassing the above settings**
- ❌ **Allow force pushes** (اتركه معطّلاً دائماً)

## 4) الإصدارات — Releases & tags

| المفهوم | المعنى | الأمر |
|---|---|---|
| Tag | نقطة مرجعية دائمة في التاريخ | `git tag -a v1.0.0 -m "…"` |
| Release | بطاقة إصدار على GitHub مع ملاحظات وملفات مرفقة | من تبويب Releases أو `gh release create` |
| SemVer | نظام ترقيم دلالي `major.minor.patch` | `v1.0.0` · `v1.1.0` · `v2.0.0` |

قاعدة الترقيم في مشروعنا:
- **patch** (`v1.0.1`): إصلاح خطأ في بطاقة أو تنسيق.
- **minor** (`v1.1.0`): ميزة جديدة متوافقة (مثل فلترة بالوسوم).
- **major** (`v2.0.0`): تغيير يوقف التوافق (مثل تغيير صيغة ملفات البطاقات).

## 5) الخطافات المحلية (اختياري للمتقدّمين)

| الأداة | الفائدة | مثال |
|---|---|---|
| Husky | تشغيل الفحص قبل كل التزام محلياً | `npx husky init` ثم أضف `npm test` |
| pre-commit | إطار خطافات متعدد اللغات | `.pre-commit-config.yaml` |
| EditorConfig | توحيد المسافات وتشفير الملفات | ملف `.editorconfig` في الجذر |

> الخطاف المحلي **ليس بديلاً** عن CI: الخطاف يمكن تجاوزه (`--no-verify`)، أما CI فيعمل
> على الخادم ولا يمكن تجاوزه إلا بتعديل ملف سير العمل نفسه — وهذا ما يجعله خط الدفاع
> الأخير في أي فريق.
