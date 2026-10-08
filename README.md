# تطبيق vsco التعليمي

تطبيق ويب بسيط للأغراض التعليمية لإدارة **الطلاب** و **الصفوف الدراسية**،
مبني باستخدام **Visual Basic (ASP.NET Web Forms)** وقاعدة بيانات **PostgreSQL**،
ويعمل داخل Visual Studio على Windows.

> Educational web app for managing **Students** and **Classes**,
> built with **Visual Basic (ASP.NET Web Forms)** and **PostgreSQL**,
> running in Visual Studio on Windows.

---

## ✨ المميزات (Features)

- جدولان: **الطلاب** (students) و **الصفوف** (classes)
- العمليات الأساسية على الجدولين: **إضافة / تعديل / حذف** (CRUD)
- **بحث** بالاسم (والبريد الإلكتروني / الهاتف في صفحة الطلاب)
- **تصفية** الطلاب حسب الصف الدراسي
- ترقيم الصفحات (Pagination) في الجداول
- واجهة عربية (RTL) مبنية على Bootstrap 5
- استعلامات SQL محمية من الحقن (استخدام Parameters)

## 🛠️ المتطلبات (Prerequisites)

1. **Visual Studio 2022** (أو 2019) مع عبء عمل «ASP.NET and web development»
   (حمّله من: https://visualstudio.microsoft.com)
2. **.NET Framework 4.8** (Target Pack)
3. **PostgreSQL** (الإصدار 12 أو أحدث) مع أداة **psql** أو **pgAdmin**

## 🗄️ إعداد قاعدة البيانات (Database setup)

### الطريقة 1: باستخدام psql

```bash
psql -U postgres -f Database/create_database.sql
```

### الطريقة 2: باستخدام pgAdmin

1. أنشئ قاعدة بيانات جديدة: `vsco_db` (ترميز UTF8)
2. افتح أداة الاستعلام (Query Tool) على `vsco_db`
3. انسخ أوامر البند (3) وما بعده من ملف `Database/create_database.sql` ونفّذها

الملف يقوم بإنشاء:

| الجدول | الأعمدة |
|---------|---------|
| `classes` | `class_id` (PK), `class_name`, `grade`, `room` |
| `students` | `student_id` (PK), `full_name`, `email`, `phone`, `class_id` (FK → classes, ON DELETE SET NULL) |

مع إدراج **بيانات تجريبية** (3 صفوف و 6 طلاب) يمكن تعديلها أو حذفها.

## 🔌 ضبط الاتصال (Connection string)

افتح `VsCo/Web.config` وعدّل سلسلة الاتصال بما يناسب تثبيت PostgreSQL لديك:

```xml
<add name="VsCoDb"
     connectionString="Host=localhost;Port=5432;Database=vsco_db;Username=postgres;Password=كلمة_السر_هنا" />
```

## ▶️ التشغيل (Run)

1. افتح الملف `VsCo.sln` في Visual Studio
2. اضغط **F5** (أو Ctrl+F5)
3. يتم استعادة حزم NuGet تلقائياً (حزمة `Npgsql`)
4. تصفح التطبيق:
   - `Default.aspx` — الصفحة الرئيسية
   - `Students.aspx` — إدارة الطلاب (إضافة / تعديل / حذف / بحث / تصفية حسب الصف)
   - `Classes.aspx` — إدارة الصفوف (إضافة / تعديل / حذف / بحث)

## 📁 هيكل المشروع (Project structure)

```
vsco/
├── VsCo.sln                  ملف الحل (Solution)
├── VsCo/                     مشروع الويب (Web Application)
│   ├── VsCo.vbproj           ملف المشروع (Visual Basic، .NET Framework 4.8)
│   ├── Web.config            الإعدادات وسلسلة الاتصال
│   ├── Global.asax(.vb)      تهيئة التطبيق
│   ├── Site.Master(.vb)      القالب الرئيسي (RTL + Bootstrap)
│   ├── Default.aspx(.vb)     الصفحة الرئيسية
│   ├── Students.aspx(.vb)    صفحة الطلاب (CRUD + بحث + تصفية)
│   ├── Classes.aspx(.vb)     صفحة الصفوف (CRUD + بحث)
│   ├── App_Code/
│   │   └── DbHelper.vb       مساعد الاتصال بـ PostgreSQL (Npgsql)
│   ├── App_Start/
│   │   └── RouteConfig.vb    إعدادات التوجيه
│   ├── Content/
│   │   └── Site.css          الأنماط العامة
│   └── Properties/
│       └── AssemblyInfo.vb   معلومات Assembly
└── Database/
    └── create_database.sql   سكربت إنشاء قاعدة البيانات + بيانات تجريبية
```

## 📝 ملاحظات (Notes)

- أمثلة استعلامات SQL معرفة Parameterized موجودة في `VsCo/App_Code/DbHelper.vb`
- يمكن تعديل منفذ (Port) واسم المستخدم وكلمة المرور في سلسلة الاتصال حسب احتياجك
- عند حذف صف مرتبط بطلاب: يصبح `class_id` للطلاب NULL تلقائياً (بسبب `ON DELETE SET NULL`)

## 📄 الرخصة (License)

مشروع تعليمي — يمكن استخدامه وتعديله بحرية.
