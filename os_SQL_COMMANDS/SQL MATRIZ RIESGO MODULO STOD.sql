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

       /*
       =========================================
       ||| MODIFICACION  |||
       =========================================
       */
		ALTER TABLE dbo.Matriz_Riesgo_Individual_26_general_Bitacora
			ADD 
				DocEntry INT NULL,
				NumAtCard NVARCHAR(100) NULL

       /*
       =========================================
       ||| SP PARA REVISION DE FACTURAS|||
       =========================================
       */

		CREATE PROCEDURE IVEMRI_ConsultaMatrizRiesgoFactura
			@NumeroFactura NVARCHAR(100),
			@UsuarioSTOD NVARCHAR(100)
		AS
		BEGIN
			SET NOCOUNT ON;

			DECLARE @DocEntrySAP INT = NULL; -- Inicializado en NULL para validación precisa
			DECLARE @cantidad_coincidencias INT = 0;

			-- 1. OBTENER EL DOCENTRY DESDE SAP (SERVIDOR 167)
			SELECT TOP 1 @DocEntrySAP = DocEntry
			FROM [128.1.200.167].[SBO_CANELLA].[dbo].[OINV]
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
			EXEC [128.1.200.167].[SBO_CANELLA].[dbo].[Reporte_Vehiculos_IVE_Opt_Individual] @DocEntryBuscado = @DocEntrySAP;

			-- 5. VALIDACIÓN DE COINCIDENCIAS
			SELECT @cantidad_coincidencias = COUNT(*)
			FROM [128.1.200.167].[STOD_SAPBONE].[dbo].[COREP_Facturas]
			WHERE DocEntry = @DocEntrySAP 
			  AND CAST(FacturaFecha AS DATE) = CAST(GETDATE() AS DATE);

			-- 6. SI NO HAY COINCIDENCIAS (INSERTAR CON NUMATCARD VACÍO)
			IF @cantidad_coincidencias = 0
			BEGIN
				INSERT INTO [128.1.200.167].[SBO_CANELLA].[dbo].[Matriz_Riesgo_Individual_26_general_Bitacora] 
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
			FROM [128.1.200.167].[SBO_CANELLA].[dbo].[OINV] A
			WHERE A.DocEntry = @DocEntrySAP;

		fin:
			PRINT 'Proceso finalizado';
		END
