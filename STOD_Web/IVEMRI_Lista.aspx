<%@ Page Title="" Language="C#" MasterPageFile="~/STODpla.Master" AutoEventWireup="true" CodeBehind="IVEMRI_Lista.aspx.cs" Inherits="STOD_Web.IVEMRI_Lista" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    
    <style type="text/css">
        /* --- 1. PADDING Y ESTRUCTURA --- */
        html, body, .container-fluid { 
            padding: 0 !important; 
            margin: 0 !important; 
        }
        #ContentPlaceHolder1, .main-container { padding: 0 !important; }

        .titulo-matriz {
            font-size: 32px !important; 
            color: #2c3e50;
            margin: 15px 0 15px 15px; 
            font-weight: 800;
            letter-spacing: -0.5px;
        }
        .card-original { margin: 0 15px 25px 15px; }

        /* --- 2. TABLAS Y BOTONES --- */
        .tabla-compacta { font-size: 11px !important; }
        .tabla-compacta th, .tabla-compacta td { 
            padding: 4px 6px !important; 
            vertical-align: middle !important;
        }
        .centro-btn { text-align: center !important; }
        .izquierda-txt { text-align: left !important; padding-left: 8px !important; }

        .table-wrapper {
            margin: 0 15px;
            padding: 5px;
            background-color: white;
            border: 1px solid #ddd;
            border-radius: 4px;
        }

        .btn-mini {
            padding: 2px 8px !important;
            font-size: 12px !important;
            line-height: 1 !important;
        }

        /* --- 3. ESTILOS DEL MODAL DE CARGA (LOADER) --- */
        .loading-overlay {
            display: none; /* Oculto por defecto */
            position: fixed;
            z-index: 9999;
            top: 0; left: 0;
            width: 100%; height: 100%;
            background-color: rgba(0,0,0,0.6); /* Fondo oscuro */
            backdrop-filter: blur(2px); /* Efecto de desenfoque */
        }

        .loading-content {
            position: absolute;
            top: 50%; left: 50%;
            transform: translate(-50%, -50%);
            background-color: white;
            padding: 30px;
            border-radius: 12px;
            text-align: center;
            box-shadow: 0 10px 25px rgba(0,0,0,0.5);
            min-width: 280px;
        }

        .spinner {
            border: 5px solid #f3f3f3;
            border-top: 5px solid #3498db;
            border-radius: 50%;
            width: 50px;
            height: 50px;
            animation: spin 1s linear infinite;
            margin: 0 auto 15px auto;
        }

        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
    </style>

    <div id="loaderOverlay" class="loading-overlay">
        <div class="loading-content">
            <div class="spinner"></div>
            <h4 style="margin:0; color: #2c3e50; font-weight: bold;">Procesando solicitud</h4>
            <p style="margin: 10px 0 0 0; font-size: 14px; color: #7f8c8d;">Esto puede tardar unos segundos...</p>
        </div>
    </div>

    <div class="container-fluid">
        <h1 class="titulo-matriz">Consulta Matriz de Riesgo IVEMRI</h1>
        <hr style="margin-bottom: 25px; margin-left: 15px; margin-right: 15px;" />

        <div class="card shadow-sm card-original">
            <div class="card-header bg-primary text-white">
                <h5 class="mb-0" style="color: white;">Filtro de Búsqueda</h5>
            </div>
            <div class="card-body">
                <div class="row">
                    <div class="col-md-9 col-lg-8">
                        <asp:Label ID="lblFactura" runat="server" Text="Número de Factura:" Font-Bold="true"></asp:Label>
                        <div style="display: flex; gap: 10px; margin-top: 5px;">
                            <asp:TextBox ID="txtNumeroFactura" runat="server" CssClass="form-control" placeholder="Ingrese factura..." style="flex: 1; min-width: 200px;"></asp:TextBox> 
                            
                            <asp:Button ID="btnConsultar" runat="server" Text="Consultar" CssClass="btn btn-primary" 
                                ValidationGroup="GrupoBusqueda" OnClick="btnConsultar_Click" 
                                OnClientClick="return ejecutarBloqueo(this, '...', true);" />
                            
                            <asp:Button ID="btnHistorico" runat="server" Text="Histórico" CssClass="btn btn-secondary" 
                                ValidationGroup="GrupoBusqueda" OnClick="btnHistorico_Click" 
                                OnClientClick="return ejecutarBloqueo(this, '...', true);" />
                            
                            <asp:Button ID="btnRefrescar" runat="server" Text="🔄 Refrescar" CssClass="btn btn-secondary" 
                                OnClick="btnRefrescar_Click" 
                                OnClientClick="return ejecutarBloqueo(this, '...', false);" />
                        </div>
                        <asp:RequiredFieldValidator ID="rfvFactura" runat="server" ControlToValidate="txtNumeroFactura" ErrorMessage="* Por favor ingrese un número de factura." ForeColor="Red" ValidationGroup="GrupoBusqueda" Display="Dynamic" CssClass="small"></asp:RequiredFieldValidator>
                    </div>
                </div>
            </div>
        </div>

        <div style="margin: 15px;">
            <asp:Label ID="lblMensaje" runat="server" Font-Bold="true" Font-Size="11pt"></asp:Label>
        </div>

        <div class="table-wrapper shadow-sm">
            <div class="table-responsive">
                <asp:GridView ID="gvResultado" runat="server" AutoGenerateColumns="false"
                    CssClass="table table-bordered table-striped table-hover mb-0 tabla-compacta"
                    DataKeyNames="NumeroFactura, HTML" OnRowCommand="gvResultado_RowCommand">
                    <HeaderStyle BackColor="#f8f9fa" Font-Bold="true" HorizontalAlign="Center" />
                    <Columns>
                        <asp:TemplateField HeaderText="No.">
                            <ItemStyle CssClass="centro-btn" Width="40px" />
                            <ItemTemplate><%# Container.DataItemIndex + 1 %></ItemTemplate>
                        </asp:TemplateField>

                        <asp:BoundField DataField="FechaHoraEjecucion" HeaderText="Fecha y Hora">
                            <ItemStyle CssClass="centro-btn" Width="110px" />
                        </asp:BoundField>

                        <asp:BoundField DataField="UsuarioSAP_Nombre" HeaderText="Usuario SAP">
                            <ItemStyle CssClass="izquierda-txt" />
                        </asp:BoundField>

                        <asp:TemplateField HeaderText="Acciones">
                            <ItemStyle CssClass="centro-btn" Width="60px" />
                            <ItemTemplate>
                                <asp:Button ID="btnVerMatriz" runat="server" Text="👁️" 
                                    CommandName="ver_matriz" CommandArgument='<%# ((GridViewRow) Container).RowIndex %>' 
                                    CssClass="btn btn-info btn-mini text-white" 
                                    OnClientClick="ejecutarBloqueo(this, '...', false);" UseSubmitBehavior="false" />
                            </ItemTemplate>
                        </asp:TemplateField>
                    </Columns>
                </asp:GridView>
            </div>
        </div>

        <div class="d-flex justify-content-between align-items-center mb-4 mt-2" style="padding: 0 15px;">
            <asp:Button ID="btnAnterior" runat="server" Text="&laquo; Anterior" CssClass="btn btn-outline-primary btn-sm" 
                OnClick="btnAnterior_Click" Enabled="false" OnClientClick="return ejecutarBloqueo(this, '...', false);" />
            
            <asp:Label ID="lblPaginaActual" runat="server" Text="Página 1" Font-Bold="true" CssClass="text-muted small"></asp:Label>
            
            <asp:Button ID="btnSiguiente" runat="server" Text="Siguiente &raquo;" CssClass="btn btn-outline-primary btn-sm" 
                OnClick="btnSiguiente_Click" OnClientClick="return ejecutarBloqueo(this, '...', false);" />
        </div>

        <%-- PANEL DE RESULTADO --%>
        <div id="panelMatriz" runat="server" visible="false" class="card shadow-sm border-info" style="margin: 15px;">
            <div class="card-header bg-dark text-white d-flex justify-content-between align-items-center" style="padding: 5px 15px;">
                <span style="font-size: 14px; font-weight: bold;">Vista Detallada</span>
                <asp:LinkButton ID="btnCerrarMatriz" runat="server" CssClass="btn btn-danger btn-sm" OnClick="btnCerrarMatriz_Click">
                    ✖ Cerrar
                </asp:LinkButton>
            </div>
            <div class="card-body bg-light" style="overflow-x: auto; padding: 10px;">
                <asp:Literal ID="litHtmlMatriz" runat="server"></asp:Literal>
            </div>
        </div>

        <asp:HiddenField ID="hfPaginaActual" runat="server" Value="1" />
        <asp:HiddenField ID="hfModo" runat="server" Value="GENERAL" />
    </div>

    <script type="text/javascript">
        function ejecutarBloqueo(btn, textoBoton, validar) {
            // 1. Validar si los campos requeridos están llenos
            if (validar && typeof (Page_ClientValidate) === 'function') {
                if (!Page_ClientValidate("GrupoBusqueda")) {
                    return false;
                }
            }

            // 2. Mostrar el modal de carga
            document.getElementById('loaderOverlay').style.display = 'block';

            // 3. Bloquear todos los botones de la página para evitar interrupciones
            setTimeout(function () {
                var todosLosBotones = document.querySelectorAll('input[type="submit"], input[type="button"], button, .btn');
                todosLosBotones.forEach(function (b) {
                    b.disabled = true;
                    b.style.opacity = '0.5';
                    b.style.cursor = 'wait';
                });

                // Cambiar texto al botón presionado
                if (btn.tagName === 'INPUT') {
                    btn.value = textoBoton;
                } else {
                    btn.innerText = textoBoton;
                }
            }, 10);

            return true;
        }
    </script>
</asp:Content>
