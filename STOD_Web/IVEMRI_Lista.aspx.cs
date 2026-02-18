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
                CargarListadoGeneral();
        }

        #region Eventos de Botones

        // Botón 1: Consulta y Genera (Proceso Completo/SAP)
        protected void btnConsultar_Click(object sender, EventArgs e)
        {
            RealizarProcesoBusqueda("NORMAL");
        }

        // Botón 2: Búsqueda Histórica (Solo Bitácora)
        protected void btnHistorico_Click(object sender, EventArgs e)
        {
            RealizarProcesoBusqueda("HISTORICO");
        }

        #endregion

        #region Lógica de Búsqueda Unificada
        private void RealizarProcesoBusqueda(string tipo)
        {
            // 1. Validación de controles de la página
            if (!Page.IsValid) return;

            // 2. Limpieza de entrada y de interfaz
            string facturaBuscada = txtNumeroFactura.Text.Trim();
            lblMensaje.Text = "";
            gvResultado.DataSource = null;
            gvResultado.DataBind();
            litHtmlMatriz.Text = "";
            panelMatriz.Visible = false;

            // 3. Validación Defensiva de longitud
            if (facturaBuscada.Length < 3)
            {
                lblMensaje.Text = "⚠️ El número de factura es demasiado corto. Revíselo.";
                lblMensaje.ForeColor = System.Drawing.Color.Orange;
                return;
            }

            try
            {
                // 4. Preparación de parámetros
                IVEMRIWS.CL_Diccionario[] parametros = new IVEMRIWS.CL_Diccionario[2];
                parametros[0] = new IVEMRIWS.CL_Diccionario { Nombre = "@NumeroFactura", Valor = facturaBuscada };
                parametros[1] = new IVEMRIWS.CL_Diccionario
                {
                    Nombre = "@UsuarioSTOD",
                    Valor = Session["USR_Usuario"] != null ? Session["USR_Usuario"].ToString() : "AdminLocal"
                };

                // 5. Instancia del Web Service
                IVEMRIWS.IVEMRIWebService ws = new IVEMRIWS.IVEMRIWebService();
                IVEMRIWS.CL_Resultado resultado;

                // 6. Selección del método según el botón presionado
                if (tipo == "HISTORICO")
                    resultado = ws.IVEMRI_ConsultarHistoricoMatriz(parametros);
                else
                    resultado = ws.IVEMRI_ConsultarMatrizRiesgo(parametros);

                // 7. Evaluación de la ejecución
                if (resultado.resultadoEjecucion)
                {
                    if (resultado.Datos != null && resultado.Datos.Rows.Count > 0)
                    {
                        gvResultado.DataSource = resultado.Datos;
                        gvResultado.DataBind();
                        lblMensaje.Text = (tipo == "HISTORICO") ? "✅ Historial recuperado exitosamente." : "✅ Consulta generada exitosamente.";
                        lblMensaje.ForeColor = System.Drawing.Color.Green;
                    }
                    else
                    {
                        // Cambia temporalmente esta línea para ver si el objeto Datos es nulo o solo está vacío
                        string razon = (resultado.Datos == null) ? "Objeto Datos es Nulo" : "Tabla tiene 0 filas";
                        lblMensaje.Text = $"ℹ️ No se encontraron coincidencias ({razon}) para: {facturaBuscada}";
                        lblMensaje.ForeColor = System.Drawing.Color.Blue;
                    }
                }
                else
                {
                    // Manejo detallado de errores según tu lógica previa
                    string detalleError = "No se encontraron coincidencias para la factura buscada.";
                    System.Drawing.Color colorMensaje = System.Drawing.Color.Blue;
                    string icono = "ℹ️ ";

                    if (resultado.Mensaje != null && !string.IsNullOrEmpty(resultado.Mensaje.MensajeDescripcion))
                    {
                        detalleError = resultado.Mensaje.MensajeDescripcion;
                        colorMensaje = System.Drawing.Color.Red;
                        icono = "❌ ";
                    }

                    lblMensaje.Text = icono + detalleError;
                    lblMensaje.ForeColor = colorMensaje;
                }
            }
            catch (Exception ex)
            {
                lblMensaje.Text = "❌ Error de conexión: " + ex.Message;
                lblMensaje.ForeColor = System.Drawing.Color.DarkRed;
            }
        }
        #endregion

        #region Listado General
        private void CargarListadoGeneral()
        {
            try
            {
                IVEMRIWS.CL_Diccionario[] parametros = new IVEMRIWS.CL_Diccionario[2];
                parametros[0] = new IVEMRIWS.CL_Diccionario { Nombre = "@Pagina", Valor = "1" };
                parametros[1] = new IVEMRIWS.CL_Diccionario { Nombre = "@RegistrosPorPagina", Valor = "20" };

                IVEMRIWS.IVEMRIWebService ws = new IVEMRIWS.IVEMRIWebService();
                IVEMRIWS.CL_Resultado resultado = ws.IVEMRI_ListarBitacoraPaginada(parametros);

                if (resultado.resultadoEjecucion && resultado.Datos != null)
                {
                    gvResultado.DataSource = resultado.Datos;
                    gvResultado.DataBind();
                }
            }
            catch (Exception ex)
            {
                lblMensaje.Text = "❌ Error al cargar listado: " + ex.Message;
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

                    // Lógica Maestra: Recuperar HTML desde el DataKey (memoria)
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

                        // Scroll automático al panel de la matriz
                        ScriptManager.RegisterStartupScript(this, GetType(), "scroll", "location.hash = '#panelDetalle';", true);
                    }
                }
                catch (Exception ex)
                {
                    lblMensaje.Text = "❌ Error al mostrar matriz: " + ex.Message;
                }
            }
        }
        #endregion
    }
}
