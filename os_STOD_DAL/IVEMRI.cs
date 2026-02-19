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
                // 2. Validación Defensiva: ¿Nos mandaron parámetros vacíos desde la web?
                if (ListParamsIn == null || ListParamsIn.Count == 0)
                {
                    Obj_Mensaje.MensajeTipo = 0; // Asumo que 0 es Error
                    Obj_Mensaje.MensajeDescripcion = "Error: No se recibieron parámetros para la búsqueda.";
                    return dt; // Retornamos la tabla vacía y cortamos aquí
                }

                DAL DAC = new DAL();
                string Procedimiento = "IVEMRI_ConsultaMatrizRiesgoFactura";
                string conectionStringNombre = "SAP_OITM";

                dt = DAC.EjecutarQueryPorPAConRetorno(Procedimiento, conectionStringNombre, ListParamsIn, out Obj_Mensaje);
            }
            catch (Exception ex)
            {
                Obj_Mensaje.MensajeTipo = 0; // 0 = Error

                // Aquí guardamos el error exacto de SQL (Timeout, Fallo de Login, etc.)
                Obj_Mensaje.MensajeDescripcion = "Fallo en la base de datos: " + ex.Message;
            }

            return dt;
        }
        #endregion

        #region datatable IVEMRI LISTADO GENERAL PAGINADO
        public DataTable IVEMRI_LISTADO_GENERAL(List<CL_Diccionario> ListParamsIn, out CL_TipoMensaje Obj_Mensaje)
        {
            Obj_Mensaje = new CL_TipoMensaje();
            DataTable dt = new DataTable("DatosPaginados");

            try
            {
                // 1. Validación: Aunque son opcionales en el SP, 
                // es bueno asegurar que la lista de parámetros no sea nula.
                if (ListParamsIn == null)
                {
                    ListParamsIn = new List<CL_Diccionario>();
                }

                DAL DAC = new DAL();
                // Usamos el nuevo SP que creamos
                string Procedimiento = "STOD_ListarFacturasPaginadas";
                string conectionStringNombre = "SAP_OITM";

                // Ejecutamos usando tu arquitectura existente
                dt = DAC.EjecutarQueryPorPAConRetorno(Procedimiento, conectionStringNombre, ListParamsIn, out Obj_Mensaje);
            }
            catch (Exception ex)
            {
                Obj_Mensaje.MensajeTipo = 0;
                Obj_Mensaje.MensajeDescripcion = "Error al obtener listado general: " + ex.Message;
            }

            return dt;
        }
        #endregion
        #region datatable IVEMRI CONSULTA HISTORICA
        public DataTable IVEMRI_HISTORICO(List<CL_Diccionario> ListParamsIn, out CL_TipoMensaje Obj_Mensaje)
        {
            Obj_Mensaje = new CL_TipoMensaje();
            DataTable dt = new DataTable("DatosHistoricos");

            try
            {
                if (ListParamsIn == null || ListParamsIn.Count == 0)
                {
                    Obj_Mensaje.MensajeTipo = 0;
                    Obj_Mensaje.MensajeDescripcion = "Error: No se recibieron parámetros para el histórico.";
                    return dt;
                }

                DAL DAC = new DAL();
                // ESTE ES EL CAMBIO CLAVE: El SP de histórico
                string Procedimiento = "IVEMRI_ConsultaMatrizRiesgoHistorico";
                string conectionStringNombre = "SAP_OITM";

                dt = DAC.EjecutarQueryPorPAConRetorno(Procedimiento, conectionStringNombre, ListParamsIn, out Obj_Mensaje);
            }
            catch (Exception ex)
            {
                Obj_Mensaje.MensajeTipo = 0;
                Obj_Mensaje.MensajeDescripcion = "Fallo al consultar histórico: " + ex.Message;
            }

            return dt;
        }
        #endregion
    }
}
