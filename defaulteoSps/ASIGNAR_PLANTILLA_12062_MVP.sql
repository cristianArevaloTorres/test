/*
    Configura exclusivamente EMIdEmpresa de empresas hijas.

    @Aplicar = 0: solo consulta.
    @Aplicar = 1: inserta faltantes.
    La migracion 153 a 12062/BF3 esta habilitada.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Aplicar BIT = 0;
DECLARE @Migrar153 BIT = 1;
DECLARE @Usuario INT = 5;

DECLARE @Solicitadas TABLE (IdEmpresa INT PRIMARY KEY);
DECLARE @Empresas TABLE (IdEmpresa INT PRIMARY KEY);
DECLARE @Insertadas TABLE (IdEmpresa INT PRIMARY KEY);
DECLARE @Migradas TABLE (IdEmpresa INT PRIMARY KEY);

/* IDs de empresas hijas obtenidos del Excel y ff_Empresa local. */
INSERT INTO @Solicitadas (IdEmpresa)
VALUES
    (191),
    (659),
    (719),
    (720),
    (722),
    (724),
    (728),
    (744),
    (753),
    (757),
    (759),
    (761),
    (763),
    (791),
    (798),
    (800),
    (807),
    (813),
    (815),
    (821),
    (841),
    (861),
    (891),
    (930),
    (954),
    (983),
    (1011),
    (1013),
    (1022),
    (1037),
    (1084),
    (1096),
    (1102),
    (1106),
    (1116),
    (1144),
    (1158),
    (1165),
    (1183),
    (1200),
    (1207),
    (1225),
    (1233),
    (1234),
    (1235),
    (1237),
    (1241),
    (1254),
    (1264),
    (1270),
    (1281),
    (1283),
    (1293),
    (1304),
    (1306),
    (1329),
    (1338),
    (1346),
    (1350),
    (1359),
    (1384),
    (1392),
    (1394),
    (1399),
    (1411),
    (1412),
    (1414),
    (1427),
    (1432),
    (1440),
    (1446),
    (1469),
    (1471),
    (1473),
    (1491),
    (1509),
    (1519),
    (1521),
    (1523),
    (1576),
    (1578),
    (1580),
    (1584),
    (1612),
    (1633),
    (1654),
    (1656),
    (1718),
    (1733),
    (1735),
    (1741),
    (1757),
    (1761),
    (1774),
    (1782),
    (1787),
    (1795),
    (1798),
    (1811),
    (1813),
    (1815),
    (1829),
    (1851),
    (1853),
    (1857),
    (1861),
    (1887),
    (1923),
    (1927),
    (1929),
    (1931),
    (1933),
    (1935),
    (1942),
    (1944),
    (1946),
    (1950),
    (1954),
    (1975),
    (1984),
    (2004),
    (2009),
    (2044),
    (2068),
    (2070),
    (2084),
    (2141),
    (2145),
    (2161),
    (2163),
    (2165),
    (2167),
    (2169),
    (2171),
    (2232),
    (2248),
    (2250),
    (2253),
    (2254),
    (2256),
    (2257),
    (2259),
    (2261),
    (2263),
    (2265),
    (2269),
    (2271),
    (2273),
    (2275),
    (2277),
    (2279),
    (2281),
    (2283),
    (2285),
    (2287),
    (2289),
    (2292),
    (2315),
    (2321),
    (2333),
    (2337),
    (2339),
    (2341),
    (2363),
    (2365),
    (2367),
    (2372),
    (2374),
    (2398),
    (2404),
    (2408),
    (2412),
    (2426),
    (2446),
    (2453),
    (2455),
    (2470),
    (2488),
    (2492),
    (2500),
    (2503),
    (2509),
    (2521),
    (2523),
    (2525),
    (2536),
    (2538),
    (2546),
    (2553),
    (2555),
    (2564),
    (2578),
    (2588),
    (2590),
    (2592),
    (2596),
    (2598),
    (2607),
    (2613),
    (2620),
    (2624),
    (2626),
    (2636),
    (2654),
    (2657),
    (2659),
    (2679),
    (2732),
    (2748),
    (2750),
    (2772),
    (2780),
    (2784),
    (2793),
    (2795),
    (2801),
    (2817),
    (2819),
    (2823),
    (2825),
    (2827),
    (2835),
    (2837),
    (2840),
    (2844),
    (2847),
    (2851),
    (2883),
    (2887),
    (2891),
    (2898),
    (2902),
    (2914),
    (2921),
    (2925),
    (2931),
    (2939);

/* Usar solo empresas hijas activas. */
INSERT INTO @Empresas (IdEmpresa)
SELECT s.IdEmpresa
FROM @Solicitadas s
INNER JOIN dbo.ff_Empresa e
    ON e.EMidEmpresa = s.IdEmpresa
WHERE e.EMidEstatus = 1
  AND e.EMNivel > 0
  AND e.EMidEmpresa <> e.EMidCorporativo;

IF @Aplicar = 1
BEGIN
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ff_Plantilla
        WHERE PLIdPlantilla = 12062
          AND PLIdEstatus = 1
    )
        THROW 50001, 'La plantilla 12062 no existe o esta inactiva.', 1;

    IF OBJECT_ID(N'dbo.ff_XCMTitularesAltaCMM_BF3', N'P') IS NULL
        THROW 50002, 'No existe ff_XCMTitularesAltaCMM_BF3.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        /* Opcional: migrar una sola configuracion activa 153 a BF3. */
        IF @Migrar153 = 1
        BEGIN
            UPDATE ce
               SET ce.CEIdPlantilla = 12062,
                   ce.CEStoredProc = 'ff_XCMTitularesAltaCMM_BF3',
                   ce.CEStoredProcAtributos = 3,
                   ce.CEUsuarioUMod = @Usuario,
                   ce.CEFechaUMod = GETDATE()
            OUTPUT inserted.CEIdEmpresa INTO @Migradas (IdEmpresa)
            FROM dbo.ff_CargaMasivaOperacionEmpresa ce
            INNER JOIN @Empresas e
                ON e.IdEmpresa = ce.CEIdEmpresa
            WHERE ce.CEIdOperacion = 2
              AND ce.CEIdEstatus = 1
              AND ce.CEIdPlantilla = 153
              AND
              (
                  SELECT COUNT(*)
                  FROM dbo.ff_CargaMasivaOperacionEmpresa x
                  WHERE x.CEIdEmpresa = ce.CEIdEmpresa
                    AND x.CEIdOperacion = 2
                    AND x.CEIdEstatus = 1
              ) = 1;
        END;

        /* Insertar empresas que no tengan configuracion activa de operacion 2. */
        INSERT INTO dbo.ff_CargaMasivaOperacionEmpresa
        (
            CEIdOperacion,
            CEIdEmpresa,
            CEIdPlantilla,
            CEStoredProc,
            CEStoredProcAtributos,
            CEIdEstatus,
            CEUsuarioAdd,
            CEFechaAdd,
            CEUsuarioUMod,
            CEFechaUMod
        )
        OUTPUT inserted.CEIdEmpresa INTO @Insertadas (IdEmpresa)
        SELECT
            2,
            e.IdEmpresa,
            12062,
            'ff_XCMTitularesAltaCMM_BF3',
            3,
            1,
            @Usuario,
            GETDATE(),
            @Usuario,
            GETDATE()
        FROM @Empresas e
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.ff_CargaMasivaOperacionEmpresa ce WITH (UPDLOCK, HOLDLOCK)
            WHERE ce.CEIdEmpresa = e.IdEmpresa
              AND ce.CEIdOperacion = 2
              AND ce.CEIdEstatus = 1
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

/* Resumen. */
SELECT
    Modo = CASE WHEN @Aplicar = 1 THEN 'APLICAR' ELSE 'SOLO CONSULTA' END,
    Migrar153 = CASE WHEN @Migrar153 = 1 THEN 'SI' ELSE 'NO' END,
    EmpresasSolicitadas = (SELECT COUNT(*) FROM @Solicitadas),
    EmpresasHijasActivas = (SELECT COUNT(*) FROM @Empresas),
    Insertadas = (SELECT COUNT(*) FROM @Insertadas),
    MigradasDesde153 = (SELECT COUNT(*) FROM @Migradas);

/* Estado final de cada empresa. */
SELECT
    s.IdEmpresa,
    Empresa = MAX(emp.EMNombre),
    Plantilla = MAX(ce.CEIdPlantilla),
    Procedimiento = MAX(ce.CEStoredProc),
    ConfiguracionesActivas = COUNT(ce.CEIdOperacionEmpresa),
    Resultado = CASE
        WHEN e.IdEmpresa IS NULL THEN 'NO ES EMPRESA HIJA ACTIVA'
        WHEN i.IdEmpresa IS NOT NULL THEN 'INSERTADA'
        WHEN m.IdEmpresa IS NOT NULL THEN 'MIGRADA DE 153 A 12062'
        WHEN COUNT(ce.CEIdOperacionEmpresa) = 0 THEN 'PENDIENTE DE INSERTAR'
        WHEN COUNT(ce.CEIdOperacionEmpresa) > 1 THEN 'CONFLICTO: VARIAS CONFIGURACIONES ACTIVAS'
        WHEN MAX(ce.CEIdPlantilla) = 12062
         AND MAX(RTRIM(ce.CEStoredProc)) = 'ff_XCMTitularesAltaCMM_BF3'
            THEN 'OK: BF3'
        WHEN MAX(ce.CEIdPlantilla) = 153 THEN 'PLANTILLA VIEJA 153'
        ELSE 'CONFLICTO: OTRA CONFIGURACION'
    END
FROM @Solicitadas s
LEFT JOIN @Empresas e
    ON e.IdEmpresa = s.IdEmpresa
LEFT JOIN dbo.ff_Empresa emp
    ON emp.EMidEmpresa = s.IdEmpresa
LEFT JOIN dbo.ff_CargaMasivaOperacionEmpresa ce
    ON ce.CEIdEmpresa = s.IdEmpresa
   AND ce.CEIdOperacion = 2
   AND ce.CEIdEstatus = 1
LEFT JOIN @Insertadas i
    ON i.IdEmpresa = s.IdEmpresa
LEFT JOIN @Migradas m
    ON m.IdEmpresa = s.IdEmpresa
GROUP BY s.IdEmpresa, e.IdEmpresa, i.IdEmpresa, m.IdEmpresa
ORDER BY s.IdEmpresa;

/* Solo informa cabeceras con BF3; no las modifica. */
SELECT DISTINCT
    CabeceraCorporativa = cab.EMidEmpresa,
    cab.EMNombre,
    ce.CEIdPlantilla,
    ce.CEStoredProc,
    Resultado = 'REVISAR: CONFIGURACION EN CABECERA'
FROM @Empresas x
INNER JOIN dbo.ff_Empresa hija
    ON hija.EMidEmpresa = x.IdEmpresa
INNER JOIN dbo.ff_Empresa cab
    ON cab.EMidEmpresa = hija.EMidCorporativo
   AND cab.EMNivel = 0
INNER JOIN dbo.ff_CargaMasivaOperacionEmpresa ce
    ON ce.CEIdEmpresa = cab.EMidEmpresa
   AND ce.CEIdOperacion = 2
   AND ce.CEIdEstatus = 1
   AND ce.CEIdPlantilla = 12062
ORDER BY cab.EMidEmpresa;
