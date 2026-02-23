<%@ Page Title="" Language="C#" MasterPageFile="~/STODpla.Master" AutoEventWireup="true" CodeBehind="IVEMRI_Lista.aspx.cs" Inherits="STOD_Web.IVEMRI_Lista" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="server">
    
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">
    <style type="text/css">
        /* --- 1. PADDING Y ESTRUCTURA --- */
        html, body, .container-fluid { 
            padding: 0 !important; 
            margin: 0px;
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
            display: none;
            position: fixed;
            z-index: 9999;
            top: 0; left: 0;
            width: 100%; height: 100%;
            background-color: rgba(0,0,0,0.6);
            backdrop-filter: blur(2px);
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
                /* Efecto de girar el icono de refrescar */
        .btn-refrescar:hover i {
            display: inline-block;
            animation: girarRapido 0.8s linear infinite;
        }

        @keyframes girarRapido {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
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

        /* --- 4. CONFIGURACIÓN DE IMPRESIÓN --- */
        @media print {
            body * { visibility: hidden; }
            #iframeMatriz, #iframeMatriz * { 
                visibility: visible; 
                /* FORZAR COLORES EN IMPRESIÓN */
                -webkit-print-color-adjust: exact !important; 
                print-color-adjust: exact !important;
                margin: 0.5cm; 
            }
            #iframeMatriz { 
                position: absolute; 
                left: 0; 
                top: 0; 
                width: 100%; 
                height: 100%; 
                border: none;
            }
        }

        /* --- 5. ANIMACIONES --- */
        .btn { transition: all 0.3s ease !important; }
        .btn:hover { transform: translateY(-2px); box-shadow: 0 4px 8px rgba(0,0,0,0.15); }
        .fade-in-up { animation: fadeInUp 0.4s ease-out forwards; }

        @keyframes fadeInUp {
            from { opacity: 0; transform: translateY(15px); }
            to { opacity: 1; transform: translateY(0); }
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
        <h1 class="titulo-matriz">Consulta Matriz de Riesgo</h1>
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
        
                            <asp:Button ID="btnHistorico" runat="server" Text="Histórico" CssClass="btn btn-primary" 
                                ValidationGroup="GrupoBusqueda" OnClick="btnHistorico_Click" 
                                OnClientClick="return ejecutarBloqueo(this, '...', true);" />

                            <asp:Button ID="btnConsultar" runat="server" Text="Consultar" CssClass="btn btn-secondary" 
                                ValidationGroup="GrupoBusqueda" OnClick="btnConsultar_Click" 
                                OnClientClick="return ejecutarBloqueo(this, '...', true);" />
                            
                            <asp:LinkButton ID="btnRefrescar" runat="server" CssClass="btn btn-secondary btn-refrescar" 
                                OnClick="btnRefrescar_Click" 
                                OnClientClick="return ejecutarBloqueo(this, '...', false);">
                                <i class="bi bi-arrow-clockwise"></i> Refrescar
                            </asp:LinkButton>

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
                            <ItemStyle CssClass="centro-btn" Width="130px" />
                        </asp:BoundField>

                        <asp:BoundField DataField="UsuarioSAP_Nombre" HeaderText="Usuario SAP">
                            <ItemStyle CssClass="izquierda-txt" />
                        </asp:BoundField>

                        <asp:TemplateField HeaderText="Acciones">
                            <ItemStyle CssClass="centro-btn" Width="60px" />
                            <ItemTemplate>
                                <asp:LinkButton ID="btnVerMatriz" runat="server" 
                                    CommandName="ver_matriz" 
                                    CommandArgument='<%# ((GridViewRow) Container).RowIndex %>' 
                                    CssClass="btn btn-info btn-mini text-white" 
                                    OnClientClick="ejecutarBloqueo(this, '...', false);" 
                                    style="display: inline-flex; align-items: center; justify-content: center;">
                                    <i class="bi bi-eye-fill" style="font-size: 14px;"></i>
                                </asp:LinkButton>
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
        <div id="panelMatriz" runat="server" visible="false" class="card shadow-sm border-info fade-in-up" style="margin: 15px;">
            <div class="card-header bg-dark text-white d-flex justify-content-between align-items-center" style="padding: 12px 25px;">
                <span style="font-size: 16px; font-weight: bold; letter-spacing: 0.5px; margin-left: 10px; margin-bottom: 10px; display: inline-block;">
                    Vista Detallada
                </span>                <div>
                    <button type="button" class="btn btn-primary btn-sm" onclick="imprimirReporte();" style="margin-right: 15px; font-weight: bold; padding: 5px 15px;">
                        <i class="bi bi-printer-fill"></i> Imprimir
                    </button>
            
                    <asp:LinkButton ID="btnCerrarMatriz" runat="server" CssClass="btn btn-danger btn-sm" OnClick="btnCerrarMatriz_Click" style="padding: 5px 15px; font-weight: bold;">
                        <i class="bi bi-x-circle"></i> Cerrar
                    </asp:LinkButton>
                </div>
            </div>
            <div class="card-body bg-light" style="padding: 0;">
                <iframe id="iframeMatriz" runat="server" clientidmode="Static" width="100%" height="600px" style="border: none; background-color: white;"></iframe>
            </div>
        </div>

        <asp:HiddenField ID="hfPaginaActual" runat="server" Value="1" />
        <asp:HiddenField ID="hfModo" runat="server" Value="GENERAL" />
    </div>

    <script type="text/javascript">
        function ejecutarBloqueo(btn, textoBoton, validar) {
            if (validar && typeof (Page_ClientValidate) === 'function') {
                if (!Page_ClientValidate("GrupoBusqueda")) { return false; }
            }
            document.getElementById('loaderOverlay').style.display = 'block';
            setTimeout(function () {
                var todosLosBotones = document.querySelectorAll('input[type="submit"], input[type="button"], button, .btn');
                todosLosBotones.forEach(function (b) {
                    b.disabled = true;
                    b.style.opacity = '0.5';
                    b.style.cursor = 'wait';
                });
                if (btn.tagName === 'INPUT') { btn.value = textoBoton; }
                else { btn.style.pointerEvents = 'none'; }
            }, 10);
            return true;
        }

        function imprimirReporte() {
            var iframe = document.getElementById('iframeMatriz');
            if (iframe) {
                try {
                    // Guardamos el título original de la página
                    var tituloOriginal = document.title;

                    // Cambiamos el título a algo limpio (o vacío) para que el navegador no imprima "STOD - Canella"
                    document.title = " - ";

                    var doc = iframe.contentWindow.document;

                    // Inyectamos estilo para forzar colores y ocultar basura
                    var style = doc.createElement('style');
                    style.innerHTML = `
                @media print { 
                    body { 
                        -webkit-print-color-adjust: exact !important; 
                        print-color-adjust: exact !important; 
                    }
                    /* Ocultamos cualquier cosa que diga STOD en el contenido del iframe */
                    .no-print { display: none !important; }
                }
            `;
                    doc.head.appendChild(style);

                    iframe.contentWindow.focus();
                    iframe.contentWindow.print();

                    // Restauramos el título original después de imprimir
                    setTimeout(function () {
                        document.title = tituloOriginal;
                    }, 1000);

                } catch (e) {
                    alert("Error al procesar la impresión.");
                    console.error(e);
                }
            }
        }
    </script>
</asp:Content>
