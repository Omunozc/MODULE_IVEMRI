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
				NumAtCard NVARCHAR(100) NULL,
				UsuarioFactura NVARCHAR(100) NULL;

       /*
       =========================================
       ||| SP MODIFICADO CON -1 QUEMADO A DOCENTRY|||
       =========================================
       */


CREATE PROCEDURE IVEMRI_ConsultaMatrizRiesgoFactura
    @NumeroFactura NVARCHAR(100),
    @UsuarioSTOD NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DocEntrySAP INT = -1;
    DECLARE @NumAtCardSAP NVARCHAR(100) = '';
    

    SELECT TOP 1 
        @DocEntrySAP = DocEntry
    FROM dbo.OINV
    WHERE NumAtCard = @NumeroFactura; -- O @NumeroFactura según tu campo de búsqueda

    -- 3. Registrar la solicitud en la nueva bitácora local STOD (IVEMRI_)
    INSERT INTO IVEMRI_Bitacora_matriz_riesgo (
        NumeroFacturaBuscada,
        DocEntryBuscado,
        UsuarioSTOD,
        FechaHoraSolicitud
    )
    VALUES (
        @NumeroFactura,
        @DocEntrySAP,
        @UsuarioSTOD,
        GETDATE()
    );

    IF @DocEntrySAP = -1
    BEGIN
        -- Registrar en la bitácora del 167 el intento fallido
        EXEC [LINKED_167].[NombreBD].[dbo].[sp_RegistrarBitacora167] 
             @NombreSP = 'IVEMRI_ConsultaMatrizRiesgoFactura',
             @Parametros = @NumeroFactura,
             @Respuesta = 'SIN DATOS EN SAP',
             @DocEntry = -1,
             @NumAtCard = '',
             @Usuario = @UsuarioSTOD;

        SELECT 'Factura no encontrada en SAP' AS Mensaje, @NumeroFactura AS Factura;
        RETURN;
    END

    -- 5. Obtener detalle de Matriz y consolidar con un JOIN
    -- Consultamos el detalle (suponiendo una tabla o función en el 167) 
    -- y lo unimos con la bitácora histórica del 167
    SELECT 
        A.DocEntry AS DocEntry_SAP,
        A.NumAtCard AS Factura_SAP,
        B.RespuestaSalida AS Detalle_Matriz,
        B.FechaHoraEjecucion AS Fecha_Registro_Matriz,
        @UsuarioSTOD AS Solicitante_STOD
    FROM [LINKED_SAP].[SBO_CANELLA].[dbo].[OINV] A
    INNER JOIN [LINKED_167].[NombreBD].[dbo].[Matriz_Riesgo_Individual_26_general_Bitacora] B
        ON A.DocEntry = B.DocEntry -- Llave JOIN por DocEntry
    WHERE A.DocEntry = @DocEntrySAP
    ORDER BY B.FechaHoraEjecucion DESC;

END