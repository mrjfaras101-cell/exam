# دليل فريق الصف — Class Team Hub

> **مشروع تدريبي عملي لورشة Git وGitHub**
> A practice repository for the Git & GitHub classroom workshop.

موقع ويب بسيط (HTML + CSS + JavaScript) يعرض بطاقة تعريف لكل طالب في الفريق، ويُبنى
بالتعاون: كل طالب يضيف بطاقته على فرع (branch) خاص به، ثم يدمجها في `main` عبر
طلب سحب (Pull Request). المشروع لا يحتاج أي تثبيت برامج لتشغيله — يكفي فتح
`index.html` في المتصفح.

A simple static website (HTML + CSS + JS) that displays a profile card for every
student in the class. Each student contributes from their own branch and merges
through a Pull Request. No build step, no dependencies: just open `index.html`.

---

## 1) ما هو هذا المشروع؟ | What is this project?

| العنصر / Item | الوصف / Description |
|---|---|
| الاسم / Name | `class-team-hub` — دليل فريق الصف |
| النوع / Type | موقع ثابت (Static site): HTML + CSS + JavaScript |
| التشغيل / Run | افتح `index.html` مباشرة بالمتصفح — أو استخدم GitHub Pages |
| المحتوى / Content | `data/site-config.json` + بطاقة لكل طالب في `data/members/` |
| الأدوات / Tools | Git, GitHub, VS Code (اختياري: GitHub Desktop, Node.js للتحقق) |

## 2) الملفات المهمة | Key files

```text
class-team-hub/
├── index.html              الصفحة الرئيسية / main page
├── css/style.css           التنسيقات / styles
├── js/app.js               قراءة البيانات وبناء الصفحة / data loading + rendering
├── data/
│   ├── site-config.json    إعدادات الموقع المشتركة (ملف حساس للتعارض) / shared config
│   ├── members-index.json  فهرس أسماء البطاقات (يُحدَّث تلقائياً) / generated index
│   ├── members/            بطاقة واحدة لكل طالب / one card file per student
│   └── schedule.md         جدول جلسات الورشة / workshop schedule
├── sandbox/
│   ├── conflict-lab.md     مختبر تمارين التعارض / conflict practice lab
│   └── team-slogan.txt     شعار الفريق (سطر واحد يعدّله الجميع) / shared one-liner
├── tools/build-index.mjs   إعادة توليد الفهرس تلقائياً / regenerate the index
├── tests/validate-members.mjs  فحص صحة بطاقات الأعضاء / validate member cards
└── docs/                   أوراق مرجعية / reference docs
```

## 3) البدء السريع | Quick start

```bash
# 1. انسخ المستودع إلى جهازك / clone the repository
git clone https://github.com/<ORG>/class-team-hub.git
cd class-team-hub

# 2. شغّل الموقع: افتح index.html في المتصفح / open the site
#    (لا حاجة لأي تثبيت — no installation required)

# 3. تحقق من صحة بياناتك (اختياري، يحتاج Node.js)
node tests/validate-members.mjs
```

## 4) سير العمل المعتمد | Team workflow

1. **حدّث فرعك من المصدر** — `git switch main && git pull`
2. **أنشئ فرعاً باسم واضح** — `git switch -c feature/<github-username>-card`
3. **عدّل ملفاً واحداً تقريباً لكل فرع** واحفظ رسائل التزام واضحة (Conventional Commits)
4. **ارفع فرعك** — `git push -u origin feature/<github-username>-card`
5. **افتح طلب سحب (Pull Request)** واطلب مراجعة من زميل
6. **بعد الدمج، احذف الفرع وحدّث `main`** — `git switch main && git pull`

> القاعدة الذهبية: **لا تعمل مباشرة على `main` أبداً**. الفرع المحمي (Protected branch)
> يمنع الدفع المباشر، فلا بد من طلب سحب ومراجعة.

## 5) طريقة إضافة بطاقتك | How to add your card

1. انسخ الملف `data/members/00-template.json` إلى ملف جديد باسم مستخدمك:
   `data/members/<github-username>.json`
2. املأ الحقول الخمسة الإلزامية: `fullName`, `github`, `role`, `favoriteCommand`, `message`
3. أضف اسم ملفك إلى `data/members-index.json` **أو** شغّل:
   `node tools/build-index.mjs`
4. تحقق ثم التزم وارفع:
   ```bash
   node tests/validate-members.mjs
   git add data/members data/members-index.json
   git commit -m "feat(members): add card for <github-username>"
   git push -u origin feature/<github-username>-card
   ```

## 6) الأخطاء الشائعة | Troubleshooting

| المشكلة / Problem | الحل / Fix |
|---|---|
| البطاقة لا تظهر في الصفحة | تأكد من إضافة اسم الملف إلى `data/members-index.json` ثم أعد تحميل الصفحة (Ctrl+Shift+R) |
| الصفحة فارغة تماماً | افتح `index.html` عبر خادم محلي: `python3 -m http.server 8000` (بعض المتصفحات تمنع `fetch` للملفات المحلية) |
| الخطأ `! [rejected] ... non-fast-forward` | نفّذ `git pull --rebase` ثم `git push` مرة أخرى |
| تعارض في ملف الفهرس | أعد توليده: `node tools/build-index.mjs` ثم `git add` و`git commit` |
| نسيت كلمة مرور GitHub | استخدم رمز وصول شخصي (PAT) أو GitHub Desktop بدل كلمة المرور |

## 7) قواعد السلوك | Code of conduct

- لا تضع أي بيانات شخصية حساسة (عنوان، هاتف، رقم الهوية، كلمات مرور، رموز وصول).
- احترم عمل زملائك، واكتب ملاحظات المراجعة بأسلوب مهني.
- لا تحذف ملفات الآخرين ولا تعدّل ملفات لا تخص مهمتك.

## 8) الترخيص | License

MIT — انظر `LICENSE`.
