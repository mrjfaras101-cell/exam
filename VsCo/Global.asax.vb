Imports System.Web.Routing

Public Class Global
    Inherits System.Web.HttpApplication

    Protected Sub Application_Start(sender As Object, e As EventArgs)
        RouteConfig.RegisterRoutes(RouteTable.Routes)
    End Sub
End Class
