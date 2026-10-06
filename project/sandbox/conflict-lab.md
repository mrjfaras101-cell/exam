# مختبر التعارض — Conflict Lab

> هذا الملف مخصّص للتجارب الآمنة. الهدف: **أن تسبّب تعارضاً عن قصد، ثم تحلّه بثقة.**

## التمرين أ: تعارض في سطر واحد / Single-line conflict

الفريق كله يعدّل السطر التالي. اكتب اسمك في نهاية السطر ضمن فرعك الخاص:

> **شعار الفريق:** «نتعلّم معاً، ونرفع معاً» — أعضاء الفريق:

الطريقة / How to:
```bash
git switch main && git pull
git switch -c feature/<username>-slogan
# عدّل السطر أعلاه وأضف اسمك في نهايته
git commit -am "docs(slogan): add <username> to the team slogan"
git push -u origin feature/<username>-slogan
# افتح طلب سحب وادمجه / open a PR and merge it
```
بعد دمج أول طالب، سيصبح دمج الثاني **متعارضاً**. هذا مقصود — انتقل إلى القسم «حل التعارض» أدناه.

## التمرين ب: تعارض في ملف مُولَّد / Generated-file conflict

`data/members-index.json` ملف يُعاد توليده آلياً. إن تعارض:

```bash
node tools/build-index.mjs          # 1) أعد التوليد — هذا هو الحل الصحيح
git add data/members-index.json data/members-bundle.js
git commit -m "chore(index): regenerate members index"
git rebase --continue               # أو git commit إن كنت في merge
```

**القاعدة:** لا تحلّ تعارض ملف مُولَّد يدوياً أبداً — أعد توليده.

## التمرين ج: تعارض في ملفين متجاورين (بلا تعارض فعلي)

طالبان يضيفان بطاقتين مختلفتين في مجلد `data/members/`. النتيجة: Git يدمجهما تلقائياً.
سجّل ما تراه:

- هل ظهر التعارض؟ / Conflict appeared?
- من حلّ الدمج؟ / Who resolved it?

```bash
git log --oneline --graph --all           # افحص شكل التاريخ / inspect the graph
git diff main..HEAD -- data/members/      # ما الذي سيدخل فعلاً؟
```

## خطوات حل أي تعارض / The 5-step resolution

1. **اقرأ الرسالة:** `CONFLICT (content): Merge conflict in <file>`
2. **اعرض الملفات المتعارضة:** `git status`
3. **افتح الملف وابحث عن العلامات:** `<<<<<<<` و `=======` و `>>>>>>>`
4. **اختر النتيجة النهائية** واحذف العلامات الثلاث تماماً، ثم:
   ```bash
   git add <file>
   git rebase --continue      # أو git merge --continue  /  أو git commit
   ```
5. **تحقق ثم ارفع:**
   ```bash
   node tests/validate-members.mjs
   git push --force-with-lease origin <your-branch>
   ```

## حل بديل سريع / Fast alternative

```bash
# ابدأ من جديد فوق آخر نسخة من main ثم انقل تعديلك الوحيد
git fetch origin
git reset --hard origin/main
git cherry-pick <commit-sha>
```

## تحذير / Warning

`git push --force` يحذف تاريخ الآخرين عند رفعه على `main`. استخدم دائماً:
`git push --force-with-lease` وعلى **فرعك فقط**.
