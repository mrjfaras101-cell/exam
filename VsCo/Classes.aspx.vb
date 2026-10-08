Public Class ClassesPage
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(sender As Object, e As EventArgs) Handles Me.Load
        If Not IsPostBack Then
            BindGrid()
        End If
    End Sub

    ''' <summary>ربط جدول الصفوف بالبيانات (مع تمرير فلتر البحث)</summary>
    Private Sub BindGrid()
        gvClasses.DataSource = DbHelper.GetClasses(txtSearch.Text.Trim())
        gvClasses.DataBind()
    End Sub

    ''' <summary>عرض رسالة للمستخدم (نجاح / خطأ)</summary>
    Private Sub ShowMessage(text As String, isError As Boolean)
        lblMessage.Text = text
        lblMessage.CssClass = "alert " & If(isError, "alert-danger", "alert-success")
    End Sub

    ''' <summary>إضافة صف جديد</summary>
    Protected Sub btnAdd_Click(sender As Object, e As EventArgs)
        Try
            DbHelper.InsertClass(txtName.Text.Trim(), txtGrade.Text.Trim(), txtRoom.Text.Trim())
            txtName.Text = String.Empty
            txtGrade.Text = String.Empty
            txtRoom.Text = String.Empty
            ShowMessage("تمت إضافة الصف بنجاح.", False)
            BindGrid()
        Catch ex As Exception
            ShowMessage("حدث خطأ أثناء الإضافة: " & ex.Message, True)
        End Try
    End Sub

    ''' <summary>بحث بالاسم</summary>
    Protected Sub btnSearch_Click(sender As Object, e As EventArgs)
        gvClasses.PageIndex = 0
        BindGrid()
    End Sub

    ''' <summary>إعادة تعيين البحث</summary>
    Protected Sub btnReset_Click(sender As Object, e As EventArgs)
        txtSearch.Text = String.Empty
        gvClasses.PageIndex = 0
        BindGrid()
    End Sub

    Protected Sub gvClasses_PageIndexChanging(sender As Object, e As GridViewPageEventArgs)
        gvClasses.PageIndex = e.NewPageIndex
        BindGrid()
    End Sub

    Protected Sub gvClasses_RowEditing(sender As Object, e As GridViewEditEventArgs)
        gvClasses.EditIndex = e.NewEditIndex
        BindGrid()
    End Sub

    Protected Sub gvClasses_RowCancelingEdit(sender As Object, e As GridViewCancelEditEventArgs)
        gvClasses.EditIndex = -1
        BindGrid()
    End Sub

    ''' <summary>حفظ التعديلات</summary>
    Protected Sub gvClasses_RowUpdating(sender As Object, e As GridViewUpdateEventArgs)
        Try
            Dim id As Integer = CInt(gvClasses.DataKeys(e.RowIndex).Value)
            Dim row As GridViewRow = gvClasses.Rows(e.RowIndex)
            Dim name As String = CType(row.Cells(1).Controls(0), TextBox).Text.Trim()
            Dim grade As String = CType(row.Cells(2).Controls(0), TextBox).Text.Trim()
            Dim room As String = CType(row.Cells(3).Controls(0), TextBox).Text.Trim()

            DbHelper.UpdateClass(id, name, grade, room)
            gvClasses.EditIndex = -1
            ShowMessage("تم تحديث بيانات الصف.", False)
            BindGrid()
        Catch ex As Exception
            ShowMessage("حدث خطأ أثناء التحديث: " & ex.Message, True)
        End Try
    End Sub

    ''' <summary>حذف صف</summary>
    Protected Sub gvClasses_RowDeleting(sender As Object, e As GridViewDeleteEventArgs)
        Try
            Dim id As Integer = CInt(gvClasses.DataKeys(e.RowIndex).Value)
            DbHelper.DeleteClass(id)
            ShowMessage("تم حذف الصف.", False)
            BindGrid()
        Catch ex As Exception
            ShowMessage("حدث خطأ أثناء الحذف: " & ex.Message, True)
        End Try
    End Sub

    ''' <summary>إضافة تأكيد قبل الحذف</summary>
    Protected Sub gvClasses_RowDataBound(sender As Object, e As GridViewRowEventArgs)
        If e.Row.RowType <> DataControlRowType.DataRow Then Return

        For Each ctrl As Control In e.Row.Cells(4).Controls
            Dim btn = TryCast(ctrl, LinkButton)
            If btn IsNot Nothing AndAlso btn.CommandName = "Delete" Then
                btn.OnClientClick = "return confirm('هل أنت متأكد من حذف هذا الصف؟');"
            End If
        Next
    End Sub
End Class
