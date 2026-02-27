USE [SBO_CANELLA]
GO
/****** Object:  StoredProcedure [dbo].[Reporte_Vehiculos_IVE_Opt_Individual]    Script Date: 27/02/2026 08:44:07 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* =========================================================================
   Procedimiento:  dbo.Reporte_Vehiculos_IVE_Opt
   Descripción  :  Devuelve la información IVE de un DocNum de factura (OINV)
   Parámetros   :  @DocEntryBuscado  — número de factura (OINV.DocEntry)
   ========================================================================= */
ALTER   PROCEDURE [dbo].[Reporte_Vehiculos_IVE_Opt_Individual]
(
    @DocEntryBuscado INT      
)
AS
BEGIN
    SET NOCOUNT ON;

    /* ---------- Caches para evitar sub‑consultas por fila ---------- */
       SELECT *
       INTO #cobros
       FROM(
        SELECT  DocNum,
                MAX(CashSum) AS MontoEfectivo
        FROM    ORCT WITH (NOLOCK)
        WHERE   Canceled = 'N'
        GROUP BY DocNum
    ) as cobrosTemporal;

    SELECT *
    INTO #agencias
    FROM (
        SELECT  PrcCode,
                MAX(U_CodigoAgencia) AS CodigoSucursal
        FROM    OPRC WITH (NOLOCK)
        GROUP BY PrcCode
    )as agenciasTemporal;

       SELECT *
       INTO #cte_datos
       FROM (

    /* ==================== BLOQUE 1 – Ventas con entrega ==================== */
    SELECT 
           a.DocNum,
           a.DocEntry,
           CONVERT(char(8), ISNULL(f.U_FechaPlacas, a.DocDate), 112)                       AS FechaTransaccion,
           CASE WHEN a.U_DoctoSerie = 'CCCJ4' THEN 0 ELSE ag.CodigoSucursal END            AS CodigoSucursal,   
           'V' AS TipoTransaccion, 
           UPPER(a.U_DoctoSerie) + '-' + a.U_DoctoNo                                       AS NumeroFactura,    
           a.DocDate                                                                       AS FechaFactura,     
           a.DocTotal                                                                      AS MontoTransaccion, 
           ISNULL(co.MontoEfectivo, 0)                                                     AS MontoEfectivo,    
           /* ---- Datos personales (idénticos al original) ---- */
           ISNULL((SELECT MAX(U_TipoPersona)        FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry) ,
                  (SELECT MAX(u_tipopersona)        FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS TipoPersona, 
           ISNULL((SELECT MAX(U_TipoIdentificacion) FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                  (SELECT MAX(u_tipoidentificacion) FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS TipoDocIdentificacion, 
           ISNULL((SELECT CONVERT(varchar, MAX(U_DocIdent)) FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                  (SELECT MAX(VatIdUnCmp)                    FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS DPI , 
           UPPER(REPLACE(a.U_SNNIT, '-', '')) AS NIT, 
           ISNULL((SELECT MAX(U_Nacionalidad)     FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                  (SELECT MAX(u_nacionalidad)     FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS Nacionalidad, 
           ISNULL((SELECT CONVERT(char, MAX(U_FechaNacimiento), 112) FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                  (SELECT CONVERT(char, MAX(u_FechaNacimiento), 112) FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS FechaNacimiento, 
           ISNULL((SELECT MAX(U_PrimerNombre)     FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry  AND a.U_PrimerNombre  <> ''),
                  (SELECT MAX(u_PrimerNombre)     FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND u_PrimerNombre     <> '')) AS PrimerNombre, 
           ISNULL((SELECT MAX(U_SegundoNombre)    FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry  AND a.U_SegundoNombre <> ''),
                  (SELECT MAX(u_SegundoNombre)    FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND u_SegundoNombre    <> '')) AS SegundoNombre, 
           ISNULL((SELECT MAX(U_PrimerApellido)   FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry  AND a.U_PrimerApellido <> ''),
                  (SELECT MAX(u_PrimerApellido)   FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND u_PrimerApellido   <> '')) AS PrimerApellido, 
           ISNULL((SELECT MAX(U_SegundoApellido)  FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry  AND a.U_SegundoApellido <> ''),
                  (SELECT MAX(u_SegundoApellido)  FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND u_SegundoApellido  <> '')) AS SegundoApellido, 
           COALESCE((SELECT TOP 1 U_ApellidoCasada FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry AND U_ApellidoCasada <> ''),
                    (SELECT TOP 1 U_ApellidoCasada FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND U_ApellidoCasada <> '')) AS ApellidoCasada, 
           a.U_SNNombre AS ClienteReal, 
           ISNULL(CASE WHEN ISNULL((SELECT MAX(u_tipopersona) FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode), '.') = 'J'
                        THEN a.CardName END,
                  (SELECT CardName FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry
                          AND (SELECT U_TipoPersona FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry) = 'J')) AS PersonaJuridica, 
           /* ---- Datos del vehículo ---- */
           CASE WHEN f.U_Estado = '0' THEN 'NUEVO' ELSE 'USADO' END                                               AS Estado, 
           f.U_TipoVehiculo AS TipoVehiculo,             
           f.U_DetTipoVehiculo AS DetalleTipoVehiculo,          
           f.U_Marca AS Marca,                    
           UPPER(SUBSTRING(d.ItemCode, 1, 20))                              AS Linea, 
           d.ItemName                                                       AS DescripcionVehiculo, 
           f.U_UsoVehiculo AS UsoDelVehiculo,            
           f.U_Placa AS NoPlaca,                  
           f.U_Color AS Color,                  
           f.U_Modelo AS Modelo,                 
           UPPER(f.DistNumber)         AS NoSerie
    FROM  OINV        a WITH (NOLOCK)
    JOIN  INV1        c WITH (NOLOCK) ON c.DocEntry = a.DocEntry
    JOIN  DLN1        e WITH (NOLOCK) ON e.ObjType  = c.BaseType
                                     AND e.DocEntry = c.BaseEntry
                                     AND e.LineNum  = c.BaseLine
    JOIN  SRI1_LINK2  f WITH (NOLOCK) ON f.BaseType  = e.ObjType
                                     AND f.BaseEntry = e.DocEntry
                                     AND f.BaseLinNum= e.LineNum
                                     AND f.ItemCode  = c.ItemCode
    JOIN  OITM        d WITH (NOLOCK) ON d.ItemCode = c.ItemCode
    LEFT JOIN #cobros  co ON co.DocNum = a.ReceiptNum
    LEFT JOIN #agencias ag ON ag.PrcCode = c.OcrCode
    WHERE a.DocEntry = @DocEntryBuscado
      AND (   d.ItmsGrpCod IN (118,119,149,148,120,133,151,150,236,290,291,310)
           OR (d.ItemName LIKE '%ACUATICA%' AND d.ItmsGrpCod = 148) )
      AND c.BaseType IN ('15','-1','17')
      AND c.TargetType <> 14
      AND NOT EXISTS (SELECT 1 FROM ORIN r WITH (NOLOCK)
                      WHERE r.U_FE_MP_DocVin = a.DocNum
                        AND r.DocTotal       = a.DocTotal)

    /* ==================== BLOQUE 2 – Ventas sin entrega ==================== */
    UNION ALL
    SELECT 
              a.DocNum,
           a.DocEntry,
           CONVERT(char(8), ISNULL(f.U_FechaPlacas, a.DocDate), 112) AS FechaTransaccion, 
           CASE WHEN a.U_DoctoSerie = 'CCCJ4' THEN 0 ELSE ag.CodigoSucursal END AS CodigoSucursal, 
           'V' AS TipoTransaccion, 
           UPPER(a.U_DoctoSerie) + '-' + a.U_DoctoNo AS NumeroFactura, 
           a.DocDate AS FechaFactura , 
           a.DocTotal AS MontoTransaccion,  
           ISNULL(co.MontoEfectivo, 0) AS MontoEfectivo, 
           /* —— datos personales (idénticos al bloque‑1) —— */
           ISNULL((SELECT MAX(U_TipoPersona)        FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                  (SELECT MAX(u_tipopersona)        FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS TipoPersona, 
           ISNULL((SELECT MAX(U_TipoIdentificacion) FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                  (SELECT MAX(u_tipoidentificacion) FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS TipoDocIdentificacion, 
           ISNULL((SELECT CONVERT(varchar, MAX(U_DocIdent)) FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                  (SELECT MAX(VatIdUnCmp)                    FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode))  AS DPI, 
           UPPER(REPLACE(a.U_SNNIT, '-', '')) AS NIT, 
           ISNULL((SELECT MAX(U_Nacionalidad)     FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                  (SELECT MAX(u_nacionalidad)     FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS Nacionalidad, 
           ISNULL((SELECT CONVERT(char, MAX(U_FechaNacimiento), 112) FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                  (SELECT CONVERT(char, MAX(u_FechaNacimiento), 112) FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS FechaNacimiento, 
           ISNULL((SELECT MAX(U_PrimerNombre)     FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry  AND a.U_PrimerNombre  <> ''),
                  (SELECT MAX(u_PrimerNombre)     FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND u_PrimerNombre     <> '')) AS PrimerNombre, 
           ISNULL((SELECT MAX(U_SegundoNombre)    FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry  AND a.U_SegundoNombre <> ''),
                  (SELECT MAX(u_SegundoNombre)    FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND u_SegundoNombre    <> '')) AS SegundoNombre, 
           ISNULL((SELECT MAX(U_PrimerApellido)   FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry  AND a.U_PrimerApellido <> ''),
                  (SELECT MAX(u_PrimerApellido)   FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND u_PrimerApellido   <> '')) AS PrimerApellido, 
           ISNULL((SELECT MAX(U_SegundoApellido)  FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry  AND a.U_SegundoApellido <> ''),
                  (SELECT MAX(u_SegundoApellido)  FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND u_SegundoApellido  <> '')) AS SegundoApellido, 
           COALESCE((SELECT TOP 1 U_ApellidoCasada FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry AND U_ApellidoCasada <> ''),
                    (SELECT TOP 1 U_ApellidoCasada FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND U_ApellidoCasada <> '')) AS ApellidoCasada, 
           a.U_SNNombre AS ClienteReal, 
           ISNULL(CASE WHEN ISNULL((SELECT MAX(u_tipopersona) FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode), '.') = 'J'
                        THEN a.CardName END,
                  (SELECT CardName FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry
                          AND (SELECT U_TipoPersona FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry) = 'J')) AS PersonaJuridica, 
           CASE WHEN f.U_Estado = '0' THEN 'NUEVO' ELSE 'USADO' END AS Estado, 
           f.U_TipoVehiculo AS TipoVehiculo, 
           f.U_DetTipoVehiculo AS DetalleTipoVehiculo, 
           f.U_Marca AS Marca, 
           UPPER(SUBSTRING(d.ItemCode, 1, 20)) AS Linea, 
           d.ItemName AS DescripcionVehiculo, 
           f.U_UsoVehiculo AS UsoDelVehiculo, 
           f.U_Placa AS NoPlaca, 
           f.U_Color AS Color, 
           f.U_Modelo AS Modelo, 
           UPPER(f.DistNumber) AS NoSerie
    FROM  OINV        a WITH (NOLOCK)
    JOIN  INV1        c WITH (NOLOCK) ON c.DocEntry = a.DocEntry
    JOIN  SRI1_LINK2  f WITH (NOLOCK) ON f.BaseType   = c.ObjType
                                     AND f.BaseEntry  = c.DocEntry
                                     AND f.BaseLinNum = c.LineNum
                                     AND f.ItemCode   = c.ItemCode
    JOIN  OITM        d WITH (NOLOCK) ON d.ItemCode = c.ItemCode
    LEFT JOIN #cobros  co ON co.DocNum = a.ReceiptNum
    LEFT JOIN #agencias ag ON ag.PrcCode = c.OcrCode
    WHERE a.DocEntry = @DocEntryBuscado
      AND d.ItmsGrpCod IN (118,119,149,148,120,133,151,150,236,290,291,310)
      AND c.BaseType IN ('-1','17','171')
      AND c.TargetType <> 14
      AND NOT EXISTS (SELECT 1 FROM ORIN r WITH (NOLOCK)
                      WHERE r.U_FE_MP_DocVin = a.DocNum
                        AND r.DocTotal       = a.DocTotal)

    /* ==================== BLOQUE 3 – Vehículos usados (sin serie) ============ */
    UNION ALL
    SELECT 
    a.DocNum,
           a.DocEntry,
           CONVERT(char(8), a.DocDate, 112) AS FechaTransaccion, 
           CASE WHEN a.U_DoctoSerie = 'CCCJ4' THEN 0 ELSE ag.CodigoSucursal END AS CodigoSucursal, 
           'V' AS TipoTransaccion, 
           UPPER(a.U_DoctoSerie) + '-' + a.U_DoctoNo AS NumeroFactura, 
           a.DocDate AS FechaFactura , 
           a.DocTotal AS MontoTransaccion,  
           ISNULL(co.MontoEfectivo, 0) AS MontoEfectivo, 
           ISNULL((SELECT MAX(U_TipoPersona)        FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                  (SELECT MAX(u_tipopersona)        FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS TipoPersona, 
           ISNULL((SELECT MAX(U_TipoIdentificacion) FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                  (SELECT MAX(u_tipoidentificacion) FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS TipoDocIdentificacion, 
           ISNULL((SELECT CONVERT(varchar, MAX(U_DocIdent)) FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                  (SELECT MAX(VatIdUnCmp)                    FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode))  AS DPI, 
           UPPER(REPLACE(a.U_SNNIT, '-', '')) AS NIT, 
           ISNULL((SELECT MAX(U_Nacionalidad)     FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                  (SELECT MAX(u_nacionalidad)     FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS Nacionalidad, 
           ISNULL((SELECT CONVERT(char, MAX(U_FechaNacimiento), 112) FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                  (SELECT CONVERT(char, MAX(u_FechaNacimiento), 112) FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS FechaNacimiento, 
           ISNULL((SELECT MAX(U_PrimerNombre)     FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry  AND a.U_PrimerNombre  <> ''),
                  (SELECT MAX(u_PrimerNombre)     FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND u_PrimerNombre     <> '')) AS PrimerNombre, 
           ISNULL((SELECT MAX(U_SegundoNombre)    FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry  AND a.U_SegundoNombre <> ''),
                  (SELECT MAX(u_SegundoNombre)    FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND u_SegundoNombre    <> '')) AS SegundoNombre, 
           ISNULL((SELECT MAX(U_PrimerApellido)   FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry  AND a.U_PrimerApellido <> ''),
                  (SELECT MAX(u_PrimerApellido)   FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND u_PrimerApellido   <> '')) AS PrimerApellido, 
           ISNULL((SELECT MAX(U_SegundoApellido)  FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry  AND a.U_SegundoApellido <> ''),
                  (SELECT MAX(u_SegundoApellido)  FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND u_SegundoApellido  <> '')) AS SegundoApellido, 
           COALESCE((SELECT TOP 1 U_ApellidoCasada FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry AND U_ApellidoCasada <> ''),
                    (SELECT TOP 1 U_ApellidoCasada FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND U_ApellidoCasada <> '')) AS ApellidoCasada, 
           a.U_SNNombre AS ClienteReal, 
           ISNULL(CASE WHEN ISNULL((SELECT MAX(u_tipopersona) FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode), '.') = 'J'
                        THEN a.CardName END,
                  (SELECT CardName FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry
                          AND (SELECT U_TipoPersona FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry) = 'J')) AS PersonaJuridica, 
           'USADO' AS Estado, 
           CASE WHEN d.ItmsGrpCod IN (118,119,146,147,149,150,220,221,236) THEN 'T' ELSE 'M' END AS TipoVehiculo, 
           '' AS DetalleTipoVehiculo, 
           '' AS Marca,   -- Marca
           UPPER(SUBSTRING(d.ItemCode, 1, 20)) AS Linea, 
           '' AS DescripcionVehiculo,   -- Descripción
           '' AS UsoDelVehiculo,   -- Uso
           '' AS NoPlaca,   -- Placa
           '' AS Color,   -- Color
           '' AS Modelo,   -- Modelo
           '' AS NoSerie
    FROM  OINV        a WITH (NOLOCK)
    JOIN  INV1        c WITH (NOLOCK) ON c.DocEntry = a.DocEntry
    JOIN  OITM        d WITH (NOLOCK) ON d.ItemCode = c.ItemCode
    LEFT JOIN #cobros  co ON co.DocNum = a.ReceiptNum
    LEFT JOIN #agencias ag ON ag.PrcCode = c.OcrCode
    WHERE a.DocEntry = @DocEntryBuscado
      AND d.ItmsGrpCod IN (221, 220)
      AND NOT EXISTS (SELECT 1 FROM ORIN r WITH (NOLOCK)
                      WHERE r.U_FE_MP_DocVin = a.DocNum
                        AND r.DocTotal       = a.DocTotal)


    /* ==================== BLOQUE 4 – MAQUINARIA ============ */
    UNION ALL
     SELECT 
       a.DocNum,
           a.DocEntry,
        -- Fecha de transacción: U_FechaPlacas si existe, sino DocDate
        CASE 
            WHEN f.U_Fechaplacas IS NULL THEN 
            
                CASE 
                    WHEN p.U_FechaEntrega IS NOT NULL THEN CONVERT(CHAR(8), p.U_FechaEntrega, 112)
                    WHEN m.U_FechaEntrega IS NOT NULL THEN CONVERT(CHAR(8), m.U_FechaEntrega, 112)
                END
                
            ELSE CONVERT(CHAR, f.U_Fechaplacas, 112)
        END AS FechaTransaccion, 

        -- Código de sucursal
        CASE 
            WHEN a.U_DoctoSerie = 'CCCJ4' THEN 0
            ELSE (SELECT MAX(u_codigoagencia) FROM OPRC (NOLOCK) WHERE prccode = c.ocrcode)
        END AS CodigoSucursal, 

        'V' AS TipoTransaccion, 
        UPPER(a.U_DoctoSerie) + '-' + a.U_DoctoNo AS NumeroFactura, 
        a.DocDate AS FechaFactura, 
        a.DocTotal AS MontoTransaccion, 

        ISNULL((SELECT MAX(cashsum) FROM ORCT (NOLOCK) WHERE docnum = a.receiptnum AND canceled = 'N'), 0) AS MontoEfectivo, 

        ISNULL((SELECT MAX(U_TipoPersona) FROM OINV WHERE DocEntry = a.DocEntry),
               (SELECT MAX(u_tipopersona) FROM OCRD WHERE CardCode = a.CardCode)) AS TipoPersona, 

        ISNULL((SELECT MAX(U_tipoIdentificacion) FROM OINV WHERE DocEntry = a.DocEntry),
               (SELECT MAX(u_tipoidentificacion) FROM OCRD WHERE CardCode = a.CardCode)) AS TipoDocIdentificacion, 

        ISNULL((SELECT MAX(U_DocIdent) FROM OINV WHERE DocEntry = a.DocEntry),
               (SELECT MAX(VatIdUnCmp) FROM OCRD WHERE CardCode = a.CardCode)) AS DPI, 

        UPPER(REPLACE(a.U_SNNIT, '-', '')) AS NIT, 

        ISNULL((SELECT MAX(U_Nacionalidad) FROM OINV WHERE DocEntry = a.DocEntry),
               (SELECT MAX(u_nacionalidad) FROM OCRD WHERE CardCode = a.CardCode)) AS Nacionalidad, 

        ISNULL(CONVERT(CHAR, (SELECT MAX(U_FechaNacimiento) FROM OINV WHERE DocEntry = a.DocEntry), 112),
               CONVERT(CHAR, (SELECT MAX(u_fechanacimiento) FROM OCRD WHERE CardCode = a.CardCode), 112)) AS FechaNacimiento, 

        -- Nombres y apellidos
        ISNULL(NULLIF((SELECT MAX(U_PrimerNombre) FROM OINV WHERE DocEntry = a.DocEntry), ''), 
               (SELECT MAX(U_PrimerNombre) FROM OCRD WHERE CardCode = a.CardCode)) AS PrimerNombre, 

        ISNULL(NULLIF((SELECT MAX(U_SegundoNombre) FROM OINV WHERE DocEntry = a.DocEntry), ''), 
               (SELECT MAX(U_SegundoNombre) FROM OCRD WHERE CardCode = a.CardCode)) AS SegundoNombre, 

        ISNULL(NULLIF((SELECT MAX(U_PrimerApellido) FROM OINV WHERE DocEntry = a.DocEntry), ''), 
               (SELECT MAX(U_PrimerApellido) FROM OCRD WHERE CardCode = a.CardCode)) AS PrimerApellido, 

        ISNULL(NULLIF((SELECT MAX(U_SegundoApellido) FROM OINV WHERE DocEntry = a.DocEntry), ''), 
               (SELECT MAX(U_SegundoApellido) FROM OCRD WHERE CardCode = a.CardCode)) AS SegundoApellido, 

        -- Apellido casada
        COALESCE(
            (SELECT TOP 1 U_ApellidoCasada FROM OINV WHERE DocEntry = a.DocEntry AND U_ApellidoCasada <> ''),
            (SELECT TOP 1 U_ApellidoCasada FROM OCRD WHERE CardCode = a.CardCode AND U_ApellidoCasada <> '')
        ) AS ApellidoCasada, 

        a.U_SNNombre AS ClienteReal, 

        CASE 
            WHEN ISNULL((SELECT MAX(u_tipopersona) FROM OCRD WHERE CardCode = a.CardCode), '.') = 'J' THEN a.CardName
            ELSE NULL
        END AS PersonaJuridica, 

        -- Estado, Tipo y Detalle
        CASE WHEN f.U_Estado = '0' THEN 'NUEVO' ELSE 'USADO' END AS Estado, 
        f.U_TipoVehiculo AS TipoVehiculo, 
        f.U_DetTipoVehiculo AS DetalleTipoVehiculo, 

        -- Marca traducida
        f.u_marca AS Marca, 

        UPPER(SUBSTRING(d.ItemCode, 1, 20)) AS Linea, 
        d.ItemName AS DescripcionVehiculo, 
        f.U_UsoVehiculo AS UsoDelVehiculo, 
        f.U_Placa AS NoPlaca, 
        f.U_Color AS Color, 
        f.U_Modelo AS Modelo, 
        UPPER(f.DistNumber) AS NoSerie

    

    FROM OINV a
    INNER JOIN INV1 c ON a.DocEntry = c.DocEntry
    INNER JOIN OITM d ON c.ItemCode = d.ItemCode
    INNER JOIN SRI1_LINK2 f ON f.BaseEntry = c.DocEntry OR f.BaseEntry = c.BaseEntry AND f.ItemCode = c.ItemCode AND f.BaseLinNum = c.LineNum
	

    OUTER APPLY (
        SELECT TOP 1 U_FechaEntrega
        FROM [@PASENH]
        WHERE U_Vin = f.DistNumber
        ORDER BY UpdateDate DESC
    ) p

    OUTER APPLY (
        SELECT TOP 1 U_FechaEntrega
        FROM [@PASEMAQCONS]
        WHERE U_Chasis = f.DistNumber
        ORDER BY UpdateDate DESC
    ) m

    -- Fechas válidas: si no hay placas, usamos DocDate
    WHERE
        a.DocEntry = @DocEntryBuscado
        AND f.u_marca IN ('4', '5') 
        AND d.ItmsGrpCod IN (146, 243, 242, 281)
        AND c.BaseType IN ('15', '-1', '17')
        AND c.TargetType <> 14
        AND NOT EXISTS (
            SELECT 1 FROM ORIN WHERE U_FE_MP_DocVin = a.DocNum AND DocTotal = a.DocTotal
        )

    ) AS cte_datos_base;



       /*
       ===========================================================
       ||| VALIDACIONES SOBRE REGISTROS COMPATIBLES CON MATRIZ |||
       ===========================================================
       */

	          /*
       ===========================================================
       ||| CAMBIOS REALIZADOS POR OSCAR MUÑOZ |||
       ===========================================================
       */

		DECLARE @cantidad_coincidencias INT = 0;

		SELECT 
			@cantidad_coincidencias = COUNT(*)
		FROM 
			#cte_datos;

		IF @cantidad_coincidencias = 0
		BEGIN
			-- Insertamos quemando los valores para que no fallen los listados
			INSERT INTO dbo.Matriz_Riesgo_Individual_26_general_Bitacora 
			(
				NombreSP, 
				ParametrosEntrada, 
				RespuestaSalida, 
				DocEntry, 
				NumAtCard, 
				UsuarioFactura, 
				UsuarioCodigo
			)
			VALUES (
				'Matriz_Riesgo_Individual_26_general',
				CONCAT('{"SIN DATOS","DocEntryBuscado":"', @DocEntryBuscado, '"}'),
				'SIN DATOS',
				@DocEntryBuscado, -- El ID que recibimos
				'SIN FACTURA',    -- Quemado
				'SISTEMA',        -- Quemado
				'0'               -- Quemado
			);

			goto fin; 
		END

       /*
       ======================================================================
       ||| OBTENCION DE VALORES DE CALIFICACION DE SEGMENTACION DE RIESGO |||
       ======================================================================
       */


       CREATE TABLE #ValoresParaCalificacionDeFactura (
              Segmento NVARCHAR(100),
              Descripcion NVARCHAR(100),
              Valor DECIMAL(10,4)
       );

       CREATE TABLE #ValoresRiesgoSegmentacion (
              DETALLE_ID INT,
              EVALUACION_ID INT,
              NO_FACTOR INT,
              FACTOR NVARCHAR(200),
              SEGMENTO_ID INT,
              NO_SEGMENTO INT,
              SEGMENTO NVARCHAR(200),
              ITEM_ID INT,
              NO_ITEM INT,
              ITEM NVARCHAR(200),
              NIVEL_RIESGO_INHERENTE NUMERIC(10,3),
              CANT_OPERACIONES INT,
              IMP_REPUTACIONAL NUMERIC(10,3),
              IMP_LEGAL NUMERIC(10,3),
              IMP_CONTAGIO NUMERIC(10,3),
              IMP_OPERATIVO NUMERIC(10,3),
              NIVEL_IMPACTO NUMERIC(10,3),
              NIVEL_RIESGO_LDFT NUMERIC(10,3)
              );

       INSERT INTO #ValoresRiesgoSegmentacion
       SELECT
              d.DETALLE_ID,
              d.EVALUACION_ID,
              f.CODIGO      AS NO_FACTOR,
              f.NOMBRE      AS FACTOR,
              s.SEGMENTO_ID,
              s.ORDEN       AS NO_SEGMENTO,
              s.NOMBRE      AS SEGMENTO,
              i.ITEM_ID,
              i.ORDEN       AS NO_ITEM,
              i.NOMBRE      AS ITEM,

              d.NIVEL_RIESGO_INHERENTE,
              d.CANT_OPERACIONES,
              d.IMP_REPUTACIONAL,
              d.IMP_LEGAL,
              d.IMP_CONTAGIO,
              d.IMP_OPERATIVO,

              d.NIVEL_IMPACTO,
              d.NIVEL_RIESGO_LDFT
       FROM UTILS.dbo.src180_IVE_RESPUESTA_AL_RIESGO_SEG_DETALLE d
       JOIN UTILS.dbo.src180_IVE_RESPUESTA_AL_RIESGO_SEG_ITEM i      ON i.ITEM_ID     = d.ITEM_ID
       JOIN UTILS.dbo.src180_IVE_RESPUESTA_AL_RIESGO_SEG_SEGMENTO s  ON s.SEGMENTO_ID = i.SEGMENTO_ID
       JOIN UTILS.dbo.src180_IVE_RESPUESTA_AL_RIESGO_SEG_FACTOR f    ON f.FACTOR_ID   = s.FACTOR_ID;
       -- ORDER BY f.CODIGO, s.ORDEN, i.ORDEN;


       /*
       =========================================
       ||| PRIMER APARTADO DETALLE VEHICULOS |||
       =========================================
       */

       

       /* 1) Agregar por Marca/Detalle y preparar campos base */
       ;WITH base AS (
       SELECT
              Marca,
              DetalleTipoVehiculo,
              COUNT(DISTINCT ClienteReal) AS Clientes,
              COUNT(*) AS Transacciones
       FROM #cte_datos
       GROUP BY Marca, DetalleTipoVehiculo
       ),
       /* 2) Construir la descripción legible */
       desc_base AS (
       SELECT
              b.Marca,
              b.DetalleTipoVehiculo,
              b.Clientes,
              b.Transacciones,
              CAST(
              CONCAT(
                     CASE
                     WHEN b.Marca IS NULL THEN N'Marca nula'
                     WHEN b.Marca = '0'   THEN N'ISUZU'
                     WHEN b.Marca = '1'   THEN N'YAMAHA'
                     WHEN b.Marca = '4'   THEN N'HYUNDAI'
                     WHEN b.Marca = '5'   THEN N'NEW HOLLAND'
                     WHEN b.Marca = '6'   THEN N'DFSK'
                     ELSE N'Marca desconocida'
                     END,
                     N' - ',
                     CASE 
                     WHEN b.DetalleTipoVehiculo IS NULL THEN N'Detalle de tipo de vehículo nulo'
                     WHEN b.DetalleTipoVehiculo = 'T15' THEN N'Camioneta'
                     WHEN b.DetalleTipoVehiculo = 'T26' THEN N'Microbús'
                     WHEN b.DetalleTipoVehiculo = 'T30' THEN N'Panel'
                     WHEN b.DetalleTipoVehiculo = 'T32' THEN N'Pick up'
                     WHEN b.DetalleTipoVehiculo = 'T33' THEN N'Tractor'
                     WHEN b.DetalleTipoVehiculo = 'T34' THEN N'Tractor Agrícola'
                     WHEN b.DetalleTipoVehiculo = 'T7'  THEN N'Camión'
                     WHEN b.DetalleTipoVehiculo = 'T22' THEN N'Cuatrímoto'
                     WHEN b.DetalleTipoVehiculo = 'T28' THEN N'Motocicletas'
                     WHEN b.DetalleTipoVehiculo = 'T36' THEN N'Vehículo Rústico'
                     WHEN b.DetalleTipoVehiculo = 'M5'  THEN N'Moto de Agua'
                     ELSE N'Tipo Vehículo sin definir'
                     END
              ) AS NVARCHAR(200)
              ) AS [Descripción marca y tipo de vehículos]
       FROM base b
       ),
       /* 3) Asignar numeración por volumen (transacciones) */
       ranked AS (
       SELECT
              ROW_NUMBER() OVER (ORDER BY Transacciones DESC) AS [No.],
              [Descripción marca y tipo de vehículos],
              Clientes,
              Transacciones,
              CAST(0 AS INT) AS TotalTransacciones
       FROM desc_base
       )

       SELECT *
       INTO #Descripcion_marca_tipoVehiculo
       FROM (
       SELECT * FROM ranked
       UNION ALL
       SELECT
              0 AS [No.],
              N'TOTAL GENERAL' AS [Descripción marca y tipo de vehículos],
              COUNT(DISTINCT ClienteReal) AS Clientes,
              COUNT(*) AS Transacciones,
              COUNT(*) AS TotalTransacciones  -- total general de transacciones
       FROM #cte_datos
       ) x;

       

       INSERT INTO #ValoresParaCalificacionDeFactura
       SELECT
              R.Segmento,
              R.ITEM,
              R.NIVEL_RIESGO_LDFT
       FROM #Descripcion_marca_tipoVehiculo C
       JOIN #ValoresRiesgoSegmentacion R
       ON LTRIM(RTRIM(C.[Descripción marca y tipo de vehículos])) COLLATE Latin1_General_100_CI_AI
              = LTRIM(RTRIM(R.ITEM)) COLLATE Latin1_General_100_CI_AI
       WHERE C.[No.] > 0;

       /*
       ==============================================
       ||| PERSONAS INDIVIDUALES POR NACIONALIDAD |||
       ==============================================
       */
       
       CREATE TABLE #nacionalidad_individual (
              [No.] INT,
              [Descripción de nacionalidad personas INDIVIDUALES] NVARCHAR(100) ,
              Clientes INT  ,
              Transacciones INT  
       );

       ;WITH clasificado AS (
       SELECT
              ClienteReal,
              CASE 
              WHEN TipoDocIdentificacion = 'D'
                     OR NULLIF(LTRIM(RTRIM(DPI)), '') IS NOT NULL
                     OR Nacionalidad = 'GT'
              THEN N'NACIONALES GUATEMALTECOS'
              ELSE N'EXTRANJEROS'
              END AS Descripcion
       FROM #cte_datos
       WHERE UPPER(TipoPersona) = 'I'
       ),
       /* 2) Agregar conteos */
       agregado AS (
       SELECT
              Descripcion,
              COUNT(DISTINCT ClienteReal) AS Clientes,
              COUNT(*) AS Transacciones
       FROM clasificado
       GROUP BY Descripcion
       ),
       /* 3) Numerar filas por orden alfabético de la descripción */
       numerado AS (
       SELECT
              ROW_NUMBER() OVER (ORDER BY Descripcion) AS [No.],
              CAST(Descripcion AS NVARCHAR(100)) AS [Descripción de nacionalidad personas INDIVIDUALES],
              Clientes,
              Transacciones
       FROM agregado
       )
       /* 4) Persistir en temporal */
       INSERT INTO #nacionalidad_individual ([No.], [Descripción de nacionalidad personas INDIVIDUALES], Clientes, Transacciones)
       SELECT [No.], [Descripción de nacionalidad personas INDIVIDUALES], Clientes, Transacciones
       FROM numerado;

       


       INSERT INTO #ValoresParaCalificacionDeFactura
       SELECT
              R.Segmento,
              R.ITEM,
              R.NIVEL_RIESGO_LDFT
       FROM #nacionalidad_individual C
       JOIN #ValoresRiesgoSegmentacion R
       ON LTRIM(RTRIM(C.[Descripción de nacionalidad personas INDIVIDUALES])) COLLATE Latin1_General_100_CI_AI
              = LTRIM(RTRIM(R.ITEM)) COLLATE Latin1_General_100_CI_AI
       WHERE R.Segmento = 'POR NACIONALIDAD PERSONAS INDIVIDUALES'

       /*
       ==============================================
       ||| PERSONAS JURIDICAS POR NACIONALIDAD |||
       ==============================================
       */
       
       CREATE TABLE #nacionalidad_juridica (
              [No.] INT  ,
              [Descripción de nacionalidad personas JURÍDICAS] NVARCHAR(100)  ,
              Clientes INT  ,
              Transacciones INT  
       );

       /* 1) Clasificar personas JURÍDICAS por nacionalidad */
       ;WITH clasificado AS (
       SELECT
              ClienteReal,
              CASE 
              WHEN TipoDocIdentificacion = 'D'
                     OR NULLIF(LTRIM(RTRIM(DPI)), '') IS NOT NULL
                     OR UPPER(LTRIM(RTRIM(Nacionalidad))) = 'GT'
              THEN N'Nacionales'
              ELSE N'Extranjeros'
              END AS Descripcion
       FROM #cte_datos
       WHERE UPPER(TipoPersona) = 'J'
       ),
       /* 2) Agregar conteos */
       agregado AS (
       SELECT
              Descripcion,
              COUNT(DISTINCT ClienteReal) AS Clientes,
              COUNT(*) AS Transacciones
       FROM clasificado
       GROUP BY Descripcion
       ),
       /* 3) Numerar filas por orden alfabético de la descripción */
       numerado AS (
       SELECT
              ROW_NUMBER() OVER (ORDER BY Descripcion) AS [No.],
              CAST(Descripcion AS NVARCHAR(100)) AS [Descripción de nacionalidad personas JURÍDICAS],
              Clientes,
              Transacciones
       FROM agregado
       )
       /* 4) Persistir en temporal */
       INSERT INTO #nacionalidad_juridica ([No.], [Descripción de nacionalidad personas JURÍDICAS], Clientes, Transacciones)
       SELECT [No.], [Descripción de nacionalidad personas JURÍDICAS], Clientes, Transacciones
       FROM numerado;

       

       INSERT INTO #ValoresParaCalificacionDeFactura
       SELECT
              R.Segmento,
              R.ITEM,
              R.NIVEL_RIESGO_LDFT
       FROM #nacionalidad_juridica C
       JOIN #ValoresRiesgoSegmentacion R
       ON LTRIM(RTRIM(C.[Descripción de nacionalidad personas JURÍDICAS])) COLLATE Latin1_General_100_CI_AI
              = LTRIM(RTRIM(R.ITEM)) COLLATE Latin1_General_100_CI_AI
       WHERE R.Segmento = 'PERSONAS JURÍDICAS'

       /*
       ==============================================
       ||| OBTENER LOS VALORES DE NIT DE VISUALHUR |||
       ==============================================
       */

       SELECT 
       CASE 
              WHEN CHARINDEX('-', IDE_NIT) > 0 THEN REPLACE(IDE_NIT, '-', '') 
              ELSE IDE_NIT
       END COLLATE SQL_Latin1_General_CP1_CI_AS AS NitEmpleado
       INTO #NitEmpleados
       FROM UTILS.dbo.src095_PLA_IDE_IDENT_EMP
       WHERE IDE_NIT IS NOT NULL;


       /*
       ==================================================
       ||| OBTENER LOS VALORES DE NIT DE PERSONAS PEP |||
       ==================================================
       */

       SELECT 
       CASE 
              WHEN CHARINDEX('-', NIT) > 0 THEN REPLACE(NIT, '-', '') 
              ELSE NIT
       END COLLATE SQL_Latin1_General_CP1_CI_AS AS NitPEP
       INTO #NitPersonasPEP
       FROM UTILS.dbo.src180_IVE_Clientes_PEPs
       WHERE NIT IS NOT NULL;

       /*
       ======================================================================================
       ||| OBTENER LOS VALORES DE NIT DE PERSONAS JURIDICA QUE PROVEE FONDOS COMO TERCERO |||
       ======================================================================================
       */

       SELECT DISTINCT
              NITPPFT 
       INTO #NitPPFCT
       FROM (
              SELECT 
                     CASE 
                     WHEN CHARINDEX('-', T19_NIT) > 0 THEN REPLACE(T19_NIT, '-', '') 
                     ELSE T19_NIT 
                     END AS NITPPFT
              FROM UTILS.dbo.src180_FEICPJ_T19_PersonaJuridicaProveeFondos

              UNION ALL

              SELECT 
                     CASE 
                     WHEN CHARINDEX('-', T17_NIT) > 0 THEN REPLACE(T17_NIT, '-', '') 
                     ELSE T17_NIT 
                     END AS NITPPFT
              FROM UTILS.dbo.src180_FEICPJ_T17_PersonaIndividualProveeFondos
       ) AS NitPersonasProveenFondosComoTerceros;


       /*
       ===========================================================================================
       ||| OBTENER LOS VALORES DE NIT DEL TIPO 'POR MEDIO DE MANDATARIOS (SIN VINCULO FAMILIAR)|||
       ===========================================================================================
       */

       SELECT DISTINCT
              CASE 
                     WHEN CHARINDEX('-', T16_NIT) > 0 THEN REPLACE(T16_NIT, '-', '') 
                     ELSE T16_NIT 
              END AS NitMandatario  
       INTO #NitPorMandatarios
       FROM UTILS.dbo.src180_FEICPI_T16_Representante a
       INNER JOIN UTILS.dbo.src180_FEICPI_T01_Principal b ON a.T16_FormularioID = b.FormularioID
       WHERE
              b.T1_calidadActua = 'Representante Legal'
              AND a.T16_NIT <> '' 
              AND a.T16_NIT IS NOT NULL

       /*
       ==============================================================================================================================
       ||| OBTENER LOS VALORES DE NIT DEL TIPO 'Organizaciones sin fines de lucro (Asociaciones, Fundaciones, ONG´s, entre otras)'|||
       ==============================================================================================================================
       */

       SELECT DISTINCT
              CASE 
                     WHEN CHARINDEX('-', AddID) > 0 THEN REPLACE(AddID, '-', '') 
                     ELSE AddID 
              END AS NitSFL
       INTO #NitOrganizacionesSFL
       FROM OCRD
       WHERE  
              U_ClasifPersona = 'PJ11'; -- U_ClasifPersona-> PJ11: OSFL; organizaciones sin fines de lucro



       /*
       ====================================================================================================================
       ||| OBTENER LOS VALORES DE NIT DEL TIPO 'Entidades del Estado (Ministerios, Secretarias, Municipalidades, otras)'|||
       ====================================================================================================================
       */

       SELECT DISTINCT
              CASE 
                     WHEN CHARINDEX('-', AddID) > 0 THEN REPLACE(AddID, '-', '') 
                     ELSE AddID 
              END AS NitEDE
       INTO #NitEntidadesDelEstado
       FROM OCRD
       WHERE  
              U_ClasifPersona = 'PJ10'; -- U_ClasifPersona-> PJ10: ENITDADES DEL ESTADO;



       /*
       ================================================================================================
       ||| OBTENER LOS VALORES DE NIT DEL TIPO 'Embajadas, Consulados u Organismos Internacionales.'|||
       ================================================================================================
       */

       SELECT DISTINCT
              CASE 
                     WHEN CHARINDEX('-', AddID) > 0 THEN REPLACE(AddID, '-', '') 
                     ELSE AddID 
              END AS NitEEC
       INTO #NitEntidadesEmbajadasConsulados
       FROM OCRD
       WHERE  
              U_ClasifPersona = 'PJ09'; -- U_ClasifPersona-> PJ09: ORGANISMO INTERNACIONAL, MISION, DIPLOMACIA O CONSULAR;

       /*
       ==========================================================================================================================================
       |||                                                            PERSONAS POR EXPERIENCIA COMERCIAL                                      |||
       ==========================================================================================================================================
       */



       
       DECLARE @anioABuscar INT = YEAR(GETDATE());


       -- OBTENER DATOS BASE DE TODAS LAS FACTURAS QUE CAZAN EN EL ANIO ACTUAL.
       SELECT 
              OINV.DocEntry,
              OINV.DocNum,
              OINV.DocDate,
              CASE 
                     WHEN CHARINDEX('-', OINV.U_SNNIT) > 0 THEN REPLACE(OINV.U_SNNIT, '-', '') 
                     ELSE OINV.U_SNNIT
              END AS CleanNIT
       INTO #FacturasDelAnioActualConNitFormateado
       FROM OINV
       WHERE OINV.DocDate >= DATEFROMPARTS(@anioABuscar, 1, 1)
       AND OINV.DocDate <  DATEFROMPARTS(@anioABuscar + 1, 1, 1);


       -- FACTURAS QUE PERTENECEN AL MISMO CLIENTE.
       SELECT F.*
       INTO #FacturasDelNitDelActualComprador
       FROM #FacturasDelAnioActualConNitFormateado F
       INNER JOIN #cte_datos N ON F.CleanNIT = N.Nit;


       -- OBTENER LOS DATOS DE LAS FACTURAS QUE SI APLICAN

       SELECT *
       INTO #cte_datos_facturas_cliente
       FROM (

              /* ==================== BLOQUE 1 – Ventas con entrega ==================== */
              SELECT 
              a.DocNum,
              a.DocEntry,
              a.U_Dist_Isuzu,
              a.SlpCode,
                     CONVERT(char(8), ISNULL(f.U_FechaPlacas, a.DocDate), 112)                       AS FechaTransaccion,
                     CASE WHEN a.U_DoctoSerie = 'CCCJ4' THEN 0 ELSE ag.CodigoSucursal END            AS CodigoSucursal,   
                     'V' AS TipoTransaccion, 
                     UPPER(a.U_DoctoSerie) + '-' + a.U_DoctoNo                                       AS NumeroFactura,    
                     a.DocDate                                                                       AS FechaFactura,     
                     a.DocTotal                                                                      AS MontoTransaccion, 
                     ISNULL(co.MontoEfectivo, 0)                                                     AS MontoEfectivo,    
                     
                     ISNULL((SELECT MAX(U_TipoPersona)        FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry) ,
                            (SELECT MAX(u_tipopersona)        FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS TipoPersona, 
                     ISNULL((SELECT MAX(U_TipoIdentificacion) FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                            (SELECT MAX(u_tipoidentificacion) FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS TipoDocIdentificacion, 
                     ISNULL((SELECT CONVERT(varchar, MAX(U_DocIdent)) FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                            (SELECT MAX(VatIdUnCmp)                    FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS DPI , 
                     UPPER(REPLACE(a.U_SNNIT, '-', '')) AS NIT, 
                     ISNULL((SELECT MAX(U_Nacionalidad)     FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                            (SELECT MAX(u_nacionalidad)     FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS Nacionalidad, 
                     ISNULL((SELECT CONVERT(char, MAX(U_FechaNacimiento), 112) FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                            (SELECT CONVERT(char, MAX(u_FechaNacimiento), 112) FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS FechaNacimiento, 
                     ISNULL((SELECT MAX(U_PrimerNombre)     FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry  AND a.U_PrimerNombre  <> ''),
                            (SELECT MAX(u_PrimerNombre)     FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND u_PrimerNombre     <> '')) AS PrimerNombre, 
                     ISNULL((SELECT MAX(U_SegundoNombre)    FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry  AND a.U_SegundoNombre <> ''),
                            (SELECT MAX(u_SegundoNombre)    FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND u_SegundoNombre    <> '')) AS SegundoNombre, 
                     ISNULL((SELECT MAX(U_PrimerApellido)   FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry  AND a.U_PrimerApellido <> ''),
                            (SELECT MAX(u_PrimerApellido)   FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND u_PrimerApellido   <> '')) AS PrimerApellido, 
                     ISNULL((SELECT MAX(U_SegundoApellido)  FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry  AND a.U_SegundoApellido <> ''),
                            (SELECT MAX(u_SegundoApellido)  FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND u_SegundoApellido  <> '')) AS SegundoApellido, 
                     COALESCE((SELECT TOP 1 U_ApellidoCasada FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry AND U_ApellidoCasada <> ''),
                            (SELECT TOP 1 U_ApellidoCasada FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND U_ApellidoCasada <> '')) AS ApellidoCasada, 
                     a.U_SNNombre AS ClienteReal, 
                     ISNULL(CASE WHEN ISNULL((SELECT MAX(u_tipopersona) FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode), '.') = 'J'
                                   THEN a.CardName END,
                            (SELECT CardName FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry
                                   AND (SELECT U_TipoPersona FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry) = 'J')) AS PersonaJuridica, 
                     /* ---- Datos del vehículo ---- */
                     CASE WHEN f.U_Estado = '0' THEN 'NUEVO' ELSE 'USADO' END                                               AS Estado, 
                     f.U_TipoVehiculo AS TipoVehiculo,             
                     f.U_DetTipoVehiculo AS DetalleTipoVehiculo,          
                     f.U_Marca AS Marca,                    
                     UPPER(SUBSTRING(d.ItemCode, 1, 20))                              AS Linea, 
                     d.ItemName                                                       AS DescripcionVehiculo, 
                     f.U_UsoVehiculo AS UsoDelVehiculo,            
                     f.U_Placa AS NoPlaca,                  
                     f.U_Color AS Color,                  
                     f.U_Modelo AS Modelo,                 
                     UPPER(f.DistNumber)         AS NoSerie
              FROM  OINV        a WITH (NOLOCK)
              JOIN #FacturasDelNitDelActualComprador  ON #FacturasDelNitDelActualComprador.DocNum = a.DocNum
              JOIN  INV1        c WITH (NOLOCK) ON c.DocEntry = a.DocEntry
              JOIN  DLN1        e WITH (NOLOCK) ON e.ObjType  = c.BaseType
                                                 AND e.DocEntry = c.BaseEntry
                                                 AND e.LineNum  = c.BaseLine
              JOIN  SRI1_LINK2  f WITH (NOLOCK) ON f.BaseType  = e.ObjType
                                                 AND f.BaseEntry = e.DocEntry
                                                 AND f.BaseLinNum= e.LineNum
                                                 AND f.ItemCode  = c.ItemCode
              JOIN  OITM        d WITH (NOLOCK) ON d.ItemCode = c.ItemCode
              LEFT JOIN #cobros  co ON co.DocNum = a.ReceiptNum
              LEFT JOIN #agencias ag ON ag.PrcCode = c.OcrCode
              WHERE  (   d.ItmsGrpCod IN (118,119,149,148,120,133,151,150,236,290,291,310)
                     OR (d.ItemName LIKE '%ACUATICA%' AND d.ItmsGrpCod = 148) )
              AND c.BaseType IN ('15','-1','17')
              AND c.TargetType <> 14
              AND NOT EXISTS (SELECT 1 FROM ORIN r WITH (NOLOCK)
                                   WHERE r.U_FE_MP_DocVin = a.DocNum
                                   AND r.DocTotal       = a.DocTotal)

              /* ==================== BLOQUE 2 – Ventas sin entrega ==================== */
              UNION ALL
              SELECT 
                     a.DocNum,
                     a.DocEntry,
                     a.U_Dist_Isuzu,
                     a.SlpCode,
                     CONVERT(char(8), ISNULL(f.U_FechaPlacas, a.DocDate), 112) AS FechaTransaccion, 
                     CASE WHEN a.U_DoctoSerie = 'CCCJ4' THEN 0 ELSE ag.CodigoSucursal END AS CodigoSucursal, 
                     'V' AS TipoTransaccion, 
                     UPPER(a.U_DoctoSerie) + '-' + a.U_DoctoNo AS NumeroFactura, 
                     a.DocDate AS FechaFactura , 
                     a.DocTotal AS MontoTransaccion,  
                     ISNULL(co.MontoEfectivo, 0) AS MontoEfectivo, 
                     /* —— datos personales (idénticos al bloque‑1) —— */
                     ISNULL((SELECT MAX(U_TipoPersona)        FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                            (SELECT MAX(u_tipopersona)        FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS TipoPersona, 
                     ISNULL((SELECT MAX(U_TipoIdentificacion) FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                            (SELECT MAX(u_tipoidentificacion) FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS TipoDocIdentificacion, 
                     ISNULL((SELECT CONVERT(varchar, MAX(U_DocIdent)) FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                            (SELECT MAX(VatIdUnCmp)                    FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode))  AS DPI, 
                     UPPER(REPLACE(a.U_SNNIT, '-', '')) AS NIT, 
                     ISNULL((SELECT MAX(U_Nacionalidad)     FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                            (SELECT MAX(u_nacionalidad)     FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS Nacionalidad, 
                     ISNULL((SELECT CONVERT(char, MAX(U_FechaNacimiento), 112) FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                            (SELECT CONVERT(char, MAX(u_FechaNacimiento), 112) FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS FechaNacimiento, 
                     ISNULL((SELECT MAX(U_PrimerNombre)     FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry  AND a.U_PrimerNombre  <> ''),
                            (SELECT MAX(u_PrimerNombre)     FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND u_PrimerNombre     <> '')) AS PrimerNombre, 
                     ISNULL((SELECT MAX(U_SegundoNombre)    FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry  AND a.U_SegundoNombre <> ''),
                            (SELECT MAX(u_SegundoNombre)    FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND u_SegundoNombre    <> '')) AS SegundoNombre, 
                     ISNULL((SELECT MAX(U_PrimerApellido)   FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry  AND a.U_PrimerApellido <> ''),
                            (SELECT MAX(u_PrimerApellido)   FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND u_PrimerApellido   <> '')) AS PrimerApellido, 
                     ISNULL((SELECT MAX(U_SegundoApellido)  FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry  AND a.U_SegundoApellido <> ''),
                            (SELECT MAX(u_SegundoApellido)  FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND u_SegundoApellido  <> '')) AS SegundoApellido, 
                     COALESCE((SELECT TOP 1 U_ApellidoCasada FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry AND U_ApellidoCasada <> ''),
                            (SELECT TOP 1 U_ApellidoCasada FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND U_ApellidoCasada <> '')) AS ApellidoCasada, 
                     a.U_SNNombre AS ClienteReal, 
                     ISNULL(CASE WHEN ISNULL((SELECT MAX(u_tipopersona) FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode), '.') = 'J'
                                   THEN a.CardName END,
                            (SELECT CardName FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry
                                   AND (SELECT U_TipoPersona FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry) = 'J')) AS PersonaJuridica, 
                     CASE WHEN f.U_Estado = '0' THEN 'NUEVO' ELSE 'USADO' END AS Estado, 
                     f.U_TipoVehiculo AS TipoVehiculo, 
                     f.U_DetTipoVehiculo AS DetalleTipoVehiculo, 
                     f.U_Marca AS Marca, 
                     UPPER(SUBSTRING(d.ItemCode, 1, 20)) AS Linea, 
                     d.ItemName AS DescripcionVehiculo, 
                     f.U_UsoVehiculo AS UsoDelVehiculo, 
                     f.U_Placa AS NoPlaca, 
                     f.U_Color AS Color, 
                     f.U_Modelo AS Modelo, 
                     UPPER(f.DistNumber) AS NoSerie
              FROM  OINV        a WITH (NOLOCK)
              JOIN #FacturasDelNitDelActualComprador  ON #FacturasDelNitDelActualComprador.DocNum = a.DocNum
              JOIN  INV1        c WITH (NOLOCK) ON c.DocEntry = a.DocEntry
              JOIN  SRI1_LINK2  f WITH (NOLOCK) ON f.BaseType   = c.ObjType
                                                 AND f.BaseEntry  = c.DocEntry
                                                 AND f.BaseLinNum = c.LineNum
                                                 AND f.ItemCode   = c.ItemCode
              JOIN  OITM        d WITH (NOLOCK) ON d.ItemCode = c.ItemCode
              LEFT JOIN #cobros  co ON co.DocNum = a.ReceiptNum
              LEFT JOIN #agencias ag ON ag.PrcCode = c.OcrCode
              WHERE 
              d.ItmsGrpCod IN (118,119,149,148,120,133,151,150,236,290,291,310)
              AND c.BaseType IN ('-1','17','171')
              AND c.TargetType <> 14
              AND NOT EXISTS (SELECT 1 FROM ORIN r WITH (NOLOCK)
                                   WHERE r.U_FE_MP_DocVin = a.DocNum
                                   AND r.DocTotal       = a.DocTotal)

              /* ==================== BLOQUE 3 – Vehículos usados (sin serie) ============ */
              UNION ALL
              SELECT 
                     a.DocNum,
                     a.DocEntry,
                     a.U_Dist_Isuzu,
                     a.SlpCode,
                     CONVERT(char(8), a.DocDate, 112) AS FechaTransaccion, 
                     CASE WHEN a.U_DoctoSerie = 'CCCJ4' THEN 0 ELSE ag.CodigoSucursal END AS CodigoSucursal, 
                     'V' AS TipoTransaccion, 
                     UPPER(a.U_DoctoSerie) + '-' + a.U_DoctoNo AS NumeroFactura, 
                     a.DocDate AS FechaFactura , 
                     a.DocTotal AS MontoTransaccion,  
                     ISNULL(co.MontoEfectivo, 0) AS MontoEfectivo, 
                     ISNULL((SELECT MAX(U_TipoPersona)        FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                            (SELECT MAX(u_tipopersona)        FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS TipoPersona, 
                     ISNULL((SELECT MAX(U_TipoIdentificacion) FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                            (SELECT MAX(u_tipoidentificacion) FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS TipoDocIdentificacion, 
                     ISNULL((SELECT CONVERT(varchar, MAX(U_DocIdent)) FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                            (SELECT MAX(VatIdUnCmp)                    FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode))  AS DPI, 
                     UPPER(REPLACE(a.U_SNNIT, '-', '')) AS NIT, 
                     ISNULL((SELECT MAX(U_Nacionalidad)     FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                            (SELECT MAX(u_nacionalidad)     FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS Nacionalidad, 
                     ISNULL((SELECT CONVERT(char, MAX(U_FechaNacimiento), 112) FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry),
                            (SELECT CONVERT(char, MAX(u_FechaNacimiento), 112) FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode)) AS FechaNacimiento, 
                     ISNULL((SELECT MAX(U_PrimerNombre)     FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry  AND a.U_PrimerNombre  <> ''),
                            (SELECT MAX(u_PrimerNombre)     FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND u_PrimerNombre     <> '')) AS PrimerNombre, 
                     ISNULL((SELECT MAX(U_SegundoNombre)    FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry  AND a.U_SegundoNombre <> ''),
                            (SELECT MAX(u_SegundoNombre)    FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND u_SegundoNombre    <> '')) AS SegundoNombre, 
                     ISNULL((SELECT MAX(U_PrimerApellido)   FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry  AND a.U_PrimerApellido <> ''),
                            (SELECT MAX(u_PrimerApellido)   FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND u_PrimerApellido   <> '')) AS PrimerApellido, 
                     ISNULL((SELECT MAX(U_SegundoApellido)  FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry  AND a.U_SegundoApellido <> ''),
                            (SELECT MAX(u_SegundoApellido)  FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND u_SegundoApellido  <> '')) AS SegundoApellido, 
                     COALESCE((SELECT TOP 1 U_ApellidoCasada FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry AND U_ApellidoCasada <> ''),
                            (SELECT TOP 1 U_ApellidoCasada FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode AND U_ApellidoCasada <> '')) AS ApellidoCasada, 
                     a.U_SNNombre AS ClienteReal, 
                     ISNULL(CASE WHEN ISNULL((SELECT MAX(u_tipopersona) FROM OCRD WITH (NOLOCK) WHERE CardCode = a.CardCode), '.') = 'J'
                                   THEN a.CardName END,
                            (SELECT CardName FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry
                                   AND (SELECT U_TipoPersona FROM OINV WITH (NOLOCK) WHERE DocEntry = a.DocEntry) = 'J')) AS PersonaJuridica, 
                     'USADO' AS Estado, 
                     CASE WHEN d.ItmsGrpCod IN (118,119,146,147,149,150,220,221,236) THEN 'T' ELSE 'M' END AS TipoVehiculo, 
                     '' AS DetalleTipoVehiculo, 
                     '' AS Marca,   -- Marca
                     UPPER(SUBSTRING(d.ItemCode, 1, 20)) AS Linea, 
                     '' AS DescripcionVehiculo,   -- Descripción
                     '' AS UsoDelVehiculo,   -- Uso
                     '' AS NoPlaca,   -- Placa
                     '' AS Color,   -- Color
                     '' AS Modelo,   -- Modelo
                     '' AS NoSerie
              FROM  OINV        a WITH (NOLOCK)
              JOIN #FacturasDelNitDelActualComprador  ON #FacturasDelNitDelActualComprador.DocNum = a.DocNum
              JOIN  INV1        c WITH (NOLOCK) ON c.DocEntry = a.DocEntry
              JOIN  OITM        d WITH (NOLOCK) ON d.ItemCode = c.ItemCode
              LEFT JOIN #cobros  co ON co.DocNum = a.ReceiptNum
              LEFT JOIN #agencias ag ON ag.PrcCode = c.OcrCode
              WHERE
              d.ItmsGrpCod IN (221, 220)
              AND NOT EXISTS (SELECT 1 FROM ORIN r WITH (NOLOCK)
                                   WHERE r.U_FE_MP_DocVin = a.DocNum
                                   AND r.DocTotal       = a.DocTotal)


              /* ==================== BLOQUE 4 – MAQUINARIA ============ */
              UNION ALL
              SELECT 
                     a.DocNum,
                     a.DocEntry,
                     a.U_Dist_Isuzu,
                     a.SlpCode,
                     -- Fecha de transacción: U_FechaPlacas si existe, sino DocDate
                     CASE 
                     WHEN f.U_Fechaplacas IS NULL THEN 
                     
                            CASE 
                            WHEN p.U_FechaEntrega IS NOT NULL THEN CONVERT(CHAR(8), p.U_FechaEntrega, 112)
                            WHEN m.U_FechaEntrega IS NOT NULL THEN CONVERT(CHAR(8), m.U_FechaEntrega, 112)
                            END
                            
                     ELSE CONVERT(CHAR, f.U_Fechaplacas, 112)
                     END AS FechaTransaccion, 

                     -- Código de sucursal
                     CASE 
                     WHEN a.U_DoctoSerie = 'CCCJ4' THEN 0
                     ELSE (SELECT MAX(u_codigoagencia) FROM OPRC (NOLOCK) WHERE prccode = c.ocrcode)
                     END AS CodigoSucursal, 

                     'V' AS TipoTransaccion, 
                     UPPER(a.U_DoctoSerie) + '-' + a.U_DoctoNo AS NumeroFactura, 
                     a.DocDate AS FechaFactura, 
                     a.DocTotal AS MontoTransaccion, 

                     ISNULL((SELECT MAX(cashsum) FROM ORCT (NOLOCK) WHERE docnum = a.receiptnum AND canceled = 'N'), 0) AS MontoEfectivo, 

                     ISNULL((SELECT MAX(U_TipoPersona) FROM OINV WHERE DocEntry = a.DocEntry),
                            (SELECT MAX(u_tipopersona) FROM OCRD WHERE CardCode = a.CardCode)) AS TipoPersona, 

                     ISNULL((SELECT MAX(U_tipoIdentificacion) FROM OINV WHERE DocEntry = a.DocEntry),
                            (SELECT MAX(u_tipoidentificacion) FROM OCRD WHERE CardCode = a.CardCode)) AS TipoDocIdentificacion, 

                     ISNULL((SELECT MAX(U_DocIdent) FROM OINV WHERE DocEntry = a.DocEntry),
                            (SELECT MAX(VatIdUnCmp) FROM OCRD WHERE CardCode = a.CardCode)) AS DPI, 

                     UPPER(REPLACE(a.U_SNNIT, '-', '')) AS NIT, 

                     ISNULL((SELECT MAX(U_Nacionalidad) FROM OINV WHERE DocEntry = a.DocEntry),
                            (SELECT MAX(u_nacionalidad) FROM OCRD WHERE CardCode = a.CardCode)) AS Nacionalidad, 

                     ISNULL(CONVERT(CHAR, (SELECT MAX(U_FechaNacimiento) FROM OINV WHERE DocEntry = a.DocEntry), 112),
                            CONVERT(CHAR, (SELECT MAX(u_fechanacimiento) FROM OCRD WHERE CardCode = a.CardCode), 112)) AS FechaNacimiento, 

                     -- Nombres y apellidos
                     ISNULL(NULLIF((SELECT MAX(U_PrimerNombre) FROM OINV WHERE DocEntry = a.DocEntry), ''), 
                            (SELECT MAX(U_PrimerNombre) FROM OCRD WHERE CardCode = a.CardCode)) AS PrimerNombre, 

                     ISNULL(NULLIF((SELECT MAX(U_SegundoNombre) FROM OINV WHERE DocEntry = a.DocEntry), ''), 
                            (SELECT MAX(U_SegundoNombre) FROM OCRD WHERE CardCode = a.CardCode)) AS SegundoNombre, 

                     ISNULL(NULLIF((SELECT MAX(U_PrimerApellido) FROM OINV WHERE DocEntry = a.DocEntry), ''), 
                            (SELECT MAX(U_PrimerApellido) FROM OCRD WHERE CardCode = a.CardCode)) AS PrimerApellido, 

                     ISNULL(NULLIF((SELECT MAX(U_SegundoApellido) FROM OINV WHERE DocEntry = a.DocEntry), ''), 
                            (SELECT MAX(U_SegundoApellido) FROM OCRD WHERE CardCode = a.CardCode)) AS SegundoApellido, 

                     -- Apellido casada
                     COALESCE(
                     (SELECT TOP 1 U_ApellidoCasada FROM OINV WHERE DocEntry = a.DocEntry AND U_ApellidoCasada <> ''),
                     (SELECT TOP 1 U_ApellidoCasada FROM OCRD WHERE CardCode = a.CardCode AND U_ApellidoCasada <> '')
                     ) AS ApellidoCasada, 

                     a.U_SNNombre AS ClienteReal, 

                     CASE 
                     WHEN ISNULL((SELECT MAX(u_tipopersona) FROM OCRD WHERE CardCode = a.CardCode), '.') = 'J' THEN a.CardName
                     ELSE NULL
                     END AS PersonaJuridica, 

                     -- Estado, Tipo y Detalle
                     CASE WHEN f.U_Estado = '0' THEN 'NUEVO' ELSE 'USADO' END AS Estado, 
                     f.U_TipoVehiculo AS TipoVehiculo, 
                     f.U_DetTipoVehiculo AS DetalleTipoVehiculo, 

                     -- Marca traducida
                     f.u_marca AS Marca, 

                     UPPER(SUBSTRING(d.ItemCode, 1, 20)) AS Linea, 
                     d.ItemName AS DescripcionVehiculo, 
                     f.U_UsoVehiculo AS UsoDelVehiculo, 
                     f.U_Placa AS NoPlaca, 
                     f.U_Color AS Color, 
                     f.U_Modelo AS Modelo, 
                     UPPER(f.DistNumber) AS NoSerie

              

              FROM OINV a
              JOIN #FacturasDelNitDelActualComprador  ON #FacturasDelNitDelActualComprador.DocNum = a.DocNum
              INNER JOIN INV1 c ON a.DocEntry = c.DocEntry
              INNER JOIN OITM d ON c.ItemCode = d.ItemCode
              INNER JOIN SRI1_LINK2 f ON f.BaseEntry = c.DocEntry OR f.BaseEntry = c.BaseEntry AND f.ItemCode = c.ItemCode AND f.BaseLinNum = c.LineNum
                     

              OUTER APPLY (
                     SELECT TOP 1 U_FechaEntrega
                     FROM [@PASENH]
                     WHERE U_Vin = f.DistNumber
                     ORDER BY UpdateDate DESC
              ) p

              OUTER APPLY (
                     SELECT TOP 1 U_FechaEntrega
                     FROM [@PASEMAQCONS]
                     WHERE U_Chasis = f.DistNumber
                     ORDER BY UpdateDate DESC
              ) m

              -- Fechas válidas: si no hay placas, usamos DocDate
              WHERE
                     f.u_marca IN ('4', '5') 
                     AND d.ItmsGrpCod IN (146, 243, 242, 281)
                     AND c.BaseType IN ('15', '-1', '17')
                     AND c.TargetType <> 14
                     AND NOT EXISTS (
                     SELECT 1 FROM ORIN WHERE U_FE_MP_DocVin = a.DocNum AND DocTotal = a.DocTotal
                     )

              ) AS cte_registros_filtrados_por_nit;



       /*
       ===================================================
       ||| CLASIFICACION EN BASE A CANTIDAD DE COMPRAS |||
       ===================================================
       */

       ------------------------------------------------------------------
       -- 1 - Datos base reutilizables
       ------------------------------------------------------------------
       SELECT  NIT,
              NumeroFactura,
              FORMAT(FechaFactura,'yyyyMM') AS AnioMes
       INTO    #Base
       FROM    #cte_datos_facturas_cliente
       WHERE   NIT IS NOT NULL;         

       ----------------------------------------------------------------
       -- Paso 2 ▸ Facturas con 2 o + vehículos  →  Regla 1
       ----------------------------------------------------------------
       SELECT  NIT
       INTO    #MultiFactura
       FROM    #Base
       GROUP BY NIT, NumeroFactura
       HAVING  COUNT(*) > 1;             -- varias filas = varios vehículos

       ----------------------------------------------------------------
       -- Paso 3 ▸ ¿Cuántos meses distintos tiene cada NIT?
       ----------------------------------------------------------------
       SELECT  NIT,
              COUNT(DISTINCT AnioMes) AS MesesDistintos
       INTO    #MesesComprados
       FROM    #Base
       GROUP BY NIT;

       ----------------------------------------------------------------
       -- Paso 4 ▸ Total de vehículos en el año por NIT
       ----------------------------------------------------------------
       SELECT  NIT,
              COUNT(*) AS TotalVehiculos
       INTO    #TotalVehiculos
       FROM    #Base
       GROUP BY NIT;


       ------------------------------------------------------------------
       -- Paso 5 - Total de facturas (transacciones) por NIT
       ------------------------------------------------------------------
       SELECT  NIT,
              COUNT(DISTINCT NumeroFactura) AS TotalTransacciones
       INTO    #TotalTransacciones
       FROM    #Base
       GROUP BY NIT;

       ----------------------------------------------------------------
       -- Paso 6 - Clasificación final (una sola por NIT)
       ----------------------------------------------------------------
       ;WITH Base AS (
       SELECT DISTINCT NIT FROM #Base
       ),
       Q AS (
              SELECT
              p.NIT,
              CASE
              WHEN EXISTS (SELECT 1 FROM #NitEntidadesEmbajadasConsulados e
                            WHERE e.NitEEC = p.NIT COLLATE SQL_Latin1_General_CP1_CI_AS)
                     THEN 'EMBAJADAS, CONSULADOS U ORGANISMOS INTERNACIONALES.'
              WHEN EXISTS (SELECT 1 FROM #NitEntidadesDelEstado e
                            WHERE e.NitEDE = p.NIT COLLATE SQL_Latin1_General_CP1_CI_AS)
                     THEN 'ENTIDADES DEL ESTADO (MINISTERIOS, SECRETARÍAS, MUNICIPALIDADES, OTRAS)'
              WHEN EXISTS (SELECT 1 FROM #NitOrganizacionesSFL s
                            WHERE s.NitSFL = p.NIT COLLATE SQL_Latin1_General_CP1_CI_AS)
                     THEN 'ORGANIZACIONES SIN FINES DE LUCRO (ASOCIACIONES, FUNDACIONES, ONG´S, ENTRE OTRAS)'
              WHEN EXISTS (SELECT 1 FROM #NitPorMandatarios m
                            WHERE m.NitMandatario = p.NIT COLLATE SQL_Latin1_General_CP1_CI_AS)
                     THEN 'POR MEDIO DE MANDATARIOS (SIN VÍNCULO FAMILIAR)'
              WHEN EXISTS (SELECT 1 FROM #NitPPFCT t
                            WHERE t.NITPPFT = p.NIT COLLATE SQL_Latin1_General_CP1_CI_AS)
                     THEN 'POR MEDIO DE TERCEROS (PADRE, HIJO, CÓNYUGE, HERMANO, ETC.)'
              WHEN EXISTS (SELECT 1 FROM #NitPersonasPEP pe
                            WHERE pe.NitPEP = p.NIT COLLATE SQL_Latin1_General_CP1_CI_AS)
                     THEN 'PERSONAS EXPUESTAS POLÍTICAMENTE (PARIENTES Y ASOCIADOS PEP)'
              WHEN EXISTS (SELECT 1 FROM #NitEmpleados ne
                            WHERE ne.NitEmpleado = p.NIT COLLATE SQL_Latin1_General_CP1_CI_AS)
                     THEN 'EMPLEADOS'
              WHEN EXISTS (SELECT 1 FROM #MultiFactura mf
                            WHERE mf.NIT = p.NIT)
                     THEN 'HABITUALES (VARIOS VEHÍCULOS)'
              WHEN EXISTS (SELECT 1 FROM #MesesComprados mc
                            WHERE mc.NIT = p.NIT AND mc.MesesDistintos > 1)
                     THEN 'HABITUALES (UN VEHÍCULO)'
              WHEN EXISTS (SELECT 1 FROM #TotalVehiculos tv
                            WHERE tv.NIT = p.NIT AND tv.TotalVehiculos = 1)
                     THEN 'OCASIONALES'
              ELSE 'HABITUALES (UN VEHÍCULO)'
              END AS Clasificacion_Experiencia_Comercial,
              1 AS TotalTransacciones
              FROM Base p
       )
       SELECT
              Q.NIT,
              Q.Clasificacion_Experiencia_Comercial,
              CC.CantidadClientes,
              Q.TotalTransacciones
       INTO #Clasificacion_Experiencia_Comercial_tabla
       FROM Q
       CROSS JOIN (
       SELECT COUNT(*) AS CantidadClientes
       FROM (SELECT DISTINCT NIT FROM #Base) d
       ) CC
       ORDER BY Q.NIT;
       
       

       INSERT INTO #ValoresParaCalificacionDeFactura
       SELECT
              R.Segmento,
              R.ITEM,
              R.NIVEL_RIESGO_LDFT
       FROM #Clasificacion_Experiencia_Comercial_tabla C
       JOIN #ValoresRiesgoSegmentacion R
       ON LTRIM(RTRIM(C.Clasificacion_Experiencia_Comercial)) COLLATE Latin1_General_100_CI_AI
              = LTRIM(RTRIM(R.ITEM)) COLLATE Latin1_General_100_CI_AI
       WHERE R.NO_ITEM NOT IN ( 1, 2, 3 )
              AND R.Segmento = 'OTRAS VARIABLES DE CLIENTES';

       /*
       ==========================================================================================================================================
       |||                                                            VENTAS POR CANALES DE DISTRIBUCION                                      |||
       ==========================================================================================================================================
       */

       SELECT 
              *
       INTO #DetallesDeFacturasINV1
       FROM(
              SELECT
                     T1.DocEntry,
                     T1.OcrCode
              FROM INV1 T1
              JOIN #FacturasDelAnioActualConNitFormateado T0 ON T0.DocEntry = T1.DocEntry
       ) AS detallesDacturasTmp;


       SELECT 
              Clasificacion_Canales_Distribucion,
              SUM(TotalClientes)  AS TotalClientes,
              SUM(TotalFacturas)  AS TotalFacturas
       INTO #canales_distribucion
       FROM (
              ----------------------------------------------------------------
              -- YAMAHA
              ----------------------------------------------------------------
              

                     -- EL CENTRO DE COSTO CON CODIGO 1104 ES EL CODIGO QUE USAN LOS DISTRIBUIDORES

                     SELECT
                            r.Clasificacion_Canales_Distribucion,
                            COUNT(DISTINCT a.NIT) AS TotalClientes,
                            --COUNT(DISTINCT a.DocEntry) AS TotalFacturas -- ESTO SERVIRA EN EL MASIVO
                            1 AS TotalFacturas -- Esto queda dado que solo se esta evaluando la factura actual.
                     FROM #cte_datos_facturas_cliente a
                     JOIN (
                            SELECT
                                   DocEntry,
                                   CASE WHEN MAX(CASE WHEN OcrCode = '1104' THEN 1 ELSE 0 END) = 1
                                          THEN 'DISTRIBUIDORES'
                                          ELSE 'AGENCIAS PROPIAS (EMPLEADOS)'
                                   END AS Clasificacion_Canales_Distribucion
                            FROM #DetallesDeFacturasINV1
                            GROUP BY DocEntry
                     ) r
                     ON r.DocEntry = a.DocEntry
                     WHERE 
                            a.Marca = '1'
                            AND SlpCode NOT IN (
                                   '209',
                                   '122',
                                   '353',
                                   '369'              
                            )
                     GROUP BY r.Clasificacion_Canales_Distribucion, a.NIT


              ----------------------------------------------------------------
              -- MAQUINARIA = NEW HOLLAND Y HYUNDAI
              ----------------------------------------------------------------
              UNION ALL
                     SELECT
                            r.Clasificacion_Canales_Distribucion,
                            COUNT(DISTINCT a.NIT) AS TotalClientes,
                            --COUNT(DISTINCT a.DocEntry) AS TotalFacturas -- ESTO SERVIRA EN EL MASIVO
                            1 AS TotalFacturas -- Esto queda dado que solo se esta evaluando la factura actual.
                     FROM #cte_datos_facturas_cliente a
                     JOIN (
                            SELECT
                                   DocEntry,
                                   'AGENCIAS PROPIAS (EMPLEADOS)' AS Clasificacion_Canales_Distribucion
                            FROM #DetallesDeFacturasINV1
                            GROUP BY DocEntry
                     ) r
                     ON r.DocEntry = a.DocEntry
                     WHERE 
                            a.Marca IN ('4','5')
                            AND SlpCode NOT IN (
                                   '209',
                                   '122',
                                   '353',
                                   '369'              
                            )       
                     GROUP BY r.Clasificacion_Canales_Distribucion, a.NIT


              ----------------------------------------------------------------
              -- ISUZU / DFSK
              ----------------------------------------------------------------
              UNION ALL
                     SELECT
                            v.Clasificacion_Canales_Distribucion,
                            COUNT(DISTINCT a.NIT)       AS TotalClientes,
                            --COUNT(DISTINCT a.DocEntry) AS TotalFacturas -- ESTO SERVIRA EN EL MASIVO
                            1 AS TotalFacturas -- Esto queda dado que solo se esta evaluando la factura actual.
                     FROM 
                            #cte_datos_facturas_cliente AS a
                     CROSS APPLY (VALUES (
                            CASE WHEN NULLIF(LTRIM(RTRIM(a.U_Dist_Isuzu)), '') IS NOT NULL
                                   THEN 'DISTRIBUIDORES' ELSE 'AGENCIAS PROPIAS (EMPLEADOS)' END
                     )) AS v(Clasificacion_Canales_Distribucion)
                     WHERE 
                            a.Marca IN ('0','6')
                            AND SlpCode NOT IN (
                                   '209',
                                   '122',
                                   '353',
                                   '369'
                            )
                     GROUP BY 
                            v.Clasificacion_Canales_Distribucion

              ----------------------------------------------------------------
              -- ATENCION CORPORATIVA GERENCIA
              ----------------------------------------------------------------
              UNION ALL
                     SELECT
                            v.Clasificacion_Canales_Distribucion,
                            COUNT(DISTINCT a.NIT)       AS TotalClientes,
                            --COUNT(DISTINCT a.DocEntry) AS TotalFacturas -- ESTO SERVIRA EN EL MASIVO
                            1 AS TotalFacturas -- Esto queda dado que solo se esta evaluando la factura actual.
                     FROM 
                            #cte_datos_facturas_cliente AS a
                     CROSS APPLY (VALUES (
                            'Atención Corporativa (Gerencia)'
                     )) AS v(Clasificacion_Canales_Distribucion)
                     WHERE 
                            SlpCode IN (
                                   '209',
                                   '122',
                                   '353',
                                   '369'
                            )
                     GROUP BY 
                            v.Clasificacion_Canales_Distribucion
              
       ) x
       GROUP BY Clasificacion_Canales_Distribucion;


       INSERT INTO #ValoresParaCalificacionDeFactura
       SELECT
              R.Segmento,
              R.ITEM,
              R.NIVEL_RIESGO_LDFT
       FROM #canales_distribucion C
       JOIN #ValoresRiesgoSegmentacion R
       ON LTRIM(RTRIM(C.Clasificacion_Canales_Distribucion)) COLLATE Latin1_General_100_CI_AI
              = LTRIM(RTRIM(R.ITEM)) COLLATE Latin1_General_100_CI_AI
       WHERE R.Segmento = 'CANAL DE DISTRIBUCIÓN';

       /*
       ==========================================================================================================================================
       |||                                                            VENTAS POR UBICACION GEOGRAFICA NACIONAL                                |||
       ==========================================================================================================================================
       */

       SELECT *
       INTO #DetallesDepartamentoMunicipioPorCentroCosto
       FROM(
              SELECT
                     P.PrcCode        AS CodigoCentroCosto,
                     P.U_CodigoAgencia,
                     A.U_Departamento AS Departamento,
                     A.U_Municipio    AS Municipio
              FROM OPRC AS P
              INNER JOIN [@CODAGENCIAIVE] AS A
                     ON LTRIM(RTRIM(A.U_codigo)) = LTRIM(RTRIM(P.U_CodigoAgencia))
              WHERE 
                     ISNULL(P.Active, 'Y') = 'Y'
       ) as tmp;
       

       --centroCosto
       WITH CC_Factura AS (
       SELECT
              i.DocNum,
              i.DocEntry,
              i.Nit,
              MIN(CAST(l.OcrCode AS varchar(50))) AS CodigoCentroCosto,  -- CentroCosto de la factura
              COUNT(DISTINCT l.OcrCode)           AS CCs_Distintos_Fact   -- Diagnóstico (debería ser 1)
       FROM #cte_datos i
       INNER JOIN INV1 l
              ON l.DocEntry = i.DocEntry
       GROUP BY i.DocNum, i.DocEntry, i.Nit
       )

      
       SELECT
              COALESCE(m.Departamento, 'SIN_MAPEO_DEPARTAMENTO') AS Departamento,
              COALESCE(m.Municipio,    'SIN_MAPEO_MUNICIPIO') AS Municipio,
              COUNT(DISTINCT b.Nit)     AS TotalClientes,   -- NITs diferentes
              COUNT(DISTINCT b.DocNum)              AS TotalTransacciones   -- Facturas diferentes
       INTO #ventas_ubicacion_geografica_nacional
       FROM CC_Factura b
       LEFT JOIN #DetallesDepartamentoMunicipioPorCentroCosto m
              ON m.CodigoCentroCosto = b.CodigoCentroCosto
       GROUP BY
              COALESCE(m.Departamento, 'SIN_MAPEO_DEPARTAMENTO'),
              COALESCE(m.Municipio,    'SIN_MAPEO_MUNICIPIO');


       INSERT INTO #ValoresParaCalificacionDeFactura
       SELECT 
              R.Segmento,
              R.ITEM,
              R.NIVEL_RIESGO_LDFT
       FROM #ventas_ubicacion_geografica_nacional C
       JOIN #ValoresRiesgoSegmentacion R
       ON     LTRIM(RTRIM( LTRIM(RTRIM(C.Departamento)) + ' - ' +  LTRIM(RTRIM(C.Municipio) ) ) ) COLLATE Latin1_General_100_CI_AI
              = LTRIM(RTRIM(R.ITEM)) COLLATE Latin1_General_100_CI_AI
              
       WHERE R.Segmento = 'DEPARTAMENTAL';


       /*
       ===============================================================================================================================================
       |||                                                            VENTAS POR UBICACION GEOGRAFICA INTERNACIONAL                                |||
       ===============================================================================================================================================
       */


       -- DADO QUE ACTUALMENTE ES A NIVEL INDIVIDUAL SOLO SE DIRA QUE ES UN CLIENTE Y QUE ES UNA TRANSACCION
       SELECT *
       INTO #DetalleVentasUbicacionInternacional
       FROM(
              SELECT
                     COUNT(DISTINCT NIT)    AS TOTAL_CLIENTES_GUATEMALA,
                     COUNT(DISTINCT DocNum) AS TOTAL_TRANSACCIONES_GUATEMALA
              FROM #cte_datos     -- ESTE SOLO EVALUA EL APARTADO ACTUAL
       ) as tmp;
       
       

       INSERT INTO #ValoresParaCalificacionDeFactura
       SELECT
              R.Segmento,
              R.ITEM,
              R.NIVEL_RIESGO_LDFT
       FROM #ValoresRiesgoSegmentacion R
       WHERE R.Segmento = 'INTERNACIONAL' AND R.ITEM_ID = 373; -- EL ID 373 ES EL ID DE NACIONALES



       /*
       ==========================================================================================================================================
       |||                                                            VENTAS AL CONTADO                                                       |||
       ==========================================================================================================================================
       */



       CREATE TABLE #ResultadoPagos (
              NumeroFactura  varchar(100) COLLATE DATABASE_DEFAULT  ,
              ConceptoPago    varchar(50)   ,
              FormaDePago    varchar(50)   ,
              Monto          decimal(19,6)  
       );

              ----------------------------------------------------------------
              -- CREACION DE UTILIDADES PARA ESTE APARTADO
              ----------------------------------------------------------------
              

              CREATE TABLE #DatosDetallesPagoMatriz (
                     TipoDoc                   varchar(20),
                     NumeroFactura             varchar(100) COLLATE DATABASE_DEFAULT,
                     ImporteAplicado           decimal(19,4),
                     numeroPago                int,
                     PagosTotales              int,
                     Canceled                  varchar(20),
                     DocNum                    int,
                     MonedaPR                  varchar(10),
                     FechaContabilizacion      varchar(30), 
                     FechaTransaccion          varchar(30),
                     NombreBanco               varchar(100),
                     NoCuenta                  varchar(50),
                     BoletaDeposito_Cheque     varchar(50),
                     FormaDePago               varchar(50),
                     ValorEfectivo             decimal(19,6),
                     ValorChequesPropios       decimal(19,6),
                     ValorChequesOtrosBancos   decimal(19,6),
                     ValorTransferencia        decimal(19,6),
                     CodigoCliente             varchar(50),
                     NombreCliente             varchar(200),
                     NombreGrupo               varchar(200),
                     MontoTransaccion          decimal(19,6),
                     MonedaTransaccion         varchar(20),
                     u_name                    varchar(50),
                     Estado                    varchar(20),
                     ValidacionTransferencia   decimal(19,6),
                     MontoFinanciamientoExterno      decimal(19,6),
                     MontoEnganche       decimal(19,6),
                     Installmnt                INT

              );



       DECLARE @ListaDocNum NVARCHAR(MAX);       -- LISTADO DE DOCNUM A EVALUAR MANDADO COMO CSV AL SP SECUNDARIO ENCARGADO DE OBTENER LOS DETALLES DE PAGO

       SELECT @ListaDocNum =
       STRING_AGG(CONVERT(NVARCHAR(MAX), d.DocNum), N',')
       FROM (
              SELECT DISTINCT DocNum
              FROM #cte_datos
              WHERE DocNum IS NOT NULL
       ) AS d;

       -- Evitar pasar NULL si no hay datos 
       IF @ListaDocNum IS NULL SET @ListaDocNum = N'';

       INSERT INTO #DatosDetallesPagoMatriz
       EXEC [dbo].[Reporte_DepositosIVE_PorChasisMasivo_Matriz_Riesgo_FI_FE]
              @Listado_De_DocNum_Facturas_A_Evaluar = @ListaDocNum

       IF NOT EXISTS (
              SELECT 
                     1
              FROM 
                     #DatosDetallesPagoMatriz d
              WHERE 
                     d.NumeroFactura = (
                            SELECT 
                                   o.NumAtCard
                            FROM 
                                   OINV o
                            WHERE 
                                   o.DocEntry = @DocEntryBuscado
                     )
       )
       BEGIN

              INSERT INTO #DatosDetallesPagoMatriz (NumeroFactura)
              SELECT 
                     o.NumAtCard
              FROM 
                     OINV o
              WHERE 
                     o.DocEntry = @DocEntryBuscado;
       END

       UPDATE d
       SET 
              d.MontoFinanciamientoExterno = CONVERT(decimal(19,6), o.U_MontoFinan),
              d.MontoEnganche = CONVERT(decimal(19,6), o.U_Enganche),
              d.Installmnt = o.Installmnt
       FROM #DatosDetallesPagoMatriz d
       JOIN OINV o
       ON o.NumAtCard = d.NumeroFactura

              


              /* ====== AGRUPACIÓN Y AJUSTES  ====== */
       ;WITH base AS (
       SELECT
              d.NumeroFactura,
              d.FormaDePago,
              d.PagosTotales,
              d.Installmnt,
              MontoFinanciamientoExterno = COALESCE(d.MontoFinanciamientoExterno, 0),
              MontoEnganche              = COALESCE(d.MontoEnganche, 0),
              d.DocNum,
              -- dd/mm/yyyy a date
              FechaTransaccion = TRY_CONVERT(date, LTRIM(RTRIM(d.FechaTransaccion)), 103),
              -- Monto por renglón según forma de pago
              MontoPago = CASE
              WHEN d.FormaDePago = 'Transferencia'            THEN COALESCE(d.MontoTransaccion, 0)
              WHEN d.FormaDePago IN ('Cheque Propio','Cheque caja propia')
                                                               THEN COALESCE(d.MontoTransaccion, 0)
              WHEN d.FormaDePago = 'Cheque Otros Bancos'      THEN COALESCE(d.MontoTransaccion, 0)
              WHEN d.FormaDePago IN ('Efectivo','Efectivo caja propia')
                                                               THEN COALESCE(d.MontoTransaccion, 0)
              WHEN d.FormaDePago = 'Tarjeta de credito'       THEN COALESCE(d.MontoTransaccion, 0)
              ELSE COALESCE(d.ValorTransferencia, d.ValorChequesPropios,
                            d.ValorChequesOtrosBancos, d.ValorEfectivo, d.MontoTransaccion, 0)
              END
       FROM #DatosDetallesPagoMatriz d
       ),
       -- Elegimos el PRIMER renglón cuyo monto == MontoEnganche (si existe)
       enganche_flag AS (
       SELECT *,
              rn_pref = ROW_NUMBER() OVER (
                            PARTITION BY NumeroFactura
                            ORDER BY
                            CASE WHEN MontoEnganche > 0 AND MontoPago = MontoEnganche THEN 0 ELSE 1 END,
                            FechaTransaccion, DocNum
                            )
       FROM base
       ),
       marcada AS (
       SELECT *,
              EsEnganche = CASE
                            WHEN MontoEnganche > 0 AND MontoPago = MontoEnganche AND rn_pref = 1
                            THEN 1 ELSE 0
                            END
       FROM enganche_flag
       ),
       -- Reglas de agrupación por renglón
       por_agrup AS (
       SELECT
              NumeroFactura,
              Grupo = CASE
                     WHEN Installmnt > 1 AND PagosTotales > 1 AND EsEnganche = 0
                            THEN 'Financiamiento interno'
                     WHEN EsEnganche = 1
                            THEN 'Enganche'
                     ELSE FormaDePago
                     END,
              Monto = MontoPago,
              Installmnt,
              PagosTotales,
              MontoFinanciamientoExterno,
              MontoEnganche,
              FormaOriginal = FormaDePago
       FROM marcada
       ),
       -- Sumas por factura + forma del enganche
       sumas AS (
       SELECT
              NumeroFactura,
              SUM(CASE WHEN Grupo = 'Financiamiento interno'  THEN Monto ELSE 0 END) AS FinInterno,
              SUM(CASE WHEN Grupo = 'Transferencia'           THEN Monto ELSE 0 END) AS Transferencia,
              SUM(CASE WHEN Grupo = 'Cheque Propio'           THEN Monto ELSE 0 END) AS ChequePropio,
              SUM(CASE WHEN Grupo = 'Cheque Otros Bancos'     THEN Monto ELSE 0 END) AS ChequeOtros,
              SUM(CASE WHEN Grupo = 'Cheque caja propia'      THEN Monto ELSE 0 END) AS ChequeCajaPropia,
              SUM(CASE WHEN Grupo = 'Efectivo'                THEN Monto ELSE 0 END) AS Efectivo,
              SUM(CASE WHEN Grupo = 'Efectivo caja propia'    THEN Monto ELSE 0 END) AS EfectivoCajaPropia,
              SUM(CASE WHEN Grupo = 'Tarjeta de credito'      THEN Monto ELSE 0 END) AS TarjetaCredito,
              EngancheDetectado = SUM(CASE WHEN Grupo = 'Enganche' THEN Monto ELSE 0 END),
              MontoFinancExt   = MAX(MontoFinanciamientoExterno),
              MontoEng         = MAX(MontoEnganche),
              MaxInstallmnt    = MAX(Installmnt),
              EngancheFormaDePago = MAX(CASE WHEN Grupo = 'Enganche' THEN FormaOriginal END)
       FROM por_agrup
       GROUP BY NumeroFactura
       ),
       -- Preparación para aplicar financiamiento externo solo si NO hay cuotas (>1)
       ajustes AS (
       SELECT
              s.*,
              TieneCuotas = CASE WHEN s.MaxInstallmnt > 1 THEN 1 ELSE 0 END,
              DestinoExt =
              CASE
                     WHEN s.MontoFinancExt > 0 AND s.MaxInstallmnt <= 1 AND s.Transferencia   >= s.MontoFinancExt THEN 'Transferencia'
                     WHEN s.MontoFinancExt > 0 AND s.MaxInstallmnt <= 1 AND s.ChequePropio    >= s.MontoFinancExt THEN 'Cheque Propio'
                     WHEN s.MontoFinancExt > 0 AND s.MaxInstallmnt <= 1 AND s.ChequeOtros     >= s.MontoFinancExt THEN 'Cheque Otros Bancos'
                     WHEN s.MontoFinancExt > 0 AND s.MaxInstallmnt <= 1 AND s.ChequeCajaPropia>= s.MontoFinancExt THEN 'Cheque caja propia'
                     ELSE NULL
              END,
              MontoFinancExtEff = CASE WHEN s.MaxInstallmnt <= 1 THEN s.MontoFinancExt ELSE 0 END
       FROM sumas s
       ),
       aplicado AS (
       SELECT
              a.NumeroFactura,
              -- Montos netos por forma (después de restar financiamiento externo si aplica)
              TransferenciaAdj    = CASE WHEN a.DestinoExt = 'Transferencia'
                                          THEN a.Transferencia - a.MontoFinancExtEff ELSE a.Transferencia END,
              ChequePropioAdj     = CASE WHEN a.DestinoExt = 'Cheque Propio'
                                          THEN a.ChequePropio - a.MontoFinancExtEff ELSE a.ChequePropio END,
              ChequeOtrosAdj      = CASE WHEN a.DestinoExt = 'Cheque Otros Bancos'
                                          THEN a.ChequeOtros - a.MontoFinancExtEff ELSE a.ChequeOtros END,
              ChequeCajaPropiaAdj = CASE WHEN a.DestinoExt = 'Cheque caja propia'
                                          THEN a.ChequeCajaPropia - a.MontoFinancExtEff ELSE a.ChequeCajaPropia END,
              a.Efectivo, a.EfectivoCajaPropia, a.TarjetaCredito, a.FinInterno,
              a.MontoFinancExtEff,
              a.EngancheFormaDePago,
              ExtNoCubierto = CASE
                            WHEN a.MontoFinancExtEff > 0 AND a.DestinoExt IS NULL
                            THEN -a.MontoFinancExtEff ELSE 0
                            END,
              -- Enganche positivo si hubo match; negativo si no hubo match
              EngancheFinal = CASE
                            WHEN a.MontoEng > 0 AND ISNULL(a.EngancheDetectado,0) = 0 THEN -a.MontoEng
                            ELSE a.EngancheDetectado
                            END
       FROM ajustes a
       )

       /* --- NUEVO: detalle de financiamiento interno por MEDIO --- */
       , finint_det AS (
       SELECT
              NumeroFactura,
              Medio = FormaOriginal,
              Monto = SUM(Monto)
       FROM por_agrup
       WHERE Grupo = 'Financiamiento interno'
       GROUP BY NumeroFactura, FormaOriginal
       )

       /* --- NUEVO: salida DETALLADA con concepto + medio --- */
       , salida_det AS (
       /* 1) Financiamiento interno POR MEDIO */
       SELECT
              f.NumeroFactura,
              Concepto = 'Financiamiento interno',
              Medio    = f.Medio,
              Monto    = f.Monto,
              SortOrder = 1
       FROM finint_det f
       WHERE ISNULL(f.Monto,0) <> 0

       UNION ALL
       /* 2) Enganche POSITIVO (con su medio real) */
       SELECT
              a.NumeroFactura,
              Concepto = 'Enganche',
              Medio    = a.EngancheFormaDePago,
              Monto    = a.EngancheFinal,
              SortOrder = 2
       FROM aplicado a
       WHERE a.EngancheFinal > 0

       UNION ALL
       /* 3) Enganche NO identificado (negativo) */
       SELECT
              a.NumeroFactura,
              Concepto = 'Enganche (no identificado)',
              Medio    = NULL,
              Monto    = a.EngancheFinal,
              SortOrder = 2
       FROM aplicado a
       WHERE a.EngancheFinal < 0

       UNION ALL
       /* 4) Pagos directos NETOS por MEDIO (ya ajustados por financ. externo) */
       SELECT a.NumeroFactura, 'Pago', 'Transferencia',         a.TransferenciaAdj,     3 FROM aplicado a WHERE ISNULL(a.TransferenciaAdj,0)     <> 0
       UNION ALL
       SELECT a.NumeroFactura, 'Pago', 'Cheque Propio',         a.ChequePropioAdj,      4 FROM aplicado a WHERE ISNULL(a.ChequePropioAdj,0)      <> 0
       UNION ALL
       SELECT a.NumeroFactura, 'Pago', 'Cheque Otros Bancos',   a.ChequeOtrosAdj,       5 FROM aplicado a WHERE ISNULL(a.ChequeOtrosAdj,0)       <> 0
       UNION ALL
       SELECT a.NumeroFactura, 'Pago', 'Cheque caja propia',    a.ChequeCajaPropiaAdj,  6 FROM aplicado a WHERE ISNULL(a.ChequeCajaPropiaAdj,0)  <> 0
       UNION ALL
       SELECT a.NumeroFactura, 'Pago', 'Efectivo',              a.Efectivo,             7 FROM aplicado a WHERE ISNULL(a.Efectivo,0)             <> 0
       UNION ALL
       SELECT a.NumeroFactura, 'Pago', 'Efectivo caja propia',  a.EfectivoCajaPropia,   8 FROM aplicado a WHERE ISNULL(a.EfectivoCajaPropia,0)   <> 0
       UNION ALL
       SELECT a.NumeroFactura, 'Pago', 'Tarjeta de credito',    a.TarjetaCredito,       9 FROM aplicado a WHERE ISNULL(a.TarjetaCredito,0)       <> 0

       UNION ALL
       /* 5) Financiamiento externo con MEDIO destino */
       SELECT
              a.NumeroFactura,
              Concepto = 'Financiamiento externo',
              Medio    = a.DestinoExt,
              Monto    = a.MontoFinancExtEff,
              SortOrder = 10
       FROM ajustes a
       WHERE a.MontoFinancExtEff > 0 AND a.DestinoExt IS NOT NULL

       UNION ALL
       /* 6) Financiamiento externo NO cubierto */
       SELECT
              a.NumeroFactura,
              Concepto = 'Financiamiento externo (no cubierto)',
              Medio    = NULL,
              Monto    = -a.MontoFinancExtEff,  -- se mantiene negativo como señal
              SortOrder = 11
       FROM ajustes a
       WHERE a.MontoFinancExtEff > 0 AND a.DestinoExt IS NULL
       )

       /* --- NUEVO: normalización de MEDIO (como en tu mapeo) --- */
       , salida_det_mapeada AS (
       SELECT
              NumeroFactura,
              Concepto,
              MedioMap = CASE
              WHEN Medio IN ('Cheque Propio','Cheque Otros Bancos') THEN 'Depositos en cheque'
              WHEN Medio = 'Transferencia'                          THEN 'Transferencias bancarias'
              WHEN Medio = 'Efectivo caja propia'                   THEN 'Depositos en efectivo'
              ELSE Medio
              END,
              Monto,
              SortOrder
       FROM salida_det
       )

       /* --- NUEVO: fuente para #ResultadoPagos (MISMA salida que ya tenías) --- */
       , mapeo_categoria AS (
       SELECT
              NumeroFactura,
              Categoria = MedioMap,
              Monto,
              Concepto
       FROM salida_det_mapeada
       )

       /* --- NUEVO: SALIDA DETALLADA por factura (para “discernir”) --- */
       , pagos_detallados AS (
       SELECT
              NumeroFactura,
              Concepto,
              MedioDePago = COALESCE(MedioMap, 'No identificado'),
              Monto,
              SortOrder
       FROM salida_det_mapeada
       )

       ,src AS (
       SELECT
              NumeroFactura,  -- si puede venir NULL, normalízalo aquí con COALESCE
              FormaDePago  = COALESCE(NULLIF(Categoria, ''), 'SIN MEDIO'),
              ConceptoPago = COALESCE(NULLIF(Concepto,  ''), 'SIN CONCEPTO'),
              Monto        = ISNULL(Monto, 0)
              FROM mapeo_categoria
       -- WHERE NumeroFactura IS NOT NULL   -- descomenta si quieres filtrar nulos
       )
       INSERT INTO #ResultadoPagos (NumeroFactura, FormaDePago, Monto, ConceptoPago)
              SELECT
              NumeroFactura,
              FormaDePago,
              SUM(Monto) AS Monto,
              ConceptoPago
       FROM src
       GROUP BY
              NumeroFactura,
              FormaDePago,
              ConceptoPago;

       ;WITH matches AS (
       SELECT
              R.Segmento,
              R.ITEM,
              R.NIVEL_RIESGO_LDFT,
              -- Llave normalizada para contar/igualar sin tildes/mayúsculas/espacios
              UPPER(LTRIM(RTRIM(R.ITEM))) COLLATE Latin1_General_100_CI_AI AS ITEM_NORM
       FROM #ResultadoPagos C
       JOIN #ValoresRiesgoSegmentacion R
       ON UPPER(LTRIM(RTRIM(C.FormaDePago))) COLLATE Latin1_General_100_CI_AI
              = UPPER(LTRIM(RTRIM(R.ITEM)))        COLLATE Latin1_General_100_CI_AI
       WHERE R.Segmento COLLATE Latin1_General_100_CI_AI = 'FORMA DE PAGO'
       ),
       agg AS (
       SELECT
              MAX(Segmento) AS Segmento,
              COUNT(DISTINCT ITEM_NORM) AS CntItems,
              MIN(ITEM) AS ItemUnico,
              CAST(AVG(CAST(NIVEL_RIESGO_LDFT AS DECIMAL(10,6))) AS DECIMAL(10,3)) AS Promedio
       FROM matches
       )
       INSERT INTO #ValoresParaCalificacionDeFactura (Segmento, Descripcion, Valor)
       SELECT
       'FORMA DE PAGO' AS Segmento,
       CASE WHEN CntItems = 1 THEN ItemUnico
              ELSE 'PROMEDIO FORMAS DE PAGO' END AS Descripcion,
       Promedio AS NIVEL_RIESGO_LDFT
       FROM agg
       WHERE CntItems > 0;

       

       /*
       ============================================================================================================================================
       |||                                                            VALIDACION DE CUADRE                                                      |||
       ============================================================================================================================================
       */


       DECLARE @MargenToleranciaLocal DECIMAL(19,2) = 5.00;  -- ajusta si lo necesitas

       WITH /* 1) Suma desde #ResultadoPagos (excluyendo categorías no sumables) */
       pg_sum AS (
       SELECT
              r.NumeroFactura,
              MontoPagado_CTE = SUM(
              CASE
                     WHEN r.FormaDePago IN (N'Financiamiento externo (no cubierto)', N'No se identifico el enganche')
                     THEN 0
                     ELSE COALESCE(r.Monto, 0)
              END
              )
       FROM #ResultadoPagos AS r
       GROUP BY r.NumeroFactura
       ),
       /* 2) Acompañar con conteo de pagos y moneda desde #DatosDetallesPagoMatriz (excluye anuladas) */
       pg_det AS (
       SELECT
              d.NumeroFactura,
              CantidadPagos      = COUNT(DISTINCT d.numeroPago),
              MonedaTransaccion  = MIN(d.MonedaTransaccion)
       FROM #DatosDetallesPagoMatriz AS d
       WHERE ISNULL(d.Estado,'') <> 'Anulada'
       GROUP BY d.NumeroFactura
       ),
       -- Pagos AS (
       -- SELECT
       --        s.NumeroFactura,
       --        s.MontoPagado_CTE,
       --        d.CantidadPagos,
       --        d.MonedaTransaccion
       -- FROM pg_sum s
       -- LEFT JOIN pg_det d
       -- ON d.NumeroFactura = s.NumeroFactura
       -- ),
       
       /* 3) Fac desde OINV (usar nombre distinto al de la tabla; normalizar NumAtCard) */
       Fac AS (
       SELECT 
              DISTINCT 
              i.DocEntry,
              i.DocNum,
              NumAtCard = LTRIM(RTRIM(i.NumAtCard)),
              DocTotal  = CAST(i.DocTotal   AS DECIMAL(19,2)),
              PaidToDate= CAST(i.PaidToDate AS DECIMAL(19,2)),
              i.DocCur,
              i.DocStatus,   -- 'O' Abierta, 'C' Cerrada
              i.CANCELED     -- 'Y' Anulada
       FROM dbo.OINV AS i --  #DatosDetallesPagoMatriz
       INNER JOIN #cte_datos d
       ON d.DocNum = i.DocNum
       WHERE d.DocNum IS NOT NULL

       )
       ,Pagos AS (
       SELECT
              f.NumAtCard               AS NumeroFactura,
              COALESCE(s.MontoPagado_CTE, 0) AS MontoPagado_CTE,
              d.CantidadPagos,
              d.MonedaTransaccion
       FROM Fac f
       LEFT JOIN pg_sum s
              ON s.NumeroFactura = f.NumAtCard
       LEFT JOIN pg_det d
              ON d.NumeroFactura = f.NumAtCard
       )
       SELECT
       p.NumeroFactura,
       f.DocNum,
       f.DocEntry,
       f.NumAtCard,

       MontoPagado_CTE = CAST(ROUND(COALESCE(p.MontoPagado_CTE, 0), 2) AS DECIMAL(19,2)),
       DocTotal        = CAST(ROUND(COALESCE(f.DocTotal,        0), 2) AS DECIMAL(19,2)),
       PagadoSAP       = CAST(ROUND(COALESCE(f.PaidToDate,      0), 2) AS DECIMAL(19,2)),
       SaldoPendiente  = CAST(ROUND(COALESCE(f.DocTotal,0) - COALESCE(f.PaidToDate,0), 2) AS DECIMAL(19,2)),

       -- Diferencias
       Dif_CTE_vs_DocTotal       = CAST(ROUND(COALESCE(p.MontoPagado_CTE,0) - COALESCE(f.DocTotal,0),   2) AS DECIMAL(19,2)),
       DescuadreAbs_vs_DocTotal  = CAST(ROUND(ABS(COALESCE(p.MontoPagado_CTE,0) - COALESCE(f.DocTotal,0)), 2) AS DECIMAL(19,2)),
       Dif_CTE_vs_PagadoSAP      = CAST(ROUND(COALESCE(p.MontoPagado_CTE,0) - COALESCE(f.PaidToDate,0), 2) AS DECIMAL(19,2)),
       DescuadreAbs_vs_PagadoSAP = CAST(ROUND(ABS(COALESCE(p.MontoPagado_CTE,0) - COALESCE(f.PaidToDate,0)), 2) AS DECIMAL(19,2)),

       MargenTolerancia = @MargenToleranciaLocal,

       -- Estado de factura según SAP
       EstadoFactura =
              CASE
              WHEN f.CANCELED = 'Y' THEN N'FACTURA ANULADA'
              WHEN f.DocStatus = 'C' OR ABS(COALESCE(f.DocTotal,0) - COALESCE(f.PaidToDate,0)) <= 0.01
                     THEN N'factura cerrada'
              ELSE N'factura con saldo pendiente'
              END,

       -- Resultado del cuadre (margen sobre DocTotal si cerrada; sobre PaidToDate si abierta)
       ResultadoCuadre =
              CASE
              WHEN f.CANCELED = 'Y' THEN N'NO APLICA (anulada)'

              WHEN (f.DocStatus = 'C' OR ABS(COALESCE(f.DocTotal,0) - COALESCE(f.PaidToDate,0)) <= 0.01)
                     AND ABS(COALESCE(p.MontoPagado_CTE,0) - COALESCE(f.DocTotal,0)) <= @MargenToleranciaLocal
                     THEN N'SI CUADRA (factura cerrada)'
              WHEN (f.DocStatus = 'C' OR ABS(COALESCE(f.DocTotal,0) - COALESCE(f.PaidToDate,0)) <= 0.01)
                     AND ABS(COALESCE(p.MontoPagado_CTE,0) - COALESCE(f.DocTotal,0))  > @MargenToleranciaLocal
                     THEN N'NO CUADRA (factura cerrada)'

              WHEN (f.DocStatus <> 'C' AND f.CANCELED <> 'Y')
                     AND ABS(COALESCE(p.MontoPagado_CTE,0) - COALESCE(f.PaidToDate,0)) <= @MargenToleranciaLocal
                     THEN N'SI CUADRA (contra Pagado; factura con saldo pendiente)'
              WHEN (f.DocStatus <> 'C' AND f.CANCELED <> 'Y')
                     AND ABS(COALESCE(p.MontoPagado_CTE,0) - COALESCE(f.PaidToDate,0))  > @MargenToleranciaLocal
                     THEN N'NO CUADRA (factura con saldo pendiente)'
              END,

       f.DocCur              AS MonedaFactura,
       p.MonedaTransaccion,
       p.CantidadPagos
       INTO #ValidacionPagosFactura
       FROM Pagos p
       LEFT JOIN Fac f
       ON f.NumAtCard = LTRIM(RTRIM(p.NumeroFactura));


       /* 1) Marcar como INACTIVAS (Estado=0) las que SI CUADRAN y ya existen */
       UPDATE tgt
       SET tgt.Estado = 0,
              tgt.FechaModificacion = SYSDATETIMEOFFSET() AT TIME ZONE 'Central America Standard Time'
       FROM dbo.Reporte_Vehiculos_IVE_FacturasNoCuadran AS tgt
       JOIN (
       SELECT DISTINCT v.DocNum
       FROM #ValidacionPagosFactura v
       WHERE v.ResultadoCuadre LIKE N'SI CUADRA%'
       AND v.DocNum IS NOT NULL
       ) s
       ON s.DocNum = tgt.DocNum;


       /* 2) Upsert de NO CUADRA: si existe → activar (Estado=1) y actualizar fecha;
       si no existe → insertar con Estado=1                                 */
       MERGE dbo.Reporte_Vehiculos_IVE_FacturasNoCuadran AS tgt
       USING (
       SELECT DISTINCT v.DocNum
       FROM #ValidacionPagosFactura v
       WHERE v.ResultadoCuadre LIKE N'NO CUADRA%'
       AND v.DocNum IS NOT NULL
       ) AS s
       ON s.DocNum = tgt.DocNum
       WHEN MATCHED THEN
       UPDATE SET
              Estado = 1,
              FechaModificacion = SYSDATETIMEOFFSET() AT TIME ZONE 'Central America Standard Time'
       WHEN NOT MATCHED THEN
       INSERT (DocNum, Estado)
       VALUES (s.DocNum, 1);


       /*
       ============================================================================================================================================
       |||                                                       VISUALIZACION DETALLES                                                         |||
       ============================================================================================================================================
       */

       -- SELECT * FROM #ValoresRiesgoSegmentacion;
       -- SELECT * FROM #Descripcion_marca_tipoVehiculo;
       -- SELECT * FROM #nacionalidad_individual;
       -- SELECT * FROM #nacionalidad_juridica;
       -- SELECT * FROM #Clasificacion_Experiencia_Comercial_tabla;
       -- SELECT * FROM #canales_distribucion;
       -- SELECT * FROM #ventas_ubicacion_geografica_nacional;
       -- SELECT * FROM #DetalleVentasUbicacionInternacional;
       -- SELECT * FROM #ResultadoPagos;
       -- SELECT * FROM Reporte_Vehiculos_IVE_FacturasNoCuadran;
       -- SELECT * FROM #ValoresParaCalificacionDeFactura;
       -- SELECT * FROM #ValidacionPagosFactura;


       /*
       ============================================================================================================================================
       |||                                                       DETALLES DE CALCULOS PARA HTML                                                        |||
       ============================================================================================================================================
       */

       DECLARE @PromedioValoresRiesgoPreCalculados DECIMAL(18,3);

       SELECT @PromedioValoresRiesgoPreCalculados = CAST(AVG(CAST(Valor AS DECIMAL(18,3))) AS DECIMAL(18,3))
       FROM #ValoresParaCalificacionDeFactura;

       DECLARE @PromedioGeneralRespuestaRiesgo DECIMAL(18,3);

       SELECT @PromedioGeneralRespuestaRiesgo = CAST(AVG(CAST(ed.PONDERACION_MITIGADOR AS DECIMAL(10,3))) AS DECIMAL(10,3))
       FROM UTILS.dbo.src180_IVE_RESPUESTA_AL_RIESGO_EVALUACION_DETALLE ed
       JOIN UTILS.dbo.src180_IVE_RESPUESTA_AL_RIESGO_MITIGADOR m ON m.MITIGADOR_ID = ed.MITIGADOR_ID
       JOIN UTILS.dbo.src180_IVE_RESPUESTA_AL_RIESGO_AREA a       ON a.AREA_ID      = m.AREA_ID
       JOIN UTILS.dbo.src180_IVE_RESPUESTA_AL_RIESGO_EVALUACION e ON e.EVALUACION_ID= ed.EVALUACION_ID;

       DECLARE @Diferencia DECIMAL(18,3);
       SET @Diferencia = @PromedioValoresRiesgoPreCalculados - @PromedioGeneralRespuestaRiesgo;

       DECLARE @NivelRiesgoEvaluado INT;

       SET @NivelRiesgoEvaluado = CAST(ROUND(@Diferencia, 0) AS INT);

       DECLARE @NivelCliente NVARCHAR(20);
       SET @NivelCliente = CASE @NivelRiesgoEvaluado
                            WHEN 4 THEN N'Alto'
                            WHEN 3 THEN N'Medio Alto'
                            WHEN 2 THEN N'Medio Bajo'
                            ELSE N'Bajo'
                     END;

       DECLARE @NivelColor  NVARCHAR(7);
       DECLARE @TextColor   NVARCHAR(7);
       DECLARE @BannerHtml  NVARCHAR(MAX);
       DECLARE @DatosClienteHtml  NVARCHAR(MAX);

       SET @NivelColor = CASE @NivelCliente
              WHEN N'Alto'        THEN N'red'
              WHEN N'Medio Alto'  THEN N'yellow'
              WHEN N'Medio Bajo'  THEN N'green'
              ELSE                   N'blue'  -- Bajo
              END;

       SET @TextColor = CASE @NivelCliente
                   WHEN N'Medio Alto' THEN N'#000000'
                   ELSE                  N'#ffffff'
                 END;


       SET @BannerHtml =
       N'<div style="margin:0 0 12px 0; padding:10px 12px; ' +
       N'background:' + @NivelColor + N'; color:' + @TextColor + N'; text-align:center;">' +
       N'<h2 style="margin:0; font-family:Arial, sans-serif;">' + UPPER(@NivelCliente) + N'</h2>' +
       N'</div>';



       DECLARE @CardCode NVARCHAR(20),
              @CardName NVARCHAR(200),
              @NIT      NVARCHAR(50),
              @DocNum      NVARCHAR(50),
              @DocEntryBuscadoVarchar      NVARCHAR(50),
              @Factura  NVARCHAR(20);

       SELECT
       @CardCode = T0.CardCode,
       @CardName = T0.U_SNNombre,
       @NIT      = T0.U_SNNit,
       @Factura  = CONVERT(NVARCHAR(100), T0.NumAtCard),
       @DocNum  = CONVERT(NVARCHAR(100), T0.DocNum),
       @DocEntryBuscadoVarchar  = CONVERT(NVARCHAR(100), T0.DocEntry)
       FROM OINV T0
       INNER JOIN OCRD T1 ON T1.CardCode = T0.CardCode
       WHERE T0.DocEntry = @DocEntryBuscado;

       
       SET @DatosClienteHtml = 
       N'<div style="margin:0 0 12px 0; padding:10px 12px; ' +
       N'text-align:center;">' +
       N'<h2 style="margin:0; font-family:Arial, sans-serif;">Riesgo Por Cliente</h5>' +
       N'<h5 style="margin:0; font-family:Arial, sans-serif;">Código del Cliente: ' + @CardCode + ' </h5>' +
       N'<h5 style="margin:0; font-family:Arial, sans-serif;">Nombre Completo del Cliente: ' + @CardName + '</h5>' +
       N'<h5 style="margin:0; font-family:Arial, sans-serif;">NIT: ' + @NIT + '</h5>' +
       N'<h5 style="margin:0; font-family:Arial, sans-serif;">Número de Factura: ' + @Factura + '</h5>' +
       N'<h5 style="margin:0; font-family:Arial, sans-serif;">Nivel de Riesgo: 1</h5>' +
       N'<h5 style="margin:0; font-family:Arial, sans-serif;">DocEntry: ' + @DocEntryBuscadoVarchar + '</h5>' +
       N'<h5 style="margin:0; font-family:Arial, sans-serif;">DocNum: ' + @DocNum + '</h5>' +
       N'</div>';



       /*
       ============================================================================================================================================
       |||                                                       GENERACION DE HTML CORREO                                                      |||
       ============================================================================================================================================
       */

       /* ==============================
       0) Variables “constantes” (baratas)
       ============================== */
       DECLARE @Cliente   NVARCHAR(100),
              @Producto  NVARCHAR(250),
              @Canal     NVARCHAR(150),
              @Ubicacion NVARCHAR(200),
              @Html      NVARCHAR(MAX),
              @Headers   NVARCHAR(MAX),
              @Rows      NVARCHAR(MAX);

       -- CLIENTE (elige lo más representativo disponible)
       SET @Cliente =
       CASE
              WHEN EXISTS (SELECT 1 FROM #nacionalidad_juridica  WHERE LOWER([Descripción de nacionalidad personas JURÍDICAS]) = LOWER(N'Nacionales')  AND Clientes > 0)
              THEN N'JURIDICO NACIONAL'
              WHEN EXISTS (SELECT 1 FROM #nacionalidad_juridica  WHERE LOWER([Descripción de nacionalidad personas JURÍDICAS]) = LOWER(N'Extranjeros') AND Clientes > 0)
              THEN N'JURIDICO EXTRANJERO'
              WHEN EXISTS (SELECT 1 FROM #nacionalidad_individual WHERE LOWER([Descripción de nacionalidad personas INDIVIDUALES]) = LOWER(N'NACIONALES GUATEMALTECOS')  AND Clientes > 0)
              THEN N'INDIVIDUAL NACIONAL'
              WHEN EXISTS (SELECT 1 FROM #nacionalidad_individual WHERE LOWER([Descripción de nacionalidad personas INDIVIDUALES]) = LOWER(N'EXTRANJEROS') AND Clientes > 0)
              THEN N'INDIVIDUAL EXTRANJERO'
              ELSE N'DESCONOCIDO'
       END;

       -- PRODUCTO (primera fila distinta a “TOTAL GENERAL”)
       SELECT TOP (1) @Producto = [Descripción marca y tipo de vehículos]
       FROM #Descripcion_marca_tipoVehiculo
       WHERE [No.] <> 0
       ORDER BY [No.];

       -- CANAL (el más frecuente)
       SELECT TOP (1) @Canal = Clasificacion_Canales_Distribucion
       FROM #canales_distribucion
       ORDER BY TotalFacturas DESC, TotalClientes DESC;

       -- UBICACIÓN (la más frecuente)
       SELECT TOP (1) @Ubicacion = CONCAT(Departamento, N' - ', Municipio)
       FROM #ventas_ubicacion_geografica_nacional
       ORDER BY TotalTransacciones DESC, TotalClientes DESC;

       -- Defaults por si faltara algo
       SET @Producto  = COALESCE(@Producto,  N'N/D');
       SET @Canal     = COALESCE(@Canal,     N'N/D');
       SET @Canal     = REPLACE ( @Canal , '(EMPLEADOS)' , '' );
       SET @Ubicacion = COALESCE(@Ubicacion, N'N/D');


       /* =========================================================
       Lista de MEDIOS *fija* (no depende de pm_agg), con orden estable
       ========================================================= */
       WITH pm_agg AS (
       SELECT r.NumeroFactura,
              r.FormaDePago,
              SUM(r.Monto) AS Monto
       FROM #ResultadoPagos r
       WHERE r.FormaDePago IN (
              N'Efectivo',
              N'Transferencias bancarias',
              N'Depositos en cheque',
              N'Cheque caja propia',
              N'Depositos en efectivo',
              N'Tarjeta de credito'
       )
       GROUP BY r.NumeroFactura, r.FormaDePago
       ),
       metodos AS (
       SELECT v.FormaDePago, v.ord
       FROM (VALUES
       (N'Transferencias bancarias', 1),
       (N'Depositos en cheque',      2),
       (N'Cheque caja propia',       3),
       (N'Efectivo',                 4),
       (N'Depositos en efectivo',    5),
       (N'Tarjeta de credito',       6)
       ) AS v(FormaDePago, ord)
       ),
       /* =========================================================
       Filas por factura: forma de pago + celdas <td> dinámicas
       ========================================================= */
       filas AS (
       SELECT
       v.NumeroFactura,

       -- MONTO VEHICULO desde #ValidacionPagosFactura
       CAST(v.DocTotal AS DECIMAL(19,2)) AS MontoVehiculo,

       -- FORMA DE PAGO por factura (resuelve CONTADO/FINANCIAMIENTOS aun sin medios)
       CASE
              WHEN EXISTS (SELECT 1 FROM #ResultadoPagos rp WHERE rp.NumeroFactura = v.NumeroFactura AND rp.ConceptoPago = N'Financiamiento interno')
              AND EXISTS (SELECT 1 FROM #ResultadoPagos rp WHERE rp.NumeroFactura = v.NumeroFactura AND rp.ConceptoPago = N'Financiamiento externo')
              THEN N'FINANCIAMIENTO MIXTO (interno + externo)'
              WHEN EXISTS (SELECT 1 FROM #ResultadoPagos rp WHERE rp.NumeroFactura = v.NumeroFactura AND rp.ConceptoPago = N'Financiamiento interno')
              THEN N'FINANCIAMIENTO INTERNO'
              WHEN EXISTS (SELECT 1 FROM #ResultadoPagos rp WHERE rp.NumeroFactura = v.NumeroFactura AND ( rp.ConceptoPago = N'Financiamiento externo' OR rp.ConceptoPago = N'Financiamiento externo (no cubierto)' ))
              THEN N'FINANCIAMIENTO EXTERNO'
              ELSE N'CONTADO'
       END AS FormaPago,

       -- Celdas <td> para cada Medio (si no hay monto, imprime 0.00)
       (
              SELECT STRING_AGG(
              N'<td class="num">' 
              + CONVERT(NVARCHAR(32), CAST(COALESCE(x.Monto, 0) AS money), 1) 
              + N'</td>', N''
              ) WITHIN GROUP (ORDER BY m.ord)
              FROM metodos m
              OUTER APPLY (
              SELECT a.Monto
              FROM pm_agg a
              WHERE a.NumeroFactura = v.NumeroFactura
              AND a.FormaDePago   = m.FormaDePago
              ) AS x
       ) AS TdMedios
       FROM #ValidacionPagosFactura v
       )
       -- Encabezados dinámicos (ahora siempre existen)
       SELECT
       @Headers = (
       SELECT STRING_AGG(
       N'<th>' + UPPER(m.FormaDePago) + N'</th>', N''
       ) WITHIN GROUP (ORDER BY m.ord)
       FROM metodos m
       ),
       -- Filas HTML (si no hay medios, TdMedios saldrá con todos 0.00)
       @Rows = (
       SELECT STRING_AGG(
       N'<tr>'
       + N'<td>' + UPPER(@Cliente) + N'</td>'
       + N'<td>' + UPPER(@Producto) + N'</td>'
       + N'<td class="num">' + CONVERT(NVARCHAR(32), CAST(f.MontoVehiculo AS money), 1) + N'</td>'
       + N'<td>' + UPPER(@Canal) + N'</td>'
       + N'<td>' + UPPER(@Ubicacion) + N'</td>'
       + N'<td>' + f.FormaPago + N'</td>'
       + COALESCE(f.TdMedios, N'')   -- siempre habrá columnas; COALESCE por seguridad
       + N'</tr>'
       , N''
       ) WITHIN GROUP (ORDER BY f.NumeroFactura)
       FROM filas f
       );

       -- Por seguridad
       SET @Headers = COALESCE(@Headers, N'');

       
       /* =========================================================
       DETALLES DE PROMEDIOS
       ========================================================= */

       UPDATE v
       SET Descripcion = LTRIM(RTRIM(
                     REPLACE(
                            REPLACE(Descripcion, N' (EMPLEADOS)', N''),  
                            N'(EMPLEADOS)', N''                          
                     )
                     ))
       FROM #ValoresParaCalificacionDeFactura AS v
       WHERE v.Segmento    COLLATE Latin1_General_CI_AI = N'CANAL DE DISTRIBUCION'        
       AND v.Descripcion COLLATE Latin1_General_CI_AI = N'AGENCIAS PROPIAS (EMPLEADOS)';


       DECLARE @RowsDetalle NVARCHAR(MAX);

       SELECT @RowsDetalle =
       (
       SELECT STRING_AGG(
              N'<tr>'
       + N'<td>' + ISNULL(Segmento,   N'') + N'</td>'
       + N'<td>' + ISNULL(Descripcion,N'') + N'</td>'
       + N'<td class="num">' + CONVERT(NVARCHAR(32), CAST(Valor AS DECIMAL(18,3))) + N'</td>'
       + N'</tr>'
       , N'')
       FROM #ValoresParaCalificacionDeFactura
       );



       /* =========================================================
       HTML final (NVARCHAR(MAX))
       ========================================================= */
       SET @Html =
       N'<!DOCTYPE html>
       <html>
       <head>
       <meta charset="UTF-8">
       <style>
       table { border-collapse: collapse; font-family: Arial, sans-serif; font-size: 12px; }
       th, td { border: 1px solid #999; padding: 6px 8px; text-align: left; }
       th { background: #f0f0f0; }
       td.num { text-align: right; }
       </style>
       </head>
       <body>

       '+ @DatosClienteHtml + 
       @BannerHtml +'

       <table>
       <thead>
       <tr>
       <th>TIPO DE CLIENTE</th>
       <th>PRODUCTO</th>
       <th>MONTO VEHICULO</th>
       <th>CANAL DE DISTRIBUCION</th>
       <th>UBICACION GEOGRAFICA</th>
       <th>FORMA DE PAGO</th>' + @Headers + N'
       </tr>
       </thead>
       <tbody>'
       + COALESCE(@Rows, N'') +
       N'</tbody>
       </table>

       <br/>
       <h3>DETALLE DE VALORES DE RIESGO</h3>
              <table border="1" style="border-collapse:collapse; font-family:Arial; font-size:12px;">
              <thead>
              <tr>
              <th>Segmento</th>
              <th>Descripción</th>
              <th>Valor</th>
              </tr>
              </thead>
              <tbody>' + COALESCE(@RowsDetalle, N'') + N'</tbody>
       </table>

       <br>
       <table border="1" style="border-collapse:collapse; font-family:Arial; font-size:12px;">
       <tbody>
       <tr><th style="width:40%;">PROMEDIO DE FACTORES DE RIESGO</th>
              <td class="num">' + CONVERT(NVARCHAR(32), @PromedioValoresRiesgoPreCalculados) + N'</td></tr>
       <tr><th>PROMEDIO DE MITIGADORES</th>
              <td class="num">' + CONVERT(NVARCHAR(32), @PromedioGeneralRespuestaRiesgo) + N'</td></tr>
       <tr><th>RESULTADO</th>
              <td class="num">' + CONVERT(NVARCHAR(32), @Diferencia) + N'</td></tr>
       <tr><th>RESULTADO REDONDEADO</th>
              <td class="num">' + CONVERT(NVARCHAR(32), @NivelRiesgoEvaluado) + N'</td></tr>
       <tr><th>NIVEL DEL CLIENTE</th>
              <td style="text-align: right;">' + @NivelCliente + N'</td></tr>
       </tbody>
       </table>

       <br>
       <table border="1" style="border-collapse:collapse; font-family:Arial; font-size:12px; text-align:center;">
              <tbody>
              <tr><td style="width:30px; background:red;">4</td><td>Alto</td></tr>
              <tr><td style="background:yellow;">3</td><td>Medio Alto</td></tr>
              <tr><td style="background:green;">2</td><td>Medio Bajo</td></tr>
              <tr><td style="background:blue;">1</td><td>Bajo</td></tr>
              </tbody>
       </table>
       <p><footer>Canella S.A. &#174; canella.com.gt</footer></p>
       </body>
       </html>';

       -- vista del html
       -- SELECT @Html AS HtmlReporte;

       /*
       ============================================================================================================================================
       |||                                                       GENERACION DE HTML CORREO                                                      |||
       ============================================================================================================================================
       */


       Declare @Destinatarios NVARCHAR(MAX)            ; --- Destinarios del correo 
		Declare @CCopia   NVARCHAR(MAX)           ; --- Destinarios del correo 
		Declare @Asunto NVarChar(Max)
		Declare @Titulo Varchar(50)      


       Declare @Email nvarchar(100)
       Declare @CodVendedor nvarchar(100)
       Declare @NomVendedor nvarchar(100)

       IF @Producto COLLATE SQL_Latin1_General_Cp1_CI_AI LIKE '%' + 'ISUZU' + '%' COLLATE SQL_Latin1_General_Cp1_CI_AI OR 
       @Producto COLLATE SQL_Latin1_General_Cp1_CI_AI LIKE '%' + 'DFSK' + '%' COLLATE SQL_Latin1_General_Cp1_CI_AI OR 
       @Producto COLLATE SQL_Latin1_General_Cp1_CI_AI LIKE '%' + 'HYUNDAI' + '%' COLLATE SQL_Latin1_General_Cp1_CI_AI OR 
       @Producto COLLATE SQL_Latin1_General_Cp1_CI_AI LIKE '%' + 'NEW HOLLAND' + '%' COLLATE SQL_Latin1_General_Cp1_CI_AI 
       BEGIN

              SELECT
                     @CodVendedor = t1.SlpCode,
                     @NomVendedor = t1.SlpName, 
                     @Email = T1.U_Email
              FROM
                     OINV T0 WITH (NOLOCK) INNER JOIN OSLP T1 WITH (NOLOCK) ON T0.SlpCode = T1.SlpCode
              WHERE
                     DocEntry = @DocEntryBuscado;

       END

       /* =========================================================
       CORREO PARA LOS DE YAMAHA, Y LOS DE CC DE CUMPLIMIENTO
       ========================================================= */

       IF @Producto COLLATE SQL_Latin1_General_Cp1_CI_AI LIKE '%' + 'YAMAHA' + '%' COLLATE SQL_Latin1_General_Cp1_CI_AI
       BEGIN

              SET @Destinatarios = 'dcontreras@canella.com.gt';

              Set @CCopia = @CCopia + '; lcoc@canella.com.gt ;';

       END
       
       /* =========================================================
       CORREO PARA LOS DE CC DE CUMPLIMIENTO
       ========================================================= */
       IF @Producto COLLATE SQL_Latin1_General_Cp1_CI_AI LIKE '%' + 'NEW HOLLAND' + '%' COLLATE SQL_Latin1_General_Cp1_CI_AI OR
       @Producto COLLATE SQL_Latin1_General_Cp1_CI_AI LIKE '%' + 'HYUNDAI' + '%' COLLATE SQL_Latin1_General_Cp1_CI_AI OR
       @Producto COLLATE SQL_Latin1_General_Cp1_CI_AI LIKE '%' + 'DFSK' + '%' COLLATE SQL_Latin1_General_Cp1_CI_AI
       BEGIN
              Set @CCopia = @CCopia + '; kmrodriguez@canella.com.gt ;';
       END

       /* =========================================================
       CORREO PARA LOS DE CC DE CUMPLIMIENTO
       ========================================================= */

       IF @Producto COLLATE SQL_Latin1_General_Cp1_CI_AI LIKE '%' + 'ISUZU' + '%' COLLATE SQL_Latin1_General_Cp1_CI_AI
       BEGIN
              Set @CCopia = @CCopia + '; dmoscoso@canella.com.gt ; erodas@canella.com.gt; ';
       END

       /* =========================================================
       DETALLE DE CORREOS
       ========================================================= */
       IF @Email IS NULL
       BEGIN
              SET @Email = 'lbarrios@canella.com.gt'
       END

       Set @Destinatarios = @Email
       Set @CCopia = @CCopia + '; lbarrios@canella.com.gt ; lprado@canella.com.gt; cadeleon@canella.com.gt; edlopez@canella.com.gt; rmorales@canella.com.gt;'
       Set @Asunto = 'PRUEBAS - MATRIZ RIESGO'


       /* =========================================================
       PRUEBAS TEMPORALES
       ========================================================= */
       Set @Destinatarios = 'tmorales@canella.com.gt;';
       Set @CCopia = 'lbarrios@canella.com.gt;';

	   	          /*
       ===========================================================
       ||| CAMBIOS REALIZADOS POR OSCAR MUÑOZ |||
       ===========================================================
       */

	INSERT INTO dbo.Matriz_Riesgo_Individual_26_general_Bitacora 
			(
					NombreSP, 
					ParametrosEntrada, 
					RespuestaSalida,
					DocEntry,
					NumAtCard, 
					UsuarioFactura, 
					UsuarioCodigo
				)
				SELECT 
					'Matriz_Riesgo_Individual_26_general',
					CONCAT('{"DocEntryBuscado":"', @DocEntryBuscado, '"}'),
					@Html,
					@DocEntryBuscado,
					i.NumAtCard,       -- Se obtiene internamente de OINV
					u.U_NAME,          -- Se obtiene internamente de OUSR
					u.USER_CODE        -- Se obtiene internamente de OUSR
				FROM OINV i WITH (NOLOCK)
				LEFT JOIN OUSR u WITH (NOLOCK) ON i.UserSign = u.USERID
				WHERE i.DocEntry = @DocEntryBuscado;


       /* =========================================================
       END PRUEBAS TEMPORALES
       ========================================================= */

       IF @Html IS NOT NULL AND @Html <> ''
       BEGIN
              EXEC  msdb.dbo.sp_send_dbmail 
                     @profile_name     = 'MatrizDeRiesgo', 
                     -- @profile_name     = 'SupplierPayment', 
                     @recipients       = @Destinatarios,
                     @copy_recipients  = @CCopia,
                     @body_format      = 'HTML',
                     @subject          = @Asunto,
                     @body             = @Html;  
       END
FIN:
END
