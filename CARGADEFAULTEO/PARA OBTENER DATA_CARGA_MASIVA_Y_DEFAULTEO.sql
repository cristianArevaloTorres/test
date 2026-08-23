/*
  PRUEBAS DE SOLO LECTURA - EMPRESA 186
  Carga Masiva B2/B3 y Defaulteo 1/2/3

  REQUISITO: ejecutar antes 01_SQL_INSTALACION/000_INSTALACION_COMPLETA_SSMS.sql.
  Limite de muestra: 3000 filas.
  Mantenga todo el archivo en la misma ventana y no agregue GO: las variables
  y la tabla temporal #Muestra186 se comparten entre secciones.

  Nombre correcto: dbo.bf_ConfiguracionFlujoCargaMasiva
  No agregue una diagonal inversa antes del guion bajo.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

/* ==================== BLOQUE 0 ==================== */
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

/* ==================== BLOQUE 1 ==================== */
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

/* ==================== BLOQUE 2 ==================== */
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

/* ==================== BLOQUE 3 ==================== */
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

/* ==================== BLOQUE 4 ==================== */
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

/* ==================== BLOQUE 5 ==================== */
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

/* ==================== BLOQUE 6 ==================== */
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

/* ==================== BLOQUE 7 ==================== */
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

/* ==================== BLOQUE 8 ==================== */
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

/* ==================== BLOQUE 9 ==================== */
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

/* ==================== BLOQUE 10 ==================== */
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

/* ==================== BLOQUE 11 ==================== */
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

/* ==================== BLOQUE 12 ==================== */
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

/* ==================== BLOQUE 13 ==================== */
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

/* ==================== BLOQUE 14 ==================== */
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
