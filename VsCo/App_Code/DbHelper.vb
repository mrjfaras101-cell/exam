Imports System.Configuration
Imports System.Data
Imports Npgsql

''' <summary>
''' مساعد الاتصال بقاعدة بيانات PostgreSQL (Npgsql).
''' جميع الاستعلامات هنا محمية من حقن SQL (استخدام Parameters).
''' </summary>
Public Class DbHelper

    Private Shared ReadOnly _connectionString As String = CreateConnectionString()

    ''' <summary>
    ''' قراءة سلسلة الاتصال من ملف Web.config (الاسم: VsCoDb)
    ''' </summary>
    Private Shared Function CreateConnectionString() As String
        Dim settings = ConfigurationManager.ConnectionStrings("VsCoDb")
        If settings Is Nothing OrElse String.IsNullOrWhiteSpace(settings.ConnectionString) Then
            Throw New InvalidOperationException(
                "لم يتم العثور على سلسلة الاتصال 'VsCoDb' في ملف Web.config.")
        End If
        Return settings.ConnectionString
    End Function

    ''' <summary>
    ''' إنشاء وفتح اتصال جديد بقاعدة البيانات
    ''' </summary>
    Private Shared Function GetConnection() As NpgsqlConnection
        Dim cn As New NpgsqlConnection(_connectionString)
        cn.Open()
        Return cn
    End Function

    ''' <summary>
    ''' إضافة Parameter بأمان: القيم الفارغة أو Null تتحول إلى DBNull
    ''' </summary>
    Private Shared Sub AddParam(cmd As NpgsqlCommand, name As String, value As Object)
        If value Is Nothing OrElse (TypeOf value Is String AndAlso String.IsNullOrWhiteSpace(CStr(value))) Then
            cmd.Parameters.AddWithValue(name, DBNull.Value)
        Else
            cmd.Parameters.AddWithValue(name, value)
        End If
    End Sub

#Region "الصفوف (Classes)"

    ''' <summary>
    ''' جلب الصفوف مع إمكانية البحث بالاسم (ILIKE غير حساس لحالة الأحرف)
    ''' </summary>
    Public Shared Function GetClasses(Optional search As String = "") As DataTable
        Dim sql As String = "SELECT class_id, class_name, grade, room FROM classes"
        If Not String.IsNullOrWhiteSpace(search) Then
            sql &= " WHERE class_name ILIKE @search"
        End If
        sql &= " ORDER BY class_id"

        Using cn = GetConnection()
            Using cmd As New NpgsqlCommand(sql, cn)
                If Not String.IsNullOrWhiteSpace(search) Then
                    cmd.Parameters.AddWithValue("search", "%" & search & "%")
                End If
                Dim dt As New DataTable()
                dt.Load(cmd.ExecuteReader())
                Return dt
            End Using
        End Using
    End Function

    ''' <summary>
    ''' جلب الصفوف لقوائم الاختيار (DropDownList)
    ''' </summary>
    Public Shared Function GetClassesForDropDown() As DataTable
        Using cn = GetConnection()
            Using cmd As New NpgsqlCommand("SELECT class_id, class_name FROM classes ORDER BY class_name", cn)
                Dim dt As New DataTable()
                dt.Load(cmd.ExecuteReader())
                Return dt
            End Using
        End Using
    End Function

    ''' <summary>إضافة صف جديد</summary>
    Public Shared Sub InsertClass(className As String, grade As String, room As String)
        Using cn = GetConnection()
            Using cmd As New NpgsqlCommand(
                "INSERT INTO classes (class_name, grade, room) VALUES (@name, @grade, @room)", cn)
                AddParam(cmd, "name", className)
                AddParam(cmd, "grade", grade)
                AddParam(cmd, "room", room)
                cmd.ExecuteNonQuery()
            End Using
        End Using
    End Sub

    ''' <summary>تعديل بيانات صف</summary>
    Public Shared Sub UpdateClass(classId As Integer, className As String, grade As String, room As String)
        Using cn = GetConnection()
            Using cmd As New NpgsqlCommand(
                "UPDATE classes SET class_name = @name, grade = @grade, room = @room WHERE class_id = @id", cn)
                AddParam(cmd, "id", classId)
                AddParam(cmd, "name", className)
                AddParam(cmd, "grade", grade)
                AddParam(cmd, "room", room)
                cmd.ExecuteNonQuery()
            End Using
        End Using
    End Sub

    ''' <summary>
    ''' حذف صف. حذف الصف يجعل class_id للطلاب NULL تلقائياً (ON DELETE SET NULL)
    ''' </summary>
    Public Shared Sub DeleteClass(classId As Integer)
        Using cn = GetConnection()
            Using cmd As New NpgsqlCommand("DELETE FROM classes WHERE class_id = @id", cn)
                AddParam(cmd, "id", classId)
                cmd.ExecuteNonQuery()
            End Using
        End Using
    End Sub

#End Region

#Region "الطلاب (Students)"

    ''' <summary>
    ''' جلب الطلاب مع:
    '''  - search: البحث بالاسم أو البريد الإلكتروني أو رقم الهاتف
    '''  - classId: التصفية حسب الصف (0 = الكل)
    ''' </summary>
    Public Shared Function GetStudents(Optional search As String = "", Optional classId As Integer = 0) As DataTable
        Dim sql As String = "SELECT s.student_id, s.full_name, s.email, s.phone, s.class_id, c.class_name " &
                            "FROM students s LEFT JOIN classes c ON c.class_id = s.class_id"

        Dim conditions As New List(Of String)()
        If Not String.IsNullOrWhiteSpace(search) Then
            conditions.Add("(s.full_name ILIKE @search OR s.email ILIKE @search OR s.phone ILIKE @search)")
        End If
        If classId > 0 Then
            conditions.Add("s.class_id = @classId")
        End If
        If conditions.Count > 0 Then
            sql &= " WHERE " & String.Join(" AND ", conditions)
        End If
        sql &= " ORDER BY s.student_id"

        Using cn = GetConnection()
            Using cmd As New NpgsqlCommand(sql, cn)
                If Not String.IsNullOrWhiteSpace(search) Then
                    cmd.Parameters.AddWithValue("search", "%" & search & "%")
                End If
                If classId > 0 Then
                    cmd.Parameters.AddWithValue("classId", classId)
                End If
                Dim dt As New DataTable()
                dt.Load(cmd.ExecuteReader())
                Return dt
            End Using
        End Using
    End Function

    ''' <summary>إضافة طالب جديد (classId يمكن أن يكون DBNull)</summary>
    Public Shared Sub InsertStudent(fullName As String, email As String, phone As String, classId As Object)
        Using cn = GetConnection()
            Using cmd As New NpgsqlCommand(
                "INSERT INTO students (full_name, email, phone, class_id) VALUES (@name, @email, @phone, @classId)", cn)
                AddParam(cmd, "name", fullName)
                AddParam(cmd, "email", email)
                AddParam(cmd, "phone", phone)
                AddParam(cmd, "classId", classId)
                cmd.ExecuteNonQuery()
            End Using
        End Using
    End Sub

    ''' <summary>تعديل بيانات طالب (classId يمكن أن يكون DBNull)</summary>
    Public Shared Sub UpdateStudent(studentId As Integer, fullName As String, email As String, phone As String, classId As Object)
        Using cn = GetConnection()
            Using cmd As New NpgsqlCommand(
                "UPDATE students SET full_name = @name, email = @email, phone = @phone, class_id = @classId " &
                "WHERE student_id = @id", cn)
                AddParam(cmd, "id", studentId)
                AddParam(cmd, "name", fullName)
                AddParam(cmd, "email", email)
                AddParam(cmd, "phone", phone)
                AddParam(cmd, "classId", classId)
                cmd.ExecuteNonQuery()
            End Using
        End Using
    End Sub

    ''' <summary>حذف طالب</summary>
    Public Shared Sub DeleteStudent(studentId As Integer)
        Using cn = GetConnection()
            Using cmd As New NpgsqlCommand("DELETE FROM students WHERE student_id = @id", cn)
                AddParam(cmd, "id", studentId)
                cmd.ExecuteNonQuery()
            End Using
        End Using
    End Sub

#End Region

End Class
