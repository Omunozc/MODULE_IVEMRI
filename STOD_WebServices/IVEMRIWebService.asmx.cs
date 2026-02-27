using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Services;
using STOD_BLL;
using System.Data;
using STOD_DAL;
using System.Xml;

namespace STOD_WebServices
{
    /// <summary>
    /// Descripción breve de IVEMRIWebService
    /// </summary>
    [WebService(Namespace = "http://tempuri.org/")]
    [WebServiceBinding(ConformsTo = WsiProfiles.BasicProfile1_1)]
    [System.ComponentModel.ToolboxItem(false)]
    // [System.Web.Script.Services.ScriptService]
    public class IVEMRIWebService : System.Web.Services.WebService
    {
        #region consulta 

        // Le agregamos una descripción para que sea fácil de entender al publicarlo
        [WebMethod(Description = "Consulta la matriz de riesgo de una factura en SAP para IVEMRI")]
        public CL_Resultado IVEMRI_ConsultarMatrizRiesgo(List<CL_Diccionario> ListParamsIn)
        {
            CL_Resultado res = new CL_Resultado();

            // 1. PREVENCIÓN: Inicializamos la tabla vacía para que la vista nunca reciba un "null" en Datos
            res.Datos = new DataTable("DatosVacios");

            // 2. VALIDACIÓN DEFENSIVA: ¿El front-end nos mandó basura o una lista vacía?
            if (ListParamsIn == null || ListParamsIn.Count == 0)
            {
                res.resultadoEjecucion = false;
                res.Mensaje = new CL_TipoMensaje { MensajeTipo = 0, MensajeDescripcion = "Error WS: Parámetros de búsqueda vacíos o nulos." };
                return res; // Retornamos inmediatamente
            }

            try
            {
                // 3. Flujo normal y seguro
                IVEMRI ds = new IVEMRI();
                CL_TipoMensaje Obj_Mensaje = new CL_TipoMensaje();

                DataTable dt = ds.IVEMRI_BUSQUEDA(ListParamsIn, out Obj_Mensaje);

                res.Datos = dt;
                res.Mensaje = Obj_Mensaje;
                res.resultadoEjecucion = (Obj_Mensaje.MensajeTipo != 0);
            }
            catch (Exception ex)
            {
                // Si ocurre una caída grave, la encapsulamos elegantemente
                res.resultadoEjecucion = false;
                res.Mensaje = new CL_TipoMensaje { MensajeTipo = 0, MensajeDescripcion = "Excepción interna del servidor: " + ex.Message };
            }

            return res;
        }
        #endregion

        #region Listado General Paginado

        [WebMethod(Description = "Obtiene el listado general paginado de la bitácora de matriz de riesgo")]
        public CL_Resultado IVEMRI_ListarBitacoraPaginada(List<CL_Diccionario> ListParamsIn)
        {
            CL_Resultado res = new CL_Resultado();
            res.Datos = new DataTable("DatosPaginados");

            // En un listado general, los parámetros podrían ser opcionales (default página 1)
            // pero igual validamos la inicialización de la lista
            if (ListParamsIn == null)
            {
                ListParamsIn = new List<CL_Diccionario>();
            }

            try
            {
                IVEMRI ds = new IVEMRI();
                CL_TipoMensaje Obj_Mensaje = new CL_TipoMensaje();

                // Llamamos al nuevo método que creamos en la DAL
                DataTable dt = ds.IVEMRI_LISTADO_GENERAL(ListParamsIn, out Obj_Mensaje);

                res.Datos = dt;
                res.Mensaje = Obj_Mensaje;
                res.resultadoEjecucion = (Obj_Mensaje.MensajeTipo != 0);
            }
            catch (Exception ex)
            {
                res.resultadoEjecucion = false;
                res.Mensaje = new CL_TipoMensaje
                {
                    MensajeTipo = 0,
                    MensajeDescripcion = "Error en el servicio de listado: " + ex.Message
                };
            }

            return res;
        }

        #endregion

        #region Búsqueda Histórica

        [WebMethod(Description = "Consulta el historial de todas las matrices generadas para una factura específica")]
        public CL_Resultado IVEMRI_ConsultarHistoricoMatriz(List<CL_Diccionario> ListParamsIn)
        {
            CL_Resultado res = new CL_Resultado();
            res.Datos = new DataTable("DatosHistoricosVacios");

            // Validación Defensiva
            if (ListParamsIn == null || ListParamsIn.Count == 0)
            {
                res.resultadoEjecucion = false;
                res.Mensaje = new CL_TipoMensaje { MensajeTipo = 0, MensajeDescripcion = "Error WS: Parámetros para historial vacíos." };
                return res;
            }

            try
            {
                IVEMRI ds = new IVEMRI();
                CL_TipoMensaje Obj_Mensaje = new CL_TipoMensaje();

                // Llamamos al nuevo método que creamos en la DAL para el histórico
                DataTable dt = ds.IVEMRI_HISTORICO(ListParamsIn, out Obj_Mensaje);

                res.Datos = dt;
                res.Mensaje = Obj_Mensaje;
                res.resultadoEjecucion = (Obj_Mensaje.MensajeTipo != 0);
            }
            catch (Exception ex)
            {
                res.resultadoEjecucion = false;
                res.Mensaje = new CL_TipoMensaje
                {
                    MensajeTipo = 0,
                    MensajeDescripcion = "Excepción en el servicio histórico: " + ex.Message
                };
            }

            return res;
        }

        #endregion
    }
}
