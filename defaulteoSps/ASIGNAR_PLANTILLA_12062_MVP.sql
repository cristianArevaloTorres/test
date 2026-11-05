/*
    Fuente: Empresas_MVP__021026.xlsx, hoja Empresas_MVP.
    El Excel contiene corporativos; la insercion siempre usa EMIdEmpresa.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Aplicar BIT = 0; -- 0 = solo consultar, 1 = insertar faltantes.
DECLARE @Usuario INT = 5; -- Cambiar por el usuario que libera.
DECLARE @Corporativos TABLE (IdCorporativo INT PRIMARY KEY);
DECLARE @Empresas TABLE (IdEmpresa INT PRIMARY KEY);
DECLARE @Insertadas TABLE (IdEmpresa INT PRIMARY KEY);

INSERT INTO @Corporativos (IdCorporativo)
VALUES
    (59),
    (658),
    (718),
    (721),
    (723),
    (727),
    (752),
    (756),
    (758),
    (760),
    (762),
    (790),
    (797),
    (799),
    (806),
    (812),
    (814),
    (820),
    (840),
    (860),
    (890),
    (929),
    (953),
    (982),
    (1010),
    (1012),
    (1021),
    (1036),
    (1082),
    (1095),
    (1101),
    (1105),
    (1115),
    (1143),
    (1157),
    (1175),
    (1182),
    (1199),
    (1206),
    (1224),
    (1232),
    (1236),
    (1240),
    (1253),
    (1263),
    (1269),
    (1280),
    (1282),
    (1292),
    (1303),
    (1305),
    (1328),
    (1337),
    (1345),
    (1349),
    (1358),
    (1383),
    (1391),
    (1393),
    (1398),
    (1410),
    (1413),
    (1426),
    (1431),
    (1439),
    (1445),
    (1468),
    (1470),
    (1472),
    (1490),
    (1508),
    (1518),
    (1520),
    (1522),
    (1575),
    (1577),
    (1579),
    (1583),
    (1611),
    (1632),
    (1653),
    (1655),
    (1717),
    (1732),
    (1734),
    (1740),
    (1756),
    (1760),
    (1773),
    (1781),
    (1786),
    (1794),
    (1797),
    (1810),
    (1812),
    (1814),
    (1828),
    (1850),
    (1852),
    (1856),
    (1860),
    (1886),
    (1922),
    (1926),
    (1928),
    (1930),
    (1932),
    (1934),
    (1941),
    (1943),
    (1945),
    (1949),
    (1953),
    (1974),
    (1983),
    (2003),
    (2008),
    (2043),
    (2067),
    (2069),
    (2083),
    (2140),
    (2144),
    (2160),
    (2162),
    (2164),
    (2166),
    (2168),
    (2170),
    (2231),
    (2247),
    (2249),
    (2252),
    (2255),
    (2258),
    (2260),
    (2262),
    (2264),
    (2268),
    (2270),
    (2272),
    (2274),
    (2276),
    (2278),
    (2280),
    (2282),
    (2284),
    (2286),
    (2288),
    (2291),
    (2314),
    (2320),
    (2332),
    (2336),
    (2338),
    (2340),
    (2362),
    (2364),
    (2366),
    (2371),
    (2373),
    (2390),
    (2403),
    (2407),
    (2411),
    (2425),
    (2445),
    (2452),
    (2454),
    (2469),
    (2487),
    (2491),
    (2499),
    (2502),
    (2508),
    (2520),
    (2522),
    (2524),
    (2535),
    (2537),
    (2545),
    (2552),
    (2554),
    (2563),
    (2577),
    (2587),
    (2589),
    (2591),
    (2595),
    (2597),
    (2606),
    (2612),
    (2619),
    (2623),
    (2625),
    (2635),
    (2653),
    (2656),
    (2658),
    (2731),
    (2747),
    (2749),
    (2771),
    (2779),
    (2783),
    (2792),
    (2794),
    (2800),
    (2816),
    (2818),
    (2822),
    (2824),
    (2826),
    (2834),
    (2836),
    (2839),
    (2843),
    (2846),
    (2850),
    (2882),
    (2886),
    (2890),
    (2897),
    (2901),
    (2913),
    (2920),
    (2924),
    (2938);

/* Convertir los corporativos del Excel a empresas activas. */
INSERT INTO @Empresas (IdEmpresa)
SELECT DISTINCT e.EMidEmpresa
FROM dbo.ff_Empresa e
INNER JOIN @Corporativos c
    ON c.IdCorporativo = e.EMidCorporativo
WHERE e.EMidEstatus = 1;

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
        THROW 50002, 'No existe el procedimiento ff_XCMTitularesAltaCMM_BF3.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        /* Insertar solo empresas que no tengan configuracion activa de operacion 2. */
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
    CorporativosExcel = (SELECT COUNT(*) FROM @Corporativos),
    EmpresasActivas = (SELECT COUNT(*) FROM @Empresas),
    ConfiguracionesInsertadas = (SELECT COUNT(*) FROM @Insertadas),
    PendientesDeInsertar =
    (
        SELECT COUNT(*)
        FROM @Empresas e
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.ff_CargaMasivaOperacionEmpresa ce
            WHERE ce.CEIdEmpresa = e.IdEmpresa
              AND ce.CEIdOperacion = 2
              AND ce.CEIdEstatus = 1
        )
    );

/* En consulta muestra pendientes y conflictos; despues de aplicar, solo problemas. */
SELECT
    e.IdEmpresa,
    Empresa = MAX(emp.EMNombre),
    ConfiguracionesActivas = COUNT(ce.CEIdOperacionEmpresa),
    PlantillaEncontrada = MAX(ce.CEIdPlantilla),
    Resultado = CASE
        WHEN COUNT(ce.CEIdOperacionEmpresa) = 0 AND @Aplicar = 0 THEN 'PENDIENTE DE INSERTAR'
        WHEN COUNT(ce.CEIdOperacionEmpresa) = 0 THEN 'SIN CONFIGURACION'
        WHEN COUNT(ce.CEIdOperacionEmpresa) > 1 THEN 'CONFLICTO: MAS DE UNA CONFIGURACION ACTIVA'
        ELSE 'CONFLICTO: TIENE OTRA PLANTILLA O PROCEDIMIENTO'
    END
FROM @Empresas e
INNER JOIN dbo.ff_Empresa emp
    ON emp.EMidEmpresa = e.IdEmpresa
LEFT JOIN dbo.ff_CargaMasivaOperacionEmpresa ce
    ON ce.CEIdEmpresa = e.IdEmpresa
   AND ce.CEIdOperacion = 2
   AND ce.CEIdEstatus = 1
GROUP BY e.IdEmpresa
HAVING COUNT(ce.CEIdOperacionEmpresa) <> 1
    OR MAX
       (
           CASE
               WHEN ce.CEIdPlantilla = 12062
                AND RTRIM(ce.CEStoredProc) = 'ff_XCMTitularesAltaCMM_BF3'
                AND ce.CEStoredProcAtributos = 3
                   THEN 1
               ELSE 0
           END
       ) <> 1
ORDER BY e.IdEmpresa;

/* Debe regresar cero filas: corporativos del Excel sin empresas activas. */
SELECT
    c.IdCorporativo,
    Resultado = 'SIN EMPRESAS ACTIVAS'
FROM @Corporativos c
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.ff_Empresa e
    WHERE e.EMidCorporativo = c.IdCorporativo
      AND e.EMidEstatus = 1
)
ORDER BY c.IdCorporativo;
