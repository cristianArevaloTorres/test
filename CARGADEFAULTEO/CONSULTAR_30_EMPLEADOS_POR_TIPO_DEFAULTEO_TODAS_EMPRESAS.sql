/*
    BUSQUEDA GLOBAL DE INSUMOS PARA DEFAULTEO 1, 2 Y 3

    Devuelve hasta 30 empleados por tipo de defaulteo, indicando la empresa
    con la que debe iniciarse sesión. No modifica información.

    Si existen menos de 30 candidatos para un tipo, devuelve únicamente los
    disponibles. Un empleado puede aparecer en más de un tipo cuando cumple
    los insumos de ambos escenarios.
*/
SET NOCOUNT ON;

DECLARE @TopPorTipo INT = 30;

IF OBJECT_ID('tempdb..#EmpresaVigencia') IS NOT NULL DROP TABLE #EmpresaVigencia;
IF OBJECT_ID('tempdb..#Base') IS NOT NULL DROP TABLE #Base;
IF OBJECT_ID('tempdb..#Tipo13') IS NOT NULL DROP TABLE #Tipo13;
IF OBJECT_ID('tempdb..#Tipo2') IS NOT NULL DROP TABLE #Tipo2;

/* Vigencia que resolvería BF3 para cada empresa activa. */
SELECT
    E.EMIdEmpresa AS IdEmpresa,
    E.EMNombre AS NombreEmpresa,
    E.EMClaveAcceso AS ClaveAccesoEmpresa,
    E.EMIdEmpresaFlexiForbes AS IdEmpresaFlexiForbes,
    E.EMEtiqueta AS EtiquetaEmpresa,
    E.EMIdConfiguracion AS IdConfiguracion,
    V.VIIdVigencia AS IdVigenciaDestino,
    V.VINombre AS VigenciaDestino,
    V.VIRenovada AS IdVigenciaOrigen
INTO #EmpresaVigencia
FROM dbo.ff_Empresa E
CROSS APPLY
(
    SELECT TOP (1)
        VI.VIIdVigencia,
        VI.VINombre,
        VI.VIRenovada,
        VI.VIVigenciaIni
    FROM dbo.ff_Vigencia VI
    WHERE VI.VIIdConfiguracion = E.EMIdConfiguracion
      AND VI.VIIdEstatus = 1
    ORDER BY
        CASE WHEN CONVERT(DATE, GETDATE())
                  BETWEEN CONVERT(DATE, VI.VIVigenciaIni)
                      AND CONVERT(DATE, VI.VIVigenciaFin)
             THEN 0 ELSE 1 END,
        VI.VIVigenciaIni DESC,
        VI.VIIdVigencia DESC
) V
WHERE E.EMIdEstatus = 1;

/* Titulares que sí aparecen en el universo normal de la pantalla. */
SELECT
    EV.IdEmpresa,
    EV.NombreEmpresa,
    EV.ClaveAccesoEmpresa,
    EV.IdEmpresaFlexiForbes,
    EV.EtiquetaEmpresa,
    EV.IdConfiguracion,
    EV.IdVigenciaDestino,
    EV.VigenciaDestino,
    EV.IdVigenciaOrigen,
    EM.Id AS IdEmpleado,
    EM.EMNumeroEmpleado AS NumeroEmpleado,
    LTRIM(RTRIM(CONCAT(
        ISNULL(EM.EMNombre1, ''), ' ', ISNULL(EM.EMNombre2, ''), ' ',
        ISNULL(EM.EMApellidoPaterno, ''), ' ', ISNULL(EM.EMApellidoMaterno, '')
    ))) AS NombreEmpleado,
    EM.EMIdPerfil AS IdPerfil,
    P.PEDescripcion AS Perfil,
    EM.EMIdSexo AS IdSexo,
    EM.EMIdParentesco AS IdParentesco,
    ISNULL(dbo.RegresaEdadEmpleado(EM.Id), EM.EMEdad) AS Edad
INTO #Base
FROM #EmpresaVigencia EV
INNER JOIN dbo.ff_Empleado EM
    ON EM.EMIdEmpresa = EV.IdEmpresa
   AND EM.EMIdEstatus = 1
   AND EM.EMIdTitular = 1
   AND EM.EMNumeroEmpleado NOT LIKE 'PR%'
INNER JOIN dbo.ff_Perfil P
    ON P.PEIdPerfil = EM.EMIdPerfil
   AND P.PEIdEmpresa = EV.IdEmpresa
   AND P.PEIdEstatus = 1;

CREATE CLUSTERED INDEX IX_Base_EmpresaEmpleado ON #Base(IdEmpresa, IdEmpleado);
CREATE INDEX IX_Base_PerfilVigencia ON #Base(IdPerfil, IdVigenciaDestino);

/*
   TIPOS 1 Y 3
   Necesitan solicitud aprobada y selecciones activas en VIRenovada.
   Además se comprueba que al menos una selección siga publicada para el
   perfil y tenga tarifa en la vigencia destino.
*/
SELECT
    B.*,
    O.SolicitudesOrigenAprobadas,
    O.SeleccionesOrigen,
    EL.SeleccionesElegiblesDestino,
    TA.SeleccionesConTarifaDestino,
    D.DependientesActivos
INTO #Tipo13
FROM #Base B
CROSS APPLY
(
    SELECT
        COUNT(DISTINCT S.SOIdSolicitud) AS SolicitudesOrigenAprobadas,
        COUNT(DISTINCT POS.POIdPlanOpcionSeleccion) AS SeleccionesOrigen
    FROM dbo.ff_Solicitud S
    INNER JOIN dbo.ff_PlanOpcionSeleccion POS
        ON POS.POIdSolicitud = S.SOIdSolicitud
       AND POS.POIdEstatus = 1
    WHERE S.SOIdEmpresa = B.IdEmpresa
      AND S.SOIdEmpleado = B.IdEmpleado
      AND S.SOIdVigencia = B.IdVigenciaOrigen
      AND S.SOIdEstatus = 1
      AND S.SOEstatusSolicitud = 1
) O
CROSS APPLY
(
    SELECT COUNT(DISTINCT POS.POIdPlanOpcion) AS SeleccionesElegiblesDestino
    FROM dbo.ff_Solicitud S
    INNER JOIN dbo.ff_PlanOpcionSeleccion POS
        ON POS.POIdSolicitud = S.SOIdSolicitud
       AND POS.POIdEstatus = 1
    INNER JOIN dbo.ff_Empleado M
        ON M.Id = POS.POIdEmpleado
       AND M.EMIdEmpresa = B.IdEmpresa
       AND M.EMIdEstatus = 1
    INNER JOIN dbo.ff_PlanOpcion PO
        ON PO.POIdPlanOpcion = POS.POIdPlanOpcion
       AND PO.POIdEstatus = 1
    INNER JOIN dbo.ff_Plan PL
        ON PL.PLIdPlan = PO.POIdPlan
       AND PL.PLIdEstatus = 1
    INNER JOIN dbo.ff_PlanOpcionVigencia POV
        ON POV.VCIdPlanOpcion = POS.POIdPlanOpcion
       AND POV.VCIdVigencia = B.IdVigenciaDestino
       AND POV.VCIdEstatus = 2
    INNER JOIN dbo.ff_PlanOpcionPerfil POP
        ON POP.PPIdPlanOpcion = POS.POIdPlanOpcion
       AND POP.PPIdPerfil = B.IdPerfil
       AND POP.PPIdEstatus = 1
    INNER JOIN dbo.ff_PlanOpcionSexo PS
        ON PS.PSIdPlanOpcion = POS.POIdPlanOpcion
       AND PS.PSIdSexo = M.EMIdSexo
       AND PS.PSIdEstatus = 1
    INNER JOIN dbo.ff_PlanOpcionParentescoEdad PPE
        ON PPE.PPIdPlanOpcion = POS.POIdPlanOpcion
       AND PPE.PPIdParentesco = M.EMIdParentesco
       AND PPE.PPIdEstatus = 1
       AND ISNULL(dbo.RegresaEdadEmpleado(M.Id), M.EMEdad)
           BETWEEN PPE.PPEdadMin AND PPE.PPEdadMax
    WHERE S.SOIdEmpresa = B.IdEmpresa
      AND S.SOIdEmpleado = B.IdEmpleado
      AND S.SOIdVigencia = B.IdVigenciaOrigen
      AND S.SOIdEstatus = 1
      AND S.SOEstatusSolicitud = 1
) EL
CROSS APPLY
(
    SELECT COUNT(DISTINCT POS.POIdPlanOpcion) AS SeleccionesConTarifaDestino
    FROM dbo.ff_Solicitud S
    INNER JOIN dbo.ff_PlanOpcionSeleccion POS
        ON POS.POIdSolicitud = S.SOIdSolicitud
       AND POS.POIdEstatus = 1
    INNER JOIN dbo.ff_Empleado M
        ON M.Id = POS.POIdEmpleado
       AND M.EMIdEmpresa = B.IdEmpresa
       AND M.EMIdEstatus = 1
    INNER JOIN dbo.ff_PlanOpcion PO
        ON PO.POIdPlanOpcion = POS.POIdPlanOpcion
       AND PO.POIdEstatus = 1
    INNER JOIN dbo.ff_Plan PL
        ON PL.PLIdPlan = PO.POIdPlan
       AND PL.PLIdEstatus = 1
    INNER JOIN dbo.ff_PlanOpcionVigencia POV
        ON POV.VCIdPlanOpcion = POS.POIdPlanOpcion
       AND POV.VCIdVigencia = B.IdVigenciaDestino
       AND POV.VCIdEstatus = 2
    INNER JOIN dbo.ff_PlanOpcionPerfil POP
        ON POP.PPIdPlanOpcion = POS.POIdPlanOpcion
       AND POP.PPIdPerfil = B.IdPerfil
       AND POP.PPIdEstatus = 1
    INNER JOIN dbo.ff_PlanOpcionSexo PS
        ON PS.PSIdPlanOpcion = POS.POIdPlanOpcion
       AND PS.PSIdSexo = M.EMIdSexo
       AND PS.PSIdEstatus = 1
    INNER JOIN dbo.ff_PlanOpcionParentescoEdad PPE
        ON PPE.PPIdPlanOpcion = POS.POIdPlanOpcion
       AND PPE.PPIdParentesco = M.EMIdParentesco
       AND PPE.PPIdEstatus = 1
       AND ISNULL(dbo.RegresaEdadEmpleado(M.Id), M.EMEdad)
           BETWEEN PPE.PPEdadMin AND PPE.PPEdadMax
    INNER JOIN dbo.ff_Tarifa T
        ON T.TAIdVigencia = B.IdVigenciaDestino
       AND T.TAIdEstatus = 2
    INNER JOIN dbo.ff_TarifaCosto TC
        ON TC.TCIdTarifa = T.TAIdTarifa
       AND TC.TCIdPlanOpcion = POS.POIdPlanOpcion
       AND TC.TCIdEstatus = 1
    WHERE S.SOIdEmpresa = B.IdEmpresa
      AND S.SOIdEmpleado = B.IdEmpleado
      AND S.SOIdVigencia = B.IdVigenciaOrigen
      AND S.SOIdEstatus = 1
      AND S.SOEstatusSolicitud = 1
) TA
CROSS APPLY
(
    SELECT COUNT(*) AS DependientesActivos
    FROM dbo.ff_Empleado DEP
    WHERE DEP.EMIdEmpresa = B.IdEmpresa
      AND DEP.EMIdTitular = B.IdEmpleado
      AND DEP.EMIdParentesco <> 1
      AND DEP.EMIdEstatus = 1
) D
WHERE B.IdVigenciaOrigen IS NOT NULL
  AND O.SolicitudesOrigenAprobadas > 0
  AND O.SeleccionesOrigen > 0
  AND EL.SeleccionesElegiblesDestino > 0
  AND TA.SeleccionesConTarifaDestino > 0
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.ff_Solicitud SD
      WHERE SD.SOIdEmpresa = B.IdEmpresa
        AND SD.SOIdEmpleado = B.IdEmpleado
        AND SD.SOIdVigencia = B.IdVigenciaDestino
        AND SD.SOIdEstatus IN (1, 10)
        AND SD.SOEstatusSolicitud IN (1, 3)
  )
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.ff_Solicitud S99
      WHERE S99.SOIdEmpleado = B.IdEmpleado
        AND S99.SOEstatusSolicitud = 99
  );

/*
   TIPO 2
   Requiere plan básico del perfil en destino, detalle para titular, opción
   publicada y tarifa disponible.
*/
SELECT
    B.*,
    PB.PlanesBasicosDestino,
    PB.PlanesBasicosElegibles,
    PB.PlanesBasicosConTarifa,
    D.DependientesActivos
INTO #Tipo2
FROM #Base B
CROSS APPLY
(
    SELECT
        COUNT(DISTINCT BAS.PBIdPlanBasico) AS PlanesBasicosDestino,
        COUNT(DISTINCT CASE
            WHEN BD.PBIdPlanBasicoDetalle IS NOT NULL
             AND PO.POIdPlanOpcion IS NOT NULL
             AND PL.PLIdPlan IS NOT NULL
             AND POV.VCIdPlanOpcionVigencia IS NOT NULL
             AND POP.PPIdPlanOpcionPerfil IS NOT NULL
             AND PS.PSIdPlanOpcionSexo IS NOT NULL
             AND PPE.PPIdPlanOpcionParentescoEdad IS NOT NULL
            THEN BAS.PBIdPlanBasico END) AS PlanesBasicosElegibles,
        COUNT(DISTINCT CASE
            WHEN BD.PBIdPlanBasicoDetalle IS NOT NULL
             AND PO.POIdPlanOpcion IS NOT NULL
             AND PL.PLIdPlan IS NOT NULL
             AND POV.VCIdPlanOpcionVigencia IS NOT NULL
             AND POP.PPIdPlanOpcionPerfil IS NOT NULL
             AND PS.PSIdPlanOpcionSexo IS NOT NULL
             AND PPE.PPIdPlanOpcionParentescoEdad IS NOT NULL
             AND TC.TCIdTarifaCosto IS NOT NULL
                            THEN BAS.PBIdPlanBasico END) AS PlanesBasicosConTarifa
    FROM dbo.ff_PlanBasico BAS
    LEFT JOIN dbo.ff_PlanBasicoDetalle BD
        ON BD.PBIdPlanBasico = BAS.PBIdPlanBasico
       AND BD.PBIdParentesco = B.IdParentesco
       AND BD.PBIdEstatus = 1
    LEFT JOIN dbo.ff_PlanOpcion PO
        ON PO.POIdPlanOpcion = BAS.PBIdPlanOpcion
       AND PO.POIdEstatus = 1
    LEFT JOIN dbo.ff_Plan PL
        ON PL.PLIdPlan = PO.POIdPlan
       AND PL.PLIdEstatus = 1
    LEFT JOIN dbo.ff_PlanOpcionVigencia POV
        ON POV.VCIdPlanOpcion = BAS.PBIdPlanOpcion
       AND POV.VCIdVigencia = B.IdVigenciaDestino
       AND POV.VCIdEstatus = 2
    LEFT JOIN dbo.ff_PlanOpcionPerfil POP
        ON POP.PPIdPlanOpcion = BAS.PBIdPlanOpcion
       AND POP.PPIdPerfil = B.IdPerfil
       AND POP.PPIdEstatus = 1
    LEFT JOIN dbo.ff_PlanOpcionSexo PS
        ON PS.PSIdPlanOpcion = BAS.PBIdPlanOpcion
       AND PS.PSIdSexo = B.IdSexo
       AND PS.PSIdEstatus = 1
    LEFT JOIN dbo.ff_PlanOpcionParentescoEdad PPE
        ON PPE.PPIdPlanOpcion = BAS.PBIdPlanOpcion
       AND PPE.PPIdParentesco = B.IdParentesco
       AND PPE.PPIdEstatus = 1
       AND B.Edad BETWEEN PPE.PPEdadMin AND PPE.PPEdadMax
    LEFT JOIN dbo.ff_Tarifa T
        ON T.TAIdVigencia = B.IdVigenciaDestino
       AND T.TAIdEstatus = 2
    LEFT JOIN dbo.ff_TarifaCosto TC
        ON TC.TCIdTarifa = T.TAIdTarifa
       AND TC.TCIdPlanOpcion = BAS.PBIdPlanOpcion
       AND TC.TCIdEstatus = 1
    WHERE BAS.PBIdVigencia = B.IdVigenciaDestino
      AND BAS.PBIdPerfil = B.IdPerfil
      AND BAS.PBIdEstatus = 1
      AND BAS.PBFormaCredito NOT IN ('4', '8')
) PB
CROSS APPLY
(
    SELECT COUNT(*) AS DependientesActivos
    FROM dbo.ff_Empleado DEP
    WHERE DEP.EMIdEmpresa = B.IdEmpresa
      AND DEP.EMIdTitular = B.IdEmpleado
      AND DEP.EMIdParentesco <> 1
      AND DEP.EMIdEstatus = 1
) D
WHERE PB.PlanesBasicosDestino > 0
  AND PB.PlanesBasicosElegibles > 0
  AND PB.PlanesBasicosConTarifa > 0
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.ff_Solicitud SD
      WHERE SD.SOIdEmpresa = B.IdEmpresa
        AND SD.SOIdEmpleado = B.IdEmpleado
        AND SD.SOIdVigencia = B.IdVigenciaDestino
        AND SD.SOIdEstatus IN (1, 10)
        AND SD.SOEstatusSolicitud IN (1, 3)
  )
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.ff_Solicitud S99
      WHERE S99.SOIdEmpleado = B.IdEmpleado
        AND S99.SOEstatusSolicitud = 99
  );

/* Hasta 30 empleados por tipo. */
;WITH Resultado AS
(
    SELECT
        1 AS TipoDefaulteo,
        'TIPO 1 - REUTILIZA SELECCIONES DE LA VIGENCIA ANTERIOR' AS Uso,
        T.IdEmpresa,
        T.NombreEmpresa,
        T.ClaveAccesoEmpresa,
        T.IdEmpresaFlexiForbes,
        T.EtiquetaEmpresa,
        T.IdEmpleado,
        T.NumeroEmpleado,
        T.NombreEmpleado,
        T.IdPerfil,
        T.Perfil,
        T.IdVigenciaDestino,
        T.VigenciaDestino,
        T.IdVigenciaOrigen,
        T.SolicitudesOrigenAprobadas,
        T.SeleccionesOrigen,
        T.SeleccionesElegiblesDestino,
        CAST(NULL AS INT) AS PlanesBasicosElegibles,
        T.DependientesActivos,
        ROW_NUMBER() OVER
        (
            ORDER BY T.SeleccionesElegiblesDestino DESC,
                     T.IdEmpresa,
                     T.IdEmpleado
        ) AS Fila
    FROM #Tipo13 T

    UNION ALL

    SELECT
        2,
        'TIPO 2 - ASIGNA PLAN BASICO DEL PERFIL',
        T.IdEmpresa,
        T.NombreEmpresa,
        T.ClaveAccesoEmpresa,
        T.IdEmpresaFlexiForbes,
        T.EtiquetaEmpresa,
        T.IdEmpleado,
        T.NumeroEmpleado,
        T.NombreEmpleado,
        T.IdPerfil,
        T.Perfil,
        T.IdVigenciaDestino,
        T.VigenciaDestino,
        T.IdVigenciaOrigen,
        CAST(NULL AS INT),
        CAST(NULL AS INT),
        CAST(NULL AS INT),
        T.PlanesBasicosElegibles,
        T.DependientesActivos,
        ROW_NUMBER() OVER
        (
            ORDER BY T.PlanesBasicosElegibles DESC,
                     T.IdEmpresa,
                     T.IdEmpleado
        )
    FROM #Tipo2 T

    UNION ALL

    SELECT
        3,
        CASE WHEN T.DependientesActivos > 0
             THEN 'TIPO 3 - RECALCULA TITULAR CON DEPENDIENTES'
             ELSE 'TIPO 3 - CONTROL SIN DEPENDIENTES' END,
        T.IdEmpresa,
        T.NombreEmpresa,
        T.ClaveAccesoEmpresa,
        T.IdEmpresaFlexiForbes,
        T.EtiquetaEmpresa,
        T.IdEmpleado,
        T.NumeroEmpleado,
        T.NombreEmpleado,
        T.IdPerfil,
        T.Perfil,
        T.IdVigenciaDestino,
        T.VigenciaDestino,
        T.IdVigenciaOrigen,
        T.SolicitudesOrigenAprobadas,
        T.SeleccionesOrigen,
        T.SeleccionesElegiblesDestino,
        CAST(NULL AS INT),
        T.DependientesActivos,
        ROW_NUMBER() OVER
        (
            ORDER BY CASE WHEN T.DependientesActivos > 0 THEN 0 ELSE 1 END,
                     T.DependientesActivos DESC,
                     T.SeleccionesElegiblesDestino DESC,
                     T.IdEmpresa,
                     T.IdEmpleado
        )
    FROM #Tipo13 T
)
SELECT
    TipoDefaulteo,
    Uso AS ParaQueDefaulteo,
    IdEmpresa AS IdEmpresaLogin,
    NombreEmpresa AS NombreEmpresaLogin,
    ClaveAccesoEmpresa,
    IdEmpresaFlexiForbes,
    EtiquetaEmpresa,
    IdEmpleado,
    NumeroEmpleado,
    NombreEmpleado,
    IdPerfil,
    Perfil,
    IdVigenciaDestino AS IdVigenciaSeleccionar,
    VigenciaDestino,
    IdVigenciaOrigen,
    SolicitudesOrigenAprobadas,
    SeleccionesOrigen,
    SeleccionesElegiblesDestino,
    PlanesBasicosElegibles,
    DependientesActivos,
    'TIENE INSUMOS; VALIDAR EJECUCION EN PANTALLA' AS Resultado
FROM Resultado
WHERE Fila <= @TopPorTipo
ORDER BY TipoDefaulteo, Fila;

/* Resumen: permite saber si realmente existen 30 o menos por cada tipo. */
SELECT
    X.TipoDefaulteo,
    X.Descripcion,
    X.EmpleadosDisponibles,
    CASE WHEN X.EmpleadosDisponibles >= @TopPorTipo
         THEN CONCAT('OK: se muestran ', @TopPorTipo)
         ELSE CONCAT('Solo existen ', X.EmpleadosDisponibles, ' candidatos') END AS Resultado
FROM
(
    SELECT 1 AS TipoDefaulteo,
           'Reutiliza selecciones anteriores' AS Descripcion,
           COUNT(*) AS EmpleadosDisponibles
    FROM #Tipo13
    UNION ALL
    SELECT 2, 'Asigna plan básico del perfil', COUNT(*) FROM #Tipo2
    UNION ALL
    SELECT 3, 'Recalcula titular y dependientes', COUNT(*) FROM #Tipo13
) X
ORDER BY X.TipoDefaulteo;

DROP TABLE #Tipo2;
DROP TABLE #Tipo13;
DROP TABLE #Base;
DROP TABLE #EmpresaVigencia;
