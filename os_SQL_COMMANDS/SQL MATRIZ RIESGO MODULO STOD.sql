       /*
       =========================================
       ||| CREACION TABLA TEMPORAL |||
       =========================================
       */

		CREATE TABLE #IVEMRI_Bitacora_matriz_riesgo (
			Id INT IDENTITY(1,1) PRIMARY KEY,
				NumeroFacturaBuscada NVARCHAR(100) NULL,
				DocEntryBuscado INT NULL,
				UsuarioSTOD NVARCHAR(100) NOT NULL, 
				FechaHoraSolicitud DATETIME DEFAULT GETDATE()

		);

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
			FechaHoraSolicitud DATETIME DEFAULT GETDATE()

		);

		select top 5 * from IVEMRI_Bitacora_matriz_riesgo

       /*
       =========================================
       ||| MODIFICACION  |||
       =========================================
       */
		ALTER TABLE SBO_CANELLA.dbo.Matriz_Riesgo_Individual_26_general_Bitacora
			ADD 
				DocEntry INT NULL,
				NumAtCard NVARCHAR(100) NULL,
				UsuarioFactura NVARCHAR(100) NULL, 
				UsuarioCodigo INT NULL

ALTER TABLE SBO_CANELLA.dbo.Matriz_Riesgo_Individual_26_general_Bitacora
    ALTER COLUMN UsuarioCodigo NVARCHAR(100) NULL; -- Si DocEntry siempre es el ID numérico de SAP, se queda INT
       /*
       =========================================
       ||| MODIFICACION EN 166|||
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
') AT [128.1.200.166];

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
ALTER PROCEDURE [dbo].[IVEMRI_ConsultaMatrizRiesgoFactura]
    @NumeroFactura NVARCHAR(100),
    @UsuarioSTOD NVARCHAR(100),
    @MensajeTipo INT OUT,
    @MensajeDescripcion VARCHAR(200) OUT
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;

		declare @Numero NVARCHAR(100)  = NULL;
		DECLARE @COINCIDENCIAS INT = 1;
        DECLARE @DocEntrySAP INT = -1; 
        DECLARE @SAP_UsuarioNombre NVARCHAR(100) = NULL;
        DECLARE @SAP_UserCode NVARCHAR(100) = NULL; -- Usaremos el USER_CODE alfanumérico

        -- =========================================================================
        -- 1. BUSCAMOS LOS DATOS EN SAP (OINV y OUSR)
        -- =========================================================================
        SELECT TOP 1 
			@Numero = o.NumAtCard,
            @DocEntrySAP = O.DocEntry,
            @SAP_UserCode = U.USER_CODE,
            @SAP_UsuarioNombre = U.U_NAME 
        FROM [128.1.200.166].[SBO_CANELLA].[dbo].[OINV] O
        LEFT JOIN [128.1.200.166].[SBO_CANELLA].[dbo].[OUSR] U ON O.UserSign = U.USERID
        WHERE O.NumAtCard = @NumeroFactura;

        -- VALIDACIÓN: Si no existe en SAP
        IF @DocEntrySAP IS NULL OR @DocEntrySAP = -1
        BEGIN
            SELECT 
                GETDATE() AS FechaHoraEjecucion,
                @NumeroFactura AS NumeroFactura,
                @UsuarioSTOD AS STOD,
                'Factura no encontrada en SAP' AS Mensaje,
                'SIN DATOS' AS HTML,
                NULL AS UsuarioSAP_Nombre,
                NULL AS UsuarioSAP_Codigo;
            
            SET @MensajeDescripcion = 'Factura no encontrada en SAP.';
            SET @MensajeTipo = 2;
            RETURN;
        END

        -- =========================================================================
        -- 2. EJECUCIÓN DEL REPORTE REMOTO (Genera el HTML)
        -- =========================================================================
       EXEC [128.1.200.166].[SBO_CANELLA].[dbo].[Reporte_Vehiculos_IVE_Opt_Individual] @DocEntryBuscado = @DocEntrySAP, @NumAtCard = @Numero, @U_USER_NAME=@SAP_UsuarioNombre, @U_CODIGO_SAP= @SAP_UserCode;

        -- =========================================================================
        -- 3. INSERTAR EN BITÁCORA LOCAL (Incluyendo datos de SAP para el listado)
        -- =========================================================================
			INSERT INTO IVEMRI_Bitacora_matriz_riesgo (
				FechaHoraSolicitud,
				UsuarioSTOD, 
				DocEntryBuscado, 
				NumeroFacturaBuscada
			)
			VALUES (
				GETDATE(),
				@UsuarioSTOD,          
				@DocEntrySAP,
				@NumeroFactura
			);

        -- =========================================================================
        -- 4. RESULTADO FINAL PARA LA PANTALLA
        -- =========================================================================
        SELECT top 1
            FechaHoraEjecucion,
            RespuestaSalida AS HTML,
            @NumeroFactura AS NumeroFactura,
            @UsuarioSTOD AS STOD,
            'REPORTE GENERADO EXITOSAMENTE' AS Mensaje,
            @SAP_UsuarioNombre AS UsuarioSAP_Nombre,
            @SAP_UserCode AS UsuarioSAP_Codigo
        FROM [128.1.200.166].[SBO_CANELLA].[dbo].[Matriz_Riesgo_Individual_26_general_Bitacora]
        WHERE DocEntry = @DocEntrySAP
        ORDER BY Id DESC; 

        SET @MensajeDescripcion = 'Transacción completada satisfactoriamente...!!!';
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

        -- =========================================================================
        -- 1. BUSCAMOS LOS DATOS EN SAP (OINV y OUSR)
        -- =========================================================================
        SELECT TOP 1 
            @DocEntrySAP = O.DocEntry,
            @SAP_UserCode = U.USER_CODE,
            @SAP_UsuarioNombre = U.U_NAME 
        FROM [128.1.200.166].[SBO_CANELLA].[dbo].[OINV] O
        LEFT JOIN [128.1.200.166].[SBO_CANELLA].[dbo].[OUSR] U ON O.UserSign = U.USERID
        WHERE O.NumAtCard = @NumeroFactura;

        -- VALIDACIÓN: Si no existe en SAP
        IF @DocEntrySAP IS NULL OR @DocEntrySAP = -1
        BEGIN
            SELECT 
                GETDATE() AS FechaHoraEjecucion,
                @NumeroFactura AS NumeroFactura,
                @UsuarioSTOD AS STOD,
                'Factura no encontrada en SAP' AS Mensaje,
                'SIN DATOS' AS HTML,
                NULL AS UsuarioSAP_Nombre,
                NULL AS UsuarioSAP_Codigo;
            
            SET @MensajeDescripcion = 'Factura no encontrada en SAP.';
            SET @MensajeTipo = 2;
            RETURN;
        END

        -- =========================================================================
        -- 2. INSERTAR EN BITÁCORA LOCAL 
        -- =========================================================================
        INSERT INTO IVEMRI_Bitacora_matriz_riesgo (
            FechaHoraSolicitud,
            UsuarioSTOD,          
            DocEntryBuscado, 
            NumeroFacturaBuscada
        )
        VALUES (
            GETDATE(),
            @UsuarioSTOD,          
            @DocEntrySAP,
            @NumeroFactura
        );

        -- =========================================================================
        -- 3. RESULTADO FINAL (PRIORIDAD A TU NUEVA TABLA)
        -- =========================================================================
        -- Tu tabla es la base principal. Si hay HTML en SAP, lo trae; si no, pone "SIN DATOS".
        SELECT 
            B.FechaHoraSolicitud AS FechaHoraEjecucion,
            ISNULL(S.RespuestaSalida, 'SIN DATOS') AS HTML,
            B.NumeroFacturaBuscada AS NumeroFactura,
            B.UsuarioSTOD AS STOD,
            CASE 
                WHEN S.RespuestaSalida IS NOT NULL THEN 'REPORTE GENERADO EXITOSAMENTE'
                ELSE 'BÚSQUEDA REGISTRADA (SIN MATRIZ EN SAP)'
            END AS Mensaje,
            @SAP_UsuarioNombre AS UsuarioSAP_Nombre,
            @SAP_UserCode AS UsuarioSAP_Codigo
        FROM IVEMRI_Bitacora_matriz_riesgo B
        OUTER APPLY (
            -- Traemos el HTML más reciente de SAP para ese documento
            SELECT TOP 1 RespuestaSalida 
            FROM [128.1.200.166].[SBO_CANELLA].[dbo].[Matriz_Riesgo_Individual_26_general_Bitacora]
            WHERE DocEntry = B.DocEntryBuscado
            ORDER BY Id DESC
        ) S
        WHERE B.NumeroFacturaBuscada = @NumeroFactura
        ORDER BY B.FechaHoraSolicitud DESC; 

        SET @MensajeDescripcion = 'Transacción completada satisfactoriamente...!!!';
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

        -- =========================================================================
        -- 1. BUSCAMOS LOS DATOS EN SAP (OINV y OUSR)
        -- =========================================================================
        SELECT TOP 1 
            @DocEntrySAP = O.DocEntry,
            @SAP_UserCode = U.USER_CODE,
            @SAP_UsuarioNombre = U.U_NAME 
        FROM [128.1.200.166].[SBO_CANELLA].[dbo].[OINV] O
        LEFT JOIN [128.1.200.166].[SBO_CANELLA].[dbo].[OUSR] U ON O.UserSign = U.USERID
        WHERE O.NumAtCard = @NumeroFactura;

        -- VALIDACIÓN: Si no existe en SAP
        IF @DocEntrySAP IS NULL OR @DocEntrySAP = -1
        BEGIN
            SELECT 
                GETDATE() AS FechaHoraEjecucion,
                @NumeroFactura AS NumeroFactura,
                @UsuarioSTOD AS STOD,
                'Factura no encontrada en SAP' AS Mensaje,
                'SIN DATOS' AS HTML,
                NULL AS UsuarioSAP_Nombre,
                NULL AS UsuarioSAP_Codigo;
            
            SET @MensajeDescripcion = 'Factura no encontrada en SAP.';
            SET @MensajeTipo = 2;
            RETURN;
        END

        -- =========================================================================
        -- 2. INSERTAR EN BITÁCORA LOCAL 
        -- =========================================================================
        INSERT INTO IVEMRI_Bitacora_matriz_riesgo (
            FechaHoraSolicitud,
            UsuarioSTOD,          
            DocEntryBuscado, 
            NumeroFacturaBuscada
        )
        VALUES (
            GETDATE(),
            @UsuarioSTOD,          
            @DocEntrySAP,
            @NumeroFactura
        );

        -- =========================================================================
        -- 3. RESULTADO FINAL (PRIORIDAD A TU NUEVA TABLA)
        -- =========================================================================
        -- Tu tabla es la base principal. Si hay HTML en SAP, lo trae; si no, pone "SIN DATOS".
        SELECT 
            B.FechaHoraSolicitud AS FechaHoraEjecucion,
            ISNULL(S.RespuestaSalida, 'SIN DATOS') AS HTML,
            B.NumeroFacturaBuscada AS NumeroFactura,
            B.UsuarioSTOD AS STOD,
            CASE 
                WHEN S.RespuestaSalida IS NOT NULL THEN 'REPORTE GENERADO EXITOSAMENTE'
                ELSE 'BÚSQUEDA REGISTRADA (SIN MATRIZ EN SAP)'
            END AS Mensaje,
            @SAP_UsuarioNombre AS UsuarioSAP_Nombre,
            @SAP_UserCode AS UsuarioSAP_Codigo
        FROM IVEMRI_Bitacora_matriz_riesgo B
        OUTER APPLY (
            -- Traemos el HTML más reciente de SAP para ese documento
            SELECT TOP 1 RespuestaSalida 
            FROM [128.1.200.166].[SBO_CANELLA].[dbo].[Matriz_Riesgo_Individual_26_general_Bitacora]
            WHERE DocEntry = B.DocEntryBuscado
            ORDER BY Id DESC
        ) S
        WHERE B.NumeroFacturaBuscada = @NumeroFactura
        ORDER BY B.FechaHoraSolicitud DESC; 

        SET @MensajeDescripcion = 'Transacción completada satisfactoriamente...!!!';
        SET @MensajeTipo = 1;

    END TRY
    BEGIN CATCH
        SET @MensajeDescripcion = 'Error: ' + ERROR_MESSAGE();
        SET @MensajeTipo = 0;
    END CATCH
END




				/*
       =========================================
       |||PRUEBAS GENERALES|
       =========================================
       */
DECLARE @OutTipo INT;
DECLARE @OutDescripcion VARCHAR(200);
EXEC [dbo].[STOD_ListarFacturasPaginadas] 1,20, @MensajeTipo = @OutTipo OUT, 
    @MensajeDescripcion = @OutDescripcion OUT;
	SELECT @OutTipo AS TipoMensaje, @OutDescripcion AS TextoMensaje;


INSERT INTO [SBO_CANELLA].[dbo].[IVEMRI_Bitacora_matriz_riesgo] 
(FechaHoraSolicitud, DocEntryBuscado, NumeroFacturaBuscada, UsuarioSTOD)
VALUES 
(GETDATE(), 101, 'FAC-001', 'OMUNOZ'),
(GETDATE(), 102, 'FAC-002', 'OMUNOZ');

UPDATE [SBO_CANELLA].[dbo].[IVEMRI_Bitacora_matriz_riesgo]
SET NumeroFacturaBuscada = '2929037' 
WHERE DocEntryBuscado = 101;

-- Ahora vuelve a ejecutar el SP
EXEC [dbo].[STOD_ListarFacturasPaginadas] @Pagina = 1, @RegistrosPorPagina = 10;



		declare @codigo INT, @msg varchar(200)
		EXEC [dbo].[IVEMRI_ConsultaMatrizRiesgoFactura] '40055','omunoz', @codigo OUT, @msg OUT

		select @codigo, @msg




       /* =========================================================
       MODIFICACIONES SP TOMAS
       ========================================================= */


       Set @Destinatarios = 'tmorales@canella.com.gt;';
       Set @CCopia = 'lbarrios@canella.com.gt;';

       INSERT INTO dbo.Matriz_Riesgo_Individual_26_general_Bitacora (NombreSP, ParametrosEntrada, RespuestaSalida,DocEntry,NumAtCard, UsuarioFactura, UsuarioCodigo)
        VALUES (
            'Matriz_Riesgo_Individual_26_general',
            CONCAT('{"DocEntryBuscado":"', @DocEntryBuscado, '}'),
            @Html,
			@DocEntryBuscado,
			@NumAtCard,
			@U_USER_NAME,
			@U_CODIGO_SAP
        );


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

       DECLARE @cantidad_coincidencias INT = 0;


       SELECT 
              @cantidad_coincidencias = COUNT(*)
       FROM 
              #cte_datos;

       IF @cantidad_coincidencias = 0
       BEGIN
              -- SELECT 'SIN DATOS' AS RESPUESTA;
              INSERT INTO dbo.Matriz_Riesgo_Individual_26_general_Bitacora (NombreSP, ParametrosEntrada, RespuestaSalida, DocEntry,NumAtCard,UsuarioFactura,UsuarioCodigo)
              VALUES (
                     'Matriz_Riesgo_Individual_26_general',
                     CONCAT('{"SIN DATOS","DocEntryBuscado":"', @DocEntryBuscado, '}'),
                     'SIN DATOS',
					 -1,
					 NULL,
					 NULL,
					 NULL

              );

              goto fin; 
       END
	   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
ALTER   PROCEDURE [dbo].[Reporte_Vehiculos_IVE_Opt_Individual]
(
    @DocEntryBuscado INT,      
	@NumAtCard nvarchar(100),
	@U_USER_NAME nvarchar(100),
	@U_CODIGO_SAP nvarchar(100)

)
