# ورقة المرجع السريع لأوامر Git | Git command cheat sheet

## الإعداد لمرة واحدة / One-time setup

```bash
git --version
git config --global user.name  "الاسم الكامل"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
git config --global pull.rebase true
git config --global core.editor "code --wait"      # اختياري
git config --list                                   # مراجعة الإعدادات
git config --global --unset user.email              # حذف إعداد خاطئ
```

## المستودع / Repository

```bash
git clone https://github.com/<ORG>/class-team-hub.git
git init                        # إنشاء مستودع جديد محلياً
git status                      # الحالة الحالية
git status -s                   # مختصرة
git remote -v                   # المستودعات البعيدة
git remote add origin <URL>
```

## المرحلة الانتقالية / Staging & committing

```bash
git add <file>                  # إضافة ملف
git add .                       # إضافة كل التغييرات
git add -p                      # إضافة مقاطع مختارة
git restore --staged <file>     # إخراج ملف من المرحلة (unstage)
git restore <file>              # التراجع عن تعديل غير مُلتزم (يحذف التعديل!)
git commit -m "feat: ..."
git commit -am "fix: ..."       # إضافة + التزام للملفات المتتبَّعة
git commit --amend              # تعديل آخر التزام (قبل الدفع فقط)
```

## الفروع / Branches

```bash
git branch                      # الفروع المحلية
git branch -a                   # كل الفروع (محلية وبعيدة)
git switch -c feature/x         # إنشاء فرع والانتقال إليه
git switch main                 # الانتقال إلى فرع موجود
git branch -d feature/x         # حذف فرع مدموج
git branch -D feature/x         # حذف فرع غير مدموج (حذر!)
git branch -m new-name          # إعادة تسمية الفرع الحالي
git merge feature/x             # دمج فرع في الفرع الحالي
git rebase main                 # إعادة تشكيل فرعك فوق main
```

## المزامنة / Sync

```bash
git pull                        # جلب + دمج
git pull --rebase               # جلب + إعادة تشكيل (تاريخ أنظف)
git fetch origin                # جلب بلا دمج
git push                        # رفع الالتزامات
git push -u origin <branch>     # رفع فرع جديد وربطه
git push --force-with-lease     # دفع آمن بعد إعادة التشكيل (لفرعك فقط!)
```

## الفحص والمقارنة / Inspect & diff

```bash
git log --oneline --graph --all --decorate    # شجرة الفروع
git log -3 --stat                             # آخر 3 التزامات مع الملفات
git show <sha>                                # تفاصيل التزام
git diff                                      # تعديلات لم تُمرَّر للمرحلة
git diff --staged                             # تعديلات مُمرَّرة
git diff main..HEAD --stat                    # ما سيُدمج فعلاً
git blame <file>                              # من كتب كل سطر
git shortlog -sn                              # ترتيب المساهمين
```

## التراجع / Undo (الأهم)

| الحالة / Situation | الأمر / Command |
|---|---|
| تعديل ملف لم يُمرَّر للمرحلة | `git restore <file>` |
| ملف مُمرَّر للمرحلة بالخطأ | `git restore --staged <file>` |
| آخر التزام لم يُرفع | `git reset --soft HEAD~1` |
| آخر التزام ويُحذف تعديله أيضاً | `git reset --hard HEAD~1` |
| التزام مرفوع ويراد إلغاؤه بأمان | `git revert <sha>` |
| حفظ العمل مؤقتاً | `git stash` ثم `git stash pop` |
| استرجاع ملف من التزام سابق | `git checkout <sha> -- <file>` |

> `--hard` و`checkout <file>` **تحذف عملك** بلا رجعة. تأكد من `git status` أولاً.

## حل التعارض / Conflict resolution

```bash
git status                       # الملفات المتعارضة
git diff --name-only --diff-filter=U
# عدّل الملف: احذف <<<<<<< ======= >>>>>>> واترك النتيجة النهائية
git add <file>
git merge --continue             # أو git rebase --continue أو git commit
git merge --abort                # إلغاء الدمج والعودة لما قبل
git rebase --abort               # إلغاء إعادة التشكيل
```

## المستودعات البعيدة والنسخ / Remotes & forks

```bash
git remote add upstream https://github.com/<OWNER>/<REPO>.git
git fetch upstream
git switch main && git merge upstream/main
gh repo fork <OWNER>/<REPO> --clone      # مع GitHub CLI
```

## التنظيف / Cleanup

```bash
git clean -nd                    # معاينة ما سيُحذف (جاف)
git clean -fd                    # حذف الملفات غير المتتبَّعة (حذر!)
git gc --prune=now               # ضغط المستودع
git remote prune origin          # حذف مراجع الفروع البعيدة المحذوفة
```
