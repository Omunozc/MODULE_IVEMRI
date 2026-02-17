using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Services;
using STOD_BLL;
using System.Data;
using STOD_DAL;
using System.Xml;

namespace STOD_Web
{
    public partial class IVEMRI_Lista : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
                CargarListadoGeneral();

        }
        #region consultar con SP
        protected void btnConsultar_Click(object sender, EventArgs e)
        {
            // 1. Si el validador del HTML falla, detenemos todo aquí mismo
            if (!Page.IsValid) return;

            // 2. Limpiamos espacios basura que haya dejado el usuario
            string facturaBuscada = txtNumeroFactura.Text.Trim();

            // Limpiamos mensajes y la tabla de consultas anteriores
            lblMensaje.Text = "";
            gvResultado.DataSource = null;
            gvResultado.DataBind();

            // 3. Validación Defensiva: Longitud mínima
            if (facturaBuscada.Length < 3)
            {
                lblMensaje.Text = "⚠️ El número de factura es demasiado corto. Revíselo.";
                lblMensaje.ForeColor = System.Drawing.Color.Orange;
                return;
            }

            try
            {
                // 4. Armamos los parámetros para el Web Service
                IVEMRIWS.CL_Diccionario[] parametros = new IVEMRIWS.CL_Diccionario[2];

                parametros[0] = new IVEMRIWS.CL_Diccionario();
                parametros[0].Nombre = "@NumeroFactura";
                parametros[0].Valor = facturaBuscada;

                parametros[1] = new IVEMRIWS.CL_Diccionario();
                parametros[1].Nombre = "@UsuarioSTOD";
                // Si no hay sesión, ponemos un genérico temporal
                parametros[1].Valor = Session["Usuario"] != null ? Session["Usuario"].ToString() : "AdminLocal";

                // 5. Llamamos al Web Service
                IVEMRIWS.IVEMRIWebService ws = new IVEMRIWS.IVEMRIWebService();
                IVEMRIWS.CL_Resultado resultado = ws.IVEMRI_ConsultarMatrizRiesgo(parametros);

                // 6. Evaluamos la respuesta
                if (resultado.resultadoEjecucion)
                {
                    // ¿Nos trajo filas de SAP?
                    if (resultado.Datos != null && resultado.Datos.Rows.Count > 0)
                    {
                        gvResultado.DataSource = resultado.Datos;
                        gvResultado.DataBind();
                        lblMensaje.Text = "✅ Consulta generada exitosamente.";
                        lblMensaje.ForeColor = System.Drawing.Color.Green;
                    }
                    else
                    {
                        // Pasó por SQL, pero devolvió la tabla vacía o el "SIN DATOS"
                        lblMensaje.Text = "ℹ️ No se encontraron coincidencias o la factura no existe.";
                        lblMensaje.ForeColor = System.Drawing.Color.Blue;
                    }
                }
                else
                {
                    // 1. Asumimos un error genérico por defecto
                    string detalleError = "Error desconocido al comunicarse con el servidor.";

                    // 2. Verificamos si el Web Service realmente nos mandó el objeto Mensaje
                    if (resultado.Mensaje != null && !string.IsNullOrEmpty(resultado.Mensaje.MensajeDescripcion))
                    {
                        detalleError = resultado.Mensaje.MensajeDescripcion;
                    }

                    // 3. Mostramos el mensaje de forma segura usando 'detalleError' en lugar de 'ex'
                    lblMensaje.Text = "❌ Error del Web Service: " + detalleError;
                    lblMensaje.ForeColor = System.Drawing.Color.Red;
                }
            }
            catch (Exception ex)
            {
                // ¡Aquí SÍ existe la variable 'ex'!
                lblMensaje.Text = "❌ Error de conexión. Intente más tarde: " + ex.Message;
                lblMensaje.ForeColor = System.Drawing.Color.DarkRed;
            }
        }
        #endregion
        // Creamos un método reutilizable para llenar el grid
        /*
        private void CargarGrid(string filtroFactura)
        {
            try
            {
                // 1. Preparamos el parámetro de búsqueda
                IVEMRIWS.CL_Diccionario[] parametros = new IVEMRIWS.CL_Diccionario[1];
                parametros[0] = new IVEMRIWS.CL_Diccionario();
                parametros[0].nombre = "@NumeroFactura"; // Cambia este nombre si tu SP de listar usa otro parámetro
                parametros[0].valor = filtroFactura;

                // 2. Instanciamos el Web Service
                IVEMRIWS.IVEMRIWebService ws = new IVEMRIWS.IVEMRIWebService();

                // 3. Llamamos al método de listar (OJO: Revisa el paso 2 abajo sobre este nombre)
                IVEMRIWS.CL_Resultado resultado = ws.IVEMRI_ListarFacturasNormales(parametros);

                if (resultado.resultadoEjecucion)
                {
                    DataTable dt = resultado.Datos;

                    if (dt != null && dt.Rows.Count > 0)
                    {
                        gvResultado.DataSource = dt;
                        gvResultado.DataBind();
                        lblMensaje.Text = "Facturas cargadas (" + dt.Rows.Count + " registros).";
                    }
                    else
                    {
                        gvResultado.DataSource = null;
                        gvResultado.DataBind();
                        lblMensaje.Text = "No se encontraron facturas con ese criterio.";
                    }
                }
                else
                {
                    lblMensaje.Text = "Error al cargar la lista: " + resultado.Mensaje.MensajeDescripcion;
                }
            }
            catch (Exception ex)
            {
                lblMensaje.Text = "Error inesperado al cargar el grid: " + ex.Message;
            }
        }*/

        private void CargarListadoGeneral()
        {
            try
            {
                // 1. Usamos la estructura del Web Service
                IVEMRIWS.CL_Diccionario[] parametros = new IVEMRIWS.CL_Diccionario[2];

                parametros[0] = new IVEMRIWS.CL_Diccionario();
                parametros[0].Nombre = "@Pagina";
                parametros[0].Valor = "1";

                parametros[1] = new IVEMRIWS.CL_Diccionario();
                parametros[1].Nombre = "@RegistrosPorPagina";
                parametros[1].Valor = "20";

                // 2. Instanciamos TU Web Service (el que acabamos de arreglar)
                IVEMRIWS.IVEMRIWebService ws = new IVEMRIWS.IVEMRIWebService();
                IVEMRIWS.CL_Resultado resultado = ws.IVEMRI_ListarBitacoraPaginada(parametros);

                // 3. Evaluamos si el Web Service respondió con éxito
                if (resultado.resultadoEjecucion)
                {
                    if (resultado.Datos != null && resultado.Datos.Rows.Count > 0)
                    {
                        gvResultado.DataSource = resultado.Datos;
                        gvResultado.DataBind();
                        lblMensaje.Text = "✅ Listado cargado correctamente.";
                        lblMensaje.ForeColor = System.Drawing.Color.Green;
                    }
                    else
                    {
                        gvResultado.DataSource = null;
                        gvResultado.DataBind();
                        lblMensaje.Text = "ℹ️ La bitácora está vacía.";
                        lblMensaje.ForeColor = System.Drawing.Color.Blue;
                    }
                }
                else
                {
                    lblMensaje.Text = "❌ Error: " + resultado.Mensaje.MensajeDescripcion;
                    lblMensaje.ForeColor = System.Drawing.Color.Red;
                }
            }
            catch (Exception ex)
            {
                lblMensaje.Text = "❌ Error al cargar la lista: " + ex.Message;
                lblMensaje.ForeColor = System.Drawing.Color.DarkRed;
            }
        }
    }
}
