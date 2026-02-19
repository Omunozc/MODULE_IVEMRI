<%@ Page Title="" Language="C#" MasterPageFile="~/STODpla.Master" AutoEventWireup="true" CodeBehind="IVEMRI_Lista.aspx.cs" Inherits="STOD_Web.IVEMRI_Lista" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    
    <style type="text/css">
        /* --- ESTILOS VISUALES --- */
        .centro-btn { text-align: center !important; vertical-align: middle !important; }
        .izquierda-txt { text-align: left !important; vertical-align: middle !important; padding-left: 15px !important; }
         .derecha-txt { text-align: right !important; vertical-align: middle !important; padding-right: 15px !important; }

        
        .titulo-matriz {
            font-size: 32px !important; 
            color: #2c3e50;
            margin-top: 15px; 
            margin-bottom: 15px; 
            font-weight: 800;
            letter-spacing: -0.5px;
        }

        .col-mensaje {
            min-width: 350px !important; 
            padding: 12px 20px !important; 
            text-align: left !important;
            vertical-align: middle !important;
            font-weight: 500;
        }
    </style>

    <div class="container-fluid mt-3 mb-5">
        <h1 class="titulo-matriz">Consulta Matriz de Riesgo IVEMRI</h1>
        <hr style="margin-bottom: 25px;" />

        <div class="card shadow-sm mb-4">
            <div class="card-header bg-primary text-white">
                <h5 class="mb-0" style="color: white;">Filtro de Búsqueda</h5>
            </div>
            <div class="card-body">
                <div class="row">
                    <div class="col-md-9 col-lg-8">
                        <asp:Label ID="lblFactura" runat="server" Text="Número de Factura:" Font-Bold="true"></asp:Label>
                        
                        <div style="display: flex; gap: 10px; margin-top: 5px;">
                            <asp:TextBox ID="txtNumeroFactura" runat="server" 
                                CssClass="form-control" 
                                placeholder="Ingrese factura 00000" 
                                autocomplete="off" 
                                MaxLength="50"
                                style="flex: 1; min-width: 200px;"></asp:TextBox> 
        
                            <asp:Button ID="btnConsultar" runat="server" Text="Consultar Matriz (Hoy)" 
                                CssClass="btn btn-primary" 
                                ValidationGroup="GrupoBusqueda" 
                                OnClick="btnConsultar_Click" />

                            <asp:Button ID="btnHistorico" runat="server" Text="Búsqueda Histórica" 
                                CssClass="btn btn-secondary" 
                                ValidationGroup="GrupoBusqueda" 
                                OnClick="btnHistorico_Click" />

                            <asp:Button ID="btnRefrescar" runat="server" Text="🔄 Refrescar" 
                                CssClass="btn btn-success" 
                                CausesValidation="false" 
                                OnClick="btnRefrescar_Click" />
                        </div>
                            
                        <asp:RequiredFieldValidator ID="rfvFactura" runat="server" 
                            ControlToValidate="txtNumeroFactura" 
                            ErrorMessage="* Por favor ingrese un número de factura." 
                            ForeColor="Red" 
                            ValidationGroup="GrupoBusqueda" 
                            Display="Dynamic" 
                            CssClass="small"
                            style="margin-top: 5px; display: block;"></asp:RequiredFieldValidator>
                    </div>
                </div>
            </div>
        </div>

        <div style="margin-top: 25px; margin-bottom: 25px;">
            <asp:Label ID="lblMensaje" runat="server" Font-Bold="true" Font-Size="12pt"></asp:Label>
        </div>

        <div class="table-responsive shadow-sm p-3 bg-white" style="border-radius: 5px; border: 1px solid #ddd;">
            <asp:GridView ID="gvResultado" runat="server" AutoGenerateColumns="false"
                CssClass="table table-bordered table-striped table-hover mb-0"
                AllowPaging="false" 
                DataKeyNames="NumeroFactura, HTML" 
                OnRowCommand="gvResultado_RowCommand">
                
                <HeaderStyle BackColor="#f8f9fa" Font-Bold="true" HorizontalAlign="Center" />
                
                 <Columns>
                    <asp:BoundField DataField="FechaHoraEjecucion" HeaderText="Fecha y Hora">
                        <ItemStyle CssClass="centro-btn" Width="150px" />
                    </asp:BoundField>

                    <asp:BoundField DataField="NumeroFactura" HeaderText="No. Factura">
                        <ItemStyle CssClass="izquierda-txt" Font-Bold="true" Width="150px" />
                    </asp:BoundField> 

                    <%-- <asp:BoundField DataField="STOD" HeaderText="Usuario STOD">
                        <ItemStyle CssClass="centro-btn" Width="150px" />
                    </asp:BoundField> --%> 

                    <asp:BoundField DataField="UsuarioSAP_Nombre" HeaderText="Nombre SAP">
                        <ItemStyle CssClass="izquierda-txt" Width="150px" />
                    </asp:BoundField>

                    <asp:BoundField DataField="UsuarioSAP_Codigo" HeaderText="Cód. SAP">
                        <ItemStyle CssClass="izquierda-txt" Width="80px" />
                    </asp:BoundField>

                    <%-- <asp:BoundField DataField="Mensaje" HeaderText="Resultado de Validación">
                        <ItemStyle CssClass="col-mensaje" />
                    </asp:BoundField> --%> 

                    <asp:TemplateField HeaderText="Acciones">
                        <ItemStyle CssClass="centro-btn" Width="120px" />
                        <ItemTemplate>
                            <asp:Button ID="btnVerMatriz" runat="server" 
                                Text="Ver Matriz" 
                                CommandName="ver_matriz" 
                                CommandArgument='<%# ((GridViewRow) Container).RowIndex %>' 
                                CssClass="btn btn-info btn-sm text-white" />
                        </ItemTemplate>
                    </asp:TemplateField>
                </Columns>
            </asp:GridView>
        </div>

        <div class="d-flex justify-content-between align-items-center mb-4 mt-2">
            <asp:Button ID="btnAnterior" runat="server" Text="&laquo; Página Anterior" CssClass="btn btn-outline-primary" OnClick="btnAnterior_Click" Enabled="false" />
            <asp:Label ID="lblPaginaActual" runat="server" Text="Página 1" Font-Bold="true" CssClass="text-muted"></asp:Label>
            <asp:Button ID="btnSiguiente" runat="server" Text="Página Siguiente &raquo;" CssClass="btn btn-outline-primary" OnClick="btnSiguiente_Click" />
            
            <asp:HiddenField ID="hfPaginaActual" runat="server" Value="1" />
            <asp:HiddenField ID="hfModo" runat="server" Value="GENERAL" />
        </div>

        <div id="panelMatriz" runat="server" visible="false" class="card shadow-sm mt-4 border-info">
            <div class="card-header bg-dark text-white d-flex justify-content-between align-items-center">
                <h5 class="mb-0" style="color: white;">Vista Detallada de la Matriz</h5>
                <asp:LinkButton ID="btnCerrarMatriz" runat="server" CssClass="btn btn-danger btn-sm" OnClick="btnCerrarMatriz_Click">
                    ✖ Cerrar Matriz
                </asp:LinkButton>
            </div>
            <div class="card-body bg-light" style="min-height: 150px; overflow-x: auto;">
                <asp:Literal ID="litHtmlMatriz" runat="server"></asp:Literal>
            </div>
        </div>

    </div>
</asp:Content>
