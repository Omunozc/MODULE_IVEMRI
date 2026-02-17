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
    // Para permitir que se llame a este servicio web desde un script, usando ASP.NET AJAX, quite la marca de comentario de la línea siguiente. 
    // [System.Web.Script.Services.ScriptService]
    public class IVEMRIWebService : System.Web.Services.WebService
    {


        #region consulta 
        [WebMethod]
        public CL_Resultado IVEMRI_ConsultarMatrizRiesgo(List<CL_Diccionario> ListParamsIn)
        {
            CL_Resultado res = new CL_Resultado();

            // CORRECCIÓN: Instanciamos la clase de la DAL (STOD_DAL.IVEMRI_DAL)
            IVEMRI ds = new IVEMRI();

            CL_TipoMensaje Obj_Mensaje = new CL_TipoMensaje();

            try
            {
                // Ahora 'ds' sí tiene el método porque apunta a la capa DAL
                DataTable dt = ds.IVEMRI_BUSQUEDA(ListParamsIn, out Obj_Mensaje);

                res.Datos = dt;
                res.Mensaje = Obj_Mensaje;
                res.resultadoEjecucion = (Obj_Mensaje.MensajeTipo != 0);
            }
            catch (Exception ex)
            {
                res.resultadoEjecucion = false;
                res.Mensaje = new CL_TipoMensaje { MensajeTipo = 0, MensajeDescripcion = ex.Message };
            }

            return res;
        }
        #endregion
    }
}
