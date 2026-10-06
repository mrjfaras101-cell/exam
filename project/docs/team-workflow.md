# سير عمل الفريق | Team workflow

## نموذج الفروع / Branch model

```text
                      ┌── feature/sara-card ──┐
                      │   (بطاقة سارة)        │
main ──●──────────────┴───────────────────────┴──●──────●──────►
       │  ↑                                    ↑  ↑      ↑
       │  └── PR + مراجعة ─────────────────────┘  │      │
       │                                          │      │
       └── feature/omar-readme ──●────────────────┘      │
                                  (تحديث التوثيق)        │
                                                         │
                          fix/leen-search-filter ────────┘
```

## المراحل الست / Six phases

### 1. المزامنة / Sync
```bash
git switch main
git pull --ff-only
```
> ابدأ دائماً من `main` محدَّث. لو بدأت من نسخة قديمة فستصنع تعارضاً بنفسك بلا داعٍ.

### 2. الفرع / Branch
```bash
git switch -c feature/<username>-<topic>
git branch --show-current          # تأكد أنك على فرعك
```

### 3. التنفيذ / Implement
- عدّل ملفاً واحداً منطقياً فقط.
- `git status` بعد كل خطوة، و`git diff` قبل الإضافة.
- التزم على دفعات صغيرة:
```bash
git add data/members/<username>.json
git commit -m "feat(members): add card for <username>"
```

### 4. الرفع / Push
```bash
git push -u origin feature/<username>-<topic>
```

### 5. طلب السحب والمراجعة / Pull request + review
- افتح طلب سحب إلى `main` واملأ القالب.
- المراجع يكتب تعليقاً واحداً على الأقل: سؤال، ملاحظة، أو موافقة مسبَّبة.
- لا يُدمج أي طلب سحب بلا موافقة صريحة.

### 6. الدمج ثم التنظيف / Merge & cleanup
```bash
git switch main
git pull --prune
git branch -d feature/<username>-<topic>
```

## كيف يرى كل طالب تعديلات زملائه؟ / Seeing teammates' changes

| الطريقة / Way | الأمر / Command | متى تستخدمها / When |
|---|---|---|
| شجرة الفروع | `git log --oneline --graph --all --decorate` | لرؤية شكل التاريخ والفروع |
| ما سيدخل `main` | `git diff main..origin/feature/x` | قبل الدمج |
| من عدّل ماذا | `git shortlog -sn --all` | تقرير الفريق |
| من كتب سطراً | `git blame data/members/x.json` | عند التحقيق في خطأ |
| مقارنة فرعين | `git diff feature/a feature/b` | عند تشابه الملفات |
| تاريخ ملف واحد | `git log -p -- data/members/x.json` | متابعة تطور ملف |
| طلب سحب لا يُدمج | `git fetch origin pull/12/head:pr-12` | تجربة PR زميل محلياً |

## استراتيجيات الدمج الثلاث / Three merge strategies

| الاستراتيجية | متى / When | الأثر على التاريخ |
|---|---|---|
| **Merge commit** | فرع طويل بمهام متعددة | يحفظ كل الالتزامات + عقدة دمج |
| **Squash and merge** | بطاقة واحدة أو إصلاح صغير | التزام واحد نظيف على `main` |
| **Rebase and merge** | تاريخ خطّي بلا عقد دمج | التزامات مرتّبة بلا فوضى |

**الخطأ الشائع:** إعادة تشكيل (rebase) لفرع **مشترك** يعمل عليه زميل. القاعدة:
`rebase` للفروع الشخصية فقط، و`merge` للفروع المشتركة.

## قواعد ذهبية / Golden rules

1. `main` محمي دائماً: لا دفع مباشر، ولا `--force`.
2. فرع واحد = مهمة واحدة.
3. مزامنة قبل العمل، واختبار قبل الدفع.
4. الملفات المُولَّدة (الفهرس) تُعاد توليدها ولا تُحلّ يدوياً.
5. المراجعة قبل الدمج، والوصف في كل طلب سحب.
