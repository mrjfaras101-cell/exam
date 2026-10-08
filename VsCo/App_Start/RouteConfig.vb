Imports System.Web.Routing

Public Class RouteConfig
    Public Shared Sub RegisterRoutes(routes As RouteCollection)
        routes.Ignore("{resource}.axd/{*pathInfo}")
    End Sub
End Class
