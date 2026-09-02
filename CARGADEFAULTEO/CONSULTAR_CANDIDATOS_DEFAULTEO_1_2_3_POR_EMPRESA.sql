/*
    CANDIDATOS PARA PRUEBAS DE DEFAULTEO 1, 2 Y 3

    - Solo lectura: no inserta, actualiza ni elimina datos.
    - Cambie únicamente @IdEmpresa. Ejemplo: 186.
    - @IdVigenciaDestino = NULL toma la vigencia actual de la configuración;
      si no existe una vigente por fecha, toma la activa más reciente.
    - El resultado 02_CANDIDATOS devuelve registros con las precondiciones
      conocidas del motor. La ejecución del motor sigue siendo la validación
      funcional definitiva porque también evalúa candados particulares.
*/
SET NOCOUNT ON;

DECLARE @IdEmpresa INT = 186;
DECLARE @IdVigenciaDestino INT = NULL;
DECLARE @TopPorTipo INT = 30;
DECLARE @MostrarDescartados BIT = 1;

DECLARE @IdConfiguracion INT;
DECLARE @IdVigenciaOrigen INT;
DECLARE @IdVigenciaActual INT;
DECLARE @EsActual BIT = 0;

SELECT @IdConfiguracion = E.EMIdConfiguracion
FROM dbo.ff_Empresa E
WHERE E.EMIdEmpresa = @IdEmpresa
  AND E.EMIdEstatus = 1;

IF @IdConfiguracion IS NULL
    THROW 52001, 'La empresa no existe, está inactiva o no tiene configuración.', 1;

SELECT TOP (1) @IdVigenciaActual = V.VIIdVigencia
FROM dbo.ff_Vigencia V
WHERE V.VIIdConfiguracion = @IdConfiguracion
  AND V.VIIdEstatus = 1
  AND CONVERT(DATE, GETDATE()) BETWEEN CONVERT(DATE, V.VIVigenciaIni)
                                   AND CONVERT(DATE, V.VIVigenciaFin)
ORDER BY V.VIVigenciaIni DESC, V.VIIdVigencia DESC;

IF @IdVigenciaActual IS NULL
BEGIN
    SELECT TOP (1) @IdVigenciaActual = V.VIIdVigencia
    FROM dbo.ff_Vigencia V
    WHERE V.VIIdConfiguracion = @IdConfiguracion
      AND V.VIIdEstatus = 1
    ORDER BY V.VIVigenciaIni DESC, V.VIIdVigencia DESC;
END;

SET @IdVigenciaDestino = COALESCE(@IdVigenciaDestino, @IdVigenciaActual);

SELECT @IdVigenciaOrigen = V.VIRenovada
FROM dbo.ff_Vigencia V
WHERE V.VIIdVigencia = @IdVigenciaDestino
  AND V.VIIdConfiguracion = @IdConfiguracion
  AND V.VIIdEstatus = 1;

IF @IdVigenciaDestino IS NULL
    THROW 52002, 'No existe una vigencia activa para la configuración de la empresa.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.ff_Vigencia V
    WHERE V.VIIdVigencia = @IdVigenciaDestino
      AND V.VIIdConfiguracion = @IdConfiguracion
      AND V.VIIdEstatus = 1
)
    THROW 52003, 'La vigencia indicada no pertenece a la configuración activa de la empresa.', 1;

SET @EsActual = CONVERT(BIT, CASE WHEN @IdVigenciaDestino = @IdVigenciaActual THEN 1 ELSE 0 END);

SELECT
    '01_CONTEXTO' AS Bloque,
    @IdEmpresa AS IdEmpresa,
    E.EMNombre AS Empresa,
    @IdConfiguracion AS IdConfiguracion,
    @IdVigenciaDestino AS IdVigenciaDestino,
    VD.VINombre AS VigenciaDestino,
    VD.VIVigenciaIni AS InicioDestino,
    VD.VIVigenciaFin AS FinDestino,
    @IdVigenciaOrigen AS IdVigenciaOrigen,
    VO.VINombre AS VigenciaOrigen,
    @EsActual AS EsVigenciaActual,
    CASE
        WHEN @IdVigenciaOrigen IS NULL
            THEN 'ADVERTENCIA: sin VIRenovada; no habrá candidatos confiables para tipos 1 y 3.'
        ELSE 'OK: la vigencia destino pertenece a la empresa y tiene vigencia origen.'
    END AS Resultado
FROM dbo.ff_Empresa E
INNER JOIN dbo.ff_Vigencia VD ON VD.VIIdVigencia = @IdVigenciaDestino
LEFT JOIN dbo.ff_Vigencia VO ON VO.VIIdVigencia = @IdVigenciaOrigen
WHERE E.EMIdEmpresa = @IdEmpresa;

IF OBJECT_ID('tempdb..#Evaluacion') IS NOT NULL DROP TABLE #Evaluacion;

CREATE TABLE #Evaluacion
(
    IdEmpleado INT NOT NULL,
    NumeroEmpleado VARCHAR(100) NULL,
    NombreEmpleado VARCHAR(250) NULL,
    IdPerfil INT NULL,
    Perfil VARCHAR(250) NULL,
    Edad INT NULL,
    IdSexo INT NULL,
    SolicitudesOrigenAprobadas INT NOT NULL,
    SeleccionesOrigen INT NOT NULL,
    SeleccionesElegiblesDestino INT NOT NULL,
    SeleccionesConTarifaDestino INT NOT NULL,
    PlanesBasicosDestino INT NOT NULL,
    PlanesBasicosElegibles INT NOT NULL,
    PlanesBasicosConTarifa INT NOT NULL,
    DependientesActivos INT NOT NULL,
    SolicitudesDestinoActivas INT NOT NULL,
    SolicitudesPendientes99 INT NOT NULL
);

INSERT INTO #Evaluacion
SELECT
    E.Id,
    E.EMNumeroEmpleado,
    LTRIM(RTRIM(CONCAT(
        ISNULL(E.EMNombre1, ''), ' ', ISNULL(E.EMNombre2, ''), ' ',
        ISNULL(E.EMApellidoPaterno, ''), ' ', ISNULL(E.EMApellidoMaterno, '')
    ))),
    E.EMIdPerfil,
    P.PEDescripcion,
    ED.Edad,
    E.EMIdSexo,
    SO.SolicitudesOrigenAprobadas,
    SEL.SeleccionesOrigen,
    ELI.SeleccionesElegiblesDestino,
    TARSEL.SeleccionesConTarifaDestino,
    PB.PlanesBasicosDestino,
    PBELI.PlanesBasicosElegibles,
    PBTAR.PlanesBasicosConTarifa,
    DEP.DependientesActivos,
    SD.SolicitudesDestinoActivas,
    S99.SolicitudesPendientes99
FROM dbo.ff_Empleado E
INNER JOIN dbo.ff_Perfil P
    ON P.PEIdPerfil = E.EMIdPerfil
   AND P.PEIdEmpresa = @IdEmpresa
   AND P.PEIdEstatus = 1
CROSS APPLY
(
    SELECT ISNULL(dbo.RegresaEdadEmpleado(E.Id), E.EMEdad) AS Edad
) ED
OUTER APPLY
(
    SELECT COUNT(DISTINCT S.SOIdSolicitud) AS SolicitudesOrigenAprobadas
    FROM dbo.ff_Solicitud S
    WHERE S.SOIdEmpresa = @IdEmpresa
      AND S.SOIdEmpleado = E.Id
      AND S.SOIdVigencia = @IdVigenciaOrigen
      AND S.SOIdEstatus = 1
      AND S.SOEstatusSolicitud = 1
) SO
OUTER APPLY
(
    SELECT COUNT(DISTINCT POS.POIdPlanOpcionSeleccion) AS SeleccionesOrigen
    FROM dbo.ff_Solicitud S
    INNER JOIN dbo.ff_PlanOpcionSeleccion POS
        ON POS.POIdSolicitud = S.SOIdSolicitud
       AND POS.POIdEstatus = 1
    WHERE S.SOIdEmpresa = @IdEmpresa
      AND S.SOIdEmpleado = E.Id
      AND S.SOIdVigencia = @IdVigenciaOrigen
      AND S.SOIdEstatus = 1
      AND S.SOEstatusSolicitud = 1
) SEL
OUTER APPLY
(
    SELECT COUNT(DISTINCT POS.POIdPlanOpcion) AS SeleccionesElegiblesDestino
    FROM dbo.ff_Solicitud S
    INNER JOIN dbo.ff_PlanOpcionSeleccion POS
        ON POS.POIdSolicitud = S.SOIdSolicitud
       AND POS.POIdEstatus = 1
    INNER JOIN dbo.ff_Empleado M
        ON M.Id = POS.POIdEmpleado
       AND M.EMIdEmpresa = @IdEmpresa
       AND M.EMIdEstatus = 1
    INNER JOIN dbo.ff_PlanOpcion PO
        ON PO.POIdPlanOpcion = POS.POIdPlanOpcion
       AND PO.POIdEstatus = 1
    INNER JOIN dbo.ff_Plan PL
        ON PL.PLIdPlan = PO.POIdPlan
       AND PL.PLIdEstatus = 1
    INNER JOIN dbo.ff_PlanOpcionVigencia POV
        ON POV.VCIdPlanOpcion = POS.POIdPlanOpcion
       AND POV.VCIdVigencia = @IdVigenciaDestino
       AND POV.VCIdEstatus = 2
    INNER JOIN dbo.ff_PlanOpcionPerfil POP
        ON POP.PPIdPlanOpcion = POS.POIdPlanOpcion
       AND POP.PPIdPerfil = E.EMIdPerfil
       AND POP.PPIdEstatus = 1
    INNER JOIN dbo.ff_PlanOpcionSexo POSEX
        ON POSEX.PSIdPlanOpcion = POS.POIdPlanOpcion
       AND POSEX.PSIdSexo = M.EMIdSexo
       AND POSEX.PSIdEstatus = 1
    INNER JOIN dbo.ff_PlanOpcionParentescoEdad POEDAD
        ON POEDAD.PPIdPlanOpcion = POS.POIdPlanOpcion
       AND POEDAD.PPIdParentesco = M.EMIdParentesco
       AND POEDAD.PPIdEstatus = 1
       AND ISNULL(dbo.RegresaEdadEmpleado(M.Id), M.EMEdad)
           BETWEEN POEDAD.PPEdadMin AND POEDAD.PPEdadMax
    WHERE S.SOIdEmpresa = @IdEmpresa
      AND S.SOIdEmpleado = E.Id
      AND S.SOIdVigencia = @IdVigenciaOrigen
      AND S.SOIdEstatus = 1
      AND S.SOEstatusSolicitud = 1
) ELI
OUTER APPLY
(
    SELECT COUNT(DISTINCT POS.POIdPlanOpcion) AS SeleccionesConTarifaDestino
    FROM dbo.ff_Solicitud S
    INNER JOIN dbo.ff_PlanOpcionSeleccion POS
        ON POS.POIdSolicitud = S.SOIdSolicitud
       AND POS.POIdEstatus = 1
    WHERE S.SOIdEmpresa = @IdEmpresa
      AND S.SOIdEmpleado = E.Id
      AND S.SOIdVigencia = @IdVigenciaOrigen
      AND S.SOIdEstatus = 1
      AND S.SOEstatusSolicitud = 1
      AND
      (
          (@EsActual = 1 AND EXISTS
          (
              SELECT 1
              FROM dbo.ff_Tarifa T
              INNER JOIN dbo.ff_TarifaCosto TC
                  ON TC.TCIdTarifa = T.TAIdTarifa
                 AND TC.TCIdPlanOpcion = POS.POIdPlanOpcion
                 AND TC.TCIdEstatus = 1
              WHERE T.TAIdVigencia = @IdVigenciaDestino
                AND T.TAIdEstatus = 2
          ))
          OR
          (@EsActual = 0 AND EXISTS
          (
              SELECT 1
              FROM dbo.ff_Tarifa T
              INNER JOIN dbo.ff_TarifaCosto_hist TC
                  ON TC.TCIdTarifa = T.TAIdTarifa
                 AND TC.TCIdPlanOpcion = POS.POIdPlanOpcion
                 AND TC.TCIdEstatus = 1
              WHERE T.TAIdVigencia = @IdVigenciaDestino
                AND T.TAIdEstatus = 2
          ))
      )
) TARSEL
OUTER APPLY
(
    SELECT COUNT(DISTINCT B.PBIdPlanBasico) AS PlanesBasicosDestino
    FROM dbo.ff_PlanBasico B
    WHERE B.PBIdVigencia = @IdVigenciaDestino
      AND B.PBIdPerfil = E.EMIdPerfil
      AND B.PBIdEstatus = 1
      AND B.PBFormaCredito NOT IN ('4', '8')
) PB
OUTER APPLY
(
    SELECT COUNT(DISTINCT B.PBIdPlanBasico) AS PlanesBasicosElegibles
    FROM dbo.ff_PlanBasico B
    INNER JOIN dbo.ff_PlanBasicoDetalle BD
        ON BD.PBIdPlanBasico = B.PBIdPlanBasico
       AND BD.PBIdParentesco = E.EMIdParentesco
       AND BD.PBIdEstatus = 1
    INNER JOIN dbo.ff_PlanOpcion PO
        ON PO.POIdPlanOpcion = B.PBIdPlanOpcion
       AND PO.POIdEstatus = 1
    INNER JOIN dbo.ff_Plan PL
        ON PL.PLIdPlan = PO.POIdPlan
       AND PL.PLIdEstatus = 1
    INNER JOIN dbo.ff_PlanOpcionVigencia POV
        ON POV.VCIdPlanOpcion = B.PBIdPlanOpcion
       AND POV.VCIdVigencia = @IdVigenciaDestino
       AND POV.VCIdEstatus = 2
    INNER JOIN dbo.ff_PlanOpcionPerfil POP
        ON POP.PPIdPlanOpcion = B.PBIdPlanOpcion
       AND POP.PPIdPerfil = E.EMIdPerfil
       AND POP.PPIdEstatus = 1
    INNER JOIN dbo.ff_PlanOpcionSexo POSEX
        ON POSEX.PSIdPlanOpcion = B.PBIdPlanOpcion
       AND POSEX.PSIdSexo = E.EMIdSexo
       AND POSEX.PSIdEstatus = 1
    INNER JOIN dbo.ff_PlanOpcionParentescoEdad POEDAD
        ON POEDAD.PPIdPlanOpcion = B.PBIdPlanOpcion
       AND POEDAD.PPIdParentesco = E.EMIdParentesco
       AND POEDAD.PPIdEstatus = 1
       AND ED.Edad BETWEEN POEDAD.PPEdadMin AND POEDAD.PPEdadMax
    WHERE B.PBIdVigencia = @IdVigenciaDestino
      AND B.PBIdPerfil = E.EMIdPerfil
      AND B.PBIdEstatus = 1
      AND B.PBFormaCredito NOT IN ('4', '8')
) PBELI
OUTER APPLY
(
    SELECT COUNT(DISTINCT B.PBIdPlanBasico) AS PlanesBasicosConTarifa
    FROM dbo.ff_PlanBasico B
    WHERE B.PBIdVigencia = @IdVigenciaDestino
      AND B.PBIdPerfil = E.EMIdPerfil
      AND B.PBIdEstatus = 1
      AND B.PBFormaCredito NOT IN ('4', '8')
      AND
      (
          (@EsActual = 1 AND EXISTS
          (
              SELECT 1
              FROM dbo.ff_Tarifa T
              INNER JOIN dbo.ff_TarifaCosto TC
                  ON TC.TCIdTarifa = T.TAIdTarifa
                 AND TC.TCIdPlanOpcion = B.PBIdPlanOpcion
                 AND TC.TCIdEstatus = 1
              WHERE T.TAIdVigencia = @IdVigenciaDestino
                AND T.TAIdEstatus = 2
          ))
          OR
          (@EsActual = 0 AND EXISTS
          (
              SELECT 1
              FROM dbo.ff_Tarifa T
              INNER JOIN dbo.ff_TarifaCosto_hist TC
                  ON TC.TCIdTarifa = T.TAIdTarifa
                 AND TC.TCIdPlanOpcion = B.PBIdPlanOpcion
                 AND TC.TCIdEstatus = 1
              WHERE T.TAIdVigencia = @IdVigenciaDestino
                AND T.TAIdEstatus = 2
          ))
      )
) PBTAR
OUTER APPLY
(
    SELECT COUNT(*) AS DependientesActivos
    FROM dbo.ff_Empleado D
    WHERE D.EMIdEmpresa = @IdEmpresa
      AND D.EMIdTitular = E.Id
      AND D.EMIdParentesco <> 1
      AND D.EMIdEstatus = 1
) DEP
OUTER APPLY
(
    SELECT COUNT(*) AS SolicitudesDestinoActivas
    FROM dbo.ff_Solicitud S
    WHERE S.SOIdEmpresa = @IdEmpresa
      AND S.SOIdEmpleado = E.Id
      AND S.SOIdVigencia = @IdVigenciaDestino
      AND S.SOIdEstatus IN (1, 10)
      AND S.SOEstatusSolicitud IN (1, 3)
) SD
OUTER APPLY
(
    SELECT COUNT(*) AS SolicitudesPendientes99
    FROM dbo.ff_Solicitud S
    WHERE S.SOIdEmpleado = E.Id
      AND S.SOEstatusSolicitud = 99
) S99
WHERE E.EMIdEmpresa = @IdEmpresa
  AND E.EMIdEstatus = 1
  AND E.EMIdTitular = 1
  AND E.EMNumeroEmpleado NOT LIKE 'PR%';

/*
    02_CANDIDATOS:
      TIPO 1 = antecedente aprobado + selección anterior aún parametrizada.
      TIPO 2 = plan básico vigente y elegible para el perfil del titular.
      TIPO 3 = antecedente reutilizable; muestra casos con y sin dependientes.
*/
;WITH Candidatos AS
(
    SELECT
        X.TipoDefaulteo,
        X.CasoPrueba,
        E.*,
        ROW_NUMBER() OVER
        (
            PARTITION BY X.TipoDefaulteo, X.CasoPrueba
            ORDER BY E.SeleccionesElegiblesDestino DESC,
                     E.PlanesBasicosElegibles DESC,
                     E.IdEmpleado
        ) AS Fila
    FROM #Evaluacion E
    CROSS APPLY
    (
        VALUES
        (1, 'REUTILIZAR SELECCIONES ANTERIORES',
            CASE WHEN E.SolicitudesOrigenAprobadas > 0
                       AND E.SeleccionesOrigen > 0
                       AND E.SeleccionesElegiblesDestino > 0
                       AND E.SeleccionesConTarifaDestino > 0
                       AND E.SolicitudesDestinoActivas = 0
                       AND E.SolicitudesPendientes99 = 0 THEN 1 ELSE 0 END),
        (2, 'ASIGNAR PLAN BASICO DEL PERFIL',
            CASE WHEN E.PlanesBasicosDestino > 0
                       AND E.PlanesBasicosElegibles > 0
                       AND E.PlanesBasicosConTarifa > 0
                       AND E.SolicitudesDestinoActivas = 0
                       AND E.SolicitudesPendientes99 = 0 THEN 1 ELSE 0 END),
        (3, CASE WHEN E.DependientesActivos > 0
                 THEN 'RECALCULAR CON DEPENDIENTES'
                 ELSE 'CONTROL SIN DEPENDIENTES' END,
            CASE WHEN E.SolicitudesOrigenAprobadas > 0
                       AND E.SeleccionesOrigen > 0
                       AND E.SeleccionesElegiblesDestino > 0
                       AND E.SeleccionesConTarifaDestino > 0
                       AND E.SolicitudesDestinoActivas = 0
                       AND E.SolicitudesPendientes99 = 0 THEN 1 ELSE 0 END)
    ) X(TipoDefaulteo, CasoPrueba, EsCandidato)
    WHERE X.EsCandidato = 1
)
SELECT
    '02_CANDIDATOS' AS Bloque,
    TipoDefaulteo,
    CasoPrueba,
    IdEmpleado,
    NumeroEmpleado,
    NombreEmpleado,
    IdPerfil,
    Perfil,
    Edad,
    IdSexo,
    @IdVigenciaDestino AS IdVigenciaASeleccionarEnPantalla,
    @IdVigenciaOrigen AS IdVigenciaOrigen,
    SolicitudesOrigenAprobadas,
    SeleccionesOrigen,
    SeleccionesElegiblesDestino,
    PlanesBasicosElegibles,
    DependientesActivos,
    'LISTO PARA PRUEBA FUNCIONAL' AS Resultado
FROM Candidatos
WHERE Fila <= @TopPorTipo
ORDER BY TipoDefaulteo, CasoPrueba, Fila;

/* Cantidad total disponible para cada tipo, sin el límite de @TopPorTipo. */
SELECT
    '03_RESUMEN' AS Bloque,
    SUM(CASE WHEN SolicitudesOrigenAprobadas > 0
                  AND SeleccionesOrigen > 0
                  AND SeleccionesElegiblesDestino > 0
                  AND SeleccionesConTarifaDestino > 0
                  AND SolicitudesDestinoActivas = 0
                  AND SolicitudesPendientes99 = 0 THEN 1 ELSE 0 END) AS CandidatosTipo1,
    SUM(CASE WHEN PlanesBasicosDestino > 0
                  AND PlanesBasicosElegibles > 0
                  AND PlanesBasicosConTarifa > 0
                  AND SolicitudesDestinoActivas = 0
                  AND SolicitudesPendientes99 = 0 THEN 1 ELSE 0 END) AS CandidatosTipo2,
    SUM(CASE WHEN SolicitudesOrigenAprobadas > 0
                  AND SeleccionesOrigen > 0
                  AND SeleccionesElegiblesDestino > 0
                  AND SeleccionesConTarifaDestino > 0
                  AND DependientesActivos > 0
                  AND SolicitudesDestinoActivas = 0
                  AND SolicitudesPendientes99 = 0 THEN 1 ELSE 0 END) AS CandidatosTipo3ConDependientes,
    SUM(CASE WHEN SolicitudesOrigenAprobadas > 0
                  AND SeleccionesOrigen > 0
                  AND SeleccionesElegiblesDestino > 0
                  AND SeleccionesConTarifaDestino > 0
                  AND DependientesActivos = 0
                  AND SolicitudesDestinoActivas = 0
                  AND SolicitudesPendientes99 = 0 THEN 1 ELSE 0 END) AS CandidatosTipo3SinDependientes
FROM #Evaluacion;

/* Primer motivo por el que un empleado no está listo para cada tipo. */
IF @MostrarDescartados = 1
BEGIN
    ;WITH Descartes AS
    (
        SELECT
            X.TipoDefaulteo,
            E.IdEmpleado,
            E.NumeroEmpleado,
            E.NombreEmpleado,
            E.IdPerfil,
            E.Perfil,
            X.Motivo,
            ROW_NUMBER() OVER
            (
                PARTITION BY X.TipoDefaulteo
                ORDER BY E.IdEmpleado
            ) AS Fila
        FROM #Evaluacion E
        CROSS APPLY
        (
            VALUES
            (1, CASE
                    WHEN @IdVigenciaOrigen IS NULL THEN 'La vigencia destino no tiene VIRenovada.'
                    WHEN E.SolicitudesOrigenAprobadas = 0 THEN 'No tiene solicitud aprobada en la vigencia origen.'
                    WHEN E.SeleccionesOrigen = 0 THEN 'La solicitud origen no tiene selecciones activas.'
                    WHEN E.SeleccionesElegiblesDestino = 0 THEN 'Las selecciones anteriores no son elegibles en destino.'
                    WHEN E.SeleccionesConTarifaDestino = 0 THEN 'Las selecciones anteriores no tienen tarifa en destino.'
                    WHEN E.SolicitudesDestinoActivas > 0 THEN 'Ya tiene solicitud activa o por autorizar en destino.'
                    WHEN E.SolicitudesPendientes99 > 0 THEN 'Tiene solicitud pendiente con estatus 99.'
                    ELSE NULL END),
            (2, CASE
                    WHEN E.PlanesBasicosDestino = 0 THEN 'El perfil no tiene plan básico en la vigencia destino.'
                    WHEN E.PlanesBasicosElegibles = 0 THEN 'El plan básico no pasa perfil, sexo, edad o parentesco.'
                    WHEN E.PlanesBasicosConTarifa = 0 THEN 'El plan básico no tiene tarifa en destino.'
                    WHEN E.SolicitudesDestinoActivas > 0 THEN 'Ya tiene solicitud activa o por autorizar en destino.'
                    WHEN E.SolicitudesPendientes99 > 0 THEN 'Tiene solicitud pendiente con estatus 99.'
                    ELSE NULL END),
            (3, CASE
                    WHEN @IdVigenciaOrigen IS NULL THEN 'La vigencia destino no tiene VIRenovada.'
                    WHEN E.SolicitudesOrigenAprobadas = 0 THEN 'No tiene solicitud aprobada en la vigencia origen.'
                    WHEN E.SeleccionesOrigen = 0 THEN 'La solicitud origen no tiene selecciones activas.'
                    WHEN E.SeleccionesElegiblesDestino = 0 THEN 'La composición anterior no es elegible en destino.'
                    WHEN E.SeleccionesConTarifaDestino = 0 THEN 'La composición anterior no tiene tarifa en destino.'
                    WHEN E.SolicitudesDestinoActivas > 0 THEN 'Ya tiene solicitud activa o por autorizar en destino.'
                    WHEN E.SolicitudesPendientes99 > 0 THEN 'Tiene solicitud pendiente con estatus 99.'
                    ELSE NULL END)
        ) X(TipoDefaulteo, Motivo)
        WHERE X.Motivo IS NOT NULL
    )
    SELECT
        '04_DESCARTADOS' AS Bloque,
        TipoDefaulteo,
        IdEmpleado,
        NumeroEmpleado,
        NombreEmpleado,
        IdPerfil,
        Perfil,
        Motivo
    FROM Descartes
    WHERE Fila <= @TopPorTipo
    ORDER BY TipoDefaulteo, Fila;
END;

DROP TABLE #Evaluacion;

