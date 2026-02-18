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
				UsuarioCodigo INT NULL
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

        DECLARE @DocEntrySAP INT = -1; 
        DECLARE @SAP_UsuarioNombre NVARCHAR(100) = NULL;
        DECLARE @SAP_UserCode NVARCHAR(100) = NULL; -- Usaremos el USER_CODE alfanumérico

        -- =========================================================================
        -- 1. BUSCAMOS LOS DATOS EN SAP (OINV y OUSR)
        -- =========================================================================
        SELECT TOP 1 
            @DocEntrySAP = O.DocEntry,
            @SAP_UserCode = U.USER_CODE,
            @SAP_UsuarioNombre = U.U_NAME 
        FROM [128.1.200.166].[SBO_CANELLA].[dbo].[OINV] O
        LEFT JOIN [128.1.200.166].[SBO_CANELLA].[dbo].[OUSR] U ON O.UserSign = U.USERID
        WHERE O.DocNum = @NumeroFactura;

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
        EXEC [128.1.200.166].[SBO_CANELLA].[dbo].[Reporte_Vehiculos_IVE_Opt_Individual] @DocEntryBuscado = @DocEntrySAP;

        -- =========================================================================
        -- 3. INSERTAR EN BITÁCORA LOCAL (Incluyendo datos de SAP para el listado)
        -- =========================================================================
        -- Nota: No enviamos @UsuarioSTOD a la bitácora remota. Se queda aquí.
        INSERT INTO IVEMRI_Bitacora_matriz_riesgo (
            FechaHoraSolicitud,
			UsuarioSTOD, 
            DocEntryBuscado, 
			NumeroFacturaBuscada

        )
        VALUES (
            GETDATE(),
            @NumeroFactura,             
			@UsuarioSTOD, 
            @DocEntrySAP

        );

        -- =========================================================================
        -- 4. RESULTADO FINAL PARA LA PANTALLA
        -- =========================================================================
        SELECT TOP 1
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

        -- Variables para capturar datos de SAP
        DECLARE @DocEntrySAP INT = -1; 
        DECLARE @DocDate DATETIME = NULL;
        DECLARE @SAP_UserCode NVARCHAR(100) = NULL;
        DECLARE @SAP_UsuarioNombre NVARCHAR(100) = NULL;

        -- =========================================================================
        -- 1. BUSQUEDA ESTANDARIZADA (Usando tu lógica de OINV y OUSR)
        -- =========================================================================
        SELECT TOP 1 
            @DocEntrySAP = i.DocEntry,
            @DocDate = i.DocDate,
            @SAP_UserCode = u.USER_CODE,
            @SAP_UsuarioNombre = u.U_NAME
        FROM [128.1.200.166].[SBO_CANELLA].[dbo].[OINV] i WITH (NOLOCK)
        LEFT JOIN [128.1.200.166].[SBO_CANELLA].[dbo].[OUSR] u WITH (NOLOCK) 
            ON i.UserSign = u.USERID
        WHERE i.DocNum = @NumeroFactura;

        -- Validar si la factura existe en SAP
        IF @DocEntrySAP IS NULL OR @DocEntrySAP = -1
        BEGIN
            SET @MensajeDescripcion = 'Factura ' + @NumeroFactura + ' no encontrada en SAP.';
            SET @MensajeTipo = 2;
            -- Retornamos estructura vacía para evitar errores de "Object Null" en C#
            SELECT TOP 0 NULL AS FechaHoraEjecucion;
            RETURN;
        END

        -- =========================================================================
        -- 2. TRAEMOS EL HISTORIAL DE LA BITÁCORA
        -- =========================================================================
        SELECT 
            B.FechaHoraEjecucion,
            B.RespuestaSalida AS HTML,
            @NumeroFactura AS NumeroFactura,
            @UsuarioSTOD AS STOD,
            @DocDate AS DocDate,                -- Nueva columna
            @SAP_UserCode AS USER_CODE,         -- Nueva columna
            @SAP_UsuarioNombre AS NombreUsuario, -- Nueva columna
            'CONSULTA HISTÓRICA' AS Mensaje
        FROM [128.1.200.166].[SBO_CANELLA].[dbo].[Matriz_Riesgo_Individual_26_general_Bitacora] B
        WHERE B.DocEntry = @DocEntrySAP
        ORDER BY B.FechaHoraEjecucion DESC;

        -- =========================================================================
        -- 3. VALIDAMOS SI ENCONTRÓ REGISTROS EN BITÁCORA
        -- =========================================================================
        IF @@ROWCOUNT > 0
        BEGIN
            SET @MensajeDescripcion = 'Historial recuperado exitosamente.';
            SET @MensajeTipo = 1;
        END
        ELSE
        BEGIN
            SET @MensajeDescripcion = 'La factura existe en SAP, pero no tiene historial en bitácora.';
            SET @MensajeTipo = 2;
        END

    END TRY
    BEGIN CATCH
        SET @MensajeDescripcion = 'Error: ' + ERROR_MESSAGE();
        SET @MensajeTipo = 0;
        -- Retornamos estructura vacía por seguridad
        SELECT TOP 0 NULL AS FechaHoraEjecucion;
    END CATCH
END

DECLARE @TipoRespuesta INT;
DECLARE @DescRespuesta VARCHAR(200);

EXEC [dbo].[IVEMRI_ConsultaMatrizRiesgoHistorico]
    @NumeroFactura = '2949407', 
    @UsuarioSTOD = 'omunoz',
    @MensajeTipo = @TipoRespuesta OUTPUT,
    @MensajeDescripcion = @DescRespuesta OUTPUT;

SELECT @TipoRespuesta as Tipo, @DescRespuesta as Descripcion;

-- El resultado de la tabla debería aparecer en la pestaña de "Results" de abajo

				/*
       =========================================
       ||| SP PARA LISTAR LA NUEVA TABLA||
       =========================================
       */

ALTER PROCEDURE [dbo].[STOD_ListarFacturasPaginadas]
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
            A.DocEntryBuscado,
            A.NumeroFacturaBuscada,
            A.FechaHoraSolicitud,
            A.UsuarioSTOD
        FROM [SBO_CANELLA].[dbo].[IVEMRI_Bitacora_matriz_riesgo] A
        ORDER BY A.FechaHoraSolicitud DESC
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
            FROM [128.1.200.166].[SBO_CANELLA].[dbo].[Matriz_Riesgo_Individual_26_general_Bitacora] B
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
