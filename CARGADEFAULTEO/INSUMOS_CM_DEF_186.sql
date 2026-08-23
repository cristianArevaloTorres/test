/*
  FRAGMENTO PEQUENO DE INSUMOS - EMPRESA 186
  Carga Masiva B2/B3 y Defaulteo 1/2/3

  - Solo consulta tablas existentes del modelo BeFlex.
  - No consulta las nuevas tablas de configuracion o logs.
  - No ejecuta stored procedures.
  - No inserta, actualiza ni elimina datos permanentes.
  - La poblacion base se limita a 500 titulares y los conjuntos relacionados
    tambien tienen limites explicitos.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

DECLARE @IdEmpresa         INT = 186;
DECLARE @TopeEmpleados     INT = 500;
DECLARE @TopeConfiguracion INT = 200;
DECLARE @TopeRelacionados  INT = 1000;
DECLARE @IdConfiguracion   INT;
DECLARE @IdVigenciaDestino INT;
DECLARE @IdVigenciaOrigen  INT;

SELECT @IdConfiguracion = E.EMIdConfiguracion
FROM dbo.ff_Empresa E
WHERE E.EMIdEmpresa = @IdEmpresa;

IF @IdConfiguracion IS NULL
    THROW 51100, 'La empresa 186 no existe en esta base.', 1;

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

SELECT @IdVigenciaOrigen = V.VIRenovada
FROM dbo.ff_Vigencia V
WHERE V.VIIdVigencia = @IdVigenciaDestino;

/* 1. Empresa y vigencias usadas por los procesos. */
SELECT
    E.EMIdEmpresa,
    E.EMNombre,
    E.EMIdCorporativo,
    E.EMIdConfiguracion,
    E.EMIdEstatus,
    @IdVigenciaOrigen AS idVigenciaOrigen,
    @IdVigenciaDestino AS idVigenciaDestino
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
         WHEN V.VIIdVigencia = @IdVigenciaOrigen THEN 'ORIGEN' END AS uso
FROM dbo.ff_Vigencia V
WHERE V.VIIdConfiguracion = @IdConfiguracion
ORDER BY V.VIVigenciaIni DESC, V.VIIdVigencia DESC;

/* 2. Insumos existentes de Carga Masiva B2. */
SELECT TOP (@TopeConfiguracion)
    FA.FAIdFuncion,
    FA.FANombre,
    FA.FADescripcion,
    FA.FATitular,
    FA.FAIdPlantilla,
    LTRIM(RTRIM(FA.FASp)) AS storedProcedure,
    A.DOId AS idDocumento,
    A.DONombreDocumento,
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

/* 3. Insumos existentes de Carga Masiva B3. */
SELECT TOP (@TopeConfiguracion)
    CE.CEIdOperacionEmpresa,
    O.COIdOperacion,
    O.CONombre,
    O.CODescripcion,
    O.COTabla,
    CE.CEIdPlantilla,
    P.PLDescripcion AS plantilla,
    LTRIM(RTRIM(CE.CEStoredProc)) AS storedProcedure,
    CE.CEStoredProcAtributos,
    CE.CEIdEstatus
FROM dbo.ff_CargaMasivaOperacionEmpresa CE
INNER JOIN dbo.ff_CargaMasivaOperacion O
  ON O.COIdOperacion = CE.CEIdOperacion
LEFT JOIN dbo.ff_Plantilla P
  ON P.PLIdPlantilla = CE.CEIdPlantilla
WHERE CE.CEIdEmpresa = @IdEmpresa
ORDER BY O.COIdOperacion;

SELECT TOP (@TopeRelacionados)
    O.COIdOperacion,
    O.CONombre AS operacion,
    CE.CEIdPlantilla,
    CP.CPIdConfiguracionPlantilla,
    CP.CPOrden,
    LTRIM(RTRIM(CP.CPEtiqueta)) AS encabezadoArchivo,
    C.CAIdCampo,
    LTRIM(RTRIM(C.CANombreCampo)) AS campoDestino,
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

/* 4. Catalogo existente de tipos 1, 2 y 3. */
SELECT
    TD.TDIdTipoDefaulteo,
    TD.TDNombre,
    TD.TDDescripcion,
    TD.TDIdEstatus,
    CASE TD.TDIdTipoDefaulteo
         WHEN 1 THEN 'def1'
         WHEN 2 THEN 'def2'
         WHEN 3 THEN 'def3' END AS tokenMotor
FROM dbo.ff_TipoDefaulteo TD
WHERE TD.TDIdTipoDefaulteo IN (1, 2, 3)
ORDER BY TD.TDIdTipoDefaulteo;

/* 5. Fragmento de titulares que alimenta Defaulteo 1/2/3. */
DROP TABLE IF EXISTS #Muestra186;

;WITH Titulares AS
(
    SELECT
        E.Id,
        E.EMIdEmpresa,
        E.EMNumeroEmpleado,
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
            PARTITION BY E.EMIdPerfil, E.EMIdAcceso
            ORDER BY E.Id DESC
        ) AS filaEstrato
    FROM dbo.ff_Empleado E
    WHERE E.EMIdEmpresa = @IdEmpresa
      AND E.EMIdEstatus = 1
      AND E.EMIdParentesco = 1
)
SELECT TOP (@TopeEmpleados)
    T.Id,
    T.EMIdEmpresa,
    T.EMNumeroEmpleado,
    T.EMIdPerfil,
    T.EMIdParentesco,
    T.EMIdSexo,
    T.EMIdAcceso,
    T.EMIdEstatus,
    T.EMOficina,
    T.EMArea,
    T.EMSalarioBase,
    T.EMFechaIngresoEmpresa,
    T.EMFechaAntiguedadGMM,
    T.EMFechaNacimiento
INTO #Muestra186
FROM Titulares T
ORDER BY T.filaEstrato, T.EMIdPerfil, T.EMIdAcceso, T.Id DESC;

CREATE UNIQUE CLUSTERED INDEX IX_Muestra186_Id ON #Muestra186(Id);

SELECT TOP (@TopeEmpleados)
    M.*,
    P.PENombre AS perfil
FROM #Muestra186 M
LEFT JOIN dbo.ff_Perfil P ON P.PEIdPerfil = M.EMIdPerfil
ORDER BY M.Id;

/* 6. Solicitudes relacionadas con la muestra. */
DROP TABLE IF EXISTS #SolicitudesMuestra;

SELECT TOP (@TopeEmpleados)
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
INTO #SolicitudesMuestra
FROM dbo.ff_Solicitud S
INNER JOIN #Muestra186 M ON M.Id = S.SOIdEmpleado
WHERE S.SOIdEmpresa = @IdEmpresa
  AND S.SOIdVigencia IN (@IdVigenciaOrigen, @IdVigenciaDestino)
ORDER BY S.SOIdSolicitud DESC;

SELECT *
FROM #SolicitudesMuestra
ORDER BY SOIdSolicitud DESC;

/* 7. Selecciones anteriores: insumo principal de tipos 1 y 3. */
SELECT TOP (@TopeRelacionados)
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
INNER JOIN #SolicitudesMuestra S ON S.SOIdSolicitud = POS.POIdSolicitud
WHERE POS.POIdEmpresa = @IdEmpresa
ORDER BY POS.POIdPlanOpcionSeleccion DESC;

/* 8. Planes basicos/espejo: insumo principal de tipo 2. */
SELECT TOP (@TopeEmpleados)
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
WHERE B.PBIdVigencia = @IdVigenciaDestino
  AND EXISTS (SELECT 1 FROM #Muestra186 M WHERE M.EMIdPerfil = B.PBIdPerfil)
ORDER BY B.PBIdPerfil, B.PBIdPlanBasico;

/* 9. Dependientes actuales: insumo especifico de tipo 3. */
SELECT TOP (@TopeRelacionados)
    D.Id,
    D.EMIdEmpresa,
    D.EMNumeroEmpleado,
    D.EMIdTitular,
    D.EMIdPerfil,
    D.EMIdParentesco,
    D.EMIdSexo,
    D.EMIdEstatus,
    D.EMFechaNacimiento
FROM dbo.ff_Empleado D
INNER JOIN #Muestra186 M ON M.Id = D.EMIdTitular
WHERE D.EMIdEmpresa = @IdEmpresa
  AND D.EMIdParentesco <> 1
ORDER BY D.EMIdTitular, D.Id;

/* 10. Resumen compacto de disponibilidad de insumos. */
SELECT
    (SELECT COUNT(*) FROM #Muestra186) AS titularesMuestra,
    (SELECT COUNT(*) FROM #SolicitudesMuestra) AS solicitudesMuestra,
    (SELECT COUNT(*)
     FROM dbo.ff_PlanOpcionSeleccion POS
     INNER JOIN #SolicitudesMuestra S ON S.SOIdSolicitud = POS.POIdSolicitud
     WHERE POS.POIdEmpresa = @IdEmpresa) AS seleccionesRelacionadas,
    (SELECT COUNT(*)
     FROM dbo.ff_Empleado D
     INNER JOIN #Muestra186 M ON M.Id = D.EMIdTitular
     WHERE D.EMIdEmpresa = @IdEmpresa AND D.EMIdParentesco <> 1) AS dependientesRelacionados,
    @IdVigenciaOrigen AS idVigenciaOrigen,
    @IdVigenciaDestino AS idVigenciaDestino;

