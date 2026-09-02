/*
    CONSULTA DE LOS 90 CASOS CONTROLADOS DE DEFAULTEO - EMPRESA 186

    No modifica informacion. Busca exclusivamente los empleados creados por
    DUMMY_DEF_123_186.sql y confirma que existan 30 listos por cada tipo.

    Vigencia origen BF3 : 3924
    Vigencia destino BF3: 4235
*/
SET NOCOUNT ON;

DECLARE @IdEmpresa INT = 186;
DECLARE @IdVigenciaOrigen INT = 3924;
DECLARE @IdVigenciaDestino INT = 4235;

IF OBJECT_ID('tempdb..#CasosDefaulteo') IS NOT NULL
    DROP TABLE #CasosDefaulteo;

SELECT
    CASE
        WHEN EM.EMNumeroEmpleado LIKE 'QD1-186-%' THEN 1
        WHEN EM.EMNumeroEmpleado LIKE 'QD2-186-%' THEN 2
        WHEN EM.EMNumeroEmpleado LIKE 'QD3-186-%' THEN 3
    END AS TipoDefaulteo,
    TRY_CONVERT(INT,RIGHT(EM.EMNumeroEmpleado,3)) AS Consecutivo,
    E.EMIdEmpresa AS IdEmpresa,
    E.EMNombre AS EmpresaLogin,
    E.EMClaveAcceso AS ClaveAccesoEmpresa,
    EM.Id AS IdEmpleado,
    EM.EMNumeroEmpleado AS NumeroEmpleado,
    LTRIM(RTRIM(CONCAT(
        ISNULL(EM.EMNombre1,''),' ',ISNULL(EM.EMNombre2,''),' ',
        ISNULL(EM.EMApellidoPaterno,''),' ',ISNULL(EM.EMApellidoMaterno,'')
    ))) AS NombreEmpleado,
    EM.EMIdPerfil AS IdPerfil,
    @IdVigenciaOrigen AS IdVigenciaOrigen,
    @IdVigenciaDestino AS IdVigenciaDestino,
    SO.SolicitudesOrigenAprobadas,
    POS.SeleccionesOrigen,
    EL.OpcionesElegiblesDestino,
    TA.OpcionesConTarifaDestino,
    PB.PlanesBasicosDestino,
    DEP.DependientesActivos,
    SD.SolicitudesDestinoActivas,
    CONVERT(BIT,CASE
        WHEN EM.EMNumeroEmpleado LIKE 'QD1-186-%'
         AND SO.SolicitudesOrigenAprobadas>0
         AND POS.SeleccionesOrigen>0
         AND EL.OpcionesElegiblesDestino>0
         AND TA.OpcionesConTarifaDestino>0
         AND SD.SolicitudesDestinoActivas=0 THEN 1
        WHEN EM.EMNumeroEmpleado LIKE 'QD2-186-%'
         AND PB.PlanesBasicosDestino>0
         AND SD.SolicitudesDestinoActivas=0 THEN 1
        WHEN EM.EMNumeroEmpleado LIKE 'QD3-186-%'
         AND SO.SolicitudesOrigenAprobadas>0
         AND POS.SeleccionesOrigen>0
         AND EL.OpcionesElegiblesDestino>0
         AND TA.OpcionesConTarifaDestino>0
         AND SD.SolicitudesDestinoActivas=0
         AND
         (
             (TRY_CONVERT(INT,RIGHT(EM.EMNumeroEmpleado,3)) BETWEEN 1 AND 15
              AND DEP.DependientesActivos>0)
             OR
             (TRY_CONVERT(INT,RIGHT(EM.EMNumeroEmpleado,3)) BETWEEN 16 AND 30
              AND DEP.DependientesActivos=0)
         ) THEN 1
        ELSE 0
    END) AS Listo
INTO #CasosDefaulteo
FROM dbo.ff_Empleado EM
INNER JOIN dbo.ff_Empresa E
    ON E.EMIdEmpresa=EM.EMIdEmpresa
OUTER APPLY
(
    SELECT COUNT(*) AS SolicitudesOrigenAprobadas
    FROM dbo.ff_Solicitud S
    WHERE S.SOIdEmpresa=@IdEmpresa
      AND S.SOIdEmpleado=EM.Id
      AND S.SOIdVigencia=@IdVigenciaOrigen
      AND S.SOIdEstatus=1
      AND S.SOEstatusSolicitud=1
) SO
OUTER APPLY
(
    SELECT COUNT(*) AS SeleccionesOrigen
    FROM dbo.ff_PlanOpcionSeleccion P
    WHERE P.POIdEmpresa=@IdEmpresa
      AND P.POIdEmpleado=EM.Id
      AND P.POIdVigencia=@IdVigenciaOrigen
      AND P.POIdEstatus=1
) POS
OUTER APPLY
(
    SELECT COUNT(DISTINCT P.POIdPlanOpcion) AS OpcionesElegiblesDestino
    FROM dbo.ff_PlanOpcionSeleccion P
    INNER JOIN dbo.ff_PlanOpcion O
        ON O.POIdPlanOpcion=P.POIdPlanOpcion AND O.POIdEstatus=1
    INNER JOIN dbo.ff_Plan PL
        ON PL.PLIdPlan=O.POIdPlan AND PL.PLIdEstatus=1
    INNER JOIN dbo.ff_PlanOpcionVigencia V
        ON V.VCIdPlanOpcion=P.POIdPlanOpcion
       AND V.VCIdVigencia=@IdVigenciaDestino AND V.VCIdEstatus=2
    INNER JOIN dbo.ff_PlanOpcionPerfil PP
        ON PP.PPIdPlanOpcion=P.POIdPlanOpcion
       AND PP.PPIdPerfil=EM.EMIdPerfil AND PP.PPIdEstatus=1
    INNER JOIN dbo.ff_PlanOpcionSexo PS
        ON PS.PSIdPlanOpcion=P.POIdPlanOpcion
       AND PS.PSIdSexo=EM.EMIdSexo AND PS.PSIdEstatus=1
    INNER JOIN dbo.ff_PlanOpcionParentescoEdad PE
        ON PE.PPIdPlanOpcion=P.POIdPlanOpcion
       AND PE.PPIdParentesco=EM.EMIdParentesco
       AND PE.PPIdEstatus=1
       AND ISNULL(dbo.RegresaEdadEmpleado(EM.Id),EM.EMEdad)
           BETWEEN PE.PPEdadMin AND PE.PPEdadMax
    WHERE P.POIdEmpresa=@IdEmpresa
      AND P.POIdEmpleado=EM.Id
      AND P.POIdVigencia=@IdVigenciaOrigen
      AND P.POIdEstatus=1
) EL
OUTER APPLY
(
    SELECT COUNT(DISTINCT P.POIdPlanOpcion) AS OpcionesConTarifaDestino
    FROM dbo.ff_PlanOpcionSeleccion P
    INNER JOIN dbo.ff_Tarifa T
        ON T.TAIdVigencia=@IdVigenciaDestino AND T.TAIdEstatus=2
    INNER JOIN dbo.ff_TarifaCosto TC
        ON TC.TCIdTarifa=T.TAIdTarifa
       AND TC.TCIdPlanOpcion=P.POIdPlanOpcion
       AND TC.TCIdEstatus=1
    WHERE P.POIdEmpresa=@IdEmpresa
      AND P.POIdEmpleado=EM.Id
      AND P.POIdVigencia=@IdVigenciaOrigen
      AND P.POIdEstatus=1
) TA
OUTER APPLY
(
    SELECT COUNT(*) AS PlanesBasicosDestino
    FROM dbo.ff_PlanBasico B
    INNER JOIN dbo.ff_PlanOpcion O
        ON O.POIdPlanOpcion=B.PBIdPlanOpcion AND O.POIdEstatus=1
    WHERE B.PBIdPerfil=EM.EMIdPerfil
      AND B.PBIdVigencia=@IdVigenciaDestino
      AND B.PBIdEstatus=1
) PB
OUTER APPLY
(
    SELECT COUNT(*) AS DependientesActivos
    FROM dbo.ff_Empleado D
    WHERE D.EMIdEmpresa=@IdEmpresa
      AND D.EMIdTitular=EM.Id
      AND D.EMIdParentesco<>1
      AND D.EMIdEstatus=1
) DEP
OUTER APPLY
(
    SELECT COUNT(*) AS SolicitudesDestinoActivas
    FROM dbo.ff_Solicitud S
    WHERE S.SOIdEmpresa=@IdEmpresa
      AND S.SOIdEmpleado=EM.Id
      AND S.SOIdVigencia=@IdVigenciaDestino
      AND S.SOIdEstatus IN(1,10)
      AND S.SOEstatusSolicitud IN(1,3)
) SD
WHERE EM.EMIdEmpresa=@IdEmpresa
  AND EM.EMIdEstatus=1
  AND EM.EMIdTitular=1
  AND
  (
      EM.EMNumeroEmpleado LIKE 'QD1-186-%'
      OR EM.EMNumeroEmpleado LIKE 'QD2-186-%'
      OR EM.EMNumeroEmpleado LIKE 'QD3-186-%'
  );

/* Primer resultado: los 90 empleados y el motivo si alguno requiere revision. */
SELECT
    TipoDefaulteo,Consecutivo,IdEmpresa,EmpresaLogin,ClaveAccesoEmpresa,
    IdEmpleado,NumeroEmpleado,NombreEmpleado,IdPerfil,
    IdVigenciaOrigen,IdVigenciaDestino,
    SolicitudesOrigenAprobadas,SeleccionesOrigen,OpcionesElegiblesDestino,
    OpcionesConTarifaDestino,PlanesBasicosDestino,DependientesActivos,
    SolicitudesDestinoActivas,
    CASE WHEN Listo=1 THEN 'LISTO'
         ELSE 'REVISAR INSUMOS DEL TIPO ASIGNADO' END AS Resultado
FROM #CasosDefaulteo
ORDER BY TipoDefaulteo,Consecutivo;

/* Segundo resultado: deben aparecer tres filas con 30/30 y resultado OK. */
;WITH Tipos AS
(
    SELECT 1 AS TipoDefaulteo UNION ALL
    SELECT 2 UNION ALL
    SELECT 3
)
SELECT
    T.TipoDefaulteo,
    COUNT(C.IdEmpleado) AS CasosEncontrados,
    SUM(CASE WHEN C.Listo=1 THEN 1 ELSE 0 END) AS CasosListos,
    30 AS CasosEsperados,
    CASE WHEN COUNT(C.IdEmpleado)=30
              AND SUM(CASE WHEN C.Listo=1 THEN 1 ELSE 0 END)=30
         THEN 'OK: 30 CASOS LISTOS'
         WHEN COUNT(C.IdEmpleado)=0
         THEN 'SIN CASOS: EJECUTAR DUMMY_DEF_123_186.sql'
         ELSE 'INCOMPLETO: REVISAR DETALLE' END AS Resultado
FROM Tipos T
LEFT JOIN #CasosDefaulteo C ON C.TipoDefaulteo=T.TipoDefaulteo
GROUP BY T.TipoDefaulteo
ORDER BY T.TipoDefaulteo;

DROP TABLE #CasosDefaulteo;
