<%@ Page Title="إدارة الصفوف" Language="VB" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Classes.aspx.vb" Inherits="VsCo.ClassesPage" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <h2 class="mb-3">إدارة الصفوف الدراسية</h2>

    <asp:Label ID="lblMessage" runat="server" EnableViewState="false" CssClass="alert" role="alert"></asp:Label>

    <div class="card mb-4">
        <div class="card-header">إضافة صف جديد</div>
        <div class="card-body">
            <div class="row g-2 align-items-end">
                <div class="col-md-4">
                    <label class="form-label">اسم الصف</label>
                    <asp:TextBox ID="txtName" runat="server" CssClass="form-control" placeholder="مثال: الصف الأول"></asp:TextBox>
                    <asp:RequiredFieldValidator ID="valName" runat="server" ControlToValidate="txtName"
                        ErrorMessage="اسم الصف مطلوب" CssClass="text-danger small" Display="Dynamic"
                        ValidationGroup="AddClass"></asp:RequiredFieldValidator>
                </div>
                <div class="col-md-3">
                    <label class="form-label">المرحلة الدراسية</label>
                    <asp:TextBox ID="txtGrade" runat="server" CssClass="form-control" placeholder="مثال: المرحلة الابتدائية"></asp:TextBox>
                </div>
                <div class="col-md-3">
                    <label class="form-label">رقم القاعة</label>
                    <asp:TextBox ID="txtRoom" runat="server" CssClass="form-control" placeholder="مثال: 101"></asp:TextBox>
                </div>
                <div class="col-md-2">
                    <asp:Button ID="btnAdd" runat="server" Text="إضافة" CssClass="btn btn-success w-100"
                        OnClick="btnAdd_Click" ValidationGroup="AddClass" />
                </div>
            </div>
        </div>
    </div>

    <div class="card mb-4">
        <div class="card-header">بحث عن صف</div>
        <div class="card-body">
            <div class="row g-2">
                <div class="col-md-4">
                    <asp:TextBox ID="txtSearch" runat="server" CssClass="form-control" placeholder="اكتب جزءاً من اسم الصف"></asp:TextBox>
                </div>
                <div class="col-md-2">
                    <asp:Button ID="btnSearch" runat="server" Text="بحث" CssClass="btn btn-primary" OnClick="btnSearch_Click" />
                </div>
                <div class="col-md-2">
                    <asp:Button ID="btnReset" runat="server" Text="إعادة تعيين" CssClass="btn btn-outline-secondary" OnClick="btnReset_Click" CausesValidation="false" />
                </div>
            </div>
        </div>
    </div>

    <div class="card">
        <div class="card-header">قائمة الصفوف</div>
        <div class="card-body">
            <asp:GridView ID="gvClasses" runat="server" CssClass="table table-striped table-bordered table-hover"
                AutoGenerateColumns="False" DataKeyNames="class_id" AllowPaging="True" PageSize="10"
                OnPageIndexChanging="gvClasses_PageIndexChanging"
                OnRowEditing="gvClasses_RowEditing"
                OnRowCancelingEdit="gvClasses_RowCancelingEdit"
                OnRowUpdating="gvClasses_RowUpdating"
                OnRowDeleting="gvClasses_RowDeleting"
                OnRowDataBound="gvClasses_RowDataBound"
                EmptyDataText="لا توجد صفوف">
                <Columns>
                    <asp:BoundField DataField="class_id" HeaderText="الرقم" ReadOnly="True" />
                    <asp:BoundField DataField="class_name" HeaderText="اسم الصف" />
                    <asp:BoundField DataField="grade" HeaderText="المرحلة" />
                    <asp:BoundField DataField="room" HeaderText="رقم القاعة" />
                    <asp:CommandField ShowEditButton="True" ShowDeleteButton="True"
                        EditText="تعديل" DeleteText="حذف" UpdateText="حفظ" CancelText="إلغاء"
                        ItemStyle-CssClass="text-nowrap" />
                </Columns>
                <PagerSettings Mode="NumericFirstLast" />
            </asp:GridView>
        </div>
    </div>
</asp:Content>
