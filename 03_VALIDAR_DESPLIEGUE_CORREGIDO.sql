USE [FlexiForbesv2];
GO

SET NOCOUNT ON;

DECLARE @Procedimientos TABLE (Nombre sysname NOT NULL);

INSERT INTO @Procedimientos (Nombre)
VALUES
    (N'dbo.ff_SabanaGMM_v2'),
    (N'dbo.ff_SabanaVIDA_v2'),
    (N'dbo.ff_SabanaOPC_v2'),
    (N'dbo.ff_Sabana_v2');

IF EXISTS (
    SELECT 1
    FROM @Procedimientos
    WHERE OBJECT_ID(Nombre, N'P') IS NULL
)
BEGIN
    SELECT Nombre AS ProcedimientoFaltante
    FROM @Procedimientos
    WHERE OBJECT_ID(Nombre, N'P') IS NULL;

    THROW 50110, 'No se crearon todos los procedimientos de Sabana.', 1;
END;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.bf_CatReportesSP
    WHERE catReportesSPId = 3
      AND LTRIM(RTRIM(catReportesSPNombre)) = N'ff_Sabana_v2'
)
    THROW 50111, 'El reporte 3 no apunta a ff_Sabana_v2.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.bf_RepConf_Columna
    WHERE catReportesId = 3
      AND idEmpresa = 0
      AND grupo = N'Vida'
      AND campoOrigen = N'Costo11'
      AND encabezado <> N'Costo'
)
    THROW 50112, 'Permanece la inconsistencia del encabezado Costo11.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.bf_RepConf_Columna
    WHERE catReportesId = 3
      AND (
          encabezado LIKE N'%N?mero%'
          OR encabezado LIKE N'%Antig?edad%'
          OR encabezado LIKE N'%A?o%'
      )
)
BEGIN
    SELECT idEmpresa, grupo, campoOrigen, encabezado, orden
    FROM dbo.bf_RepConf_Columna
    WHERE catReportesId = 3
      AND (
          encabezado LIKE N'%N?mero%'
          OR encabezado LIKE N'%Antig?edad%'
          OR encabezado LIKE N'%A?o%'
      )
    ORDER BY idEmpresa, grupo, orden;

    THROW 50113, 'Se encontraron encabezados con posible perdida de acentos.', 1;
END;

SELECT
    O.name AS Procedimiento,
    O.modify_date AS FechaModificacion
FROM sys.procedures O
WHERE O.object_id IN (
    OBJECT_ID(N'dbo.ff_SabanaGMM_v2', N'P'),
    OBJECT_ID(N'dbo.ff_SabanaVIDA_v2', N'P'),
    OBJECT_ID(N'dbo.ff_SabanaOPC_v2', N'P'),
    OBJECT_ID(N'dbo.ff_Sabana_v2', N'P')
)
ORDER BY O.name;

SELECT
    catReportesSPId,
    catReportesSPNombre
FROM dbo.bf_CatReportesSP
WHERE catReportesSPId = 3;

SELECT
    COUNT(*) AS ColumnasConfiguradas,
    COUNT(DISTINCT idEmpresa) AS ConfiguracionesEmpresa
FROM dbo.bf_RepConf_Columna
WHERE catReportesId = 3;

PRINT 'VALIDACION CORRECTA: objetos y configuracion principal de Sabana disponibles.';
GO
