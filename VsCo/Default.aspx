<%@ Page Title="الرئيسية" Language="VB" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Default.aspx.vb" Inherits="VsCo.DefaultPage" %>

<asp:Content ID="Content1" ContentPlaceHolderID="MainContent" runat="server">
    <div class="p-5 mb-4 bg-white rounded-3 shadow-sm border">
        <div class="container-fluid py-3">
            <h1 class="display-5 fw-bold">مرحباً بك في تطبيق vsco التعليمي</h1>
            <p class="col-md-8 fs-4">
                تطبيق ويب بسيط لتعليم قواعد البيانات: إدارة الطلاب والصفوف الدراسية
                باستخدام Visual Basic و PostgreSQL.
            </p>
            <hr class="my-4" />
            <p>العمليات المتاحة: الإضافة، التعديل، الحذف، البحث، والتصفية حسب الصف.</p>
        </div>
    </div>

    <div class="row">
        <div class="col-md-6 mb-3">
            <div class="card h-100">
                <div class="card-body">
                    <h3 class="card-title">الطلاب</h3>
                    <p class="card-text">إضافة الطلاب وتعديل بياناتهم وحذفهم، والبحث عنهم وتصفيتهم حسب الصف الدراسي.</p>
                    <a href="Students.aspx" class="btn btn-primary">فتح صفحة الطلاب</a>
                </div>
            </div>
        </div>
        <div class="col-md-6 mb-3">
            <div class="card h-100">
                <div class="card-body">
                    <h3 class="card-title">الصفوف</h3>
                    <p class="card-text">إدارة الصفوف الدراسية (الاسم، المرحلة، رقم القاعة) مع إمكانية البحث عن الصفوف.</p>
                    <a href="Classes.aspx" class="btn btn-primary">فتح صفحة الصفوف</a>
                </div>
            </div>
        </div>
    </div>
</asp:Content>
