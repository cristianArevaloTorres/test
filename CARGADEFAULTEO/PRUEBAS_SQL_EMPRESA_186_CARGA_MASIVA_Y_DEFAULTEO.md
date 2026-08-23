# Pruebas SQL de Carga Masiva B2/B3 y Defaulteo 1/2/3 — empresa 186

Fecha de preparación: 22 de agosto de 2026.

## Objetivo y reglas de uso

Este documento permite inspeccionar la configuración real de la empresa `186`, obtener una muestra reproducible de hasta `3,000` empleados y preparar casos para probar:

- resolución independiente de Carga Masiva por pantalla y proceso automático;
- configuración, plantillas, parámetros y stored procedures de B2;
- configuración, plantillas, parámetros y stored procedures de B3;
- candidatos y datos previos para Defaulteo tipo 1, 2 y 3;
- resultados, solicitudes, selecciones y logs después de una simulación desde la aplicación/API.

Todos los bloques son de lectura. La única tabla creada es `#Muestra186`, una tabla temporal de la sesión en `tempdb`; desaparece al cerrar la ventana. No hay `INSERT`, `UPDATE`, `DELETE`, `MERGE`, `TRUNCATE` ni ejecución del motor que crea solicitudes.

No se exportan RFC, CURP, NSS, correo, teléfono, contraseña ni domicilio. Antes de sacar información del ambiente, confirme las reglas de protección de datos aplicables.

> Ejecute primero el bloque **0** y conserve la misma ventana/conexión de SSMS para los bloques siguientes. No agregue `GO`, porque las variables y `#Muestra186` deben permanecer en el mismo batch/sesión. Si únicamente se quiere diagnosticar, ejecute los bloques 0 a 10. El bloque 11 se ejecuta antes y después de una prueba funcional hecha desde B2, B3 o la API.

## Mapa de los recorridos que se validan

| Flujo | Configuración | Descubrimiento de entrada | Ejecución que modifica datos |
|---|---|---|---|
| Carga B2 | `ff_FuncionArchivo` | `ff_CTipoMovimientoMasivo`, `ff_CObtenDocumento`, `ff_CObtenProcedimiento` | SP de `FASp`; cuando hay plantilla usa además `ff_InsertaTmpPoblacion`, `ff_InsertaTmpPoblacion1` y `ff_IInsertaPoblacion` |
| Carga B3 | `ff_CargaMasivaOperacionEmpresa` | `ff_CCMOperacionesEmpresaAdm`, `ff_CObtenPlantilla2`, `ff_CObtenCatalogoPlantilla` | `ff_cargaMasivaGen` invoca el `CEStoredProc` de la operación |
| Defaulteo 1/2/3 | `ff_TipoDefaulteo`, empresa, vigencia y perfil | `bf_DefaulteoEmpleados` o `bf_DefaulteoAvanzado_Buscar` | `ff_CBuscaPlanesPerfil_V31Test` o su variante multivigencia; después inserta selección temporal y ejecuta `ff_CreateSolicitudTest` |

Los tokens que recibe el motor son `def1`, `def2` y `def3`; no son los números `1`, `2` y `3`.

## 0. Parámetros, empresa y vigencias

Cambie únicamente `@IdVigenciaDestino`, `@FechaInicio` o `@FechaFin` si QA requiere un caso específico. Cuando `@IdVigenciaDestino` es `NULL`, se toma primero la vigencia activa por fecha y, si no existe, la más reciente activa de la configuración de la empresa.

```sql
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET LOCK_TIMEOUT 15000;

DECLARE @IdEmpresa            INT  = 186;
DECLARE @Tope                 INT  = 3000;
DECLARE @IdVigenciaDestino    INT  = NULL; -- NULL = resolver automáticamente.
DECLARE @FechaInicio          DATE = DATEADD(DAY, -90, CONVERT(DATE, GETDATE()));
DECLARE @FechaFin             DATE = CONVERT(DATE, GETDATE());
DECLARE @IdCorporativo        INT;
DECLARE @IdConfiguracion      INT;
DECLARE @IdVigenciaOrigen     INT;
DECLARE @IdsEmpresaCsv        NVARCHAR(MAX) = CONVERT(NVARCHAR(20), @IdEmpresa);

IF @Tope NOT BETWEEN 1 AND 3000
    THROW 51000, 'El límite debe estar entre 1 y 3000.', 1;

SELECT
    @IdCorporativo   = E.EMIdCorporativo,
    @IdConfiguracion = E.EMIdConfiguracion
FROM dbo.ff_Empresa E
WHERE E.EMIdEmpresa = @IdEmpresa;

IF @IdCorporativo IS NULL
    THROW 51001, 'La empresa 186 no existe en esta base.', 1;

IF @IdVigenciaDestino IS NULL
BEGIN
    SELECT TOP (1) @IdVigenciaDestino = V.VIIdVigencia
    FROM dbo.ff_Vigencia V
    WHERE V.VIIdConfiguracion = @IdConfiguracion
      AND V.VIIdEstatus = 1
      AND CONVERT(DATE, GETDATE())
          BETWEEN CONVERT(DATE, V.VIVigenciaIni) AND CONVERT(DATE, V.VIVigenciaFin)
    ORDER BY V.VIVigenciaIni DESC, V.VIIdVigencia DESC;

    IF @IdVigenciaDestino IS NULL
        SELECT TOP (1) @IdVigenciaDestino = V.VIIdVigencia
        FROM dbo.ff_Vigencia V
        WHERE V.VIIdConfiguracion = @IdConfiguracion
          AND V.VIIdEstatus = 1
        ORDER BY V.VIVigenciaIni DESC, V.VIIdVigencia DESC;
END;

SELECT @IdVigenciaOrigen = V.VIRenovada
FROM dbo.ff_Vigencia V
WHERE V.VIIdVigencia = @IdVigenciaDestino
  AND V.VIIdConfiguracion = @IdConfiguracion;

SELECT
    E.EMIdEmpresa AS idEmpresa,
    E.EMNombre AS empresa,
    E.EMRazonSocial AS razonSocial,
    E.EMIdCorporativo AS idCorporativo,
    E.EMIdConfiguracion AS idConfiguracion,
    E.EMIdEstatus AS estatusEmpresa,
    @IdVigenciaDestino AS idVigenciaDestino,
    @IdVigenciaOrigen AS idVigenciaOrigen,
    @Tope AS limiteMuestra,
    @FechaInicio AS fechaInicio,
    @FechaFin AS fechaFin
FROM dbo.ff_Empresa E
WHERE E.EMIdEmpresa = @IdEmpresa;

SELECT TOP (20)
    V.VIIdVigencia,
    V.VINombre,
    V.VIVigenciaIni,
    V.VIVigenciaFin,
    V.VIRenovada,
    V.VIIdEstatus,
    CASE WHEN V.VIIdVigencia = @IdVigenciaDestino THEN 'DESTINO'
         WHEN V.VIIdVigencia = @IdVigenciaOrigen THEN 'ORIGEN'
         ELSE NULL END AS usoPrueba
FROM dbo.ff_Vigencia V
WHERE V.VIIdConfiguracion = @IdConfiguracion
ORDER BY V.VIVigenciaIni DESC, V.VIIdVigencia DESC;
```

Resultado esperado: una sola empresa y una vigencia destino válida. Para tipos 1 y 3 también debe existir `idVigenciaOrigen`; si es `NULL`, esa vigencia no está relacionada mediante `VIRenovada` y no es un caso válido para esos recorridos.

## 1. Verificación de despliegue y contratos

```sql
;WITH ObjetosRequeridos AS
(
    SELECT *
    FROM (VALUES
        ('U', 'bf_ConfiguracionFlujoCargaMasiva'),
        ('U', 'ff_TipoDefaulteo'),
        ('U', 'bf_LogDefaulteo'),
        ('U', 'bf_LogErroresDefaulteo'),
        ('P', 'bf_CargaMasivaFlujo_Obtener'),
        ('P', 'bf_CargaMasivaFlujo_Resolver'),
        ('P', 'bf_DefaulteoAvanzado_ResolverVigencia'),
        ('P', 'bf_DefaulteoAvanzado_Buscar'),
        ('P', 'bf_DefaulteoEmpleados'),
        ('P', 'bf_ReporteDefaulteo_Consultar'),
        ('P', 'ff_CTipoMovimientoMasivo'),
        ('P', 'ff_CObtenDocumento'),
        ('P', 'ff_CObtenProcedimiento'),
        ('P', 'ff_CCMOperacionesEmpresaAdm'),
        ('P', 'ff_CObtenPlantilla2'),
        ('P', 'ff_CObtenCatalogoPlantilla'),
        ('P', 'ff_cargaMasivaGen'),
        ('P', 'ff_CBuscaPlanesPerfil_V31Test'),
        ('P', 'ff_CBuscaPlanesPerfil_V31TesMultivigenciaBF3'),
        ('P', 'ff_IInsertaPlanesPerfilTmp'),
        ('P', 'ff_IInsertaPlanesPerfilTmpTestMultivigenciaBF3'),
        ('P', 'ff_CreateSolicitudTest')
    ) X(tipo, objeto)
)
SELECT
    R.tipo,
    R.objeto,
    CASE WHEN OBJECT_ID(N'dbo.' + R.objeto, R.tipo) IS NULL
         THEN 'FALTA' ELSE 'OK' END AS resultado,
    O.modify_date AS ultimaModificacion
FROM ObjetosRequeridos R
LEFT JOIN sys.objects O
  ON O.object_id = OBJECT_ID(N'dbo.' + R.objeto, R.tipo)
ORDER BY resultado, R.tipo, R.objeto;

SELECT
    P.name AS procedimiento,
    PA.parameter_id,
    PA.name AS parametro,
    TYPE_NAME(PA.user_type_id) AS tipo,
    PA.max_length,
    PA.precision,
    PA.scale,
    PA.is_output
FROM sys.procedures P
INNER JOIN sys.parameters PA ON PA.object_id = P.object_id
WHERE P.name IN
(
    'bf_CargaMasivaFlujo_Obtener',
    'bf_CargaMasivaFlujo_Resolver',
    'bf_DefaulteoAvanzado_ResolverVigencia',
    'bf_DefaulteoAvanzado_Buscar',
    'bf_ReporteDefaulteo_Consultar',
    'ff_CBuscaPlanesPerfil_V31Test',
    'ff_CBuscaPlanesPerfil_V31TesMultivigenciaBF3',
    'ff_IInsertaPlanesPerfilTmp',
    'ff_IInsertaPlanesPerfilTmpTestMultivigenciaBF3',
    'ff_CreateSolicitudTest'
)
ORDER BY P.name, PA.parameter_id;
```

Resultado esperado: ningún objeto en `FALTA`. La lista de parámetros permite detectar si la aplicación fue desplegada contra una versión de BD incompatible.

## 2. Resolución real y simulada del selector B2/B3

```sql
SELECT
    @IdEmpresa AS idEmpresa,
    C.CFFlujoPantalla AS flujoPantallaGuardado,
    C.CFFlujoAutomatico AS flujoAutomaticoGuardado,
    C.CFIdEstatus,
    CASE WHEN C.CFIdEmpresa IS NULL THEN 0 ELSE 1 END AS configurado,
    CASE WHEN C.CFIdEmpresa IS NULL THEN 1
         WHEN C.CFFlujoPantalla = 'B2' THEN 1 ELSE 0 END AS pantallaB2Permitida,
    CASE WHEN C.CFIdEmpresa IS NULL THEN 1
         WHEN C.CFFlujoPantalla = 'B3' THEN 1 ELSE 0 END AS pantallaB3Permitida,
    CASE WHEN C.CFIdEmpresa IS NULL THEN 'B2'
         ELSE C.CFFlujoAutomatico END AS flujoAutomaticoResuelto,
    C.CFUsuarioAdd,
    C.CFFechaAdd,
    C.CFUsuarioUMod,
    C.CFFechaUMod
FROM (SELECT 1 AS n) X
LEFT JOIN dbo.bf_ConfiguracionFlujoCargaMasiva C
  ON C.CFIdEmpresa = @IdEmpresa
 AND C.CFIdEstatus = 1;

IF OBJECT_ID('dbo.bf_CargaMasivaFlujo_Obtener', 'P') IS NOT NULL
    EXEC dbo.bf_CargaMasivaFlujo_Obtener @IdEmpresa = @IdEmpresa;

IF OBJECT_ID('dbo.bf_CargaMasivaFlujo_Resolver', 'P') IS NOT NULL
BEGIN
    EXEC dbo.bf_CargaMasivaFlujo_Resolver
         @IdEmpresa = @IdEmpresa, @Canal = 'PANTALLA';
    EXEC dbo.bf_CargaMasivaFlujo_Resolver
         @IdEmpresa = @IdEmpresa, @Canal = 'AUTOMATICO';
END;

;WITH Escenarios AS
(
    SELECT * FROM (VALUES
        ('SIN FILA', NULL, NULL),
        ('B2 / B2', 'B2', 'B2'),
        ('B2 / B3', 'B2', 'B3'),
        ('B3 / B2', 'B3', 'B2'),
        ('B3 / B3', 'B3', 'B3')
    ) V(escenario, flujoPantalla, flujoAutomatico)
)
SELECT
    escenario,
    CASE WHEN flujoPantalla IS NULL THEN 'B2 y B3'
         ELSE flujoPantalla END AS pantallasPermitidas,
    COALESCE(flujoAutomatico, 'B2') AS automaticoResuelto
FROM Escenarios;
```

Resultado esperado:

- sin fila activa, las dos pantallas son compatibles y automático resuelve B2;
- con fila activa, pantalla y automático se resuelven independientemente;
- compare el primer `SELECT` con las respuestas de ambos SP. Una diferencia indica contrato o despliegue inconsistente.

## 3. B2: funciones, archivos, SP e inputs reales

```sql
SELECT TOP (200)
    FA.FAIdFuncion,
    FA.FANombre,
    FA.FADescripcion,
    FA.FATitular,
    FA.FAIdPlantilla,
    LTRIM(RTRIM(FA.FASp)) AS storedProcedure,
    CASE WHEN OBJECT_ID(LTRIM(RTRIM(FA.FASp)), 'P') IS NULL
         THEN 'SP NO EXISTE' ELSE 'OK' END AS validacionSP,
    CASE WHEN FA.FAIdPlantilla IS NULL
         THEN '@IdDocumento, @IdEmpresa, @EMUsuarioUMod, @Path'
         ELSE '@IdFuncion, @IdDocumento, @IdEmpresa, @IdPerfil, @Path, @Acceso, @EMUsuarioUMod'
    END AS contratoUsadoPorB2
FROM dbo.ff_FuncionArchivo FA
WHERE FA.FAIdEmpresa = @IdEmpresa
ORDER BY FA.FAIdFuncion;

SELECT TOP (200)
    FA.FAIdFuncion,
    FA.FANombre,
    A.DOId AS idDocumento,
    A.DONombreDocumento AS archivo,
    A.DODescripcion,
    A.DOEncabezado,
    A.DOSeparadorColumnas,
    A.DOBloqueoStatus,
    A.DOFechaBloqueo
FROM dbo.ff_FuncionArchivo FA
LEFT JOIN dbo.ff_CargaMasivaArchivo A
  ON A.DOIdFuncion = FA.FAIdFuncion
 AND A.DOIdEmpresa = @IdEmpresa
WHERE FA.FAIdEmpresa = @IdEmpresa
ORDER BY FA.FAIdFuncion, A.DOId DESC;

SELECT
    FA.FAIdFuncion,
    FA.FANombre,
    LTRIM(RTRIM(FA.FASp)) AS storedProcedure,
    P.parameter_id,
    P.name AS parametro,
    TYPE_NAME(P.user_type_id) AS tipo,
    P.max_length,
    P.is_output
FROM dbo.ff_FuncionArchivo FA
LEFT JOIN sys.parameters P
  ON P.object_id = OBJECT_ID(LTRIM(RTRIM(FA.FASp)), 'P')
WHERE FA.FAIdEmpresa = @IdEmpresa
ORDER BY FA.FAIdFuncion, P.parameter_id;

SELECT DISTINCT
    FA.FAIdFuncion,
    FA.FANombre,
    LTRIM(RTRIM(FA.FASp)) AS storedProcedure,
    COALESCE(D.referenced_schema_name, 'dbo') AS esquemaDependencia,
    D.referenced_entity_name AS tablaOProcedimientoDependiente
FROM dbo.ff_FuncionArchivo FA
LEFT JOIN sys.sql_expression_dependencies D
  ON D.referencing_id = OBJECT_ID(LTRIM(RTRIM(FA.FASp)), 'P')
WHERE FA.FAIdEmpresa = @IdEmpresa
ORDER BY FA.FAIdFuncion, tablaOProcedimientoDependiente;
```

Cómo interpretar B2:

- `FAIdPlantilla IS NULL`: B2 entrega cuatro parámetros directamente al SP.
- `FAIdPlantilla IS NOT NULL`: B2 carga el TXT a tablas temporales/lógicas y llama al SP con siete parámetros, incluyendo `@Acceso`.
- `SP NO EXISTE`, parámetros faltantes o dependencias no resueltas bloquean esa función aunque el selector general indique B2.

## 4. B3: operaciones, plantillas, SP e inputs reales

```sql
SELECT TOP (200)
    CE.CEIdOperacionEmpresa,
    O.COIdOperacion,
    O.CONombre,
    O.CODescripcion,
    O.COTabla,
    CE.CEIdPlantilla,
    P.PLDescripcion AS plantilla,
    LTRIM(RTRIM(CE.CEStoredProc)) AS storedProcedure,
    CE.CEStoredProcAtributos,
    CASE WHEN OBJECT_ID(LTRIM(RTRIM(CE.CEStoredProc)), 'P') IS NULL
         THEN 'SP NO EXISTE' ELSE 'OK' END AS validacionSP,
    CASE
      WHEN EXISTS
      (
          SELECT 1 FROM sys.parameters SP
          WHERE SP.object_id = OBJECT_ID(LTRIM(RTRIM(CE.CEStoredProc)), 'P')
            AND SP.name = '@EMIdAcceso'
      ) THEN 'EMIdAcceso'
      WHEN EXISTS
      (
          SELECT 1 FROM sys.parameters SP
          WHERE SP.object_id = OBJECT_ID(LTRIM(RTRIM(CE.CEStoredProc)), 'P')
            AND SP.name = '@Acceso'
      ) THEN 'Acceso'
      WHEN EXISTS
      (
          SELECT 1
          FROM dbo.ff_ConfiguracionPlantilla CPX
          INNER JOIN dbo.ff_Campo CX ON CX.CAIdCampo = CPX.CAIdCampo
          WHERE CPX.PLIdPlantilla = CE.CEIdPlantilla
            AND CPX.CPIdEstatus = 1
            AND CX.CAIdEstatus = 1
            AND LTRIM(RTRIM(CX.CANombreCampo)) = 'EMIdAcceso'
      ) THEN 'EMIdAcceso (plantilla)'
      ELSE NULL
    END AS parametroAcceso
FROM dbo.ff_CargaMasivaOperacionEmpresa CE
INNER JOIN dbo.ff_CargaMasivaOperacion O
  ON O.COIdOperacion = CE.CEIdOperacion
LEFT JOIN dbo.ff_Plantilla P
  ON P.PLIdPlantilla = CE.CEIdPlantilla
WHERE CE.CEIdEmpresa = @IdEmpresa
  AND CE.CEIdEstatus = 1
ORDER BY O.COIdOperacion;

SELECT
    O.COIdOperacion,
    O.CONombre AS operacion,
    CE.CEIdPlantilla,
    CP.CPOrden,
    LTRIM(RTRIM(CP.CPEtiqueta)) AS encabezadoExcel,
    LTRIM(RTRIM(C.CANombreCampo)) AS parametroSQL,
    C.CATipoValor,
    C.CALongitud,
    CP.CPRequerido,
    CP.CPRangoValores,
    CP.CPVisible,
    CP.CPHabilitado
FROM dbo.ff_CargaMasivaOperacionEmpresa CE
INNER JOIN dbo.ff_CargaMasivaOperacion O
  ON O.COIdOperacion = CE.CEIdOperacion
INNER JOIN dbo.ff_ConfiguracionPlantilla CP
  ON CP.PLIdPlantilla = CE.CEIdPlantilla
 AND CP.CPIdEstatus = 1
INNER JOIN dbo.ff_Campo C
  ON C.CAIdCampo = CP.CAIdCampo
 AND C.CAIdEstatus = 1
WHERE CE.CEIdEmpresa = @IdEmpresa
  AND CE.CEIdEstatus = 1
ORDER BY O.COIdOperacion, CP.CPOrden, CP.CPIdConfiguracionPlantilla;

SELECT
    O.COIdOperacion,
    O.CONombre AS operacion,
    LTRIM(RTRIM(CE.CEStoredProc)) AS storedProcedure,
    SP.parameter_id,
    SP.name AS parametro,
    TYPE_NAME(SP.user_type_id) AS tipo,
    SP.max_length,
    SP.precision,
    SP.scale,
    SP.is_output
FROM dbo.ff_CargaMasivaOperacionEmpresa CE
INNER JOIN dbo.ff_CargaMasivaOperacion O
  ON O.COIdOperacion = CE.CEIdOperacion
LEFT JOIN sys.parameters SP
  ON SP.object_id = OBJECT_ID(LTRIM(RTRIM(CE.CEStoredProc)), 'P')
WHERE CE.CEIdEmpresa = @IdEmpresa
  AND CE.CEIdEstatus = 1
ORDER BY O.COIdOperacion, SP.parameter_id;

SELECT DISTINCT
    O.COIdOperacion,
    O.CONombre AS operacion,
    LTRIM(RTRIM(CE.CEStoredProc)) AS storedProcedure,
    COALESCE(D.referenced_schema_name, 'dbo') AS esquemaDependencia,
    D.referenced_entity_name AS tablaOProcedimientoDependiente
FROM dbo.ff_CargaMasivaOperacionEmpresa CE
INNER JOIN dbo.ff_CargaMasivaOperacion O
  ON O.COIdOperacion = CE.CEIdOperacion
LEFT JOIN sys.sql_expression_dependencies D
  ON D.referencing_id = OBJECT_ID(LTRIM(RTRIM(CE.CEStoredProc)), 'P')
WHERE CE.CEIdEmpresa = @IdEmpresa
  AND CE.CEIdEstatus = 1
ORDER BY O.COIdOperacion, tablaOProcedimientoDependiente;
```

Resultado esperado: cada operación activa tiene plantilla, SP existente y correspondencia entre columnas de plantilla y parámetros del SP. El selector de acceso sólo debe mostrarse cuando `parametroAcceso` tenga valor.

## 5. Comparación automática de los inputs B3 contra el SP

Este bloque marca campos definidos sólo en la plantilla y parámetros definidos sólo en el SP. Los parámetros de control que el backend agregue fuera del Excel deben revisarse manualmente.

```sql
;WITH Operaciones AS
(
    SELECT
        O.COIdOperacion,
        O.CONombre,
        CE.CEIdPlantilla,
        LTRIM(RTRIM(CE.CEStoredProc)) AS storedProcedure
    FROM dbo.ff_CargaMasivaOperacionEmpresa CE
    INNER JOIN dbo.ff_CargaMasivaOperacion O
      ON O.COIdOperacion = CE.CEIdOperacion
    WHERE CE.CEIdEmpresa = @IdEmpresa
      AND CE.CEIdEstatus = 1
), CamposPlantilla AS
(
    SELECT
        OP.COIdOperacion,
        LTRIM(RTRIM(C.CANombreCampo)) AS nombre
    FROM Operaciones OP
    INNER JOIN dbo.ff_ConfiguracionPlantilla CP
      ON CP.PLIdPlantilla = OP.CEIdPlantilla
     AND CP.CPIdEstatus = 1
    INNER JOIN dbo.ff_Campo C
      ON C.CAIdCampo = CP.CAIdCampo
     AND C.CAIdEstatus = 1
), ParametrosSP AS
(
    SELECT
        OP.COIdOperacion,
        STUFF(SP.name, 1, 1, '') AS nombre
    FROM Operaciones OP
    INNER JOIN sys.parameters SP
      ON SP.object_id = OBJECT_ID(OP.storedProcedure, 'P')
    WHERE SP.is_output = 0
), SoloPlantilla AS
(
    SELECT COIdOperacion, nombre, 'SOLO_PLANTILLA' AS diferencia
    FROM CamposPlantilla
    EXCEPT
    SELECT COIdOperacion, nombre, 'SOLO_PLANTILLA'
    FROM ParametrosSP
), SoloSP AS
(
    SELECT COIdOperacion, nombre, 'SOLO_SP' AS diferencia
    FROM ParametrosSP
    EXCEPT
    SELECT COIdOperacion, nombre, 'SOLO_SP'
    FROM CamposPlantilla
), Diferencias AS
(
    SELECT COIdOperacion, nombre, diferencia FROM SoloPlantilla
    UNION ALL
    SELECT COIdOperacion, nombre, diferencia FROM SoloSP
)
SELECT
    OP.COIdOperacion,
    OP.CONombre,
    OP.storedProcedure,
    D.diferencia,
    D.nombre
FROM Diferencias D
INNER JOIN Operaciones OP ON OP.COIdOperacion = D.COIdOperacion
ORDER BY OP.COIdOperacion, D.diferencia, D.nombre;
```

Un resultado vacío significa coincidencia exacta. `SOLO_SP` no siempre es error: por ejemplo, el backend puede agregar `EMIdAcceso`, usuario o empresa. Cada diferencia debe compararse con la lógica de la operación.

## 6. Muestra estratificada de hasta 3,000 empleados

La muestra prioriza variedad de estatus, parentesco y perfil. Sólo conserva identificadores y datos funcionales mínimos.

```sql
DROP TABLE IF EXISTS #Muestra186;

;WITH Universo AS
(
    SELECT
        E.Id,
        E.EMIdEmpresa,
        E.EMNumeroEmpleado,
        E.EMIdTitular,
        E.EMIdPerfil,
        E.EMIdParentesco,
        E.EMIdSexo,
        E.EMIdAcceso,
        E.EMIdEstatus,
        E.EMOficina,
        E.EMArea,
        E.EMSalarioBase,
        E.EMFechaIngresoEmpresa,
        E.EMFechaAntiguedadGMM,
        E.EMFechaNacimiento,
        ROW_NUMBER() OVER
        (
            PARTITION BY E.EMIdEstatus, E.EMIdParentesco, E.EMIdPerfil
            ORDER BY E.Id DESC
        ) AS filaEstrato
    FROM dbo.ff_Empleado E
    WHERE E.EMIdEmpresa = @IdEmpresa
)
SELECT TOP (@Tope)
    U.Id,
    U.EMIdEmpresa,
    U.EMNumeroEmpleado,
    U.EMIdTitular,
    U.EMIdPerfil,
    U.EMIdParentesco,
    U.EMIdSexo,
    U.EMIdAcceso,
    U.EMIdEstatus,
    U.EMOficina,
    U.EMArea,
    U.EMSalarioBase,
    U.EMFechaIngresoEmpresa,
    U.EMFechaAntiguedadGMM,
    U.EMFechaNacimiento
INTO #Muestra186
FROM Universo U
ORDER BY U.filaEstrato, U.EMIdEstatus, U.EMIdParentesco, U.EMIdPerfil, U.Id DESC;

CREATE UNIQUE CLUSTERED INDEX IX_Muestra186_Id ON #Muestra186(Id);

SELECT COUNT(*) AS registrosMuestra FROM #Muestra186;

SELECT TOP (@Tope)
    M.*,
    P.PENombre AS perfil
FROM #Muestra186 M
LEFT JOIN dbo.ff_Perfil P
  ON P.PEIdPerfil = M.EMIdPerfil
ORDER BY M.Id;

SELECT
    M.EMIdEstatus,
    M.EMIdParentesco,
    M.EMIdPerfil,
    P.PENombre AS perfil,
    COUNT(*) AS empleados
FROM #Muestra186 M
LEFT JOIN dbo.ff_Perfil P ON P.PEIdPerfil = M.EMIdPerfil
GROUP BY M.EMIdEstatus, M.EMIdParentesco, M.EMIdPerfil, P.PENombre
ORDER BY empleados DESC, M.EMIdEstatus, M.EMIdParentesco, M.EMIdPerfil;
```

`registrosMuestra` nunca debe superar `3,000`. Si devuelve cero, la empresa existe pero no tiene empleados en esta base.

## 7. Preparación de Defaulteo 1, 2 y 3

### 7.1 Catálogo, vigencia y SP del motor

```sql
SELECT
    TD.TDIdTipoDefaulteo,
    TD.TDNombre,
    TD.TDDescripcion,
    TD.TDIdEstatus,
    CASE TD.TDIdTipoDefaulteo
         WHEN 1 THEN 'def1'
         WHEN 2 THEN 'def2'
         WHEN 3 THEN 'def3'
         ELSE NULL END AS tokenMotor
FROM dbo.ff_TipoDefaulteo TD
ORDER BY TD.TDIdTipoDefaulteo;

IF OBJECT_ID('dbo.bf_DefaulteoAvanzado_ResolverVigencia', 'P') IS NOT NULL
   AND @IdVigenciaDestino IS NOT NULL
    EXEC dbo.bf_DefaulteoAvanzado_ResolverVigencia
         @IdEmpresa = @IdEmpresa,
         @IdVigenciaSeleccionada = @IdVigenciaDestino;

SELECT
    P.name AS procedimiento,
    PA.parameter_id,
    PA.name AS parametro,
    TYPE_NAME(PA.user_type_id) AS tipo,
    PA.max_length
FROM sys.procedures P
INNER JOIN sys.parameters PA ON PA.object_id = P.object_id
WHERE P.name IN
(
    'ff_CBuscaPlanesPerfil_V31Test',
    'ff_CBuscaPlanesPerfil_V31TesMultivigenciaBF3',
    'ff_IInsertaPlanesPerfilTmp',
    'ff_IInsertaPlanesPerfilTmpTestMultivigenciaBF3',
    'ff_CreateSolicitudTest'
)
ORDER BY P.name, PA.parameter_id;
```

### 7.2 Matriz de preparación por empleado

La matriz no promete que el motor actuarial aprobará el caso: confirma que existen los insumos principales para llevarlo hasta el motor.

```sql
;WITH Candidatos AS
(
    SELECT TOP (@Tope)
        M.Id,
        M.EMNumeroEmpleado,
        M.EMIdPerfil,
        M.EMIdAcceso,
        M.EMIdEstatus
    FROM #Muestra186 M
    WHERE M.EMIdEstatus = 1
      AND M.EMIdParentesco = 1
    ORDER BY M.Id DESC
)
SELECT
    C.Id AS idEmpleado,
    C.EMNumeroEmpleado AS numeroEmpleado,
    C.EMIdPerfil AS idPerfil,
    C.EMIdAcceso AS acceso,
    @IdVigenciaOrigen AS idVigenciaOrigen,
    @IdVigenciaDestino AS idVigenciaDestino,
    ISNULL(SO.solicitudesOrigenAprobadas, 0) AS solicitudesOrigenAprobadas,
    ISNULL(PO.seleccionesOrigen, 0) AS seleccionesOrigen,
    ISNULL(PB.planesBasicosDestino, 0) AS planesBasicosDestino,
    ISNULL(D.dependientesActivos, 0) AS dependientesActivos,
    ISNULL(SD.solicitudesDestinoActivas, 0) AS solicitudesDestinoActivas,
    CASE WHEN @IdVigenciaOrigen IS NOT NULL
                   AND ISNULL(SO.solicitudesOrigenAprobadas, 0) > 0
                   AND ISNULL(PO.seleccionesOrigen, 0) > 0
                   AND ISNULL(SD.solicitudesDestinoActivas, 0) = 0
              THEN 'LISTO' ELSE 'REVISAR' END AS tipo1,
    CASE WHEN ISNULL(PB.planesBasicosDestino, 0) > 0
                   AND ISNULL(SD.solicitudesDestinoActivas, 0) = 0
              THEN 'LISTO' ELSE 'REVISAR' END AS tipo2,
    CASE WHEN @IdVigenciaOrigen IS NOT NULL
                   AND ISNULL(SO.solicitudesOrigenAprobadas, 0) > 0
                   AND ISNULL(PO.seleccionesOrigen, 0) > 0
                   AND ISNULL(SD.solicitudesDestinoActivas, 0) = 0
              THEN CASE WHEN ISNULL(D.dependientesActivos, 0) > 0
                        THEN 'LISTO CON DEPENDIENTES'
                        ELSE 'LISTO SIN DEPENDIENTES' END
              ELSE 'REVISAR' END AS tipo3
FROM Candidatos C
OUTER APPLY
(
    SELECT COUNT(*) AS solicitudesOrigenAprobadas
    FROM dbo.ff_Solicitud S
    WHERE S.SOIdEmpleado = C.Id
      AND S.SOIdEmpresa = @IdEmpresa
      AND S.SOIdVigencia = @IdVigenciaOrigen
      AND S.SOIdEstatus = 1
      AND S.SOEstatusSolicitud = 1
) SO
OUTER APPLY
(
    SELECT COUNT(*) AS seleccionesOrigen
    FROM dbo.ff_PlanOpcionSeleccion POS
    WHERE POS.POIdEmpleado = C.Id
      AND POS.POIdEmpresa = @IdEmpresa
      AND POS.POIdVigencia = @IdVigenciaOrigen
      AND POS.POIdEstatus = 1
) PO
OUTER APPLY
(
    SELECT COUNT(*) AS planesBasicosDestino
    FROM dbo.ff_PlanBasico B
    INNER JOIN dbo.ff_PlanOpcion O
      ON O.POIdPlanOpcion = B.PBIdPlanOpcion
     AND O.POIdEstatus = 1
    WHERE B.PBIdPerfil = C.EMIdPerfil
      AND B.PBIdVigencia = @IdVigenciaDestino
      AND B.PBIdEstatus = 1
) PB
OUTER APPLY
(
    SELECT COUNT(*) AS dependientesActivos
    FROM dbo.ff_Empleado DEP
    WHERE DEP.EMIdEmpresa = @IdEmpresa
      AND DEP.EMIdTitular = C.Id
      AND DEP.EMIdParentesco <> 1
      AND DEP.EMIdEstatus = 1
) D
OUTER APPLY
(
    SELECT COUNT(*) AS solicitudesDestinoActivas
    FROM dbo.ff_Solicitud S
    WHERE S.SOIdEmpleado = C.Id
      AND S.SOIdEmpresa = @IdEmpresa
      AND S.SOIdVigencia = @IdVigenciaDestino
      AND S.SOIdEstatus = 1
      AND S.SOEstatusSolicitud IN (1, 3)
) SD
ORDER BY
    CASE WHEN ISNULL(SD.solicitudesDestinoActivas, 0) = 0 THEN 0 ELSE 1 END,
    C.Id DESC;
```

Interpretación:

- Tipo 1: necesita solicitud y selecciones aprobadas en la vigencia origen, además de no tener solicitud activa en destino.
- Tipo 2: necesita plan básico/espejo activo para el perfil en destino y no tener solicitud activa en destino.
- Tipo 3: necesita la selección anterior; la presencia de dependientes activos ayuda a probar el objetivo específico de actualización de familia. También conviene incluir al menos un caso sin dependientes como control.

### 7.3 Resumen sin devolver miles de filas

```sql
SELECT
    COUNT(*) AS empleadosEmpresa,
    SUM(CASE WHEN E.EMIdEstatus = 1 THEN 1 ELSE 0 END) AS empleadosActivos,
    SUM(CASE WHEN E.EMIdEstatus = 1 AND E.EMIdParentesco = 1 THEN 1 ELSE 0 END) AS titularesActivos,
    SUM(CASE WHEN E.EMIdEstatus = 1 AND E.EMIdParentesco <> 1 THEN 1 ELSE 0 END) AS dependientesActivos,
    SUM(CASE WHEN E.EMIdAcceso = 1 THEN 1 ELSE 0 END) AS accesoHabilitado,
    SUM(CASE WHEN E.EMIdAcceso = 0 THEN 1 ELSE 0 END) AS accesoDeshabilitado
FROM dbo.ff_Empleado E
WHERE E.EMIdEmpresa = @IdEmpresa;

SELECT
    S.SOIdVigencia,
    S.SOIdEstatus,
    S.SOEstatusSolicitud,
    COUNT(*) AS solicitudes
FROM dbo.ff_Solicitud S
WHERE S.SOIdEmpresa = @IdEmpresa
  AND S.SOIdVigencia IN (@IdVigenciaOrigen, @IdVigenciaDestino)
GROUP BY S.SOIdVigencia, S.SOIdEstatus, S.SOEstatusSolicitud
ORDER BY S.SOIdVigencia, S.SOIdEstatus, S.SOEstatusSolicitud;

SELECT
    POS.POIdVigencia,
    POS.PODefaulteo,
    POS.POIdEstatus,
    COUNT(*) AS selecciones
FROM dbo.ff_PlanOpcionSeleccion POS
WHERE POS.POIdEmpresa = @IdEmpresa
  AND POS.POIdVigencia IN (@IdVigenciaOrigen, @IdVigenciaDestino)
GROUP BY POS.POIdVigencia, POS.PODefaulteo, POS.POIdEstatus
ORDER BY POS.POIdVigencia, POS.PODefaulteo, POS.POIdEstatus;
```

## 8. Búsqueda avanzada real, limitada a 3,000

Este procedimiento es de consulta y su propio parámetro `@Top` aplica el límite. Se ejecuta sólo cuando la vigencia y el SP existen.

```sql
IF @IdVigenciaDestino IS NULL
    SELECT 'OMITIDO: no se resolvió vigencia destino.' AS resultado;
ELSE IF OBJECT_ID('dbo.bf_DefaulteoAvanzado_Buscar', 'P') IS NULL
    SELECT 'OMITIDO: falta bf_DefaulteoAvanzado_Buscar.' AS resultado;
ELSE
    EXEC dbo.bf_DefaulteoAvanzado_Buscar
         @IdCorporativo      = @IdCorporativo,
         @IdVigencia         = @IdVigenciaDestino,
         @IdsEmpresa         = @IdsEmpresaCsv,
         @IdsPerfil          = NULL,
         @IdsOficina         = NULL,
         @IdsArea            = NULL,
         @IdsSexo            = NULL,
         @IdsParentesco      = N'1',
         @IdsPlan            = NULL,
         @IdsCobertura       = NULL,
         @NumerosEmpleado    = NULL,
         @SalarioMin         = NULL,
         @SalarioMax         = NULL,
         @SumaAseguradaMin   = NULL,
         @SumaAseguradaMax   = NULL,
         @FechaIngresoIni    = NULL,
         @FechaIngresoFin    = NULL,
         @FechaAntiguedadIni = NULL,
         @FechaAntiguedadFin = NULL,
         @FechaNacimientoIni = NULL,
         @FechaNacimientoFin = NULL,
         @FechaVigenciaIni   = NULL,
         @FechaVigenciaFin   = NULL,
         @Nombre             = NULL,
         @ApellidoPaterno    = NULL,
         @ApellidoMaterno    = NULL,
         @EdadMin            = NULL,
         @EdadMax            = NULL,
         @Top                = @Tope;
```

Para una primera simulación funcional no use los 3,000 candidatos: elija entre 5 y 10 IDs de la matriz del bloque 7.2, repartidos entre tipos 1, 2 y 3.

## 9. Paquete relacional de la muestra para análisis local

Cada conjunto está limitado de forma independiente a `3,000` filas. Esto sirve para analizar relaciones y resultados, no para insertar directamente en otra base: las tablas tienen más catálogos y llaves foráneas que deben conservarse.

```sql
SELECT TOP (@Tope)
    M.*
FROM #Muestra186 M
ORDER BY M.Id;

SELECT TOP (@Tope)
    S.SOIdSolicitud,
    S.SOIdEmpresa,
    S.SOIdEmpleado,
    S.SONumEmpleado,
    S.SOIdEstatus,
    S.SOEstatusSolicitud,
    S.SOIdVigencia,
    S.SONumeroSolicitud,
    S.SOFechaAdd,
    S.SOFechaAprovacion
FROM dbo.ff_Solicitud S
INNER JOIN #Muestra186 M ON M.Id = S.SOIdEmpleado
WHERE S.SOIdEmpresa = @IdEmpresa
ORDER BY S.SOIdSolicitud DESC;

SELECT TOP (@Tope)
    POS.POIdPlanOpcionSeleccion,
    POS.POIdEmpresa,
    POS.POIdEmpleado,
    POS.PONumeroEmpleado,
    POS.POIdParentesco,
    POS.POIdGrupoParentesco,
    POS.POIdPlanOpcion,
    POS.POTarifaNeta,
    POS.POIdSolicitud,
    POS.POIdVigencia,
    POS.PODefaulteo,
    POS.POIdEstatus,
    POS.POUsuarioAdd,
    POS.POFechaAdd
FROM dbo.ff_PlanOpcionSeleccion POS
INNER JOIN #Muestra186 M ON M.Id = POS.POIdEmpleado
WHERE POS.POIdEmpresa = @IdEmpresa
ORDER BY POS.POIdPlanOpcionSeleccion DESC;

SELECT TOP (@Tope)
    B.PBIdPlanBasico,
    B.PBIdVigencia,
    B.PBIdPerfil,
    B.PBIdPlan,
    B.PBIdPlanOpcion,
    B.PBFlexible,
    B.PBParentescoDefaulteo,
    B.PBIdOficina,
    B.PBIdEstatus,
    O.PONombre,
    O.POOpcionForzosa,
    O.POIdEstatus
FROM dbo.ff_PlanBasico B
LEFT JOIN dbo.ff_PlanOpcion O ON O.POIdPlanOpcion = B.PBIdPlanOpcion
WHERE B.PBIdVigencia IN (@IdVigenciaOrigen, @IdVigenciaDestino)
  AND EXISTS
  (
      SELECT 1 FROM #Muestra186 M WHERE M.EMIdPerfil = B.PBIdPerfil
  )
ORDER BY B.PBIdVigencia, B.PBIdPerfil, B.PBIdPlanBasico;
```

## 10. Histórico y logs, también limitados

### 10.1 Histórico de selecciones defaulteadas

```sql
;WITH Historico AS
(
    SELECT
        POS.POIdEmpresa,
        POS.PONumeroEmpleado,
        POS.POIdEmpleado,
        POS.POIdSolicitud,
        POS.POIdVigencia,
        POS.POIdPlanOpcion,
        POS.POIdParentesco,
        POS.POIdGrupoParentesco,
        POS.POTarifaNeta,
        POS.POUsuarioAdd,
        POS.POFechaAdd,
        S.SOFechaAprovacion,
        ROW_NUMBER() OVER
        (
            ORDER BY S.SOFechaAprovacion DESC,
                     POS.POIdPlanOpcionSeleccion DESC
        ) AS rn
    FROM dbo.ff_PlanOpcionSeleccion POS
    INNER JOIN dbo.ff_Solicitud S
      ON S.SOIdSolicitud = POS.POIdSolicitud
    WHERE POS.POIdEmpresa = @IdEmpresa
      AND POS.PODefaulteo = 1
      AND POS.POIdEstatus = 1
      AND S.SOEstatusSolicitud = 1
      AND S.SOFechaAprovacion >= @FechaInicio
      AND S.SOFechaAprovacion < DATEADD(DAY, 1, @FechaFin)
)
SELECT TOP (@Tope) *
FROM Historico
ORDER BY rn;
```

### 10.2 Lotes y eventos de Defaulteo Avanzado

```sql
SELECT TOP (200)
    L.LDId,
    L.LDIdConfiguracion,
    L.LDIdCorporativo,
    L.LDIdEmpresa,
    L.LDIdVigencia,
    L.LDIdAdmin,
    L.LDTotalEmpleados,
    L.LDTotalExitosos,
    L.LDTotalErrores,
    L.LDFechaInicio,
    L.LDFechaFin,
    L.LDDuracionMs,
    L.LDOrigen,
    L.LDEstado,
    L.LDFiltrosJson,
    L.LDAccionesJson
FROM dbo.bf_LogDefaulteo L
WHERE L.LDIdEmpresa = @IdEmpresa
   OR (L.LDIdEmpresa IS NULL
       AND (L.LDFiltrosJson LIKE '%"idsEmpresa"%186%'
            OR L.LDFiltrosJson LIKE '%"idEmpresa"%186%'))
ORDER BY L.LDId DESC;

SELECT TOP (1000)
    E.LEDId,
    E.LEDIdLog,
    E.LEDIdEmpleado,
    E.LEDNumeroEmpleado,
    E.LEDIdEmpresa,
    E.LEDIdPerfil,
    E.LEDTipoEvento,
    E.LEDMensaje,
    E.LEDContextoJson,
    E.LEDFechaAdd
FROM dbo.bf_LogErroresDefaulteo E
WHERE E.LEDIdEmpresa = @IdEmpresa
ORDER BY E.LEDId DESC;
```

## 11. Control antes y después de una simulación funcional

Ejecute este bloque y guarde el resultado como **ANTES**. Luego pruebe desde la pantalla/API con 5–10 empleados y ejecútelo otra vez como **DESPUÉS**. Para Carga Masiva use números de empleado de prueba acordados por QA; no reutilice un titular productivo para una operación de alta.

```sql
SELECT
    'EMPLEADOS' AS entidad,
    COUNT_BIG(*) AS filas,
    CONVERT(BIGINT, ISNULL(MAX(E.Id), 0)) AS maxId,
    MAX(COALESCE(E.EMFechaUMod, E.EMFechaAdd)) AS ultimaFecha
FROM dbo.ff_Empleado E
WHERE E.EMIdEmpresa = @IdEmpresa

UNION ALL

SELECT
    'SOLICITUDES',
    COUNT_BIG(*),
    CONVERT(BIGINT, ISNULL(MAX(S.SOIdSolicitud), 0)),
    MAX(COALESCE(S.SOFechaUMod, S.SOFechaAdd))
FROM dbo.ff_Solicitud S
WHERE S.SOIdEmpresa = @IdEmpresa

UNION ALL

SELECT
    'SELECCIONES',
    COUNT_BIG(*),
    CONVERT(BIGINT, ISNULL(MAX(P.POIdPlanOpcionSeleccion), 0)),
    MAX(COALESCE(P.POFechaUMod, P.POFechaAdd))
FROM dbo.ff_PlanOpcionSeleccion P
WHERE P.POIdEmpresa = @IdEmpresa

UNION ALL

SELECT
    'LOTES_DEFAULTEO',
    COUNT_BIG(*),
    CONVERT(BIGINT, ISNULL(MAX(L.LDId), 0)),
    MAX(COALESCE(L.LDFechaFin, L.LDFechaInicio))
FROM dbo.bf_LogDefaulteo L
WHERE L.LDIdEmpresa = @IdEmpresa;

SELECT TOP (200)
    E.Id,
    E.EMNumeroEmpleado,
    E.EMIdPerfil,
    E.EMIdParentesco,
    E.EMIdAcceso,
    E.EMIdEstatus,
    E.EMUsuarioAdd,
    E.EMFechaAdd,
    E.EMUsuarioUMod,
    E.EMFechaUMod
FROM dbo.ff_Empleado E
WHERE E.EMIdEmpresa = @IdEmpresa
  AND COALESCE(E.EMFechaUMod, E.EMFechaAdd) >= DATEADD(HOUR, -4, GETDATE())
ORDER BY COALESCE(E.EMFechaUMod, E.EMFechaAdd) DESC, E.Id DESC;

SELECT TOP (200)
    S.SOIdSolicitud,
    S.SOIdEmpleado,
    S.SONumEmpleado,
    S.SOIdVigencia,
    S.SOIdEstatus,
    S.SOEstatusSolicitud,
    S.SONumeroSolicitud,
    S.SOUsuarioAdd,
    S.SOFechaAdd,
    S.SOFechaAprovacion
FROM dbo.ff_Solicitud S
WHERE S.SOIdEmpresa = @IdEmpresa
  AND S.SOFechaAdd >= DATEADD(HOUR, -4, GETDATE())
ORDER BY S.SOIdSolicitud DESC;

SELECT TOP (500)
    P.POIdPlanOpcionSeleccion,
    P.POIdEmpleado,
    P.PONumeroEmpleado,
    P.POIdSolicitud,
    P.POIdVigencia,
    P.POIdPlanOpcion,
    P.PODefaulteo,
    P.POIdEstatus,
    P.POUsuarioAdd,
    P.POFechaAdd
FROM dbo.ff_PlanOpcionSeleccion P
WHERE P.POIdEmpresa = @IdEmpresa
  AND P.POFechaAdd >= DATEADD(HOUR, -4, GETDATE())
ORDER BY P.POIdPlanOpcionSeleccion DESC;
```

## 12. Matriz mínima de aceptación

| Caso | Preparación | Validación principal |
|---|---|---|
| Selector sin configuración | empresa sin fila activa en `bf_ConfiguracionFlujoCargaMasiva` | B2 y B3 disponibles en pantalla; automático resuelve B2 |
| Pantalla B2 | `CFFlujoPantalla='B2'` | B2 abre/procesa y B3 bloquea |
| Pantalla B3 | `CFFlujoPantalla='B3'` | B3 abre/procesa y B2 bloquea |
| Automático independiente | combinar B2/B3 distinto al valor de pantalla | `bf_CargaMasivaFlujo_Resolver` devuelve el valor automático guardado |
| B3 acceso Sí | operación con `EMIdAcceso` o `Acceso` | empleado de prueba queda con acceso `1` |
| B3 acceso No | misma operación | empleado de prueba queda con acceso `0` |
| Defaulteo 1 | fila `LISTO` en tipo 1 | selección anterior homologada, solicitud destino creada, `PODefaulteo=1` |
| Defaulteo 2 | fila `LISTO` en tipo 2 | plan básico/espejo destino asignado y solicitud creada |
| Defaulteo 3 con dependientes | fila `LISTO CON DEPENDIENTES` | selección conservada y composición de dependientes actualizada |
| Defaulteo 3 control | fila `LISTO SIN DEPENDIENTES` | finaliza sin inventar dependientes |
| Reintento | empleado ya con solicitud destino activa | no duplica solicitud; queda excluido o produce error controlado |
| Histórico | caso exitoso dentro del rango | aparece con empresa 186, usuario, fecha y costo |

## Criterios de salida

La prueba se considera lista para ejecución funcional cuando:

1. el bloque 1 no reporta objetos faltantes;
2. los bloques 3 y 4 no reportan SP inexistentes;
3. las diferencias del bloque 5 están explicadas por parámetros agregados por el backend;
4. existe vigencia destino y, para tipos 1/3, vigencia origen;
5. la matriz 7.2 proporciona al menos un caso adecuado para cada tipo que se va a probar;
6. se guardó el control **ANTES** del bloque 11.

La prueba funcional se considera correcta cuando el control **DESPUÉS**, el histórico y los logs coinciden con los empleados enviados y no aparecen cambios fuera del conjunto de prueba.

## Validación técnica del documento

El 22 de agosto de 2026 se compilaron y ejecutaron los 15 bloques completos, sin errores, sobre la referencia local `(localdb)\MSSQLLocalDB`, base `FlexiForbesv2`.

Esa referencia local devolvió para la empresa 186: corporativo `185`, configuración `40`, vigencia destino `580`, vigencia origen `438`, `11,087` empleados, `4,049` titulares activos y `30,007` solicitudes. No devolvió funciones B2, operaciones B3 ni fila activa en `bf_ConfiguracionFlujoCargaMasiva`; tampoco produjo candidatos `LISTO` con esas vigencias. Estos resultados son sólo el estado de la copia local y no sustituyen la ejecución del documento en la BD destino.
