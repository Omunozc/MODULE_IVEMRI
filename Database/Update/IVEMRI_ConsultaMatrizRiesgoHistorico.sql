USE [STOD_SAPBONE]
GO
/****** Object:  StoredProcedure [dbo].[IVEMRI_ConsultaMatrizRiesgoHistorico]    Script Date: 23/02/2026 08:59:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[IVEMRI_ConsultaMatrizRiesgoHistorico]
   @NumeroFactura NVARCHAR(100),
   @UsuarioSTOD NVARCHAR(100),
   @MensajeTipo INT OUT,
   @MensajeDescripcion VARCHAR(200) OUT
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;
        DECLARE @DocEntrySAP INT = -1; 
        DECLARE @SAP_UsuarioNombre NVARCHAR(100) = NULL;
        DECLARE @SAP_UserCode NVARCHAR(100) = NULL; 

        -- 1. BUSCAMOS LOS DATOS EN SAP
        SELECT TOP 1 
            @DocEntrySAP = O.DocEntry,
            @SAP_UserCode = U.USER_CODE,
            @SAP_UsuarioNombre = U.U_NAME 
        FROM [128.1.200.167].[SBO_CANELLA].[dbo].[OINV] O
        LEFT JOIN [128.1.200.167].[SBO_CANELLA].[dbo].[OUSR] U ON O.UserSign = U.USERID
        WHERE O.NumAtCard = @NumeroFactura;

        -- 2. BITÁCORA
        INSERT INTO IVEMRI_Bitacora_matriz_riesgo (FechaHoraSolicitud, UsuarioSTOD, DocEntryBuscado, NumeroFacturaBuscada)
        VALUES (GETDATE(), @UsuarioSTOD, ISNULL(@DocEntrySAP, 0), @NumeroFactura);

        -- 3. VALIDACIÓN: SI NO EXISTE, RETURN SIN SELECT
        IF @DocEntrySAP IS NULL OR @DocEntrySAP = -1
        BEGIN
            SET @MensajeDescripcion = 'La factura ingresada no existe en SAP.';
            SET @MensajeTipo = 0;
            RETURN; -- IMPORTANTE: No hay SELECT aquí, el DataTable llegará vacío.
        END

        -- 4. RESULTADO FINAL (Solo si existe)
        SELECT 
            FechaHoraEjecucion,
            RespuestaSalida AS HTML,
            @NumeroFactura AS NumeroFactura,
            @UsuarioSTOD AS UsuarioSTOD,
            'HISTORIAL RECUPERADO' AS Mensaje,
            ISNULL(@SAP_UsuarioNombre, 'N/A') AS UsuarioSAP_Nombre,
            ISNULL(@SAP_UserCode, 'N/A') AS UsuarioSAP_Codigo
        FROM [128.1.200.167].[SBO_CANELLA].[dbo].[Matriz_Riesgo_Individual_26_general_Bitacora]
        WHERE DocEntry = @DocEntrySAP
        ORDER BY Id DESC;

        -- Si el SELECT anterior no devolvió filas, el GridView se manejará en C#
        SET @MensajeDescripcion = 'Historial cargado satisfactoriamente.';
        SET @MensajeTipo = 1;

    END TRY
    BEGIN CATCH
        SET @MensajeDescripcion = 'Error: ' + ERROR_MESSAGE();
        SET @MensajeTipo = 0;
    END CATCH
END
