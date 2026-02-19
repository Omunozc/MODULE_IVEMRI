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
                hfModo.Value = "GENERAL";
                CargarListadoGeneral(1);
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
            lblMensaje.Text = "🔄 Listado actualizado y restablecido.";
            lblMensaje.ForeColor = System.Drawing.Color.Green;

            hfModo.Value = "GENERAL";
            CargarListadoGeneral(1);
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
                IVEMRIWS.CL_Resultado resultado;

                if (tipo == "HISTORICO")
                    // Si el proxy requiere List, cambia parametros a parametros.ToList()
                    resultado = ws.IVEMRI_ConsultarHistoricoMatriz(parametros);
                else
                    resultado = ws.IVEMRI_ConsultarMatrizRiesgo(parametros);

                if (resultado.resultadoEjecucion)
                {
                    if (resultado.Datos != null && resultado.Datos.Rows.Count > 0)
                    {
                        Session["TablaBusqueda"] = resultado.Datos;
                        hfModo.Value = "BUSQUEDA";
                        CargarPaginaBusqueda(1);

                        lblMensaje.Text = (tipo == "HISTORICO") ? "✅ Historial recuperado exitosamente." : "✅ Consulta generada exitosamente.";
                        lblMensaje.ForeColor = System.Drawing.Color.Green;
                    }
                    else
                    {
                        lblMensaje.Text = $"ℹ️ No se encontraron coincidencias para: {facturaBuscada}";
                        lblMensaje.ForeColor = System.Drawing.Color.Blue;
                        btnAnterior.Visible = false; btnSiguiente.Visible = false; lblPaginaActual.Visible = false;
                    }
                }
                else
                {
                    lblMensaje.Text = "❌ " + (resultado.Mensaje != null ? resultado.Mensaje.MensajeDescripcion : "Error sin detalle.");
                    lblMensaje.ForeColor = System.Drawing.Color.Red;
                    btnAnterior.Visible = false; btnSiguiente.Visible = false; lblPaginaActual.Visible = false;
                }
            }
            catch (Exception ex)
            {
                lblMensaje.Text = "❌ Error de conexión: " + ex.Message;
                lblMensaje.ForeColor = System.Drawing.Color.DarkRed;
            }
        }

        private void CargarPaginaBusqueda(int pagina)
        {
            DataTable dtBusqueda = Session["TablaBusqueda"] as DataTable;

            if (dtBusqueda != null)
            {
                PagedDataSource pds = new PagedDataSource();
                pds.DataSource = dtBusqueda.DefaultView;
                pds.AllowPaging = true;
                pds.PageSize = 20;
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
        }
        #endregion

        #region Listado General (Paginado por SQL)
        private void CargarListadoGeneral(int pagina)
        {
            try
            {
                int registrosPorPagina = 20;

                IVEMRIWS.CL_Diccionario[] parametros = new IVEMRIWS.CL_Diccionario[2];
                parametros[0] = new IVEMRIWS.CL_Diccionario { Nombre = "@Pagina", Valor = pagina.ToString() };
                parametros[1] = new IVEMRIWS.CL_Diccionario { Nombre = "@RegistrosPorPagina", Valor = registrosPorPagina.ToString() };

                IVEMRIWS.IVEMRIWebService ws = new IVEMRIWS.IVEMRIWebService();
                // Si el proxy requiere List, cambia parametros a parametros.ToList()
                IVEMRIWS.CL_Resultado resultado = ws.IVEMRI_ListarBitacoraPaginada(parametros);

                if (resultado.resultadoEjecucion && resultado.Datos != null)
                {
                    gvResultado.DataSource = resultado.Datos;
                    gvResultado.DataBind();

                    hfPaginaActual.Value = pagina.ToString();
                    lblPaginaActual.Text = "Página " + pagina;

                    btnAnterior.Enabled = (pagina > 1);
                    btnSiguiente.Enabled = (resultado.Datos.Rows.Count == registrosPorPagina);

                    btnAnterior.Visible = true;
                    btnSiguiente.Visible = true;
                    lblPaginaActual.Visible = true;
                }
            }
            catch (Exception ex)
            {
                lblMensaje.Text = "❌ Error al cargar listado: " + ex.Message;
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
