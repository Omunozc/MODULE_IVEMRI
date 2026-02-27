USE [STOD_SAPBONE]
GO
/****** Object:  StoredProcedure [dbo].[IVEMRI_ConsultaMatrizRiesgoFactura]    Script Date: 23/02/2026 14:27:53 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[IVEMRI_ConsultaMatrizRiesgoFactura]
    @NumeroFactura NVARCHAR(100),
    @UsuarioSTOD NVARCHAR(100),
    @MensajeTipo INT OUT,
    @MensajeDescripcion VARCHAR(200) OUT
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;

        DECLARE @Numero NVARCHAR(100) = NULL;
        DECLARE @DocEntrySAP INT = -1; 
        DECLARE @SAP_UsuarioNombre NVARCHAR(100) = NULL;
        DECLARE @SAP_UserCode NVARCHAR(100) = NULL;

        -- 1. BUSCAMOS EN SAP
        SELECT TOP 1 
            @Numero = o.NumAtCard,
            @DocEntrySAP = O.DocEntry,
            @SAP_UserCode = U.USER_CODE,
            @SAP_UsuarioNombre = U.U_NAME 
        FROM [128.1.200.167].[SBO_CANELLA].[dbo].[OINV] O
        LEFT JOIN [128.1.200.167].[SBO_CANELLA].[dbo].[OUSR] U ON O.UserSign = U.USERID
        WHERE O.NumAtCard = @NumeroFactura;

        -- 2. BITÁCORA LOCAL (Rastro del intento)
        INSERT INTO IVEMRI_Bitacora_matriz_riesgo (FechaHoraSolicitud, UsuarioSTOD, DocEntryBuscado, NumeroFacturaBuscada)
        VALUES (GETDATE(), @UsuarioSTOD, ISNULL(@DocEntrySAP, -1), @NumeroFactura);

        -- 3. SI NO EXISTE: Avisamos al remoto con -1 y SALIMOS SIN SELECT
        IF @DocEntrySAP IS NULL OR @DocEntrySAP = -1
        BEGIN
            EXEC [128.1.200.167].[SBO_CANELLA].[dbo].[Reporte_Vehiculos_IVE_Opt_Individual] 
                @DocEntryBuscado = -1, 
                @NumAtCard = @NumeroFactura, 
                @U_USER_NAME = @UsuarioSTOD, 
                @U_CODIGO_SAP = 'ERROR';

            SET @MensajeDescripcion = 'La factura ingresada no existe en SAP.';
            SET @MensajeTipo = 0; 
            
            -- NO HACEMOS SELECT AQUÍ para que el GridView quede vacío en el C#
            RETURN; 
        END

        -- 4. SI EXISTE: Ejecutamos proceso normal
        EXEC [128.1.200.167].[SBO_CANELLA].[dbo].[Reporte_Vehiculos_IVE_Opt_Individual] 
            @DocEntryBuscado = @DocEntrySAP, 
            @NumAtCard = @Numero, 
            @U_USER_NAME = @SAP_UsuarioNombre, 
            @U_CODIGO_SAP = @SAP_UserCode;

        -- 5. SELECT FINAL: Solo si hay datos válidos
        SELECT
            FechaHoraEjecucion,
            RespuestaSalida AS HTML,
            @NumeroFactura AS NumeroFactura,
            @UsuarioSTOD AS STOD,
            'REPORTE GENERADO EXITOSAMENTE' AS Mensaje,
            @SAP_UsuarioNombre AS UsuarioSAP_Nombre,
            @SAP_UserCode AS UsuarioSAP_Codigo
        FROM [128.1.200.167].[SBO_CANELLA].[dbo].[Matriz_Riesgo_Individual_26_general_Bitacora]
        WHERE DocEntry = @DocEntrySAP
        ORDER BY Id DESC;

        SET @MensajeDescripcion = 'Consulta generada exitosamente.';
        SET @MensajeTipo = 1;

    END TRY
    BEGIN CATCH
        SET @MensajeDescripcion = 'Error: ' + ERROR_MESSAGE();
        SET @MensajeTipo = 0;
    END CATCH
END