CREATE PROCEDURE [dbo].[STOD_ListarFacturasPaginadas]
    @Pagina INT = 1,          
    @RegistrosPorPagina INT = 10,
    @MensajeTipo INT OUT,
    @MensajeDescripcion VARCHAR(200) OUT
AS
BEGIN
    BEGIN TRY 
        SET NOCOUNT ON;

        -- 1. Obtenemos los registros locales (Paginación)
        DECLARE @TempPagina TABLE (
            DocEntryBuscado INT,
            NumeroFactura NVARCHAR(100),
            FechaHoraEjecucion DATETIME,
            STOD NVARCHAR(100)
        );

        INSERT INTO @TempPagina
        SELECT 
			B.DocEntry,
            B.NumAtCard,
			B.FechaHoraEjecucion,
            B.UsuarioFactura
            FROM [128.1.200.167].[SBO_CANELLA].[dbo].[Matriz_Riesgo_Individual_26_general_Bitacora] B
        ORDER BY B.FechaHoraEjecucion DESC
        OFFSET (@Pagina - 1) * @RegistrosPorPagina ROWS
        FETCH NEXT @RegistrosPorPagina ROWS ONLY;

        -- 2. Cruce con la bitácora remota para traer Usuario y HTML
        SELECT 
            P.FechaHoraEjecucion,
            P.NumeroFactura,
            P.STOD,
            -- IMPORTANTE: Aquí usamos los nombres de columna de tu tabla remota
            ISNULL(R.UsuarioFactura, 'SIN DATOS') AS UsuarioSAP_Nombre, 
            ISNULL(R.UsuarioCodigo, '0') AS UsuarioSAP_Codigo,
            'REPORTE GENERADO' AS Mensaje,
            ISNULL(R.RespuestaSalida, 'SIN HTML') AS HTML
        FROM @TempPagina P
        OUTER APPLY (
            -- Buscamos en la tabla matriz_riesgo_individual_26_general_bitacora
            SELECT TOP 1 
                B.RespuestaSalida, 
                B.UsuarioFactura,  -- Verifica que se llame así en el 167
                B.UsuarioCodigo   -- Verifica que se llame así en el 167
            FROM [128.1.200.167].[SBO_CANELLA].[dbo].[Matriz_Riesgo_Individual_26_general_Bitacora] B
            WHERE B.DocEntry = P.DocEntryBuscado
            ORDER BY B.Id DESC
        ) R
        ORDER BY P.FechaHoraEjecucion DESC;

        SET @MensajeDescripcion = 'Listado cargado exitosamente.';
        SET @MensajeTipo = 1;

    END TRY
    BEGIN CATCH
        SET @MensajeDescripcion = 'Error: ' + ERROR_MESSAGE();
        SET @MensajeTipo = 0;
        -- Retorno preventivo para evitar el "pantallazo blanco"
        SELECT FechaHoraEjecucion, NumeroFactura, STOD, 'ERROR' as UsuarioSAP_Nombre, '0' as UsuarioSAP_Codigo, '' as Mensaje, '' as HTML FROM @TempPagina;
    END CATCH
END