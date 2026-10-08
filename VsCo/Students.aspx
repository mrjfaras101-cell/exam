<%@ Page Title="إدارة الطلاب" Language="VB" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Students.aspx.vb" Inherits="VsCo.StudentsPage" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <h2 class="mb-3">إدارة الطلاب</h2>

    <asp:Label ID="lblMessage" runat="server" EnableViewState="false" CssClass="alert" role="alert"></asp:Label>

    <div class="card mb-4">
        <div class="card-header">إضافة طالب جديد</div>
        <div class="card-body">
            <div class="row g-2 align-items-end">
                <div class="col-md-3">
                    <label class="form-label">الاسم الكامل</label>
                    <asp:TextBox ID="txtFullName" runat="server" CssClass="form-control" placeholder="مثال: أحمد محمد علي"></asp:TextBox>
                    <asp:RequiredFieldValidator ID="valFullName" runat="server" ControlToValidate="txtFullName"
                        ErrorMessage="الاسم الكامل مطلوب" CssClass="text-danger small" Display="Dynamic"
                        ValidationGroup="AddStudent"></asp:RequiredFieldValidator>
                </div>
                <div class="col-md-3">
                    <label class="form-label">البريد الإلكتروني</label>
                    <asp:TextBox ID="txtEmail" runat="server" CssClass="form-control" TextMode="Email" placeholder="name@example.com"></asp:TextBox>
                </div>
                <div class="col-md-2">
                    <label class="form-label">رقم الهاتف</label>
                    <asp:TextBox ID="txtPhone" runat="server" CssClass="form-control" placeholder="05xxxxxxxx"></asp:TextBox>
                </div>
                <div class="col-md-2">
                    <label class="form-label">الصف</label>
                    <asp:DropDownList ID="ddlClass" runat="server" CssClass="form-select"></asp:DropDownList>
                </div>
                <div class="col-md-2">
                    <asp:Button ID="btnAdd" runat="server" Text="إضافة" CssClass="btn btn-success w-100"
                        OnClick="btnAdd_Click" ValidationGroup="AddStudent" />
                </div>
            </div>
        </div>
    </div>

    <div class="card mb-4">
        <div class="card-header">بحث وتصفية</div>
        <div class="card-body">
            <div class="row g-2">
                <div class="col-md-4">
                    <label class="form-label">كلمة البحث (الاسم / البريد / الهاتف)</label>
                    <asp:TextBox ID="txtSearch" runat="server" CssClass="form-control" placeholder="اكتب جزءاً من الاسم أو البريد الإلكتروني"></asp:TextBox>
                </div>
                <div class="col-md-3">
                    <label class="form-label">تصفية حسب الصف</label>
                    <asp:DropDownList ID="ddlFilterClass" runat="server" CssClass="form-select"></asp:DropDownList>
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
        <div class="card-header">قائمة الطلاب</div>
        <div class="card-body">
            <asp:GridView ID="gvStudents" runat="server" CssClass="table table-striped table-bordered table-hover"
                AutoGenerateColumns="False" DataKeyNames="student_id" AllowPaging="True" PageSize="10"
                OnPageIndexChanging="gvStudents_PageIndexChanging"
                OnRowEditing="gvStudents_RowEditing"
                OnRowCancelingEdit="gvStudents_RowCancelingEdit"
                OnRowUpdating="gvStudents_RowUpdating"
                OnRowDeleting="gvStudents_RowDeleting"
                OnRowDataBound="gvStudents_RowDataBound"
                EmptyDataText="لا يوجد طلاب">
                <Columns>
                    <asp:BoundField DataField="student_id" HeaderText="الرقم" ReadOnly="True" />
                    <asp:BoundField DataField="full_name" HeaderText="الاسم الكامل" />
                    <asp:BoundField DataField="email" HeaderText="البريد الإلكتروني" />
                    <asp:BoundField DataField="phone" HeaderText="رقم الهاتف" />
                    <asp:TemplateField HeaderText="الصف">
                        <ItemTemplate>
                            <asp:Label ID="lblClassName" runat="server" Text='<%# Eval("class_name") %>'></asp:Label>
                        </ItemTemplate>
                        <EditItemTemplate>
                            <asp:DropDownList ID="ddlClassEdit" runat="server" CssClass="form-select"></asp:DropDownList>
                        </EditItemTemplate>
                    </asp:TemplateField>
                    <asp:CommandField ShowEditButton="True" ShowDeleteButton="True"
                        EditText="تعديل" DeleteText="حذف" UpdateText="حفظ" CancelText="إلغاء"
                        ItemStyle-CssClass="text-nowrap" />
                </Columns>
                <PagerSettings Mode="NumericFirstLast" />
            </asp:GridView>
        </div>
    </div>
</asp:Content>
