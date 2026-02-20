using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using System.Data;

namespace STOD_Web
{
    public partial class IVEMRI_Lista : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                // 1. Limpiamos variables de estado
                hfModo.Value = "GENERAL";
                hfPaginaActual.Value = "1";

                // 2. En lugar de cargar datos, mostramos el mensaje de bienvenida
                gvResultado.DataSource = null;
                gvResultado.DataBind();

                lblMensaje.Text = "";
                lblMensaje.ForeColor = System.Drawing.Color.Blue;

                // 3. Ocultamos los botones de paginación al inicio
                btnAnterior.Visible = false;
                btnSiguiente.Visible = false;
                lblPaginaActual.Visible = false;
            }
        }

        #region Eventos de Botones Principales

        protected void btnConsultar_Click(object sender, EventArgs e)
        {
            RealizarProcesoBusqueda("NORMAL");
        }

        protected void btnHistorico_Click(object sender, EventArgs e)
        {
            RealizarProcesoBusqueda("HISTORICO");
        }

        protected void btnRefrescar_Click(object sender, EventArgs e)
        {
            txtNumeroFactura.Text = string.Empty;
            panelMatriz.Visible = false;
            litHtmlMatriz.Text = string.Empty;

            gvResultado.DataSource = null;
            gvResultado.DataBind();

            hfModo.Value = "GENERAL";
            hfPaginaActual.Value = "1";

            btnAnterior.Visible = false;
            btnSiguiente.Visible = false;
            lblPaginaActual.Visible = false;

            lblMensaje.Text = "";
            lblMensaje.ForeColor = System.Drawing.Color.Blue;

        }
        protected void btnCerrarMatriz_Click(object sender, EventArgs e)
        {
            panelMatriz.Visible = false;
            litHtmlMatriz.Text = "";
            lblMensaje.Text = "ℹ️ Vista de matriz cerrada.";
            lblMensaje.ForeColor = System.Drawing.Color.Gray;
        }

        #endregion

        #region Controles de Paginación Personalizada

        protected void btnAnterior_Click(object sender, EventArgs e)
        {
            int paginaActual = int.Parse(hfPaginaActual.Value);
            if (paginaActual > 1)
            {
                paginaActual--;
                if (hfModo.Value == "GENERAL")
                    CargarListadoGeneral(paginaActual);
                else
                    CargarPaginaBusqueda(paginaActual);
            }
        }

        protected void btnSiguiente_Click(object sender, EventArgs e)
        {
            int paginaActual = int.Parse(hfPaginaActual.Value);
            paginaActual++;
            if (hfModo.Value == "GENERAL")
                CargarListadoGeneral(paginaActual);
            else
                CargarPaginaBusqueda(paginaActual);
        }

        #endregion

        #region Lógica de Búsqueda (Paginada en Memoria)
        private void RealizarProcesoBusqueda(string tipo)
        {
            if (!Page.IsValid) return;

            string facturaBuscada = txtNumeroFactura.Text.Trim();
            lblMensaje.Text = "";
            gvResultado.DataSource = null;
            gvResultado.DataBind();
            litHtmlMatriz.Text = "";
            panelMatriz.Visible = false;

            if (facturaBuscada.Length < 3)
            {
                lblMensaje.Text = "⚠️ El número de factura es demasiado corto. Revíselo.";
                lblMensaje.ForeColor = System.Drawing.Color.Orange;
                return;
            }

            try
            {
                IVEMRIWS.CL_Diccionario[] parametros = new IVEMRIWS.CL_Diccionario[2];
                // Nota: Si tu proxy WS requiere List<>, usa: new List<IVEMRIWS.CL_Diccionario> { new ... }
                parametros[0] = new IVEMRIWS.CL_Diccionario { Nombre = "@NumeroFactura", Valor = facturaBuscada };
                parametros[1] = new IVEMRIWS.CL_Diccionario
                {
                    Nombre = "@UsuarioSTOD",
                    Valor = Session["USR_Usuario"] != null ? Session["USR_Usuario"].ToString() : "AdminLocal"
                };

                IVEMRIWS.IVEMRIWebService ws = new IVEMRIWS.IVEMRIWebService();
                IVEMRIWS.CL_Resultado resultado = (tipo == "HISTORICO")
                    ? ws.IVEMRI_ConsultarHistoricoMatriz(parametros)
                    : ws.IVEMRI_ConsultarMatrizRiesgo(parametros);

                if (resultado.resultadoEjecucion)
                {
                    // VALIDACIÓN CLAVE: Si el SP hizo RETURN sin SELECT, Rows.Count es 0
                    if (resultado.Datos != null && resultado.Datos.Rows.Count > 0)
                    {
                        Session["TablaBusqueda"] = resultado.Datos;
                        hfModo.Value = "BUSQUEDA";
                        CargarPaginaBusqueda(1);

                        lblMensaje.Text = (tipo == "HISTORICO") ? "✅ Historial recuperado." : "✅ Consulta exitosa.";
                        lblMensaje.ForeColor = System.Drawing.Color.Green;
                    }
                    else
                    {
                        // El SP no devolvió filas (Factura inexistente o sin historial)
                        string detalle = (resultado.Mensaje != null && !string.IsNullOrEmpty(resultado.Mensaje.MensajeDescripcion))
                                         ? resultado.Mensaje.MensajeDescripcion
                                         : "No se encontraron datos para esta factura.";

                        lblMensaje.Text = "ℹ️ " + detalle;
                        lblMensaje.ForeColor = System.Drawing.Color.Red;
                    }
                }
                else
                {
                    lblMensaje.Text = "❌ " + resultado.Mensaje?.MensajeDescripcion;
                    lblMensaje.ForeColor = System.Drawing.Color.Red;
                }
            }
            catch (Exception ex)
            {
                lblMensaje.Text = "❌ Error: " + ex.Message;
                lblMensaje.ForeColor = System.Drawing.Color.DarkRed;
            }
        }

        private void CargarPaginaBusqueda(int pagina)
        {
            DataTable dtBusqueda = Session["TablaBusqueda"] as DataTable;

            // Validamos que la tabla exista y tenga columnas antes de intentar bindear
            if (dtBusqueda != null && dtBusqueda.Rows.Count > 0)
            {
                try
                {
                    PagedDataSource pds = new PagedDataSource();
                    pds.DataSource = dtBusqueda.DefaultView;
                    pds.AllowPaging = true;
                    pds.PageSize = 10;
                    pds.CurrentPageIndex = pagina - 1;

                    gvResultado.DataSource = pds;
                    gvResultado.DataBind();

                    hfPaginaActual.Value = pagina.ToString();
                    lblPaginaActual.Text = "Página " + pagina;

                    btnAnterior.Enabled = !pds.IsFirstPage;
                    btnSiguiente.Enabled = !pds.IsLastPage;

                    btnAnterior.Visible = true;
                    btnSiguiente.Visible = true;
                    lblPaginaActual.Visible = true;
                }
                catch (Exception ex)
                {
                    // Si falta una columna, aquí te dirá exactamente cuál es en el mensaje
                    lblMensaje.Text = "❌ Error en estructura de datos: " + ex.Message;
                    lblMensaje.ForeColor = System.Drawing.Color.Red;
                    gvResultado.DataSource = null;
                    gvResultado.DataBind();
                }
            }
            else
            {
                // Si no hay datos, limpiamos el Grid sin que truene
                gvResultado.DataSource = null;
                gvResultado.DataBind();
                btnAnterior.Visible = false;
                btnSiguiente.Visible = false;
                lblPaginaActual.Visible = false;
            }
        }
        #endregion

        #region Listado General (Paginado por SQL)
        private void CargarListadoGeneral(int pagina)
        {
            try
            {
                int registrosPorPagina = 10;
                IVEMRIWS.IVEMRIWebService ws = new IVEMRIWS.IVEMRIWebService();

                IVEMRIWS.CL_Diccionario[] parametros = new IVEMRIWS.CL_Diccionario[2];
                parametros[0] = new IVEMRIWS.CL_Diccionario { Nombre = "@Pagina", Valor = pagina.ToString() };
                parametros[1] = new IVEMRIWS.CL_Diccionario { Nombre = "@RegistrosPorPagina", Valor = registrosPorPagina.ToString() };

                IVEMRIWS.CL_Resultado resultado = ws.IVEMRI_ListarBitacoraPaginada(parametros);

                if (resultado.resultadoEjecucion && resultado.Datos != null && resultado.Datos.Rows.Count > 0)
                {
                    gvResultado.DataSource = resultado.Datos;
                    gvResultado.DataBind();

                    hfPaginaActual.Value = pagina.ToString();
                    lblPaginaActual.Text = "Página " + pagina;

                    btnAnterior.Visible = true;
                    btnSiguiente.Visible = true;
                    lblPaginaActual.Visible = true;

                    btnAnterior.Enabled = (pagina > 1);
                    btnSiguiente.Enabled = (resultado.Datos.Rows.Count == registrosPorPagina);
                }
                else
                {
                    // Si la tabla viene vacía, limpiamos y damos mensaje amigable
                    gvResultado.DataSource = null;
                    gvResultado.DataBind();
                    lblMensaje.Text = "";
                    lblMensaje.ForeColor = System.Drawing.Color.Gray;

                    btnAnterior.Visible = false;
                    btnSiguiente.Visible = false;
                    lblPaginaActual.Visible = false;
                }
            }
            catch (Exception ex)
            {
                lblMensaje.Text = "❌ Error al conectar con el servicio.";
                lblMensaje.ForeColor = System.Drawing.Color.DarkRed;
            }
        }
        #endregion

        #region Evento GridView (Ver Matriz)
        protected void gvResultado_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            if (e.CommandName == "ver_matriz")
            {
                try
                {
                    int index = Convert.ToInt32(e.CommandArgument);
                    string numeroFactura = gvResultado.DataKeys[index].Values["NumeroFactura"].ToString();

                    string htmlDevuelto = gvResultado.DataKeys[index].Values["HTML"] != null ?
                                         gvResultado.DataKeys[index].Values["HTML"].ToString() : "";

                    if (string.IsNullOrEmpty(htmlDevuelto) || htmlDevuelto == "SIN DATOS" || htmlDevuelto == "SIN HTML")
                    {
                        lblMensaje.Text = "ℹ️ Sin diseño de matriz disponible para la factura " + numeroFactura;
                        lblMensaje.ForeColor = System.Drawing.Color.Orange;
                        panelMatriz.Visible = false;
                    }
                    else
                    {
                        litHtmlMatriz.Text = htmlDevuelto;
                        panelMatriz.Visible = true;
                        lblMensaje.Text = "✅ Matriz cargada para la factura " + numeroFactura;
                        lblMensaje.ForeColor = System.Drawing.Color.Green;

                        ScriptManager.RegisterStartupScript(this, GetType(), "scroll", "location.hash = '#panelMatriz';", true);
                    }
                }
                catch (Exception ex)
                {
                    lblMensaje.Text = "❌ Error al mostrar matriz: " + ex.Message;
                    lblMensaje.ForeColor = System.Drawing.Color.DarkRed;
                }
            }
        }
        #endregion
    }
}
