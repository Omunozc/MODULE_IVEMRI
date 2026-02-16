using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Data;
using System.Data.SqlClient;

namespace STOD_DAL
{
    public class IVEMRI
    {

        #region datatable IVEMBRI BUSQUEDA POR FACTURA
        public DataTable IVEMRI_BUSQUEDA(List<CL_Diccionario> ListParamsIn, out CL_TipoMensaje Obj_Mensaje)
        {
            Obj_Mensaje = new CL_TipoMensaje();
            DataTable dt = new DataTable("Datos");
            try
            {
                DAL DAC = new DAL();
                string Procedimiento = "IVEMRI_ConsultaMatrizRiesgoFactura";
                string conectionStringNombre = "ServidorCanellaService"; // Asegúrate que este nombre esté en tu Web.config
                dt = DAC.EjecutarQueryPorPAConRetorno(Procedimiento, conectionStringNombre, ListParamsIn, out Obj_Mensaje);
            }
            catch (Exception ex)
            {
                Obj_Mensaje.MensajeTipo = 0;
                Obj_Mensaje.MensajeDescripcion = ex.Message;
            }
            return dt;
        }
        #endregion
    }
}
