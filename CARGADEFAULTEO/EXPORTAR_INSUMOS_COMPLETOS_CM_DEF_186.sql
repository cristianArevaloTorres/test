/*
    EXPORTACION COMPLETA DE INSUMOS - EMPRESA 186
    Carga masiva B2/B3 y defaulteos 1/2/3

    IMPORTANTE:
    - Ejecutar en la BD origen que contiene los datos correctos de la empresa 186.
    - Cada resultado contiene todas las columnas físicas de su tabla.
    - La primera columna (__Tabla) identifica el destino y facilita una carga segura.
    - No modifica datos.
    - En SSMS habilitar: Herramientas > Opciones > Resultados de consulta > SQL Server
      > Resultados en cuadrícula > Incluir encabezados de columna al copiar o guardar.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @IdEmpresa INT = 186;
DECLARE @TopeEmpleados INT = 500;
DECLARE @IdConfiguracion INT;
DECLARE @IdVigenciaDestino INT;
DECLARE @IdVigenciaOrigen INT;

SELECT @IdConfiguracion = E.EMIdConfiguracion
FROM dbo.ff_Empresa E
WHERE E.EMIdEmpresa = @IdEmpresa;

IF @IdConfiguracion IS NULL
    THROW 51100, 'La empresa 186 no existe en la base origen.', 1;

SELECT TOP (1) @IdVigenciaDestino = V.VIIdVigencia
FROM dbo.ff_Vigencia V
WHERE V.VIIdConfiguracion = @IdConfiguracion
  AND V.VIIdEstatus = 1
  AND CONVERT(date, GETDATE()) BETWEEN CONVERT(date, V.VIVigenciaIni)
                                   AND CONVERT(date, V.VIVigenciaFin)
ORDER BY V.VIVigenciaIni DESC, V.VIIdVigencia DESC;

IF @IdVigenciaDestino IS NULL
BEGIN
    SELECT TOP (1) @IdVigenciaDestino = V.VIIdVigencia
    FROM dbo.ff_Vigencia V
    WHERE V.VIIdConfiguracion = @IdConfiguracion
      AND V.VIIdEstatus = 1
    ORDER BY V.VIVigenciaIni DESC, V.VIIdVigencia DESC;
END;

SELECT @IdVigenciaOrigen = V.VIRenovada
FROM dbo.ff_Vigencia V
WHERE V.VIIdVigencia = @IdVigenciaDestino;

DROP TABLE IF EXISTS #OperacionesEmpresa;
DROP TABLE IF EXISTS #Plantillas;
DROP TABLE IF EXISTS #Campos;
DROP TABLE IF EXISTS #Muestra186;
DROP TABLE IF EXISTS #SolicitudesMuestra;

SELECT CE.CEIdOperacionEmpresa, CE.CEIdOperacion, CE.CEIdPlantilla
INTO #OperacionesEmpresa
FROM dbo.ff_CargaMasivaOperacionEmpresa CE
WHERE CE.CEIdEmpresa = @IdEmpresa;

SELECT DISTINCT OE.CEIdPlantilla AS PLIdPlantilla
INTO #Plantillas
FROM #OperacionesEmpresa OE
WHERE OE.CEIdPlantilla IS NOT NULL;

SELECT DISTINCT CP.CAIdCampo
INTO #Campos
FROM dbo.ff_ConfiguracionPlantilla CP
INNER JOIN #Plantillas P ON P.PLIdPlantilla = CP.PLIdPlantilla;

;WITH Titulares AS
(
    SELECT
        E.Id,
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
SELECT TOP (@TopeEmpleados) T.Id
INTO #Muestra186
FROM Titulares T
ORDER BY T.filaEstrato, T.Id DESC;

SELECT S.SOIdSolicitud
INTO #SolicitudesMuestra
FROM dbo.ff_Solicitud S
INNER JOIN #Muestra186 M ON M.Id = S.SOIdEmpleado
WHERE S.SOIdEmpresa = @IdEmpresa
  AND S.SOIdVigencia IN (@IdVigenciaOrigen, @IdVigenciaDestino);

/* 00. Manifiesto. */
SELECT
    '00_MANIFIESTO' AS __Tabla,
    @IdEmpresa AS IdEmpresa,
    @IdConfiguracion AS IdConfiguracion,
    @IdVigenciaOrigen AS IdVigenciaOrigen,
    @IdVigenciaDestino AS IdVigenciaDestino,
    (SELECT COUNT(*) FROM #OperacionesEmpresa) AS OperacionesEmpresa,
    (SELECT COUNT(*) FROM #Plantillas) AS Plantillas,
    (SELECT COUNT(*) FROM dbo.ff_ConfiguracionPlantilla CP INNER JOIN #Plantillas P ON P.PLIdPlantilla=CP.PLIdPlantilla) AS ConfiguracionesPlantilla,
    (SELECT COUNT(*) FROM #Campos) AS Campos,
    (SELECT COUNT(*) FROM #Muestra186) AS EmpleadosMuestra;

/* 01-03. Empresa y vigencias. */
SELECT 'dbo.ff_Empresa' AS __Tabla, E.*
FROM dbo.ff_Empresa E
WHERE E.EMIdEmpresa = @IdEmpresa;

SELECT 'dbo.ff_Vigencia' AS __Tabla, V.*
FROM dbo.ff_Vigencia V
WHERE V.VIIdConfiguracion = @IdConfiguracion
ORDER BY V.VIIdVigencia;

SELECT 'dbo.ff_TipoDefaulteo' AS __Tabla, TD.*
FROM dbo.ff_TipoDefaulteo TD
WHERE TD.TDIdTipoDefaulteo IN (1, 2, 3)
ORDER BY TD.TDIdTipoDefaulteo;

/* 04-05. Configuración de carga masiva B2. */
SELECT 'dbo.ff_FuncionArchivo' AS __Tabla, FA.*
FROM dbo.ff_FuncionArchivo FA
WHERE FA.FAIdEmpresa = @IdEmpresa
ORDER BY FA.FAIdFuncion;

SELECT 'dbo.ff_CargaMasivaArchivo' AS __Tabla, A.*
FROM dbo.ff_CargaMasivaArchivo A
WHERE A.DOIdEmpresa = @IdEmpresa
ORDER BY A.DOId;

/* 06-10. Configuración completa de carga masiva B3, en orden de dependencia. */
SELECT 'dbo.ff_CargaMasivaOperacion' AS __Tabla, O.*
FROM dbo.ff_CargaMasivaOperacion O
WHERE EXISTS
(
    SELECT 1
    FROM #OperacionesEmpresa OE
    WHERE OE.CEIdOperacion = O.COIdOperacion
)
ORDER BY O.COIdOperacion;

SELECT 'dbo.ff_Plantilla' AS __Tabla, P.*
FROM dbo.ff_Plantilla P
INNER JOIN #Plantillas X ON X.PLIdPlantilla = P.PLIdPlantilla
ORDER BY P.PLIdPlantilla;

SELECT 'dbo.ff_Campo' AS __Tabla, C.*
FROM dbo.ff_Campo C
INNER JOIN #Campos X ON X.CAIdCampo = C.CAIdCampo
ORDER BY C.CAIdCampo;

SELECT 'dbo.ff_ConfiguracionPlantilla' AS __Tabla, CP.*
FROM dbo.ff_ConfiguracionPlantilla CP
INNER JOIN #Plantillas P ON P.PLIdPlantilla = CP.PLIdPlantilla
ORDER BY CP.PLIdPlantilla, CP.CPOrden, CP.CPIdConfiguracionPlantilla;

SELECT 'dbo.ff_CargaMasivaOperacionEmpresa' AS __Tabla, CE.*
FROM dbo.ff_CargaMasivaOperacionEmpresa CE
WHERE CE.CEIdEmpresa = @IdEmpresa
ORDER BY CE.CEIdOperacionEmpresa;

/* 11-15. Titulares completos y sus catálogos directos. */
SELECT 'dbo.ff_Perfil' AS __Tabla, P.*
FROM dbo.ff_Perfil P
WHERE EXISTS
(
    SELECT 1
    FROM dbo.ff_Empleado E
    INNER JOIN #Muestra186 M ON M.Id = E.Id
    WHERE E.EMIdPerfil = P.PEIdPerfil
)
ORDER BY P.PEIdPerfil;

SELECT 'dbo.ff_Parentesco' AS __Tabla, P.*
FROM dbo.ff_Parentesco P
WHERE EXISTS
(
    SELECT 1
    FROM dbo.ff_Empleado E
    INNER JOIN #Muestra186 M ON M.Id = E.Id
    WHERE E.EMIdParentesco = P.PAIdParentesco
)
ORDER BY P.PAIdParentesco;

SELECT 'dbo.ff_Sexo' AS __Tabla, S.*
FROM dbo.ff_Sexo S
WHERE EXISTS
(
    SELECT 1
    FROM dbo.ff_Empleado E
    INNER JOIN #Muestra186 M ON M.Id = E.Id
    WHERE E.EMIdSexo = S.SEIdSexo
)
ORDER BY S.SEIdSexo;

SELECT 'dbo.ff_Rol' AS __Tabla, R.*
FROM dbo.ff_Rol R
WHERE EXISTS
(
    SELECT 1
    FROM dbo.ff_Empleado E
    INNER JOIN #Muestra186 M ON M.Id = E.Id
    WHERE E.EMIdRol = R.ROIdRol
)
ORDER BY R.ROIdRol;

SELECT 'dbo.ff_Empleado' AS __Tabla, E.*
FROM dbo.ff_Empleado E
INNER JOIN #Muestra186 M ON M.Id = E.Id
ORDER BY E.Id;

/* 16-18. Datos relacionados con los titulares para defaulteos 1/2/3. */
SELECT 'dbo.ff_Solicitud' AS __Tabla, S.*
FROM dbo.ff_Solicitud S
INNER JOIN #SolicitudesMuestra M ON M.SOIdSolicitud = S.SOIdSolicitud
ORDER BY S.SOIdSolicitud;

SELECT 'dbo.ff_PlanOpcionSeleccion' AS __Tabla, POS.*
FROM dbo.ff_PlanOpcionSeleccion POS
INNER JOIN #SolicitudesMuestra S ON S.SOIdSolicitud = POS.POIdSolicitud
WHERE POS.POIdEmpresa = @IdEmpresa
ORDER BY POS.POIdPlanOpcionSeleccion;

SELECT 'dbo.ff_Empleado_DEPENDIENTE' AS __Tabla, D.*
FROM dbo.ff_Empleado D
INNER JOIN #Muestra186 M ON M.Id = D.EMIdTitular
WHERE D.EMIdEmpresa = @IdEmpresa
  AND D.EMIdParentesco <> 1
ORDER BY D.EMIdTitular, D.Id;

/* 19-21. Planes básicos/espejo de los perfiles muestreados. */
SELECT 'dbo.ff_PlanBasico' AS __Tabla, PB.*
FROM dbo.ff_PlanBasico PB
WHERE PB.PBIdVigencia = @IdVigenciaDestino
  AND EXISTS
  (
      SELECT 1
      FROM dbo.ff_Empleado E
      INNER JOIN #Muestra186 M ON M.Id = E.Id
      WHERE E.EMIdPerfil = PB.PBIdPerfil
  )
ORDER BY PB.PBIdPlanBasico;

SELECT 'dbo.ff_Plan' AS __Tabla, P.*
FROM dbo.ff_Plan P
WHERE EXISTS
(
    SELECT 1
    FROM dbo.ff_PlanBasico PB
    WHERE PB.PBIdVigencia = @IdVigenciaDestino
      AND PB.PBIdPlan = P.PLIdPlan
      AND EXISTS
      (
          SELECT 1
          FROM dbo.ff_Empleado E
          INNER JOIN #Muestra186 M ON M.Id = E.Id
          WHERE E.EMIdPerfil = PB.PBIdPerfil
      )
)
ORDER BY P.PLIdPlan;

SELECT 'dbo.ff_PlanOpcion' AS __Tabla, PO.*
FROM dbo.ff_PlanOpcion PO
WHERE EXISTS
(
    SELECT 1
    FROM dbo.ff_PlanBasico PB
    WHERE PB.PBIdVigencia = @IdVigenciaDestino
      AND PB.PBIdPlanOpcion = PO.POIdPlanOpcion
      AND EXISTS
      (
          SELECT 1
          FROM dbo.ff_Empleado E
          INNER JOIN #Muestra186 M ON M.Id = E.Id
          WHERE E.EMIdPerfil = PB.PBIdPerfil
      )
)
ORDER BY PO.POIdPlanOpcion;

/* 99. Control final. */
SELECT
    '99_FIN_EXPORTACION' AS __Tabla,
    @IdEmpresa AS IdEmpresa,
    (SELECT COUNT(*) FROM #Muestra186) AS Titulares,
    (SELECT COUNT(*) FROM #SolicitudesMuestra) AS Solicitudes,
    (SELECT COUNT(*) FROM #OperacionesEmpresa) AS OperacionesCargaMasiva,
    (SELECT COUNT(*) FROM #Plantillas) AS PlantillasCargaMasiva,
    (SELECT COUNT(*) FROM #Campos) AS CamposCargaMasiva;
