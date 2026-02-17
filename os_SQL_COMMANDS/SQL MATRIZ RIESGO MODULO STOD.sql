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
				UsuarioFactura NVARCHAR(100) NULL -- Agregamos la columna para guardar el usuario de STOD

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
        UsuarioFactura NVARCHAR(100) NULL;
') AT [128.1.200.166];

		/*
       =========================================
       ||| SP PARA REVISION DE FACTURAS|||
       =========================================
       */

		alter PROCEDURE IVEMRI_ConsultaMatrizRiesgoFactura
			@NumeroFactura NVARCHAR(100),
			@UsuarioSTOD NVARCHAR(100)
		AS
		BEGIN
			SET NOCOUNT ON;

			DECLARE @DocEntrySAP INT = -1; -- Inicializado en NULL para validación precisa
			DECLARE @cantidad_coincidencias INT = 0;

			-- 1. OBTENER EL DOCENTRY DESDE SAP (SERVIDOR 166)
			SELECT TOP 1 @DocEntrySAP = DocEntry
			FROM [128.1.200.166].[SBO_CANELLA].[dbo].[OINV]
			WHERE NumAtCard = @NumeroFactura;

			-- 2. BITÁCORA LOCAL (STOD)
			INSERT INTO IVEMRI_Bitacora_matriz_riesgo (NumeroFacturaBuscada, DocEntryBuscado, UsuarioSTOD, FechaHoraSolicitud)
			VALUES (@NumeroFactura, @DocEntrySAP, @UsuarioSTOD, GETDATE());

			-- 3. VALIDACIÓN INICIAL: SI NO EXISTE EN SAP
			IF @DocEntrySAP IS NULL
			BEGIN
				SELECT 'SIN DATOS' AS RESPUESTA, 'Factura no existe en SAP' AS Detalle;
				RETURN;
			END

			-- 4. EJECUTAR EL PRIMER SP DE ANÁLISIS
			EXEC [128.1.200.166].[SBO_CANELLA].[dbo].[Reporte_Vehiculos_IVE_Opt_Individual] @DocEntryBuscado = @DocEntrySAP;

			-- 5. VALIDACIÓN DE COINCIDENCIAS
			SELECT @cantidad_coincidencias = COUNT(*)
			FROM STOD_SAPBONE.dbo.COREP_Facturas
			WHERE DocEntry = @DocEntrySAP 
			  AND CAST(FacturaFecha AS DATE) = CAST(GETDATE() AS DATE);

			-- 6. SI NO HAY COINCIDENCIAS (INSERTAR CON NUMATCARD VACÍO)
			IF @cantidad_coincidencias = 0
			BEGIN
				INSERT INTO [SBO_CANELLA].[dbo].[Matriz_Riesgo_Individual_26_general_Bitacora] 
					(NombreSP, ParametrosEntrada, RespuestaSalida, DocEntry, NumAtCard, UsuarioFactura)
				VALUES (
					'Matriz_Riesgo_Individual_26_general',
					CONCAT('{"SIN DATOS","DocEntryBuscado":"', CAST(@DocEntrySAP AS VARCHAR), '"}'),
					'SIN DATOS',
					@DocEntrySAP,
					'', 
					@UsuarioSTOD
				);

				SELECT 'SIN DATOS' AS RESPUESTA;
				GOTO fin; 
			END

			-- 7. RETORNO EXITOSO PARA LA VISTA
			SELECT 
				A.CreateDate,
				A.DocEntry,
				A.NumAtCard AS NumeroFactura,
				@UsuarioSTOD AS UsuarioConsulta,
				'REPORTE GENERADO EXITOSAMENTE' AS Mensaje
			FROM [128.1.200.166].[SBO_CANELLA].[dbo].[OINV] A
			WHERE A.DocEntry = @DocEntrySAP;

		fin:
			PRINT 'Proceso finalizado';
		END
		/*
       =========================================
       ||| SP PARA REVISION DE FACTURAS PRUEBA||
       =========================================
       */

alter PROCEDURE IVEMRI_ConsultaMatrizRiesgoFactura
			@NumeroFactura NVARCHAR(100),
			@UsuarioSTOD NVARCHAR(100),
			@MensajeTipo		INT OUT,
			@MensajeDescripcion VARCHAR(200) OUT
		AS
		BEGIN

		BEGIN TRY
			SET NOCOUNT ON;

			DECLARE @DocEntrySAP INT = -1; -- Inicializado en NULL para validación precisa
			DECLARE @cantidad_coincidencias INT = 0;

			-- 1. OBTENER EL DOCENTRY DESDE SAP (SERVIDOR 166)
			SELECT TOP 1 @DocEntrySAP = DocEntry
			FROM [128.1.200.166].[SBO_CANELLA].[dbo].[OINV]
			WHERE NumAtCard = @NumeroFactura;

			-- 2. BITÁCORA LOCAL (STOD)
			INSERT INTO IVEMRI_Bitacora_matriz_riesgo (NumeroFacturaBuscada, DocEntryBuscado, UsuarioSTOD, FechaHoraSolicitud)
			VALUES (@NumeroFactura, @DocEntrySAP, @UsuarioSTOD, GETDATE());

			-- 3. VALIDACIÓN INICIAL: SI NO EXISTE EN SAP
			IF @DocEntrySAP IS NULL
			BEGIN
				SELECT 'SIN DATOS' AS RESPUESTA, 'Factura no existe en SAP' AS Detalle;
				RETURN;
			END

			-- 4. EJECUTAR EL PRIMER SP DE ANÁLISIS
			-- EXEC [128.1.200.166].[SBO_CANELLA].[dbo].[Reporte_Vehiculos_IVE_Opt_Individual] @DocEntryBuscado = @DocEntrySAP;

			-- 5. VALIDACIÓN DE COINCIDENCIAS
			SELECT @cantidad_coincidencias = COUNT(*)
			FROM STOD_SAPBONE.dbo.COREP_Facturas
			WHERE DocEntry = @DocEntrySAP 
			  AND CAST(FacturaFecha AS DATE) = CAST(GETDATE() AS DATE);

			-- 6. SI NO HAY COINCIDENCIAS (INSERTAR CON NUMATCARD VACÍO)
			IF @cantidad_coincidencias = 0
			BEGIN
				INSERT INTO [SBO_CANELLA].[dbo].[Matriz_Riesgo_Individual_26_general_Bitacora] 
					(NombreSP, ParametrosEntrada, RespuestaSalida, DocEntry, NumAtCard, UsuarioFactura)
				VALUES (
					'Matriz_Riesgo_Individual_26_general',
					CONCAT('{"SIN DATOS","DocEntryBuscado":"', CAST(@DocEntrySAP AS VARCHAR), '"}'),
					'SIN DATOS',
					@DocEntrySAP,
					'', 
					@UsuarioSTOD
				);

				SELECT 'SIN DATOS' AS RESPUESTA;

			END

			-- 7. RETORNO EXITOSO PARA LA VISTA
			SELECT 
				A.CreateDate,
				A.DocEntry,
				A.NumAtCard AS NumeroFactura,
				@UsuarioSTOD AS UsuarioConsulta,
				'REPORTE GENERADO EXITOSAMENTE' AS Mensaje
			FROM [128.1.200.166].[SBO_CANELLA].[dbo].[OINV] A
			WHERE A.DocEntry = @DocEntrySAP;
			SET @MensajeDescripcion = 'Transacción completada satisfactoriamente...!!!';
			SET @MensajeTipo = 1;
			END TRY
			BEGIN CATCH
		
			SET @MensajeDescripcion = 'Transacción erronea...!!!';
			SET @MensajeTipo = 0;
			END CATCH
		END

		declare @codigo INT, @msg varchar(200)
		EXEC [dbo].[IVEMRI_ConsultaMatrizRiesgoFactura] 'FAC-001','omunoz', @codigo OUT, @msg OUT

		select @codigo, @msg




		-- Ejemplo de Procedimiento Paginado
ALTER PROCEDURE [dbo].[STOD_ListarFacturasPaginadas]
    @Pagina INT = 1,          -- Número de página
    @RegistrosPorPagina INT = 10,
	@MensajeTipo		INT OUT,
	@MensajeDescripcion VARCHAR(200) OUT
AS

BEGIN
BEGIN TRY 
    SELECT 
        A.FechaHoraSolicitud,
        A.DocEntryBuscado,
        A.NumeroFacturaBuscada AS NumeroFactura,
		A.UsuarioSTOD AS STOD,
        'REPORTE GENERADO' AS Mensaje
    FROM [SBO_CANELLA].[dbo].[IVEMRI_Bitacora_matriz_riesgo] A
    ORDER BY A.FechaHoraSolicitud DESC -- Es obligatorio ordenar para paginar
    OFFSET (@Pagina - 1) * @RegistrosPorPagina ROWS
    FETCH NEXT @RegistrosPorPagina ROWS ONLY;
	 SET @MensajeDescripcion = 'Transacción completada satisfactoriamente...!!!';
	SET @MensajeTipo = 1;
	END TRY
	BEGIN CATCH
SET @MensajeDescripcion = 'Transacción fallida, favor de verificar...!!!';
	SET @MensajeTipo = 0;
    THROW
END CATCH
END

EXEC [dbo].[STOD_ListarFacturasPaginadas] 1,20

INSERT INTO [SBO_CANELLA].[dbo].[IVEMRI_Bitacora_matriz_riesgo] 
(FechaHoraSolicitud, DocEntryBuscado, NumeroFacturaBuscada, UsuarioSTOD)
VALUES 
(GETDATE(), 101, 'FAC-001', 'OMUNOZ'),
(GETDATE(), 102, 'FAC-002', 'OMUNOZ');

-- Ahora vuelve a ejecutar el SP
EXEC [dbo].[STOD_ListarFacturasPaginadas] @Pagina = 1, @RegistrosPorPagina = 10;
