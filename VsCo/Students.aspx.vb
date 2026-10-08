Public Class StudentsPage
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(sender As Object, e As EventArgs) Handles Me.Load
        If Not IsPostBack Then
            BindClassDropDowns()
            BindGrid()
        End If
    End Sub

    ''' <summary>ملء قوائم الصفوف (قائمة الإضافة وقائمة التصفية)</summary>
    Private Sub BindClassDropDowns()
        Dim classes = DbHelper.GetClassesForDropDown()

        ddlClass.DataSource = classes
        ddlClass.DataTextField = "class_name"
        ddlClass.DataValueField = "class_id"
        ddlClass.DataBind()
        ddlClass.Items.Insert(0, New ListItem("بدون صف", ""))

        ddlFilterClass.DataSource = classes
        ddlFilterClass.DataTextField = "class_name"
        ddlFilterClass.DataValueField = "class_id"
        ddlFilterClass.DataBind()
        ddlFilterClass.Items.Insert(0, New ListItem("كل الصفوف", "0"))
    End Sub

    ''' <summary>ربط جدول الطلاب بالبيانات (مع تمرير البحث والتصفية)</summary>
    Private Sub BindGrid()
        Dim classId As Integer = 0
        If ddlFilterClass.SelectedValue <> "" Then
            classId = CInt(ddlFilterClass.SelectedValue)
        End If
        gvStudents.DataSource = DbHelper.GetStudents(txtSearch.Text.Trim(), classId)
        gvStudents.DataBind()
    End Sub

    ''' <summary>عرض رسالة للمستخدم (نجاح / خطأ)</summary>
    Private Sub ShowMessage(text As String, isError As Boolean)
        lblMessage.Text = text
        lblMessage.CssClass = "alert " & If(isError, "alert-danger", "alert-success")
    End Sub

    ''' <summary>إضافة طالب جديد</summary>
    Protected Sub btnAdd_Click(sender As Object, e As EventArgs)
        Try
            Dim classId As Object = DBNull.Value
            If ddlClass.SelectedValue <> "" Then
                classId = CInt(ddlClass.SelectedValue)
            End If

            DbHelper.InsertStudent(txtFullName.Text.Trim(), txtEmail.Text.Trim(), txtPhone.Text.Trim(), classId)

            txtFullName.Text = String.Empty
            txtEmail.Text = String.Empty
            txtPhone.Text = String.Empty
            ddlClass.SelectedIndex = 0
            ShowMessage("تمت إضافة الطالب بنجاح.", False)
            BindGrid()
        Catch ex As Exception
            ShowMessage("حدث خطأ أثناء الإضافة: " & ex.Message, True)
        End Try
    End Sub

    ''' <summary>بحث + تصفية</summary>
    Protected Sub btnSearch_Click(sender As Object, e As EventArgs)
        gvStudents.PageIndex = 0
        BindGrid()
    End Sub

    ''' <summary>إعادة تعيين البحث والتصفية</summary>
    Protected Sub btnReset_Click(sender As Object, e As EventArgs)
        txtSearch.Text = String.Empty
        ddlFilterClass.SelectedIndex = 0
        gvStudents.PageIndex = 0
        BindGrid()
    End Sub

    Protected Sub gvStudents_PageIndexChanging(sender As Object, e As GridViewPageEventArgs)
        gvStudents.PageIndex = e.NewPageIndex
        BindGrid()
    End Sub

    Protected Sub gvStudents_RowEditing(sender As Object, e As GridViewEditEventArgs)
        gvStudents.EditIndex = e.NewEditIndex
        BindGrid()
    End Sub

    Protected Sub gvStudents_RowCancelingEdit(sender As Object, e As GridViewCancelEditEventArgs)
        gvStudents.EditIndex = -1
        BindGrid()
    End Sub

    ''' <summary>حفظ التعديلات</summary>
    Protected Sub gvStudents_RowUpdating(sender As Object, e As GridViewUpdateEventArgs)
        Try
            Dim id As Integer = CInt(gvStudents.DataKeys(e.RowIndex).Value)
            Dim row As GridViewRow = gvStudents.Rows(e.RowIndex)
            Dim fullName As String = CType(row.Cells(1).Controls(0), TextBox).Text.Trim()
            Dim email As String = CType(row.Cells(2).Controls(0), TextBox).Text.Trim()
            Dim phone As String = CType(row.Cells(3).Controls(0), TextBox).Text.Trim()

            Dim classId As Object = DBNull.Value
            Dim ddl = TryCast(row.FindControl("ddlClassEdit"), DropDownList)
            If ddl IsNot Nothing AndAlso ddl.SelectedValue <> "" Then
                classId = CInt(ddl.SelectedValue)
            End If

            DbHelper.UpdateStudent(id, fullName, email, phone, classId)
            gvStudents.EditIndex = -1
            ShowMessage("تم تحديث بيانات الطالب.", False)
            BindGrid()
        Catch ex As Exception
            ShowMessage("حدث خطأ أثناء التحديث: " & ex.Message, True)
        End Try
    End Sub

    ''' <summary>حذف طالب</summary>
    Protected Sub gvStudents_RowDeleting(sender As Object, e As GridViewDeleteEventArgs)
        Try
            Dim id As Integer = CInt(gvStudents.DataKeys(e.RowIndex).Value)
            DbHelper.DeleteStudent(id)
            ShowMessage("تم حذف الطالب.", False)
            BindGrid()
        Catch ex As Exception
            ShowMessage("حدث خطأ أثناء الحذف: " & ex.Message, True)
        End Try
    End Sub

    ''' <summary>
    ''' ملاحظة: إضافة تأكيد قبل الحذف، وفي وضع التعديل نملأ قائمة الصفوف ونختار الصف الحالي
    ''' </summary>
    Protected Sub gvStudents_RowDataBound(sender As Object, e As GridViewRowEventArgs)
        If e.Row.RowType <> DataControlRowType.DataRow Then Return

        ' زر الحذف: تأكيد قبل التنفيذ
        For Each ctrl As Control In e.Row.Cells(5).Controls
            Dim btn = TryCast(ctrl, LinkButton)
            If btn IsNot Nothing AndAlso btn.CommandName = "Delete" Then
                btn.OnClientClick = "return confirm('هل أنت متأكد من حذف هذا الطالب؟');"
            End If
        Next

        ' في وضع التعديل: نملأ قائمة الصفوف ونختار الصف الحالي
        If gvStudents.EditIndex = e.Row.RowIndex Then
            Dim ddl = TryCast(e.Row.FindControl("ddlClassEdit"), DropDownList)
            If ddl IsNot Nothing Then
                ddl.DataSource = DbHelper.GetClassesForDropDown()
                ddl.DataTextField = "class_name"
                ddl.DataValueField = "class_id"
                ddl.DataBind()
                ddl.Items.Insert(0, New ListItem("بدون صف", ""))

                Dim currentClassId = System.Web.UI.DataBinder.Eval(e.Row.DataItem, "class_id")
                If currentClassId IsNot Nothing AndAlso Not IsDBNull(currentClassId) Then
                    ddl.SelectedValue = currentClassId.ToString()
                End If
            End If
        End If
    End Sub
End Class
