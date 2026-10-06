# سجل التغييرات | Changelog

كل التغييرات المهمة في مشروع `class-team-hub` موثّقة هنا.
الصيغة مبنية على [Keep a Changelog](https://keepachangelog.com/) والترقيم على
[Semantic Versioning](https://semver.org/lang/ar/).

## [Unreleased]

### قيد العمل / In progress
- ميزة الفلترة بالوسوم (`tags`) — فرع: `feature/tag-filter`.

## [1.0.0] — 2026-10-06

### أُضيف / Added
- الموقع الأساسي: `index.html` + `css/style.css` + `js/app.js`.
- مجلد بطاقات الأعضاء `data/members/` مع قالب `00-template.json`.
- أداة توليد الفهرس `tools/build-index.mjs` والنسخة المدمجة `data/members-bundle.js`.
- أداة الفحص `tests/validate-members.mjs`.
- سير عمل التحقق التلقائي `.github/workflows/validate.yml`.
- ملف مُلّاك الكود `.github/CODEOWNERS`.
- قوالب طلب السحب والمشكلات في `.github/`.

### ملاحظات / Notes
- أول إصدار مستقر يُعرض على GitHub Pages.
