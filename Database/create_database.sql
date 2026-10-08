-- ============================================================================
--  تطبيق vsco التعليمي - قاعدة بيانات PostgreSQL
--  ----------------------------------------------------------------------------
--  طريقة التشغيل (psql):
--      psql -U postgres -f Database/create_database.sql
--
--  أو عبر pgAdmin:
--      1) أنشئ قاعدة بيانات جديدة باسم vsco_db (ترميز UTF8).
--      2) افتح أداة الاستعلام ونفّذ أوامر البند (3) وما بعده من هذا الملف.
-- ============================================================================

-- 1) إنشاء قاعدة البيانات
CREATE DATABASE vsco_db
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    TEMPLATE = template0;

-- 2) الاتصال بقاعدة البيانات (psql)
\connect vsco_db

-- 3) جدول الصفوف الدراسية
CREATE TABLE classes (
    class_id    SERIAL PRIMARY KEY,
    class_name  VARCHAR(100) NOT NULL,
    grade       VARCHAR(50),
    room        VARCHAR(50)
);

-- 4) جدول الطلاب
CREATE TABLE students (
    student_id  SERIAL PRIMARY KEY,
    full_name   VARCHAR(150) NOT NULL,
    email       VARCHAR(150),
    phone       VARCHAR(50),
    class_id    INTEGER REFERENCES classes (class_id) ON DELETE SET NULL
);

-- 5) فهرس لتسريع التصفية والبحث حسب الصف
CREATE INDEX idx_students_class_id ON students (class_id);

-- 6) بيانات تجريبية (يمكنك تعديلها أو حذفها)
INSERT INTO classes (class_name, grade, room) VALUES
    ('الصف الأول',  'المرحلة الابتدائية', '101'),
    ('الصف الثاني', 'المرحلة الابتدائية', '102'),
    ('الصف الثالث', 'المرحلة الابتدائية', '103');

INSERT INTO students (full_name, email, phone, class_id) VALUES
    ('أحمد محمد علي',  'ahmed@example.com',    '0500000001', 1),
    ('سارة خالد',      'sara@example.com',     '0500000002', 1),
    ('محمد صالح',      'mohammed@example.com', '0500000003', 2),
    ('فاطمة أحمد',     'fatima@example.com',   '0500000004', 2),
    ('عبدالله يوسف',   'abdullah@example.com', '0500000005', 3),
    ('خالد عمر',      'khaled@example.com',   '0500000006', NULL);
