# تشغيل التطبيق من داخل Android Studio — خطوة بخطوة

> دليل عملي لمشروع **مُصحِّح Basem** بعد تثبيت Flutter وAndroid Studio.
> الأوامر مكتوبة لويندوز (وأشرت إلى بديل ماك/لينكس عند الاختلاف).
> النتيجة المتوقّعة في النهاية: التطبيق يعمل على جوالك أو المحاكي من داخل Android Studio،
> ويمكنك تعديل الكود ورؤية النتيجة مباشرة (Hot Reload)، ثم اختبار دورة تصحيح كاملة.

---

## 📍 أولًا: أين أضع مجلد المشروع على جهازي؟

**المكان المقترح: `C:\dev\exam`** — وأفتح منه `C:\dev\exam\app` في Android Studio.

| المكان | التقييم | السبب |
|---|---|---|
| `C:\dev\exam` | ✅ **الأفضل** | مسار قصير بالإنجليزية، بلا مزامنة، ويقلّل مشاكل بناء أندرويد |
| `C:\Users\<اسمك>\Documents\exam` | ✅ جيد | مقبول إن كان `Documents` **غير** مرتبط بـ OneDrive |
| `سطح المكتب` أو `التنزيلات` | ⚠️ يعمل | قد يُنظَّف تلقائيًا، وبطء في الفهرسة |
| داخل `OneDrive` | ❌ تجنّبه | المزامنة تُفسد مخرجات البناء (آلاف الملفات المؤقتة) وتُعرقل Gradle |
| مسار فيه **حروف عربية** أو **مسافات** | ❌ تجنّبه | مشاكل معروفة في أدوات أندرويد/Gradle على ويندوز |

> ⚠️ **تنبيه مهم:** الكود في المستودع موجود على فرع اسمه **`arena/01a0fc3b-exam`**،
> وفرع `main` فيه ملف واحد فقط (البداية). لذلك استخدم دائمًا أمر النسخ مع `-b`:
> `git clone -b arena/01a0fc3b-exam https://github.com/mrjfaras101-cell/exam.git`
> (أو من GitHub: بدّل الفرع من قائمة الفروع أعلى الصفحة قبل تنزيل ZIP).

**للتجديد لاحقًا (جلب أحدث التعديلات) داخل مجلد المشروع:**

```bash
cd /d C:\dev\exam
git status                 # تأكّد أن شجرتك نظيفة (بلا تعديلات مهمّة غير محفوظة)
git pull                   # يجلب أحدث ما نُشر على فرع العمل
```

- إن كانت لديك تعديلات محلية ولا تريد فقدانها: `git stash` ← `git pull` ← `git stash pop`.
- وإن أردت نسخة **مطابقة تمامًا** لما على GitHub (تمحو تعديلاتك المحلية):
  `git fetch --all` ثم `git reset --hard origin/arena/01a0fc3b-exam`.

---

## ⚡ أسرع مسار (لو أردت الاختصار)

```bash
mkdir C:\dev
cd /d C:\dev
git clone -b arena/01a0fc3b-exam https://github.com/mrjfaras101-cell/exam.git
cd exam\app
flutter create . --platforms=android --project-name musahhih --org com.musahhih
flutter pub get
python tool\apply_platform_config.py
python tool\install_app_icons.py
```

ثم من Android Studio: **File → Open → مجلد `exam\app`** → اختر الجهاز → زر **▶**.

<details>
<summary>تفصيل كل خطوة ولماذا (اضغط للتوسّع)</summary>

---

## 1) تحقّق من الأدوات قبل فتح Android Studio

افتح **Command Prompt** أو **PowerShell** واكتب:

```bash
flutter --version
flutter doctor
```

**المطلوب في `flutter doctor`:**

| السطر | المطلوب |
|---|---|
| `[✓] Flutter` | الإصدار **3.27 أو أحدث** (المشروع يطلب Dart 3.6+) |
| `[✓] Android toolchain` | مع `Android SDK` |
| `[✓] Android Studio` | مكتشف تلقائيًا |

**إن ظهرت ✗ بجانب Android toolchain:**

```bash
flutter doctor --android-licenses        # اقبل كل الرخص بحرف y
```

وإن قال إن `cmdline-tools` مفقودة: Android Studio → **Settings → Languages & Frameworks →
Android SDK → تبويب SDK Tools** → علّم على **Android SDK Command-line Tools (latest)** → **Apply**،
ثم أعد `flutter doctor --android-licenses`.

**إن لم يجد Android SDK:**

```bash
flutter config --android-sdk "C:\Users\<اسمك>\AppData\Local\Android\Sdk"
```

> 💡 إن كان لديك نسخة Flutter قديمة: `flutter upgrade`.

---

## 2) إضافة Flutter داخل Android Studio (مرة واحدة)

1. شغّل **Android Studio** → من الشاشة الترحيبية **Plugins**
   (أو من داخل أي مشروع: **File → Settings → Plugins**).
2. في مربع البحث اكتب **Flutter** → **Install** — سيثبّت **Dart** تلقائيًا معه.
3. **Restart IDE** عند الطلب.
4. بعد إعادة التشغيل: **File → Settings → Languages & Frameworks → Flutter**
   → **Flutter SDK path** → اختر مجلد Flutter الذي ثبّتّه (مثال: `C:\src\flutter` أو `C:\flutter`)
   → **Apply → OK**.
   (حقل Dart SDK يُضبط تلقائيًا — لا تغيّره.)

**تحقّق سريع:** الشاشة الترحيبية يجب أن تعرض زر **New Flutter Project**.

---

## 3) اجلب المشروع من GitHub

### الطريقة أ — بالطرفية (موصى بها)

```bash
git --version                 # تأكّد من وجود Git (وإن لم يوجد: انظر الطريقة ب)
mkdir C:\dev
cd /d C:\dev
git clone -b arena/01a0fc3b-exam https://github.com/mrjfaras101-cell/exam.git
```

**لماذا `-b`؟** لأن فرع `main` في هذا المستودع فيه ملف واحد فقط، وكل كود التطبيق على فرع
`arena/01a0fc3b-exam`. بدون `-b` ستحصل على مجلد شبه فارغ.

**تحقّق أن المجلد سليم:** يجب أن ترى داخل `C:\dev\exam`:
مجلدات `app` · `demo` · `docs` · `.github`، وأن يوجد الملف `app\lib\main.dart`.

```bash
cd /d C:\dev\exam
git branch                    # يجب أن يظهر فرع arena/01a0fc3b-exam بعلامة *
dir                           # على ماك/لينكس: ls
```

### الطريقة ب — بلا Git إطلاقًا (تنزيل ZIP)

**اتبع هذا الرابط المباشر (نسخة فرع العمل):**

> <https://github.com/mrjfaras101-cell/exam/archive/refs/heads/arena/01a0fc3b-exam.zip>

1. سيُنزّل ملف `exam-arena-01a0fc3b-exam.zip`.
2. أنشئ مجلدًا `C:\dev` ثم فكّ الضغط داخله.
3. سيظهر مجلد باسم طويل — **أعد تسميته إلى `exam`** فيكون المسار `C:\dev\exam`.

> ملاحظة: مع ZIP لا يوجد `git pull` للتجديد — عليك تنزيل ZIP جديد عند وجود تحديثات.
> لذلك الطريقة (أ) أفضل إن كنت ستستخدم Git.

### الطريقة ج — من داخل Android Studio

الشاشة الترحيبية → **Get from VCS** → الصق `https://github.com/mrjfaras101-cell/exam.git`
→ في خانة **Directory** اختر `C:\dev\exam` → **Clone**.

⚠️ Android Studio ينسخ الفرع الافتراضي (`main`) تلقائيًا، لذا **بدّل الفرع بعده**:
- من الطرفية داخل Android Studio: `git checkout arena/01a0fc3b-exam`
- أو من الواجهة: نافذة **Git** أسفل الشاشة → **Branches** → `Remote` →
  `origin/arena/01a0fc3b-exam` → **Checkout**.

**نصيحة اختيارية (يملكها صاحب المستودع):** يمكنك من GitHub جعل
`arena/01a0fc3b-exam` هو الفرع الافتراضي:
**Settings → General → Default branch → بدّل إلى `arena/01a0fc3b-exam` → Update**،
فيصبح التنزيل والنسخ يجلب الكود الصحيح تلقائيًا بلا `-b`.

---

## 4) افتح المجلد الصحيح: `exam\app` (مهم جدًا)

> ⚠️ افتح **`app`** وليس `exam` — لأن `app/` هو مجلد مشروع Flutter (فيه `pubspec.yaml`).

- **File → Open…** → اختر `...\exam\app` → **OK**
- إن سألك Android Studio **Trust Project** → اضغط **Trust**.

> إن فُتح بالخطأ مجلد `exam` الكامل: أغلق النافذة (`File → Close Project`) وأعد الخطوة.

بعد الفتح سيسأل عن ترقية Gradle/AGP — **لا تقبل** أي ترقية الآن (نستخدم إعدادات Flutter القياسية).

---

## 5) ولّد مجلد أندرويد + الصلاحيات + الأيقونات (مرة واحدة)

**لماذا:** المستودع يحتوي كود Flutter فقط (`lib/`, `assets/`, `test/`) — ومجلدات المنصّات
مثل `android/` و`ios/` **تُولَّد آليًا** في سير البناء على GitHub، فلا وجود لها في المستودع.

افتح الطرفية **داخل Android Studio**: **View → Tool Windows → Terminal** (اختصار `Alt+F12`).
تأكّد أن المسار ينتهي بـ `\exam\app` (اكتب `cd` وحدها لرؤية المسار) ثم:

```bash
flutter create . --platforms=android --project-name musahhih --org com.musahhih
```

هذا ينشئ مجلد `android/` كاملًا. ثم **تأكّد أن ملفاتنا لم تُلمس**:

```bash
git status
```

- المتوقّع: ظهور `android/` كملف جديد غير متعقَّب (طبيعي).
- إن ظهر أيضًا أن `pubspec.yaml` أو `lib/` تغيّر، أرجعه فورًا:

```bash
git checkout -- pubspec.yaml lib test analysis_options.yaml
```

### أ) الصلاحيات واسم التطبيق (صلاحية الكاميرا + الاسم «مُصحِّح Basem»)

```bash
python tool\apply_platform_config.py
```

(على ماك/لينكس: `python3 tool/apply_platform_config.py`)

### ب) أيقونة التطبيق

```bash
python tool\install_app_icons.py
```

### ج) التبعيات

```bash
flutter pub get
```

> **إن لم يكن Python مثبتًا على جهازك** (رسالة `'python' is not recognized`): ثبّت Python 3 من
> [python.org](https://www.python.org/downloads/) مع تعليم خيار **Add python.exe to PATH**، ثم أعد الأوامر.
> **أو** نفّذ الخطوتين يدويًا:
> 1. افتح `app\android\app\src\main\AndroidManifest.xml` وأضف قبل سطر `<application`:
>    ```xml
>    <uses-permission android:name="android.permission.CAMERA" />
>    <uses-feature android:name="android.hardware.camera" android:required="false" />
>    ```
>    وغيّر `android:label="..."` إلى `android:label="مُصحِّح Basem"` (احفظ الملف بترميز UTF-8).
> 2. الأيقونة: بدون Python تبقى أيقونة Flutter الافتراضية — لا يمنع هذا عمل التطبيق
>    (الشعار داخل التطبيق يظهر طبيعيًا).

---

## 6) جهّز جهازًا للتشغيل

### الخيار الأفضل: جوال أندرويد حقيقي

1. على الجوال: **الإعدادات → حول الجوال** → اضغط **رقم الإصدار** 7 مرات
   (تظهر رسالة «أنت الآن مطوّر»).
2. **الإعدادات → خيارات المطوّر** → فعّل **تصحيح أخطاء USB**.
3. وصّل الجوال بالكابل → ستظهر رسالة على الجوال: **السماح بتصحيح الأخطاء من هذا الكمبيوتر؟** → **السماح**.
4. تحقّق من الطرفية:

```bash
adb devices
```

- إن ظهر الجهاز مع `unauthorized`: اقبل الرسالة على الجوال ثم أعد الأمر.
- إن ظهر `command not found` للـ adb: استخدم المسار الكامل
  `"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" devices`.

### أو محاكي (Emulator) — بلا جوال

1. **Tools → Device Manager** (أو أيقونة الجوال ⧉ في الشريط الأيسر).
2. **Create Virtual Device** → **Pixel 7** أو **Pixel 8** → **Next**.
3. اختر نظامًا: **Android 14 (API 34)** — إن لم يكن منزّلًا اضغط **⤓ Download** بجانبه → **Next → Finish**.
4. اختر اسم النظام ثم اضغط **▶** لتشغيل المحاكي.

**نصيحتان للمحاكي:**
- كاميرا المحاكي الافتراضية (مشهد ثلاثي الأبعاد) لا تقرأ ورقة حقيقية. للحصول على كاميرا حقيقية:
  **Device Manager → ⋯ → Edit → Show Advanced Settings → Camera → الخلفية = `Webcam0`**،
  فيلتقط المحاكي بكاميرا حاسوبك وتستطيع تجربة المسح بورقة مطبوعة أمام الشاشة.
- بلا كاميرا إطلاقًا: استخدم مسار **«صور من المعرض»** في الخطوة 8 (يعمل بـ 100%).

---

## 7) شغّل التطبيق من Android Studio

1. من القائمة المنسدلة في الشريط العلوي اختر جهازك:
   اسم جوالك، أو `Pixel 8 API 34` (المحاكي).
2. في شجرة الملفات اليسرى افتح `lib` → `main.dart`.
3. اضغط **▶ Run** (أو `Shift+F10` — على ماك `Ctrl+R`).
4. **أول بناء يستغرق 3–10 دقائق** (يُنزّل Gradle والتبعيات). البناءات التالية ثوانٍ.
5. على الجوال: إن ظهرت رسالة تثبيت التطبيق → **تثبيت** (وإن ظهر «مصدر غير معروف» فعّل السماح).

**توقّع أن ترى:** شاشة رئيسية بعنوان **«مُصحِّح — Basem»** وشعار التطبيق، وزر أصفر/أخضر
**«اختبار جديد»** أسفل الشاشة.

---

## 8) جرّب دورة تصحيح كاملة — بلا طابعة وبلا كاميرا ✨

الصور الجاهزة في المستودع: **`demo\assets\samples\app_test\`**
وهي مُولَّدة بنفس مواصفات ما سينشئه التطبيق (10 أسئلة · «مزيج» · 4 خيارات · رمز الورقة 3)،
ومتحقَّق منها آليًا على محرّك القراءة نفسه.

### أولًا: انسخ الصور إلى معرض الجوال/المحاكي

**جوال حقيقي (الأسهل):** وصّل الكابل وانسخ ملفات `app_test\*.jpg` (7 صور) إلى مجلد **Pictures** أو **DCIM**.
**أو** من الطرفية في مجلد `exam` (وليس `app`):

```bash
adb push demo\assets\samples\app_test\. /sdcard/Pictures/musahhih/
```

ثم أعد تشغيل الجوال (أو افتح تطبيق «الملفات» مرة) حتى يفهرس نظام الصور الملفات الجديدة.

**محاكي:** اسحب الصور السبع وأفلتها على نافذة المحاكي،
أو من **View → Tool Windows → Device Explorer** → `sdcard/Pictures` → زر **Upload**.
إن لم تظهر في المعرض: أعد تشغيل المحاكي.

### ثانيًا: أنشئ اختبارًا مطابقًا في التطبيق

في التطبيق: **اختبار جديد** ← اسم: «اختبار تجريبي» ← **عدد الأسئلة: 10** ←
نوع الأسئلة: **مزيج** ← عدد الخيارات: **4** ← **إنشاء الاختبار**.
(رمز الورقة سيصبح **3** تلقائيًا لأنه أول اختبار — وهو الرمز المطبوع على الصور.)

### ثالثًا: أدخل المفتاح من «ورقة المفتاح» بالصور

1. من شاشة الاختبار اضغط **مفتاح الإجابة**.
2. اضغط **مسح ورقة المفتاح**.
3. اضغط أيقونة **🖼️ (صور من المعرض)** أعلى اليمين.
4. اختر **`keysheet.jpg`**.
5. المتوقّع: رسالة **«تم قراءة مفتاح الإجابة من الورقة ✓»** — والمفتاح يجب أن يكون:

| السؤال | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| الإجابة | ج | أ | ب | د | أ | ب | ب | أ | **لا** | **نعم** |

(الأسئلة 8–10 نوعها «نعم أو لا» بهذا الترتيب: 7 «دائرة» ثم 3 «نعم/لا» — وهو ترتيب التطبيق التلقائي.)

### رابعًا: صحّح الأوراق الست

1. **ابدأ التصحيح** → أيقونة **🖼️ (صور من المعرض)**.
2. اختر الصور الست **`appscan_00.jpg` … `appscan_05.jpg`** دفعة واحدة.
3. سيظهر شريط «جارٍ تصحيح الصور… 1/6» ثم **«تم تصحيح 6 ورقة من الصور»**.

**النتائج المتوقّعة بالضبط** (نسخة من `app_test/manifest.json`، مُتحقَّق منها آليًا):

| الصورة | رقم الجلوس | الدرجة | ملاحظات |
|---|---|---|---|
| appscan_00 | 20260101 | **10/10** | قراءة نظيفة تمامًا |
| appscan_01 | 20260102 | **8/10** | السؤال 5 قراءة خفيفة ⇐ تُدرج في «تحتاج مراجعة» |
| appscan_02 | 20260103 | **7/10** | السؤال 7 مُظلَّل مرتين (مشكوك) + **الورقة مقلوبة 180°** ويجب أن تُقرأ صحيحة |
| appscan_03 | 20260104 | **7/10** | السؤال 10 فارغ (لم يُظلَّل) |
| appscan_04 | 20260105 | **7/10** | **الورقة مقلوبة 180°** وتُقرأ صحيحة |
| appscan_05 | 20260106 | **7/10** | قراءة نظيفة |

> إن ظهرت هذه الأرقام كما هي ⇒ محرّك القراءة والتصحيح يعملان على جهازك تمامًا كما في الاختبارات الآلية.

### خامسًا: جرّب التعديل اليدوي

من **النتائج والتحليل** المس أي طالب ← تظهر بطاقة فيها كل سؤال ← المس أي سؤال لتغيير إجابته،
وراقب إعادة حساب الدرجة فورًا.

---

## 9) الاختبار الحقيقي بالورق (الهدف النهائي)

1. في التطبيق: **الورقة والطباعة** → **طباعة / PDF**.
2. في نافذة الطباعة: مقاس **A4** · اتجاه **أفقي (Landscape)** · مقياس **100%** (بلا «ملاءمة الصفحة»).
   ستطبع صفحة واحدة فيها **نسختان** من ورقة الإجابة بينهما خط قصّ.
3. اقصص الورقة في المنتصف → ورقتان.
4. ظلّل فقاعات الإجابات وشبكة رقم الجلوس بقلم جاف أزرق أو رصاص غامق.
5. في التطبيق: **ابدأ التصحيح** → وجّه الكاميرا نحو الورقة كاملة → يلتقط **تلقائيًا** عند ثباتها
   (ويوجد زر «التقاط يدوي»).
6. إن كثُرت رسائل «يحتاج مراجعة»: **الإعدادات** → خفّض/ارفع «عتبة مظلّلة» قليلًا وجرّب مرة أخرى.

> 💡 اطبع **ورقة المفتاح** بلونِ ورق مختلف حتى لا تختلط بأوراق الطلاب.

---

## 10) أثناء التطوير: تعديل ورؤية فورية

| الإجراء | الطريقة |
|---|---|
| **Hot Reload** (تطبيق التعديل فورًا مع بقاء الحالة) | عدّل أي ملف في `lib/` ثم `Ctrl+S`، أو الزر **⚡** في شريط التشغيل (`Ctrl+\`) |
| **Hot Restart** (إعادة تشغيل التطبيق من الصفر) | الزر **↻** أو `Ctrl+Shift+\` |
| إيقاف التطبيق | الزر **⬛** |
| **تصحيح بالتنقيط (Debug)** | انقر يسار السطر لإضافة نقطة توقّف (Red dot) → زر **🐞** (`Shift+F9`) → تظهر قيم المتغيرات في نافذة **Debug** |
| **قراءة سجلات التطبيق** | **View → Tool Windows → Logcat** → في مربع الفلتر اكتب `musahhih` (أو اختر التطبيق من القائمة) |
| تشغيل بلا تصحيح (أسرع) | `Shift+F10` |

**أمثلة تعديلات سريعة لتجربتها:**
- الألوان: `lib/ui/theme.dart` → `static const seed = Color(0xFF0E7C66);`
- النصوص: الشاشة الرئيسية في `lib/ui/screens/home_screen.dart`
- اسم التطبيق على الجوال: `tool/apply_platform_config.py` (`APP_LABEL_AR`) ثم أعد تنفيذه وأعد البناء
- عدد الأسئلة الأقصى: `kMaxQuestionsPerExam` في `lib/domain/models.dart`

---

## 11) بناء ملف APK من داخل Android Studio

**الطريقة الأسهل (طرفية):**

```bash
flutter build apk --release
```

**النتيجة:** `app\build\app\outputs\flutter-apk\app-release.apk` — انسخه للجوال وثبّته.

**أو من الواجهة:** **Build → Flutter → Build APK**.

> الملف موقّع بمفتاح التطوير (مناسب للتجربة والتوزيع المباشر، وليس للنشر على Google Play).
> وللحصول على ملف أصغر للجوالات الحديثة فقط: `flutter build apk --split-per-abi`.

---

## 12) الأخطاء الشائعة وحلولها

| الرسالة / المشكلة | السبب | الحل |
|---|---|---|
| `No application found for TargetPlatform.android` | مجلد `android/` غير موجود | نفّذ `flutter create . --platforms=android ...` (الخطوة 5) |
| `Dependency 'androidx...' requires ... compile against version 36 or later` أو `:jni_flutter is currently compiled against android-35` | بعض الحزم تحتاج `compileSdk` أحدث | شغّل `python tool\fix_pub_cache_compile_sdk.py --sdk 36 --min-sdk 24` ثم انسخ init script (الأسفل) وأعد البناء |
| `Unsupported class file major version` أو أخطاء Java | نسخة Java غير مناسبة | **Settings → Build, Execution, Deployment → Build Tools → Gradle → Gradle JDK = Embedded JDK**، أو `flutter config --jdk-dir "C:\Program Files\Android\Android Studio\jbr"` |
| `Gradle task assembleDebug failed with exit code 1` | سبب متعدّد | افتح **View → Tool Windows → Build** واقرأ أول سطر أحمر (هو السبب الحقيقي غالبًا) |
| الكاميرا لا تعمل على المحاكي | المحاكي بلا كاميرا حقيقية | استخدم **صور من المعرض**، أو اجعل كاميرا المحاكي `Webcam0`، أو استخدم جوالًا حقيقيًا |
| الكاميرا تعمل لكن الصورة سوداء | المعاينة لم تُهيّأ أو الجهاز مشغول | أوقف ثم شغّل الكاميرا من الشاشة، أو أعد تشغيل التطبيق (**↻**) |
| `Failed to install the app` | نسخة قديمة مثبّتة أو مساحة غير كافية | احذف النسخة القديمة من الجوال (أو `adb uninstall com.musahhih.musahhih`) ثم أعد التشغيل |
| `Flutter SDK not found` في Android Studio | مسار Flutter غير مضبوط | Settings → Languages & Frameworks → Flutter → Flutter SDK path |
| `Target of URI doesn't exist` أو كل الأسطر حمراء في `lib/` | التبعيات لم تُنزَّل | `flutter pub get` ثم **File → Invalidate Caches / Restart** |
| الصور لا تظهر في «من المعرض» | المعرض لم يفهرس الملفات بعد | أعد تشغيل الجوال/المحاكي، أو انسخ الصور يدويًا إلى `DCIM` |

**نسخ ملف إصلاح compileSdk (للاستخدام مع الرسالة الثانية) — ويندوز:**

```bash
mkdir "%USERPROFILE%\.gradle\init.d"
copy tool\android-init.gradle "%USERPROFILE%\.gradle\init.d\compile-sdk.gradle"
```

**ماك/لينكس:**

```bash
mkdir -p ~/.gradle/init.d && cp tool/android-init.gradle ~/.gradle/init.d/compile-sdk.gradle
```

---

## 13) ماذا أضافت هذه الأوامر إلى مشروعك؟

| المسار | ماذا فيه | هل يُرفع إلى GitHub؟ |
|---|---|---|
| `android/` | مشروع أندرويد المولَّد (Gradle، Manifest) | ❌ لا — مولَّد آليًا (يُولَّد في سير البناء) |
| `android/app/src/main/AndroidManifest.xml` | صلاحية الكاميرا + اسم التطبيق | ❌ لا |
| `android/app/src/main/res/mipmap-*` | أيقونة التطبيق | ❌ لا |
| `build/` | مخرجات البناء (منها ملف APK) | ❌ لا (مستثنى في `.gitignore`) |
| `assets/`, `lib/`, `test/`, `tool/` | كودنا الأصلي | ✅ نعم (كما هو) |

**لحفظ تعديلاتك في GitHub لاحقًا** (الطريقة التي يعملها سير المشروع):

```bash
git add lib assets test tool pubspec.yaml
git commit -m "وصف التعديل"
git push origin arena/01a0fc3b-exam
```

> الدفع إلى هذا الفرع يشغّل تلقائيًا سير «فحوص سريعة» (تحليل + اختبارات)، وسير «بناء APK»
> الذي ينشر نسخة جديدة على رابط التنزيل نفسه:
> <https://github.com/mrjfaras101-cell/exam/releases/download/apk-demo/musahhih-1.0.0.apk>

---

## ملحق: لو أردت إعادة كل شيء من الصفر

```bash
REM (1) المشروع
git clone https://github.com/mrjfaras101-cell/exam.git
cd exam\app

REM (2) مجلد أندرويد
flutter create . --platforms=android --project-name musahhih --org com.musahhih
git checkout -- pubspec.yaml lib test analysis_options.yaml

REM (3) التبعيات والصلاحيات والأيقونة
flutter pub get
python tool\apply_platform_config.py
python tool\install_app_icons.py

REM (4) (عند الحاجة فقط) إصلاح compileSdk
python tool\fix_pub_cache_compile_sdk.py --sdk 36 --min-sdk 24
mkdir "%USERPROFILE%\.gradle\init.d"
copy tool\android-init.gradle "%USERPROFILE%\.gradle\init.d\compile-sdk.gradle"

REM (5) التشغيل
flutter devices
flutter run
```

---

**جاهز؟** افتح `lib/main.dart` واضغط ▶، ثم اذهب إلى الخطوة 8 لتجربة التصحيح بالصور الجاهزة.
وإن واجهتك أي رسالة خطأ، انسخ نصّها وأرسلها وسأحدّد الحل بدقة.
