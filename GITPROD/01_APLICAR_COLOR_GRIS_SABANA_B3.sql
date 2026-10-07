USE [FlexiForbesv2];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

/*
    AJUSTE EXCLUSIVO DE COLOR - SABANA B3 (catReportesNum = 3)

    Resultado visual:
      Fondo de encabezados: #808080 (gris)
      Letra de encabezados: White

    Alcance:
      - Incluye configuracion global (idEmpresa=0).
      - Incluye configuraciones especificas por empresa.
      - Aplica a todos los grupos configurados para Sabana.
      - No modifica hojas, columnas, orden, registros, filtros, datos ni SP.

    NOTA SOBRE EL IDENTIFICADOR:
    Sabana se identifica en dbo.bf_CatReportes mediante catReportesNum=3.
    Por convencion heredada, dbo.bf_RepConf_Tabla guarda ese numero logico
    en la columna llamada catReportesId.

    No requiere cambio Java: el generador de Sabana ya consume colorFondo y
    colorLetra desde dbo.bf_RepConf_Tabla.
*/

DECLARE @CatReportesNum int = 3,
        @ConfiguracionesAntes int,
        @FilasActualizadas int;

BEGIN TRY
    IF OBJECT_ID(N'dbo.bf_CatReportes', N'U') IS NULL
        THROW 52301, 'No existe dbo.bf_CatReportes en FlexiForbesv2.', 1;

    IF OBJECT_ID(N'dbo.bf_RepConf_Tabla', N'U') IS NULL
        THROW 52302, 'No existe dbo.bf_RepConf_Tabla en FlexiForbesv2.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.bf_CatReportes
        WHERE catReportesNum = @CatReportesNum
          AND UPPER(LTRIM(RTRIM(catReportesNombre))) COLLATE Latin1_General_100_BIN2
              LIKE N'%SABANA%'
    )
        THROW 52303, 'El catReportesNum 3 no corresponde al reporte de Sabana.', 1;

    SELECT @ConfiguracionesAntes = COUNT(*)
    FROM dbo.bf_RepConf_Tabla
    WHERE catReportesId = @CatReportesNum;

    IF @ConfiguracionesAntes = 0
        THROW 52304, 'No existen configuraciones de Sabana en dbo.bf_RepConf_Tabla.', 1;

    BEGIN TRANSACTION;

    UPDATE dbo.bf_RepConf_Tabla
       SET colorFondo = N'#808080',
           colorLetra = N'White'
     WHERE catReportesId = @CatReportesNum
       AND
       (
           ISNULL(colorFondo,N'') COLLATE Latin1_General_100_BIN2 <> N'#808080'
           OR ISNULL(colorLetra,N'') COLLATE Latin1_General_100_BIN2 <> N'White'
       );

    SET @FilasActualizadas = @@ROWCOUNT;

    IF (SELECT COUNT(*)
        FROM dbo.bf_RepConf_Tabla
        WHERE catReportesId = @CatReportesNum) <> @ConfiguracionesAntes
        THROW 52305, 'Cambio inesperado en la cantidad de configuraciones de Sabana.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.bf_RepConf_Tabla
        WHERE catReportesId = @CatReportesNum
          AND
          (
              ISNULL(colorFondo,N'') COLLATE Latin1_General_100_BIN2 <> N'#808080'
              OR ISNULL(colorLetra,N'') COLLATE Latin1_General_100_BIN2 <> N'White'
          )
    )
        THROW 52306, 'No todas las configuraciones de Sabana quedaron en gris con letra blanca.', 1;

    COMMIT TRANSACTION;

    SELECT @ConfiguracionesAntes AS ConfiguracionesConservadas,
           @FilasActualizadas AS FilasActualizadas,
           N'#808080' AS ColorFondo,
           N'White' AS ColorLetra,
           N'Generar una Sabana nueva para observar el cambio.' AS SiguientePaso;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

