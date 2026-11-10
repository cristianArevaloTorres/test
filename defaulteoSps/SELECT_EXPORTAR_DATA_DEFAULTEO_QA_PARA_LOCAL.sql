USE [FlexiForbesv2];
GO

SET NOCOUNT ON;
SET TEXTSIZE 2147483647;
SET LOCK_TIMEOUT 30000;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

/*
  EXTRACCION PORTABLE DE N CASOS REALES PARA PRUEBAS

  Objetivo:
    - Ejecutar este archivo en QA.
    - Guardar el unico resultado final como CSV.
    - Entregar ese CSV para construir posteriormente el cargador de LocalDB.

  Alcance:
    - Cambios calificados.
    - Defaulteo de casos especiales.
    - Los dos motores PlanEspejo y sus wrappers V31.
    - Seleccion automatica de N familias por cada flujo.
    - Familias completas, incluso integrantes inactivos o dados de baja.
    - Historial completo de solicitudes y selecciones.
    - Configuracion elegible, aunque nunca haya sido seleccionada.

  Seguridad:
    - Solo lee tablas permanentes.
    - Las unicas escrituras son tablas temporales de esta sesion.
    - No ejecuta los SP de negocio.
    - Omite las propiedades de contrasena/clave del JSON de empleados y empresa.
    - El resultado conserva nombres y fechas de nacimiento de beneficiarios;
      debe tratarse como archivo sensible y compartirse por un medio seguro.

  IMPORTANTE:
    #tmpPlanesFlexibles solo existe mientras corre el wrapper y no puede
    recuperarse despues. Esta extraccion incluye la configuracion necesaria
    para que el wrapper vuelva a generarla en LocalDB.
*/

/* Cambiar solamente las cantidades. El filtro de empresa es opcional. */
DECLARE @CantidadCambiosCalificados INT = 25;
DECLARE @CantidadCasosEspeciales INT = 25;
DECLARE @IdEmpresaFiltro INT = NULL; -- NULL = tomar casos de cualquier empresa.

IF ISNULL(@CantidadCambiosCalificados, 0) < 0
   OR ISNULL(@CantidadCasosEspeciales, 0) < 0
   OR
      (
          ISNULL(@CantidadCambiosCalificados, 0) = 0
          AND ISNULL(@CantidadCasosEspeciales, 0) = 0
      )
BEGIN
    SELECT
        'ERROR' AS tipoRegistro,
        0 AS ordenCarga,
        '__ERROR' AS tabla,
        NULL AS clave,
        0 AS totalFilasTabla,
        '{"mensaje":"Las cantidades no pueden ser negativas y al menos una debe ser mayor que cero."}' AS filaJson,
        0 AS esDatoDerivado;
    RETURN;
END;

CREATE TABLE #Casos
(
    CasoId INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    Origen VARCHAR(40) NOT NULL,
    NivelCerteza VARCHAR(20) NOT NULL,
    IdReferencia INT NULL,
    IdLog INT NULL,
    SolicitudSemilla INT NULL,
    IdTitular INT NOT NULL,
    IdEmpresa INT NOT NULL,
    IdCorporativo INT NULL,
    IdConfiguracion INT NULL,
    NumeroEmpleado VARCHAR(50) NULL,
    FechaSolicitud DATETIME NULL
);

/* 1. Cambios calificados: la solicitud los identifica directamente. */
;WITH CandidatosCambio AS
(
    SELECT
        S.SOIdSolicitud AS SolicitudSemilla,
        CASE
            WHEN E.EMIdParentesco = 1 OR ISNULL(E.EMIdTitular, 0) IN (0, 1)
                THEN E.Id
            ELSE E.EMIdTitular
        END AS IdTitular,
        S.SOIdEmpresa AS IdEmpresa,
        EMP.EMIdCorporativo AS IdCorporativo,
        EMP.EMIdConfiguracion AS IdConfiguracion,
        COALESCE(NULLIF(E.EMNumeroEmpleado, ''), S.SONumEmpleado)
            AS NumeroEmpleado,
        COALESCE(S.SOFechaUMod, S.SOFechaAdd, S.SOFechaEstatus)
            AS FechaSolicitud,
        ROW_NUMBER() OVER
        (
            PARTITION BY S.SOIdEmpresa,
                CASE
                    WHEN E.EMIdParentesco = 1
                         OR ISNULL(E.EMIdTitular, 0) IN (0, 1)
                        THEN E.Id
                    ELSE E.EMIdTitular
                END
            ORDER BY
                COALESCE(S.SOFechaUMod, S.SOFechaAdd, S.SOFechaEstatus) DESC,
                S.SOIdSolicitud DESC
        ) AS rn
    FROM dbo.ff_Solicitud S
    INNER JOIN dbo.ff_Empleado E
        ON E.Id = S.SOIdEmpleado
       AND E.EMIdEmpresa = S.SOIdEmpresa
    INNER JOIN dbo.ff_Empresa EMP
        ON EMP.EMIdEmpresa = S.SOIdEmpresa
    WHERE S.SOIdCambioCalificado = 1
      AND (@IdEmpresaFiltro IS NULL OR S.SOIdEmpresa = @IdEmpresaFiltro)
      AND EXISTS
          (
              SELECT 1
              FROM dbo.ff_PlanOpcionSeleccion PS
              WHERE PS.POIdSolicitud = S.SOIdSolicitud
          )
)
INSERT INTO #Casos
(
    Origen,
    NivelCerteza,
    IdReferencia,
    IdLog,
    SolicitudSemilla,
    IdTitular,
    IdEmpresa,
    IdCorporativo,
    IdConfiguracion,
    NumeroEmpleado,
    FechaSolicitud
)
SELECT
    'CAMBIO_CALIFICADO',
    'CONFIRMADO',
    C.SolicitudSemilla,
    NULL,
    C.SolicitudSemilla,
    C.IdTitular,
    C.IdEmpresa,
    C.IdCorporativo,
    C.IdConfiguracion,
    C.NumeroEmpleado,
    C.FechaSolicitud
FROM
(
    SELECT TOP (@CantidadCambiosCalificados) X.*
    FROM CandidatosCambio X
    WHERE X.rn = 1
    ORDER BY X.FechaSolicitud DESC, X.SolicitudSemilla DESC
) C;

/*
  2. Casos especiales.

  ff_Solicitud no guarda la pantalla de origen. Se usa la bitacora:
    - CONFIRMADO: LEDContextoJson contiene idSolicitudNueva.
    - PROBABLE: solicitud de defaulteo creada por el mismo administrador,
      vigencia y ventana temporal del lote CASOS_ESPECIALES.
    - EVENTO: empleado registrado por el lote aunque no haya solicitud nueva.
*/
DECLARE @MaxLotesEspeciales INT =
    CASE
        WHEN ISNULL(@CantidadCasosEspeciales, 0) * 10 < 100 THEN 100
        ELSE ISNULL(@CantidadCasosEspeciales, 0) * 10
    END;

CREATE TABLE #LotesEspeciales
(
    LDId INT NOT NULL PRIMARY KEY,
    LDIdConfiguracion INT NULL,
    LDIdCorporativo INT NULL,
    LDIdEmpresa INT NULL,
    LDIdVigencia INT NULL,
    LDIdAdmin INT NOT NULL,
    LDFechaInicio DATETIME NOT NULL,
    LDFechaFin DATETIME NULL,
    LDOrigen VARCHAR(20) NOT NULL
);

INSERT INTO #LotesEspeciales
(
    LDId,
    LDIdConfiguracion,
    LDIdCorporativo,
    LDIdEmpresa,
    LDIdVigencia,
    LDIdAdmin,
    LDFechaInicio,
    LDFechaFin,
    LDOrigen
)
SELECT TOP (@MaxLotesEspeciales)
    L.LDId,
    L.LDIdConfiguracion,
    L.LDIdCorporativo,
    L.LDIdEmpresa,
    L.LDIdVigencia,
    L.LDIdAdmin,
    L.LDFechaInicio,
    L.LDFechaFin,
    L.LDOrigen
FROM dbo.bf_LogDefaulteo L
WHERE L.LDOrigen = 'CASOS_ESPECIALES'
  AND (@IdEmpresaFiltro IS NULL OR L.LDIdEmpresa IS NULL
       OR L.LDIdEmpresa = @IdEmpresaFiltro)
ORDER BY L.LDFechaInicio DESC, L.LDId DESC;

;WITH EspecialesConfirmados AS
(
    SELECT
        S.SOIdSolicitud AS SolicitudSemilla,
        CASE
            WHEN E.EMIdParentesco = 1 OR ISNULL(E.EMIdTitular, 0) IN (0, 1)
                THEN E.Id
            ELSE E.EMIdTitular
        END AS IdTitular,
        S.SOIdEmpresa AS IdEmpresa,
        EMP.EMIdCorporativo AS IdCorporativo,
        EMP.EMIdConfiguracion AS IdConfiguracion,
        COALESCE(NULLIF(E.EMNumeroEmpleado, ''), S.SONumEmpleado)
            AS NumeroEmpleado,
        COALESCE(S.SOFechaUMod, S.SOFechaAdd, S.SOFechaEstatus)
            AS FechaSolicitud,
        L.LDId AS IdLog,
        LED.LEDId AS IdReferencia,
        CAST('CONFIRMADO' AS VARCHAR(20)) AS NivelCerteza,
        1 AS Prioridad
    FROM #LotesEspeciales L
    INNER JOIN dbo.bf_LogErroresDefaulteo LED
        ON LED.LEDIdLog = L.LDId
    CROSS APPLY
    (
        SELECT TRY_CONVERT(INT,
            JSON_VALUE(LED.LEDContextoJson, '$.idSolicitudNueva'))
            AS IdSolicitudNueva
    ) J
    INNER JOIN dbo.ff_Solicitud S
        ON S.SOIdSolicitud = J.IdSolicitudNueva
    INNER JOIN dbo.ff_Empleado E
        ON E.Id = S.SOIdEmpleado
    INNER JOIN dbo.ff_Empresa EMP
        ON EMP.EMIdEmpresa = S.SOIdEmpresa
    WHERE L.LDOrigen = 'CASOS_ESPECIALES'
      AND J.IdSolicitudNueva IS NOT NULL
      AND (@IdEmpresaFiltro IS NULL OR S.SOIdEmpresa = @IdEmpresaFiltro)
),
EspecialesProbables AS
(
    SELECT
        S.SOIdSolicitud AS SolicitudSemilla,
        CASE
            WHEN E.EMIdParentesco = 1 OR ISNULL(E.EMIdTitular, 0) IN (0, 1)
                THEN E.Id
            ELSE E.EMIdTitular
        END AS IdTitular,
        S.SOIdEmpresa AS IdEmpresa,
        EMP.EMIdCorporativo AS IdCorporativo,
        EMP.EMIdConfiguracion AS IdConfiguracion,
        COALESCE(NULLIF(E.EMNumeroEmpleado, ''), S.SONumEmpleado)
            AS NumeroEmpleado,
        COALESCE(S.SOFechaUMod, S.SOFechaAdd, S.SOFechaEstatus)
            AS FechaSolicitud,
        L.LDId AS IdLog,
        S.SOIdSolicitud AS IdReferencia,
        CAST('PROBABLE' AS VARCHAR(20)) AS NivelCerteza,
        2 AS Prioridad
    FROM #LotesEspeciales L
    INNER JOIN dbo.ff_Solicitud S
        ON S.SOUsuarioAdd = L.LDIdAdmin
       AND (L.LDIdEmpresa IS NULL OR S.SOIdEmpresa = L.LDIdEmpresa)
       AND (L.LDIdVigencia IS NULL OR S.SOIdVigencia = L.LDIdVigencia)
       AND S.SOFechaAdd >= DATEADD(SECOND, -5, L.LDFechaInicio)
       AND S.SOFechaAdd <= DATEADD
           (
               SECOND,
               5,
               COALESCE(L.LDFechaFin, L.LDFechaInicio)
           )
    INNER JOIN dbo.ff_Empleado E
        ON E.Id = S.SOIdEmpleado
    INNER JOIN dbo.ff_Empresa EMP
        ON EMP.EMIdEmpresa = S.SOIdEmpresa
    WHERE L.LDOrigen = 'CASOS_ESPECIALES'
      AND (@IdEmpresaFiltro IS NULL OR S.SOIdEmpresa = @IdEmpresaFiltro)
      AND EXISTS
          (
              SELECT 1
              FROM dbo.ff_PlanOpcionSeleccion PS
              WHERE PS.POIdSolicitud = S.SOIdSolicitud
                AND PS.PODefaulteo = 1
          )
),
EspecialesEventos AS
(
    SELECT
        U.SOIdSolicitud AS SolicitudSemilla,
        CASE
            WHEN E.EMIdParentesco = 1 OR ISNULL(E.EMIdTitular, 0) IN (0, 1)
                THEN E.Id
            ELSE E.EMIdTitular
        END AS IdTitular,
        E.EMIdEmpresa AS IdEmpresa,
        EMP.EMIdCorporativo AS IdCorporativo,
        EMP.EMIdConfiguracion AS IdConfiguracion,
        E.EMNumeroEmpleado AS NumeroEmpleado,
        LED.LEDFechaAdd AS FechaSolicitud,
        L.LDId AS IdLog,
        LED.LEDId AS IdReferencia,
        CAST('EVENTO' AS VARCHAR(20)) AS NivelCerteza,
        3 AS Prioridad
    FROM #LotesEspeciales L
    INNER JOIN dbo.bf_LogErroresDefaulteo LED
        ON LED.LEDIdLog = L.LDId
    INNER JOIN dbo.ff_Empleado E
        ON E.Id = LED.LEDIdEmpleado
    INNER JOIN dbo.ff_Empresa EMP
        ON EMP.EMIdEmpresa = E.EMIdEmpresa
    OUTER APPLY
    (
        SELECT TOP (1) S.SOIdSolicitud
        FROM dbo.ff_Solicitud S
        WHERE S.SOIdEmpresa = E.EMIdEmpresa
          AND
              (
                  S.SOIdEmpleado = E.Id
                  OR S.SONumEmpleado = E.EMNumeroEmpleado
              )
        ORDER BY
            ABS(DATEDIFF(SECOND, S.SOFechaAdd, LED.LEDFechaAdd)),
            S.SOIdSolicitud DESC
    ) U
    WHERE L.LDOrigen = 'CASOS_ESPECIALES'
      AND (@IdEmpresaFiltro IS NULL OR E.EMIdEmpresa = @IdEmpresaFiltro)
),
UniversoEspecial AS
(
    SELECT * FROM EspecialesConfirmados
    UNION ALL
    SELECT * FROM EspecialesProbables
    UNION ALL
    SELECT * FROM EspecialesEventos
),
EspecialDedupe AS
(
    SELECT
        U.*,
        ROW_NUMBER() OVER
        (
            PARTITION BY U.IdEmpresa, U.IdTitular
            ORDER BY U.Prioridad, U.FechaSolicitud DESC,
                     ISNULL(U.SolicitudSemilla, 0) DESC
        ) AS rn
    FROM UniversoEspecial U
)
INSERT INTO #Casos
(
    Origen,
    NivelCerteza,
    IdReferencia,
    IdLog,
    SolicitudSemilla,
    IdTitular,
    IdEmpresa,
    IdCorporativo,
    IdConfiguracion,
    NumeroEmpleado,
    FechaSolicitud
)
SELECT
    'CASO_ESPECIAL',
    C.NivelCerteza,
    C.IdReferencia,
    C.IdLog,
    C.SolicitudSemilla,
    C.IdTitular,
    C.IdEmpresa,
    C.IdCorporativo,
    C.IdConfiguracion,
    C.NumeroEmpleado,
    C.FechaSolicitud
FROM
(
    SELECT TOP (@CantidadCasosEspeciales) X.*
    FROM EspecialDedupe X
    WHERE X.rn = 1
    ORDER BY X.Prioridad, X.FechaSolicitud DESC,
             ISNULL(X.SolicitudSemilla, 0) DESC
) C
OPTION (RECOMPILE, MAXDOP 1);

IF NOT EXISTS (SELECT 1 FROM #Casos)
BEGIN
    SELECT
        'ERROR' AS tipoRegistro,
        0 AS ordenCarga,
        '__ERROR' AS tabla,
        NULL AS clave,
        0 AS totalFilasTabla,
        '{"mensaje":"No se encontraron cambios calificados ni trazas de casos especiales con los filtros indicados."}'
            AS filaJson,
        0 AS esDatoDerivado;
    RETURN;
END;

CREATE TABLE #Empresas
(
    IdEmpresa INT NOT NULL PRIMARY KEY
);

INSERT INTO #Empresas (IdEmpresa)
SELECT C.IdEmpresa
FROM #Casos C
UNION
SELECT C.IdCorporativo
FROM #Casos C
WHERE C.IdCorporativo IS NOT NULL;

CREATE TABLE #FamiliaCaso
(
    CasoId INT NOT NULL,
    IdEmpleado INT NOT NULL,
    PRIMARY KEY (CasoId, IdEmpleado)
);

INSERT INTO #FamiliaCaso (CasoId, IdEmpleado)
SELECT DISTINCT
    C.CasoId,
    E.Id
FROM #Casos C
INNER JOIN dbo.ff_Empleado E
    ON E.EMIdEmpresa = C.IdEmpresa
   AND
      (
          E.Id = C.IdTitular
          OR E.EMIdTitular = C.IdTitular
          OR E.EMNumeroEmpleado = C.NumeroEmpleado
      );

CREATE TABLE #Familia
(
    IdEmpleado INT NOT NULL PRIMARY KEY
);

INSERT INTO #Familia (IdEmpleado)
SELECT DISTINCT F.IdEmpleado
FROM #FamiliaCaso F;

CREATE TABLE #Solicitudes
(
    IdSolicitud INT NOT NULL PRIMARY KEY
);

INSERT INTO #Solicitudes (IdSolicitud)
SELECT DISTINCT S.SOIdSolicitud
FROM dbo.ff_Solicitud S
INNER JOIN #Casos C
    ON S.SOIdEmpresa = C.IdEmpresa
   AND
      (
          S.SOIdEmpleado = C.IdTitular
          OR S.SONumEmpleado = C.NumeroEmpleado
          OR EXISTS
             (
                 SELECT 1
                 FROM #FamiliaCaso F
                 WHERE F.CasoId = C.CasoId
                   AND F.IdEmpleado = S.SOIdEmpleado
             )
      );

CREATE TABLE #Perfiles
(
    IdPerfil INT NOT NULL PRIMARY KEY
);

INSERT INTO #Perfiles (IdPerfil)
SELECT DISTINCT E.EMIdPerfil
FROM dbo.ff_Empleado E
INNER JOIN #Familia F
    ON F.IdEmpleado = E.Id
WHERE E.EMIdPerfil IS NOT NULL;

CREATE TABLE #Vigencias
(
    IdVigencia INT NOT NULL PRIMARY KEY
);

INSERT INTO #Vigencias (IdVigencia)
SELECT DISTINCT V.VIIdVigencia
FROM dbo.ff_Vigencia V
WHERE V.VIIdConfiguracion IN
      (
          SELECT C.IdConfiguracion
          FROM #Casos C
          WHERE C.IdConfiguracion IS NOT NULL
      )
  AND V.VIIdEstatus = 1
UNION
SELECT DISTINCT S.SOIdVigencia
FROM dbo.ff_Solicitud S
INNER JOIN #Solicitudes X
    ON X.IdSolicitud = S.SOIdSolicitud
WHERE S.SOIdVigencia IS NOT NULL;

/* La vigencia registrada por un lote de casos especiales tambien es insumo. */
INSERT INTO #Vigencias (IdVigencia)
SELECT DISTINCT L.LDIdVigencia
FROM dbo.bf_LogDefaulteo L
INNER JOIN #Casos C
    ON C.IdLog = L.LDId
WHERE L.LDIdVigencia IS NOT NULL
  AND NOT EXISTS
      (
          SELECT 1
          FROM #Vigencias V
          WHERE V.IdVigencia = L.LDIdVigencia
      );

/* Historial de beneficiarios puede pertenecer a vigencias anteriores. */
INSERT INTO #Vigencias (IdVigencia)
SELECT DISTINCT H.BHIdVigencia
FROM dbo.BF_BeneficiarioPlan_HIS H
WHERE H.BHIdVigencia IS NOT NULL
  AND
      (
          H.BHIdTitular IN (SELECT F.IdEmpleado FROM #Familia F)
          OR H.BHIdDependiente IN (SELECT F.IdEmpleado FROM #Familia F)
          OR H.BHIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F)
      )
  AND NOT EXISTS
      (
          SELECT 1
          FROM #Vigencias V
          WHERE V.IdVigencia = H.BHIdVigencia
      );

CREATE TABLE #Condiciones
(
    IdCondicion INT NOT NULL PRIMARY KEY
);

INSERT INTO #Condiciones (IdCondicion)
SELECT DISTINCT C.CPIdCondicionPlan
FROM dbo.ff_CondicionPlan C
WHERE C.CPIdEmpresa IN (SELECT X.IdEmpresa FROM #Casos X)
   OR C.CPIdPerfil IN (SELECT P.IdPerfil FROM #Perfiles P);

CREATE TABLE #Opciones
(
    IdOpcion INT NOT NULL PRIMARY KEY
);

/* Selecciones historicas y staging persistente. */
INSERT INTO #Opciones (IdOpcion)
SELECT DISTINCT S.POIdPlanOpcion
FROM dbo.ff_PlanOpcionSeleccion S
WHERE S.POIdPlanOpcion IS NOT NULL
  AND
      (
          S.POIdSolicitud IN (SELECT X.IdSolicitud FROM #Solicitudes X)
          OR S.POIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F)
      )
UNION
SELECT DISTINCT T.POIdPlanOpcion
FROM dbo.ff_PlanOpcionSeleccionTmp T
WHERE T.POIdPlanOpcion IS NOT NULL
  AND
      (
          T.POIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F)
          OR EXISTS
             (
                 SELECT 1
                 FROM #Casos C
                 WHERE C.IdEmpresa = T.POIdEmpresa
                   AND C.NumeroEmpleado = T.PONumeroEmpleado
             )
      );

/* Otras persistencias usadas por cambios calificados, BF3 y retiro. */
INSERT INTO #Opciones (IdOpcion)
SELECT DISTINCT X.IdOpcion
FROM
(
    SELECT H.POHIdPlanOpcion AS IdOpcion
    FROM dbo.ff_PlanOpcionSeleccion_Historico H
    WHERE H.POHIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F)
    UNION
    SELECT B.POIdPlanOpcion
    FROM dbo.ff_planOpcionSeleccionB3 B
    WHERE B.POIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F)
       OR B.POIdSolicitudB3 IN (SELECT S.IdSolicitud FROM #Solicitudes S)
    UNION
    SELECT R.PORIdPlanOpcion
    FROM dbo.ff_PlanOpcionSeleccionRetiro R
    WHERE R.PORIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F)
       OR R.PORIdSolicitud IN (SELECT S.IdSolicitud FROM #Solicitudes S)
) X
WHERE X.IdOpcion IS NOT NULL
  AND NOT EXISTS
      (SELECT 1 FROM #Opciones O WHERE O.IdOpcion = X.IdOpcion);

/* Basicos, opciones del perfil y opciones de las vigencias del caso. */
INSERT INTO #Opciones (IdOpcion)
SELECT DISTINCT B.PBIdPlanOpcion
FROM dbo.ff_PlanBasico B
WHERE B.PBIdPerfil IN (SELECT P.IdPerfil FROM #Perfiles P)
  AND B.PBIdPlanOpcion IS NOT NULL
  AND NOT EXISTS
      (SELECT 1 FROM #Opciones O WHERE O.IdOpcion = B.PBIdPlanOpcion);

INSERT INTO #Opciones (IdOpcion)
SELECT DISTINCT P.PPIdPlanOpcion
FROM dbo.ff_PlanOpcionPerfil P
WHERE P.PPIdPerfil IN (SELECT X.IdPerfil FROM #Perfiles X)
  AND NOT EXISTS
      (SELECT 1 FROM #Opciones O WHERE O.IdOpcion = P.PPIdPlanOpcion);

INSERT INTO #Opciones (IdOpcion)
SELECT DISTINCT V.VCIdPlanOpcion
FROM dbo.ff_PlanOpcionVigencia V
WHERE V.VCIdVigencia IN (SELECT X.IdVigencia FROM #Vigencias X)
  AND EXISTS
      (
          SELECT 1
          FROM dbo.ff_PlanOpcionPerfil P
          WHERE P.PPIdPlanOpcion = V.VCIdPlanOpcion
            AND P.PPIdPerfil IN (SELECT X.IdPerfil FROM #Perfiles X)
      )
  AND NOT EXISTS
      (SELECT 1 FROM #Opciones O WHERE O.IdOpcion = V.VCIdPlanOpcion);

/* Opciones agregadas o eliminadas mediante condiciones. */
INSERT INTO #Opciones (IdOpcion)
SELECT DISTINCT D.DCIdPlanOpcion
FROM dbo.ff_DetalleCondicionPlan D
WHERE D.DCIdCondicionPlan IN (SELECT C.IdCondicion FROM #Condiciones C)
  AND D.DCIdPlanOpcion IS NOT NULL
  AND NOT EXISTS
      (SELECT 1 FROM #Opciones O WHERE O.IdOpcion = D.DCIdPlanOpcion);

INSERT INTO #Opciones (IdOpcion)
SELECT DISTINCT R.RCIdPlanOpcion
FROM dbo.ff_ResultadoCondicionPlan R
WHERE R.RCIdCondicionPlan IN (SELECT C.IdCondicion FROM #Condiciones C)
  AND R.RCIdPlanOpcion IS NOT NULL
  AND NOT EXISTS
      (SELECT 1 FROM #Opciones O WHERE O.IdOpcion = R.RCIdPlanOpcion);

/* Homologaciones de las vigencias y empresa del caso. */
INSERT INTO #Opciones (IdOpcion)
SELECT DISTINCT H.IdOpcion
FROM
(
    SELECT PH.PHIdPlanOpcionAnt AS IdOpcion
    FROM dbo.ff_PlanOpcionHomologacion PH
    WHERE PH.PHIdEmpresa IN (SELECT C.IdEmpresa FROM #Casos C)
       OR PH.PHIdVigenciaAnt IN (SELECT V.IdVigencia FROM #Vigencias V)
       OR PH.PHIdVigenciaAct IN (SELECT V.IdVigencia FROM #Vigencias V)
    UNION
    SELECT PH.PHIdPlanOpcionAct
    FROM dbo.ff_PlanOpcionHomologacion PH
    WHERE PH.PHIdEmpresa IN (SELECT C.IdEmpresa FROM #Casos C)
       OR PH.PHIdVigenciaAnt IN (SELECT V.IdVigencia FROM #Vigencias V)
       OR PH.PHIdVigenciaAct IN (SELECT V.IdVigencia FROM #Vigencias V)
) H
WHERE H.IdOpcion IS NOT NULL
  AND NOT EXISTS
      (SELECT 1 FROM #Opciones O WHERE O.IdOpcion = H.IdOpcion);

CREATE TABLE #Planes
(
    IdPlan INT NOT NULL PRIMARY KEY
);

/* Planes provenientes de opciones y reglas. */
INSERT INTO #Planes (IdPlan)
SELECT DISTINCT O.POIdPlan
FROM dbo.ff_PlanOpcion O
INNER JOIN #Opciones X
    ON X.IdOpcion = O.POIdPlanOpcion
WHERE O.POIdPlan IS NOT NULL;

INSERT INTO #Planes (IdPlan)
SELECT DISTINCT X.IdPlan
FROM
(
    SELECT B.PBIdPlan AS IdPlan
    FROM dbo.ff_PlanBasico B
    WHERE B.PBIdPerfil IN (SELECT P.IdPerfil FROM #Perfiles P)
    UNION
    SELECT D.DCIdPlan
    FROM dbo.ff_DetalleCondicionPlan D
    WHERE D.DCIdCondicionPlan IN (SELECT C.IdCondicion FROM #Condiciones C)
    UNION
    SELECT R.RCIdPlan
    FROM dbo.ff_ResultadoCondicionPlan R
    WHERE R.RCIdCondicionPlan IN (SELECT C.IdCondicion FROM #Condiciones C)
    UNION
    SELECT C.CCIdPlan
    FROM dbo.ff_CompensacionConfiguracion C
    WHERE C.CCIdPerfil IN (SELECT P.IdPerfil FROM #Perfiles P)
       OR C.CCIdVigencia IN (SELECT V.IdVigencia FROM #Vigencias V)
       OR C.CCIdCorporativo IN
          (SELECT X.IdCorporativo FROM #Casos X WHERE X.IdCorporativo IS NOT NULL)
       OR C.CCIdEmpresaPerfil IN (SELECT X.IdEmpresa FROM #Casos X)
    UNION
    SELECT C.CCIdPlanDistribucion
    FROM dbo.ff_CompensacionConfiguracion C
    WHERE C.CCIdPerfil IN (SELECT P.IdPerfil FROM #Perfiles P)
       OR C.CCIdVigencia IN (SELECT V.IdVigencia FROM #Vigencias V)
       OR C.CCIdCorporativo IN
          (SELECT X.IdCorporativo FROM #Casos X WHERE X.IdCorporativo IS NOT NULL)
       OR C.CCIdEmpresaPerfil IN (SELECT X.IdEmpresa FROM #Casos X)
    UNION
    SELECT B.bpIdPlan
    FROM dbo.bf_BeneficiarioPlan B
    WHERE B.bpIdTitular IN (SELECT F.IdEmpleado FROM #Familia F)
       OR B.bpIdDependiente IN (SELECT F.IdEmpleado FROM #Familia F)
       OR B.bpIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F)
    UNION
    SELECT H.BHIdPlan
    FROM dbo.BF_BeneficiarioPlan_HIS H
    WHERE H.BHIdTitular IN (SELECT F.IdEmpleado FROM #Familia F)
       OR H.BHIdDependiente IN (SELECT F.IdEmpleado FROM #Familia F)
       OR H.BHIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F)
    UNION
    SELECT B.bpIdPlan
    FROM dbo.bf_BeneficiarioPlanSecundario B
    WHERE B.bpIdTitular IN (SELECT F.IdEmpleado FROM #Familia F)
       OR B.bpIdDependiente IN (SELECT F.IdEmpleado FROM #Familia F)
       OR B.bpIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F)
    UNION
    SELECT B.BSIdPlan
    FROM dbo.bf_BeneficiarioSustituto B
    WHERE B.BSIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F)
       OR B.BSIdSolicitud IN (SELECT S.IdSolicitud FROM #Solicitudes S)
) X
WHERE X.IdPlan IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM #Planes P WHERE P.IdPlan = X.IdPlan);

/*
  Cierre de planes/opciones y opciones compuestas. Evita perder una opcion
  elegible que aun no aparezca en el historial.
*/
DECLARE @Cambios INT = 1;

WHILE @Cambios > 0
BEGIN
    SET @Cambios = 0;

    INSERT INTO #Opciones (IdOpcion)
    SELECT DISTINCT O.POIdPlanOpcion
    FROM dbo.ff_PlanOpcion O
    INNER JOIN #Planes P
        ON P.IdPlan = O.POIdPlan
    WHERE EXISTS
          (
              SELECT 1
              FROM dbo.ff_PlanOpcionPerfil PP
              WHERE PP.PPIdPlanOpcion = O.POIdPlanOpcion
                AND PP.PPIdPerfil IN (SELECT X.IdPerfil FROM #Perfiles X)
          )
      AND
          (
              NOT EXISTS
              (
                  SELECT 1
                  FROM dbo.ff_PlanOpcionVigencia PV
                  WHERE PV.VCIdPlanOpcion = O.POIdPlanOpcion
              )
              OR EXISTS
              (
                  SELECT 1
                  FROM dbo.ff_PlanOpcionVigencia PV
                  WHERE PV.VCIdPlanOpcion = O.POIdPlanOpcion
                    AND PV.VCIdVigencia IN
                        (SELECT X.IdVigencia FROM #Vigencias X)
              )
          )
      AND NOT EXISTS
          (SELECT 1 FROM #Opciones X WHERE X.IdOpcion = O.POIdPlanOpcion);
    SET @Cambios += @@ROWCOUNT;

    INSERT INTO #Opciones (IdOpcion)
    SELECT DISTINCT X.IdOpcion
    FROM
    (
        SELECT C.PCIdPlanOpcion AS IdOpcion
        FROM dbo.ff_PlanOpcionCompuesto C
        WHERE C.PCIdPlanOpcionIntegrante IN
              (SELECT O.IdOpcion FROM #Opciones O)
        UNION
        SELECT C.PCIdPlanOpcionIntegrante
        FROM dbo.ff_PlanOpcionCompuesto C
        WHERE C.PCIdPlanOpcion IN
              (SELECT O.IdOpcion FROM #Opciones O)
    ) X
    WHERE X.IdOpcion IS NOT NULL
      AND NOT EXISTS
          (SELECT 1 FROM #Opciones O WHERE O.IdOpcion = X.IdOpcion);
    SET @Cambios += @@ROWCOUNT;

    INSERT INTO #Planes (IdPlan)
    SELECT DISTINCT O.POIdPlan
    FROM dbo.ff_PlanOpcion O
    INNER JOIN #Opciones X
        ON X.IdOpcion = O.POIdPlanOpcion
    WHERE O.POIdPlan IS NOT NULL
      AND NOT EXISTS
          (SELECT 1 FROM #Planes P WHERE P.IdPlan = O.POIdPlan);
    SET @Cambios += @@ROWCOUNT;
END;

CREATE TABLE #Tarifas
(
    IdTarifa INT NOT NULL PRIMARY KEY
);

INSERT INTO #Tarifas (IdTarifa)
SELECT DISTINCT T.TAIdTarifa
FROM dbo.ff_Tarifa T
WHERE T.TAIdVigencia IN (SELECT V.IdVigencia FROM #Vigencias V)
UNION
SELECT DISTINCT C.TCIdTarifa
FROM dbo.ff_TarifaCosto C
INNER JOIN dbo.ff_Tarifa T
    ON T.TAIdTarifa = C.TCIdTarifa
WHERE C.TCIdPlanOpcion IN (SELECT O.IdOpcion FROM #Opciones O)
  AND T.TAIdVigencia IN (SELECT V.IdVigencia FROM #Vigencias V)
UNION
SELECT DISTINCT H.TCIdTarifa
FROM dbo.ff_TarifaCosto_hist H
INNER JOIN dbo.ff_Tarifa T
    ON T.TAIdTarifa = H.TCIdTarifa
WHERE H.TCIdPlanOpcion IN (SELECT O.IdOpcion FROM #Opciones O)
  AND T.TAIdVigencia IN (SELECT V.IdVigencia FROM #Vigencias V)
UNION
SELECT DISTINCT P.TPIdTarifa
FROM dbo.ff_TarifaCostoPerfil P
INNER JOIN dbo.ff_Tarifa T
    ON T.TAIdTarifa = P.TPIdTarifa
WHERE
      (
          P.TPIdPerfil IN (SELECT X.IdPerfil FROM #Perfiles X)
          OR P.TPIdPlanOpcion IN (SELECT X.IdOpcion FROM #Opciones X)
      )
  AND T.TAIdVigencia IN (SELECT V.IdVigencia FROM #Vigencias V);

CREATE TABLE #Compensaciones
(
    IdCompensacion INT NOT NULL PRIMARY KEY
);

INSERT INTO #Compensaciones (IdCompensacion)
SELECT DISTINCT X.IdCompensacion
FROM
(
    SELECT B.PBIdCompensacion AS IdCompensacion
    FROM dbo.ff_PlanBasico B
    WHERE B.PBIdPerfil IN (SELECT P.IdPerfil FROM #Perfiles P)
    UNION
    SELECT C.CCIdCompensacion
    FROM dbo.ff_CompensacionConfiguracion C
    WHERE C.CCIdPerfil IN (SELECT P.IdPerfil FROM #Perfiles P)
       OR C.CCIdVigencia IN (SELECT V.IdVigencia FROM #Vigencias V)
       OR C.CCIdCorporativo IN
          (SELECT X.IdCorporativo FROM #Casos X WHERE X.IdCorporativo IS NOT NULL)
       OR C.CCIdEmpresaPerfil IN (SELECT X.IdEmpresa FROM #Casos X)
    UNION
    SELECT E.CEIdCompensacion
    FROM dbo.ff_CompensacionEmpleado E
    WHERE E.CEIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F)
    UNION
    SELECT O.CPIdCompensacion
    FROM dbo.ff_CompensacionPlanOpcion O
    WHERE O.CPIdPlanOpcion IN (SELECT P.IdOpcion FROM #Opciones P)
) X
WHERE X.IdCompensacion IS NOT NULL;

CREATE TABLE #Exportacion
(
    OrdenCarga INT NOT NULL,
    Tabla SYSNAME NOT NULL,
    Clave NVARCHAR(400) NULL,
    FilaJson NVARCHAR(MAX) NOT NULL,
    EsDatoDerivado BIT NOT NULL
);

/* Contexto general y listado de casos seleccionados. */
INSERT INTO #Exportacion
SELECT
    0,
    '__CONTEXTO',
    'GENERAL',
    (
        SELECT
            CONVERT(NVARCHAR(128), SERVERPROPERTY('ServerName')) AS servidor,
            DB_NAME() AS baseDatos,
            GETDATE() AS fechaExtraccion,
            @CantidadCambiosCalificados AS cambiosCalificadosSolicitados,
            @CantidadCasosEspeciales AS casosEspecialesSolicitados,
            (SELECT COUNT(*) FROM #Casos C
             WHERE C.Origen = 'CAMBIO_CALIFICADO') AS cambiosCalificadosEncontrados,
            (SELECT COUNT(*) FROM #Casos C
             WHERE C.Origen = 'CASO_ESPECIAL') AS casosEspecialesEncontrados,
            @IdEmpresaFiltro AS idEmpresaFiltro,
            JSON_QUERY
            (
                (
                    SELECT
                        C.CasoId,
                        C.Origen,
                        C.NivelCerteza,
                        C.IdReferencia,
                        C.IdLog,
                        C.SolicitudSemilla,
                        C.IdTitular,
                        C.IdEmpresa,
                        C.IdCorporativo,
                        C.IdConfiguracion,
                        C.NumeroEmpleado,
                        C.FechaSolicitud
                    FROM #Casos C
                    ORDER BY C.Origen, C.CasoId
                    FOR JSON PATH, INCLUDE_NULL_VALUES
                )
            ) AS casos
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
    ),
    0;

/* 100-199: catalogos requeridos por las llaves y reglas. */
INSERT INTO #Exportacion
SELECT 100, 'dbo.ff_Estatus', CONCAT(T.ESId, '|', ISNULL(T.ESModulo, '')),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_Estatus T;

INSERT INTO #Exportacion
SELECT 101, 'dbo.ff_Sexo', CONVERT(NVARCHAR(100), T.SEIdSexo),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_Sexo T;

INSERT INTO #Exportacion
SELECT 102, 'dbo.ff_Parentesco', CONVERT(NVARCHAR(100), T.PAIdParentesco),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_Parentesco T;

INSERT INTO #Exportacion
SELECT 103, 'dbo.ff_GrupoParentesco', CONVERT(NVARCHAR(100), T.GPIdGrupoParentesco),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_GrupoParentesco T;

INSERT INTO #Exportacion
SELECT 104, 'dbo.ff_GrupoParentescoParentesco',
       CONCAT(T.GPIdGrupoParentesco, '|', T.GPIdParentesco, '|', T.GPIdSexo),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_GrupoParentescoParentesco T;

INSERT INTO #Exportacion
SELECT 105, 'dbo.ff_PeriodicidadPago', CONVERT(NVARCHAR(100), T.PPIdPeriodicidadPago),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_PeriodicidadPago T;

INSERT INTO #Exportacion
SELECT 106, 'dbo.ff_TipoCondicion', CONVERT(NVARCHAR(100), T.TCIdTipoCondicion),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_TipoCondicion T;

INSERT INTO #Exportacion
SELECT 107, 'dbo.ff_TipoPromocion', CONVERT(NVARCHAR(100), T.TPIdTipoPromocion),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_TipoPromocion T;

INSERT INTO #Exportacion
SELECT 108, 'dbo.ff_TarifaTipo', CONVERT(NVARCHAR(100), T.TTIdTipoTarifa),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_TarifaTipo T;

INSERT INTO #Exportacion
SELECT 109, 'dbo.ff_TipoFumador', CONVERT(NVARCHAR(100), T.TFIdTipoFumador),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_TipoFumador T;

INSERT INTO #Exportacion
SELECT 110, 'dbo.ff_TipoCostoPlan', CONVERT(NVARCHAR(100), T.TCIdTipoCostoPlan),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_TipoCostoPlan T;

INSERT INTO #Exportacion
SELECT 111, 'dbo.ff_TipoSumaAsegurada', CONVERT(NVARCHAR(100), T.TSIdTipoSumaAsegurada),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_TipoSumaAsegurada T;

INSERT INTO #Exportacion
SELECT 112, 'dbo.ff_Moneda', CONVERT(NVARCHAR(100), T.MOIdMoneda),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_Moneda T;

INSERT INTO #Exportacion
SELECT 113, 'dbo.ff_ParentescoDefaulteo', CONVERT(NVARCHAR(100), T.PDIdParentescoDefaulteo),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_ParentescoDefaulteo T;

INSERT INTO #Exportacion
SELECT 114, 'dbo.ff_TipoDefaulteo', CONVERT(NVARCHAR(100), T.TDIdTipoDefaulteo),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_TipoDefaulteo T;

INSERT INTO #Exportacion
SELECT 115, 'dbo.ff_Campo', CONVERT(NVARCHAR(100), T.CAIdCampo),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_Campo T;

/* 200-299: empresa, configuracion, vigencias y perfiles. */
INSERT INTO #Exportacion
SELECT 200, 'dbo.ff_Configuracion', CONVERT(NVARCHAR(100), T.COIdConfiguracion),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_Configuracion T
WHERE T.COIdConfiguracion IN
      (
          SELECT C.IdConfiguracion
          FROM #Casos C
          WHERE C.IdConfiguracion IS NOT NULL
          UNION
          SELECT V.VIIdConfiguracion
          FROM dbo.ff_Vigencia V
          WHERE V.VIIdVigencia IN (SELECT X.IdVigencia FROM #Vigencias X)
      );

INSERT INTO #Exportacion
SELECT 201, 'dbo.ff_Empresa', CONVERT(NVARCHAR(100), T.EMIdEmpresa),
       JSON_MODIFY(
           (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
           N'$.EMClaveAcceso', NULL),
       0
FROM dbo.ff_Empresa T
WHERE T.EMIdEmpresa IN (SELECT E.IdEmpresa FROM #Empresas E);

INSERT INTO #Exportacion
SELECT 202, 'dbo.ff_Vigencia', CONVERT(NVARCHAR(100), T.VIIdVigencia),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_Vigencia T
WHERE T.VIIdVigencia IN (SELECT V.IdVigencia FROM #Vigencias V);

INSERT INTO #Exportacion
SELECT 203, 'dbo.ff_Perfil', CONVERT(NVARCHAR(100), T.PEIdPerfil),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_Perfil T
WHERE T.PEIdPerfil IN (SELECT P.IdPerfil FROM #Perfiles P);

INSERT INTO #Exportacion
SELECT 204, 'dbo.ff_PlanesPerfilScript', CONVERT(NVARCHAR(100), T.Id),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_PlanesPerfilScript T
WHERE T.EMIdEmpresa IN (SELECT C.IdEmpresa FROM #Casos C);

INSERT INTO #Exportacion
SELECT 205, 'dbo.ff_Parametro', CONCAT(T.PAIdEmpresa, '|', T.PAId),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_Parametro T
WHERE T.PAIdEmpresa IN (SELECT E.IdEmpresa FROM #Empresas E);

INSERT INTO #Exportacion
SELECT 206, 'dbo.ff_EdoCuentaConcepto', CONVERT(NVARCHAR(100), T.ECIdEdoCuentaConcepto),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_EdoCuentaConcepto T
WHERE T.ECIdConfiguracion IN
      (
          SELECT C.IdConfiguracion
          FROM #Casos C
          WHERE C.IdConfiguracion IS NOT NULL
      );

INSERT INTO #Exportacion
SELECT 207, 'dbo.ff_Documentos', CONVERT(NVARCHAR(100), T.DOId),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_Documentos T
WHERE T.DOIdEmpresa IN (SELECT E.IdEmpresa FROM #Empresas E)
   OR T.DOId IN
      (
          SELECT P.PLIdArchivoInformacion
          FROM dbo.ff_Plan P
          WHERE P.PLIdPlan IN (SELECT X.IdPlan FROM #Planes X)
            AND P.PLIdArchivoInformacion IS NOT NULL
          UNION
          SELECT O.POIdArchivoInformacion
          FROM dbo.ff_PlanOpcion O
          WHERE O.POIdPlanOpcion IN (SELECT X.IdOpcion FROM #Opciones X)
            AND O.POIdArchivoInformacion IS NOT NULL
      );

INSERT INTO #Exportacion
SELECT 208, 'dbo.ff_VigenciaCalendarioPago', CONVERT(NVARCHAR(100), T.VCIdVigenciaCalendarioPago),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_VigenciaCalendarioPago T
WHERE T.VCIdVigencia IN (SELECT V.IdVigencia FROM #Vigencias V);

INSERT INTO #Exportacion
SELECT 209, 'dbo.fb_CalendarioIngresoNomina', CONVERT(NVARCHAR(100), T.CNIdCalendarioIngresoNomina),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.fb_CalendarioIngresoNomina T
WHERE T.CNIdEmpresa IN (SELECT C.IdEmpresa FROM #Casos C)
   OR T.CNIdVigencia IN (SELECT V.IdVigencia FROM #Vigencias V);

/* Configuracion y trazabilidad propia de Casos Especiales. */
INSERT INTO #Exportacion
SELECT 210, 'dbo.bf_ConfiguracionDefaulteo', CONVERT(NVARCHAR(100), T.CDId),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.bf_ConfiguracionDefaulteo T
WHERE T.CDId IN
      (
          SELECT L.LDIdConfiguracion
          FROM dbo.bf_LogDefaulteo L
          INNER JOIN #Casos C ON C.IdLog = L.LDId
          WHERE L.LDIdConfiguracion IS NOT NULL
      )
   OR T.CDIdEmpresa IN (SELECT C.IdEmpresa FROM #Casos C)
   OR T.CDIdCorporativo IN
      (SELECT C.IdCorporativo FROM #Casos C WHERE C.IdCorporativo IS NOT NULL);

INSERT INTO #Exportacion
SELECT 211, 'dbo.bf_LogDefaulteo', CONVERT(NVARCHAR(100), T.LDId),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.bf_LogDefaulteo T
WHERE T.LDId IN
      (SELECT C.IdLog FROM #Casos C WHERE C.IdLog IS NOT NULL);

INSERT INTO #Exportacion
SELECT 212, 'dbo.bf_LogErroresDefaulteo', CONVERT(NVARCHAR(100), T.LEDId),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.bf_LogErroresDefaulteo T
WHERE T.LEDIdLog IN
      (SELECT C.IdLog FROM #Casos C WHERE C.IdLog IS NOT NULL);

INSERT INTO #Exportacion
SELECT 213, 'dbo.bf_SolicitudDefaulteoGenerada', CONVERT(NVARCHAR(100), T.SDId),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.bf_SolicitudDefaulteoGenerada T
WHERE T.SDIdSolicitud IN (SELECT S.IdSolicitud FROM #Solicitudes S)
   OR T.SDIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F);

INSERT INTO #Exportacion
SELECT 214, 'dbo.bf_WizardConfig', CONVERT(NVARCHAR(100), T.WizardConfig_Id),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.bf_WizardConfig T
WHERE T.WizardConfig_Clave LIKE 'CREA06:%';

INSERT INTO #Exportacion
SELECT 215, 'dbo.bf_EdicionEmpresaEmpleado', CONVERT(NVARCHAR(100), T.EEIdEdicion),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.bf_EdicionEmpresaEmpleado T
WHERE T.EEIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F);

INSERT INTO #Exportacion
SELECT 216, 'dbo.bf_WizardEnrollmentEmpresa', CONVERT(NVARCHAR(100), T.WizardEmpresa_idEmpresa),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.bf_WizardEnrollmentEmpresa T
WHERE T.IdEmpresa IN (SELECT C.IdEmpresa FROM #Casos C)
   OR T.IdVigencia IN (SELECT V.IdVigencia FROM #Vigencias V);

INSERT INTO #Exportacion
SELECT 217, 'dbo.bf_WizardEnrollmentLog', CONVERT(NVARCHAR(100), T.WizardLog_id),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.bf_WizardEnrollmentLog T
WHERE T.IdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F)
  AND T.IdVigencia IN (SELECT V.IdVigencia FROM #Vigencias V);

/* Formulas y constantes que pueden intervenir en compensaciones/candados. */
INSERT INTO #Exportacion
SELECT 220, 'dbo.ff_FormulaConstante', CONCAT(T.FCIdCorporativo, '|', T.FCIdConstante),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_FormulaConstante T
WHERE T.FCIdCorporativo IN
      (SELECT C.IdCorporativo FROM #Casos C WHERE C.IdCorporativo IS NOT NULL);

INSERT INTO #Exportacion
SELECT 221, 'dbo.ff_FormulaFormula', CONCAT(T.FFIdCorporativo, '|', T.FFIdFormula),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_FormulaFormula T
WHERE T.FFIdCorporativo IN
      (SELECT C.IdCorporativo FROM #Casos C WHERE C.IdCorporativo IS NOT NULL);

INSERT INTO #Exportacion
SELECT 222, 'dbo.ff_FormulaFuncion', CONCAT(T.FFUIdCorporativo, '|', T.FFUIdFuncion),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_FormulaFuncion T
WHERE T.FFUIdCorporativo IN
      (SELECT C.IdCorporativo FROM #Casos C WHERE C.IdCorporativo IS NOT NULL);

/* 300-399: planes, opciones, elegibilidad, basicos y condiciones. */
INSERT INTO #Exportacion
SELECT 300, 'dbo.ff_Ramo', CONVERT(NVARCHAR(100), T.RAIdRamo),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_Ramo T
WHERE T.RAIdRamo IN
      (
          SELECT P.PLIdRamo
          FROM dbo.ff_Plan P
          WHERE P.PLIdPlan IN (SELECT X.IdPlan FROM #Planes X)
          UNION
          SELECT S.SOIdRamo
          FROM dbo.ff_Solicitud S
          WHERE S.SOIdSolicitud IN (SELECT X.IdSolicitud FROM #Solicitudes X)
      );

INSERT INTO #Exportacion
SELECT 301, 'dbo.ff_Plan', CONVERT(NVARCHAR(100), T.PLIdPlan),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_Plan T
WHERE T.PLIdPlan IN (SELECT P.IdPlan FROM #Planes P);

INSERT INTO #Exportacion
SELECT 302, 'dbo.ff_PlanOpcion', CONVERT(NVARCHAR(100), T.POIdPlanOpcion),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_PlanOpcion T
WHERE T.POIdPlanOpcion IN (SELECT O.IdOpcion FROM #Opciones O);

INSERT INTO #Exportacion
SELECT 303, 'dbo.ff_PlanOpcionPerfil', CONVERT(NVARCHAR(100), T.PPIdPlanOpcionPerfil),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_PlanOpcionPerfil T
WHERE T.PPIdPlanOpcion IN (SELECT O.IdOpcion FROM #Opciones O)
  AND T.PPIdPerfil IN (SELECT P.IdPerfil FROM #Perfiles P);

INSERT INTO #Exportacion
SELECT 304, 'dbo.ff_PlanOpcionVigencia', CONVERT(NVARCHAR(100), T.VCIdPlanOpcionVigencia),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_PlanOpcionVigencia T
WHERE T.VCIdPlanOpcion IN (SELECT O.IdOpcion FROM #Opciones O)
  AND T.VCIdVigencia IN (SELECT V.IdVigencia FROM #Vigencias V);

INSERT INTO #Exportacion
SELECT 305, 'dbo.ff_PlanOpcionSexo', CONVERT(NVARCHAR(100), T.PSIdPlanOpcionSexo),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_PlanOpcionSexo T
WHERE T.PSIdPlanOpcion IN (SELECT O.IdOpcion FROM #Opciones O);

INSERT INTO #Exportacion
SELECT 306, 'dbo.ff_PlanOpcionParentescoEdad', CONVERT(NVARCHAR(100), T.PPIdPlanOpcionParentescoEdad),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_PlanOpcionParentescoEdad T
WHERE T.PPIdPlanOpcion IN (SELECT O.IdOpcion FROM #Opciones O);

INSERT INTO #Exportacion
SELECT 307, 'dbo.ff_PlanOpcionCompuesto', CONVERT(NVARCHAR(100), T.PCIdPlanOpcionCompuesto),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_PlanOpcionCompuesto T
WHERE T.PCIdPlanOpcion IN (SELECT O.IdOpcion FROM #Opciones O)
   OR T.PCIdPlanOpcionIntegrante IN (SELECT O.IdOpcion FROM #Opciones O);

INSERT INTO #Exportacion
SELECT 308, 'dbo.ff_PlanRelacion', CONVERT(NVARCHAR(100), T.PRIdPlanRelacion),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_PlanRelacion T
WHERE T.PRIdPlan IN (SELECT P.IdPlan FROM #Planes P);

INSERT INTO #Exportacion
SELECT 309, 'dbo.ff_PlanOpcionHomologacion', CONVERT(NVARCHAR(100), T.PHIdPlanOpcionHomologacion),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_PlanOpcionHomologacion T
WHERE T.PHIdEmpresa IN (SELECT C.IdEmpresa FROM #Casos C)
   OR T.PHIdPlanOpcionAnt IN (SELECT O.IdOpcion FROM #Opciones O)
   OR T.PHIdPlanOpcionAct IN (SELECT O.IdOpcion FROM #Opciones O)
   OR T.PHIdVigenciaAnt IN (SELECT V.IdVigencia FROM #Vigencias V)
   OR T.PHIdVigenciaAct IN (SELECT V.IdVigencia FROM #Vigencias V);

INSERT INTO #Exportacion
SELECT 310, 'dbo.ff_PlanBasico', CONVERT(NVARCHAR(100), T.PBIdPlanBasico),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_PlanBasico T
WHERE T.PBIdPerfil IN (SELECT P.IdPerfil FROM #Perfiles P)
  AND
      (
          T.PBIdVigencia IS NULL
          OR T.PBIdVigencia IN (SELECT V.IdVigencia FROM #Vigencias V)
      );

INSERT INTO #Exportacion
SELECT 311, 'dbo.ff_PlanBasicoDetalle', CONVERT(NVARCHAR(100), T.PBIdPlanBasicoDetalle),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_PlanBasicoDetalle T
WHERE T.PBIdPlanBasico IN
      (
          SELECT B.PBIdPlanBasico
          FROM dbo.ff_PlanBasico B
          WHERE B.PBIdPerfil IN (SELECT P.IdPerfil FROM #Perfiles P)
            AND
                (
                    B.PBIdVigencia IS NULL
                    OR B.PBIdVigencia IN (SELECT V.IdVigencia FROM #Vigencias V)
                )
      );

INSERT INTO #Exportacion
SELECT 312, 'dbo.ff_CondicionPlan', CONVERT(NVARCHAR(100), T.CPIdCondicionPlan),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_CondicionPlan T
WHERE T.CPIdCondicionPlan IN (SELECT C.IdCondicion FROM #Condiciones C);

INSERT INTO #Exportacion
SELECT 313, 'dbo.ff_DetalleCondicionPlan', CONVERT(NVARCHAR(100), T.DCIdDetalleCondicionPlan),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_DetalleCondicionPlan T
WHERE T.DCIdCondicionPlan IN (SELECT C.IdCondicion FROM #Condiciones C);

INSERT INTO #Exportacion
SELECT 314, 'dbo.ff_ResultadoCondicionPlan', CONVERT(NVARCHAR(100), T.RCIdResultadoCondicionPlan),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_ResultadoCondicionPlan T
WHERE T.RCIdCondicionPlan IN (SELECT C.IdCondicion FROM #Condiciones C);

INSERT INTO #Exportacion
SELECT 315, 'dbo.ff_PlanesParametros', CONVERT(NVARCHAR(100), T.PPId),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_PlanesParametros T
WHERE T.PPIdEmpresa IN (SELECT C.IdEmpresa FROM #Casos C)
   OR T.PPIdPlan IN (SELECT P.IdPlan FROM #Planes P);

INSERT INTO #Exportacion
SELECT 316, 'dbo.bf_GrupoPlanesCorporativo', CONVERT(NVARCHAR(100), T.GPIdPlanesGrupo),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.bf_GrupoPlanesCorporativo T
WHERE T.GPIdPlan IN (SELECT P.IdPlan FROM #Planes P);

INSERT INTO #Exportacion
SELECT 317, 'dbo.bf_PlanFormaPagoNoValido', CONVERT(NVARCHAR(100), T.IdPlanFormaPago),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.bf_PlanFormaPagoNoValido T
WHERE T.IdPlan IN (SELECT P.IdPlan FROM #Planes P);

/* Reglas especificas para captura y validacion de beneficiarios por plan. */
INSERT INTO #Exportacion
SELECT 318, 'dbo.bf_PlanBeneficiarioParametro', CONVERT(NVARCHAR(100), T.PBP_id),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.bf_PlanBeneficiarioParametro T
WHERE T.Plan_id IN (SELECT P.IdPlan FROM #Planes P)
   OR T.PBP_id IN
      (
          SELECT B.PBP_id
          FROM dbo.bf_BeneficiarioPlanSecundario B
          WHERE B.bpIdTitular IN (SELECT F.IdEmpleado FROM #Familia F)
             OR B.bpIdDependiente IN (SELECT F.IdEmpleado FROM #Familia F)
             OR B.bpIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F)
      );

INSERT INTO #Exportacion
SELECT 319, 'dbo.ff_Plan_Parentesco', CONVERT(NVARCHAR(100), T.PPId),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_Plan_Parentesco T
WHERE T.PPIdPlan IN (SELECT P.IdPlan FROM #Planes P);

INSERT INTO #Exportacion
SELECT 320, 'dbo.bf_ConsentimientoVida', CONVERT(NVARCHAR(100), T.CVIDConsentimientoVida),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.bf_ConsentimientoVida T
WHERE T.CVIDConsentimientoVida IN
      (
          SELECT P.PLIdConsentimientoVida
          FROM dbo.ff_Plan P
          WHERE P.PLIdPlan IN (SELECT X.IdPlan FROM #Planes X)
            AND P.PLIdConsentimientoVida IS NOT NULL
      );

INSERT INTO #Exportacion
SELECT 321, 'dbo.ff_DocumentoPlanB3', CONVERT(NVARCHAR(100), T.DPIdDoc),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_DocumentoPlanB3 T
WHERE T.DPIdPlan IN (SELECT P.IdPlan FROM #Planes P)
  AND T.DPIdEmpresa IN (SELECT E.IdEmpresa FROM #Empresas E);

INSERT INTO #Exportacion
SELECT 322, 'dbo.bf_ConsentimientoPoliza', CONVERT(NVARCHAR(100), T.cpId),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.bf_ConsentimientoPoliza T
WHERE T.cpIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F)
   OR
      (
          T.cpIdEmpresa IN (SELECT C.IdEmpresa FROM #Casos C)
          AND
             (
                 T.cpIdPerfil IS NULL
                 OR T.cpIdPerfil IN (SELECT P.IdPerfil FROM #Perfiles P)
             )
          AND
             (
                 T.cpIdPlan IS NULL
                 OR T.cpIdPlan IN (SELECT P.IdPlan FROM #Planes P)
             )
          AND
             (
                 T.cpIdPlanOpcion IS NULL
                 OR T.cpIdPlanOpcion IN (SELECT O.IdOpcion FROM #Opciones O)
             )
      );

INSERT INTO #Exportacion
SELECT 323, 'dbo.ff_InfoPlanMascota',
       CONCAT(ISNULL(T.IdSolicitud, 0), '|', ISNULL(T.IdBeneficiario, 0),
              '|', ISNULL(T.IdPlan, 0), '|', ISNULL(T.NumEmpleado, '')),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_InfoPlanMascota T
WHERE T.IdSolicitud IN (SELECT S.IdSolicitud FROM #Solicitudes S)
   OR T.IdPlan IN (SELECT P.IdPlan FROM #Planes P)
      AND EXISTS
          (
              SELECT 1
              FROM #Casos C
              WHERE C.NumeroEmpleado = T.NumEmpleado
          );

/* 400-499: tarifas actuales, historicas y por perfil. */
INSERT INTO #Exportacion
SELECT 400, 'dbo.ff_Tarifa', CONVERT(NVARCHAR(100), T.TAIdTarifa),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_Tarifa T
WHERE T.TAIdTarifa IN (SELECT X.IdTarifa FROM #Tarifas X);

INSERT INTO #Exportacion
SELECT 401, 'dbo.ff_TarifaCosto', CONVERT(NVARCHAR(100), T.TCIdTarifaCosto),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_TarifaCosto T
WHERE T.TCIdPlanOpcion IN (SELECT O.IdOpcion FROM #Opciones O)
  AND T.TCIdTarifa IN (SELECT X.IdTarifa FROM #Tarifas X);

INSERT INTO #Exportacion
SELECT 402, 'dbo.ff_TarifaCosto_hist',
       CONCAT(T.TCIdTarifaCosto, '|', T.TCIdTarifa, '|', T.TCIdPlanOpcion),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_TarifaCosto_hist T
WHERE T.TCIdPlanOpcion IN (SELECT O.IdOpcion FROM #Opciones O)
  AND T.TCIdTarifa IN (SELECT X.IdTarifa FROM #Tarifas X);

INSERT INTO #Exportacion
SELECT 403, 'dbo.ff_TarifaCostoPerfil',
       CONCAT(T.TPIdPerfil, '|', T.TPIdTarifa, '|', T.TPIdPlanOpcion),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_TarifaCostoPerfil T
WHERE T.TPIdPerfil IN (SELECT P.IdPerfil FROM #Perfiles P)
  AND
      (
          T.TPIdPlanOpcion IN (SELECT O.IdOpcion FROM #Opciones O)
          OR T.TPIdTarifa IN (SELECT X.IdTarifa FROM #Tarifas X)
      );

INSERT INTO #Exportacion
SELECT 404, 'dbo.bf_TarifaCostoRango', CONVERT(NVARCHAR(100), T.TCRIdTarifaCostoRango),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.bf_TarifaCostoRango T
WHERE T.TCRIdPlanOpcion IN (SELECT O.IdOpcion FROM #Opciones O)
   OR T.TCRIdPerfil IN (SELECT P.IdPerfil FROM #Perfiles P);

/* 500-599: compensaciones. */
INSERT INTO #Exportacion
SELECT 500, 'dbo.ff_Compensacion', CONVERT(NVARCHAR(100), T.COIdCompensacion),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_Compensacion T
WHERE T.COIdCompensacion IN (SELECT C.IdCompensacion FROM #Compensaciones C);

INSERT INTO #Exportacion
SELECT 501, 'dbo.ff_CompensacionConfiguracion', CONVERT(NVARCHAR(100), T.CCIdCompensacionConfiguracion),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_CompensacionConfiguracion T
WHERE T.CCIdCompensacion IN (SELECT C.IdCompensacion FROM #Compensaciones C)
   OR T.CCIdPerfil IN (SELECT P.IdPerfil FROM #Perfiles P)
   OR T.CCIdVigencia IN (SELECT V.IdVigencia FROM #Vigencias V);

INSERT INTO #Exportacion
SELECT 502, 'dbo.ff_CompensacionPlanOpcion', CONVERT(NVARCHAR(100), T.CPIdCompensacionPlanOpcion),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_CompensacionPlanOpcion T
WHERE T.CPIdCompensacion IN (SELECT C.IdCompensacion FROM #Compensaciones C)
   OR T.CPIdPlanOpcion IN (SELECT O.IdOpcion FROM #Opciones O);

INSERT INTO #Exportacion
SELECT 503, 'dbo.ff_CompensacionEmpleado', CONVERT(NVARCHAR(100), T.CEIdCompensacionEmpleado),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_CompensacionEmpleado T
WHERE T.CEIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F);

INSERT INTO #Exportacion
SELECT 504, 'dbo.bf_AplicacionCompensacion',
       CONCAT(T.ACIdEmpleado, '|', T.ACIdCompensacion, '|',
              T.ACIdPlanOpcion, '|', T.ACOrden, '|', ISNULL(T.ACIdSolicitud, 0)),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.bf_AplicacionCompensacion T
WHERE T.ACIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F)
   OR T.ACIdSolicitud IN (SELECT S.IdSolicitud FROM #Solicitudes S);

/* 600-699: reglas auxiliares y candados. */
INSERT INTO #Exportacion
SELECT 600, 'dbo.ff_AperturaSistema', CONVERT(NVARCHAR(100), T.ASIdAperturaSistema),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_AperturaSistema T
WHERE T.ASIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F);

INSERT INTO #Exportacion
SELECT 601, 'dbo.ff_PermanenciaMinimaControl', CONVERT(NVARCHAR(100), T.PMId),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_PermanenciaMinimaControl T
WHERE T.PMIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F)
   OR T.PMIdSolicitud IN (SELECT S.IdSolicitud FROM #Solicitudes S);

INSERT INTO #Exportacion
SELECT 602, 'dbo.ff_VidaAdicional', CONVERT(NVARCHAR(100), T.VAIdVidaAdicional),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_VidaAdicional T
WHERE T.VAIdPerfil IN (SELECT P.IdPerfil FROM #Perfiles P);

INSERT INTO #Exportacion
SELECT 603, 'dbo.ff_ValidaSAVida', CONVERT(NVARCHAR(100), T.VSIdValidaSAVida),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_ValidaSAVida T
WHERE T.VSIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F);

INSERT INTO #Exportacion
SELECT 604, 'dbo.bf_empledosDeloitte_SExc',
       CONCAT(T.ESIdEmpresa, '|', T.ESNumeroEmpleado),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.bf_empledosDeloitte_SExc T
WHERE EXISTS
      (
          SELECT 1
          FROM #Casos C
          WHERE C.IdEmpresa = T.ESIdEmpresa
            AND C.NumeroEmpleado = T.ESNumeroEmpleado
      );

/* 700-799: familia, historial y staging que alimentan PlanEspejo. */
INSERT INTO #Exportacion
SELECT 700, 'dbo.ff_Empleado', CONVERT(NVARCHAR(100), T.Id),
       JSON_MODIFY(
           JSON_MODIFY(
               (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES),
               N'$.EMClaveAcceso', NULL),
           N'$."EMContrase' + NCHAR(241) + N'a"', NULL),
       0
FROM dbo.ff_Empleado T
WHERE T.Id IN (SELECT F.IdEmpleado FROM #Familia F);

INSERT INTO #Exportacion
SELECT 701, 'dbo.ff_Solicitud', CONVERT(NVARCHAR(100), T.SOIdSolicitud),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_Solicitud T
WHERE T.SOIdSolicitud IN (SELECT S.IdSolicitud FROM #Solicitudes S);

INSERT INTO #Exportacion
SELECT 702, 'dbo.ff_PlanOpcionSeleccion',
       CONCAT(T.POIdPlanOpcionSeleccion, '|', T.PlanOpcionSeleccion_Id),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_PlanOpcionSeleccion T
WHERE T.POIdSolicitud IN (SELECT S.IdSolicitud FROM #Solicitudes S)
   OR T.POIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F);

INSERT INTO #Exportacion
SELECT 703, 'dbo.ff_PlanOpcionSeleccionTmp',
       CONCAT(T.POIdPlanOpcionSeleccion, '|', T.PlanOpcionSeleccion_Id),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_PlanOpcionSeleccionTmp T
WHERE T.POIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F)
   OR
      EXISTS
      (
          SELECT 1
          FROM #Casos C
          WHERE C.IdEmpresa = T.POIdEmpresa
            AND C.NumeroEmpleado = T.PONumeroEmpleado
      );

INSERT INTO #Exportacion
SELECT 704, 'dbo.ff_PlanOpcionSeleccion_Historico',
       CONVERT(NVARCHAR(100), T.POHIdPOS),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_PlanOpcionSeleccion_Historico T
WHERE T.POHIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F)
   OR T.POHIdPlanOpcionSeleccion IN
      (
          SELECT S.POIdPlanOpcionSeleccion
          FROM dbo.ff_PlanOpcionSeleccion S
          WHERE S.POIdSolicitud IN (SELECT X.IdSolicitud FROM #Solicitudes X)
             OR S.POIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F)
      );

INSERT INTO #Exportacion
SELECT 705, 'dbo.ff_planOpcionSeleccionB3',
       CONVERT(NVARCHAR(100), T.POIdPlanOpcionSeleccion),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_planOpcionSeleccionB3 T
WHERE T.POIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F)
   OR T.POIdSolicitudB3 IN (SELECT S.IdSolicitud FROM #Solicitudes S);

INSERT INTO #Exportacion
SELECT 706, 'dbo.ff_PlanOpcionSeleccionRetiro',
       CONVERT(NVARCHAR(100), T.PORIdPlanOpcionSeleccion),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.ff_PlanOpcionSeleccionRetiro T
WHERE T.PORIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F)
   OR T.PORIdSolicitud IN (SELECT S.IdSolicitud FROM #Solicitudes S);

/*
  Cambios calificados consulta esta tabla por idEmpleado/idVigencia.
  En LocalDB puede no existir; por eso la lectura es condicional y dinamica.
*/
IF OBJECT_ID(N'dbo.tmpPlanesSeleccionados_V3', N'U') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql N'
        INSERT INTO #Exportacion
        SELECT
            707,
            ''dbo.tmpPlanesSeleccionados_V3'',
            CONCAT(T.idEmpleado, ''|'', T.idVigencia, ''|'',
                   ROW_NUMBER() OVER
                   (
                       PARTITION BY T.idEmpleado, T.idVigencia
                       ORDER BY (SELECT NULL)
                   )),
            (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER,
             INCLUDE_NULL_VALUES),
            0
        FROM dbo.tmpPlanesSeleccionados_V3 T
        WHERE T.idEmpleado IN (SELECT F.IdEmpleado FROM #Familia F)
          AND T.idVigencia IN (SELECT V.IdVigencia FROM #Vigencias V);';
END;

/* Beneficiarios vigentes, historicos, secundarios y sustitutos. */
INSERT INTO #Exportacion
SELECT 720, 'dbo.bf_BeneficiarioPlan', CONVERT(NVARCHAR(100), T.bpIdBeneficiario),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.bf_BeneficiarioPlan T
WHERE T.bpIdTitular IN (SELECT F.IdEmpleado FROM #Familia F)
   OR T.bpIdDependiente IN (SELECT F.IdEmpleado FROM #Familia F)
   OR T.bpIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F);

INSERT INTO #Exportacion
SELECT 721, 'dbo.BF_BeneficiarioPlan_HIS', CONVERT(NVARCHAR(100), T.BHIdBenificiario),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.BF_BeneficiarioPlan_HIS T
WHERE T.BHIdTitular IN (SELECT F.IdEmpleado FROM #Familia F)
   OR T.BHIdDependiente IN (SELECT F.IdEmpleado FROM #Familia F)
   OR T.BHIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F);

INSERT INTO #Exportacion
SELECT 722, 'dbo.bf_BeneficiarioPlanSecundario',
       CONVERT(NVARCHAR(100), T.bpIdBeneficiarioSec),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.bf_BeneficiarioPlanSecundario T
WHERE T.bpIdTitular IN (SELECT F.IdEmpleado FROM #Familia F)
   OR T.bpIdDependiente IN (SELECT F.IdEmpleado FROM #Familia F)
   OR T.bpIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F);

INSERT INTO #Exportacion
SELECT 723, 'dbo.bf_BeneficiarioSustituto', CONVERT(NVARCHAR(100), T.BSId),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 0
FROM dbo.bf_BeneficiarioSustituto T
WHERE T.BSIdEmpleado IN (SELECT F.IdEmpleado FROM #Familia F)
   OR T.BSIdSolicitud IN (SELECT S.IdSolicitud FROM #Solicitudes S);

/*
  bf_PlanCotizador es derivada, pero se exporta porque algunas ramas del
  wrapper consultan topes ya calculados. Se marca para decidir si se importa.
*/
INSERT INTO #Exportacion
SELECT 800, 'dbo.bf_PlanCotizador',
       CONCAT(T.PCIdEmpresa, '|', T.PCNumeroEmpleado, '|', T.EMIdEmpleado,
              '|', T.POIdPlanOpcion, '|', T.TCIdTarifaCosto),
       (SELECT T.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES), 1
FROM dbo.bf_PlanCotizador T
WHERE EXISTS
      (
          SELECT 1
          FROM #Casos C
          WHERE C.IdEmpresa = T.PCIdEmpresa
            AND
               (
                   C.NumeroEmpleado = T.PCNumeroEmpleado
                   OR EXISTS
                      (
                          SELECT 1
                          FROM #FamiliaCaso F
                          WHERE F.CasoId = C.CasoId
                            AND F.IdEmpleado = T.EMIdEmpleado
                      )
               )
      );

/*
  UNICO RESULTADO A GUARDAR COMO CSV.
  Cada fila conserva exactamente una fila de una tabla origen.
*/
SELECT
    CASE WHEN E.Tabla = '__CONTEXTO' THEN 'CONTEXTO' ELSE 'DATO' END
        AS tipoRegistro,
    E.OrdenCarga AS ordenCarga,
    E.Tabla AS tabla,
    E.Clave AS clave,
    COUNT(*) OVER (PARTITION BY E.Tabla) AS totalFilasTabla,
    E.FilaJson AS filaJson,
    E.EsDatoDerivado AS esDatoDerivado
FROM #Exportacion E
ORDER BY E.OrdenCarga, E.Tabla, E.Clave;
