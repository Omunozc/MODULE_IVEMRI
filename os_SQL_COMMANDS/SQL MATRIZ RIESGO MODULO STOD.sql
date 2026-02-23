

       /*
       =========================================
       ||| CREACION TABLA DE BITACORA |||
       =========================================
       */

		CREATE TABLE IVEMRI_Bitacora_matriz_riesgo (
		Id INT IDENTITY(1,1) PRIMARY KEY,
			NumeroFacturaBuscada NVARCHAR(100) NULL,
			DocEntryBuscado INT NULL,
			UsuarioSTOD NVARCHAR(100) NOT NULL, 
			FechaHoraSolicitud DATETIME DEFAULT GETDATE(),
			DocEntry INT NULL,
			NumAtCard NVARCHAR(100) NULL,
			UsuarioFactura NVARCHAR(100) NULL, 
			UsuarioCodigo NVARCHAR(100) NULL

		);

		       /*
       =========================================
       ||| ALTER TABLE BITACORA DE TOMAS|||
       =========================================
       */

			   EXEC ('
    USE SBO_CANELLA;
    ALTER TABLE dbo.Matriz_Riesgo_Individual_26_general_Bitacora
    ADD 
				DocEntry INT NULL,
				NumAtCard NVARCHAR(100) NULL,
				UsuarioFactura NVARCHAR(100) NULL, 
				UsuarioCodigo NVARCHAR(100) NULL
') AT [128.1.200.167];

				/*
=============================================================================================================================================================================================

																			   ||| SP's del modulo||
=============================================================================================================================================================================================
       */


		/*
       =========================================
       ||| SP PARA REVISION DE FACTURAS|||
       =========================================
       */
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
            SET @MensajeTipo = 2; 
            
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

		/*
       =========================================
       ||| SP PARA CONSULTAR SIN EL SP DE TOMAS||
       =========================================
       */
SE [STOD_SAPBONE]
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
            SET @MensajeTipo = 2;
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



				/*
       =========================================
       ||| SP PARA LISTAR LA NUEVA TABLA||
       =========================================
       */
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
                B.UsuarioFactura,  -- Verifica que se llame así en el 166
                B.UsuarioCodigo   -- Verifica que se llame así en el 166
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

       /* 
