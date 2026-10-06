# حلّ المشكلات الشائعة | Troubleshooting playbook

## 1. الأخطاء عند الرفع / Push errors

### `! [rejected] main -> main (fetch first)`
**السبب:** الفرع البعيد يحتوي التزامات لا تملكها.
```bash
git pull --rebase origin main
git push
```

### `! [rejected] ... (non-fast-forward)`
**السبب:** تاريخك مختلف عن التاريخ البعيد (غالباً بعد إعادة تشكيل).
```bash
git fetch origin
git rebase origin/main          # إن كان فرعك الشخصي فقط
git push --force-with-lease     # على فرعك، وليس main
```

### `fatal: refusing to merge unrelated histories`
```bash
git pull --allow-unrelated-histories
```
> هذه القاعدة تحمي المستودعات غير المرتبطة، استخدمها فقط عند التأكد.

### `Please tell me who you are` / `Author identity unknown`
```bash
git config --global user.name "الاسم الكامل"
git config --global user.email "you@example.com"
```

### `remote: Support for password authentication was removed`
**السبب:** GitHub لم يعد يقبل كلمة المرور العادية.
**الحل:** استخدم رمز وصول شخصي (PAT) ككلمة مرور، أو مفتاح SSH، أو GitHub Desktop، أو `gh auth login`.

### `Permission denied (publickey)` مع SSH
```bash
ssh-keygen -t ed25519 -C "you@example.com"
cat ~/.ssh/id_ed25519.pub         # انسخ المفتاح العام إلى GitHub
ssh -T git@github.com             # اختبار الاتصال
```

## 2. أخطاء الفروع والدمج / Branch & merge errors

### `error: Your local changes would be overwritten by merge`
```bash
git stash                          # احفظ عملك مؤقتاً
git merge main
git stash pop                      # أعده بعد الدمج
```

### `error: The branch 'feature/x' is not fully merged`
```bash
git branch -D feature/x            # حذف قسري بعد التأكد من أن عملك لم يُفقد
```

### `You have divergent branches and need to specify how to reconcile`
```bash
git config --global pull.rebase true     # اختيار سلوك دائم
git pull --rebase
```

### دمجتُ بالخطأ وما زال الالتزام غير مرفوع
```bash
git merge --abort                  # إن كان الدمج ما زال جارياً
git reset --hard ORIG_HEAD         # إلغاء آخر عملية دمج
```

## 3. مشكلات الصفحة نفسها / Site issues

| العرض / Symptom | السبب المرجّح | الحل |
|---|---|---|
| الصفحة تفتح لكن لا تظهر بطاقات | `fetch` ممنوع على `file://` | شغّل `python3 -m http.server 8000` ثم افتح `localhost:8000` |
| بطاقة طالب لا تظهر | اسم الملف غير مُفهرس | `node tools/build-index.mjs` ثم تحديث الصفحة بـ `Ctrl+Shift+R` |
| ظهور بطاقة باسم خطأ أو حقل فارغ | JSON غير صالح أو حقل مفقود | `node tests/validate-members.mjs` |
| كانت تعمل بالأمس وتوقفت | تعارض دُمج بشكل خاطئ (علامات `<<<<<<<` باقية) | ابحث عن `<<<<<<<` في الملفات: `grep -rn "<<<<<<<" .` |
| التعديلات لا تصل إلى زميلك | لم يرفع / لم يدمج | `git log --oneline main..origin/master` وافتح طلب سحب |

## 4. رسائل تشخيص سرية / Quick diagnostics

```bash
git status -sb                     # أين أنا وما الحالة؟
git log --oneline -5               # آخر التزامات
git branch -vv                     # تتبّع الفروع البعيد
git remote -v                      # هل الوجهة صحيحة؟
git config --list --show-origin    # من أين جاء كل إعداد؟
git diff --check                   # هل بقي وسم تعارض؟
git fsck --lost-found              # ابحث عن أعمال مفقودة
git reflog                         # كل حركات HEAD (شبكة الأمان الأخيرة)
```

> **قاعدة النجاة:** `git reflog` + `git reset --hard <sha>` يستطيعان إنقاذ أي عمل
> مُلتزم — حتى بعد `reset --hard` خاطئ. لذلك: **التزم كثيراً وبسرعة**.
