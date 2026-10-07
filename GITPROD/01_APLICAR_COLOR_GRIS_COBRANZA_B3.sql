USE [FlexiForbesv2];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

/*
    COLOR GRIS - COBRANZA B3 (catReportesNum = 11)

    Requerimiento final:
      Portada "Informacion":       #808080 (gris)
      Encabezados de datos:         #808080 (gris)
      Letra:                        White

    Este script normaliza solamente la configuracion visual del reporte
    de Cobranza. No modifica hojas,
    columnas, registros, filtros, importes ni procedimientos almacenados.

    IMPORTANTE:
    El generador vigente de Cobranza tambien tiene el color codificado en
    JDBCCobranza.java. Por eso este SQL debe desplegarse junto con el archivo
    Java incluido en la entrega.

    NOTA SOBRE EL IDENTIFICADOR:
    Cobranza se identifica en dbo.bf_CatReportes mediante catReportesNum=11.
    Por convencion heredada, las tablas dbo.bf_RepConf_* guardan ese numero
    logico en su columna llamada catReportesId. Por eso los UPDATE de este
    archivo filtran bf_RepConf_Tabla.catReportesId=11; no deben usar el
    catReportesId fisico del catalogo.
*/

DECLARE @CatReportesNum int = 11,
        @FilasActualizadas int = 0;

BEGIN TRY
    IF OBJECT_ID(N'dbo.bf_RepConf_Tabla', N'U') IS NULL
        THROW 52201, 'No existe dbo.bf_RepConf_Tabla en FlexiForbesv2.', 1;

    IF OBJECT_ID(N'dbo.bf_CatReportes', N'U') IS NOT NULL
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.bf_CatReportes
           WHERE catReportesNum = @CatReportesNum
             AND UPPER(LTRIM(RTRIM(catReportesNombre))) COLLATE Latin1_General_100_BIN2 = N'COBRANZA'
       )
        THROW 52202, 'El catReportesNum 11 no corresponde al reporte de Cobranza.', 1;

    BEGIN TRANSACTION;

    /* Portada, tanto global como especifica por empresa. */
    UPDATE dbo.bf_RepConf_Tabla
       SET colorFondo = N'#808080',
           colorLetra = N'White'
     WHERE catReportesId = @CatReportesNum
       AND UPPER(LTRIM(RTRIM(grupo))) COLLATE Latin1_General_100_BIN2 = N'INFORMACION'
       AND (ISNULL(colorFondo,N'') COLLATE Latin1_General_100_BIN2 <> N'#808080'
            OR ISNULL(colorLetra,N'') COLLATE Latin1_General_100_BIN2 <> N'White');

    SET @FilasActualizadas = @FilasActualizadas + @@ROWCOUNT;

    /* Encabezados de todas las hojas y bloques de datos. */
    UPDATE dbo.bf_RepConf_Tabla
       SET colorFondo = N'#808080',
           colorLetra = N'White'
     WHERE catReportesId = @CatReportesNum
       AND UPPER(LTRIM(RTRIM(grupo))) COLLATE Latin1_General_100_BIN2 <> N'INFORMACION'
       AND (ISNULL(colorFondo,N'') COLLATE Latin1_General_100_BIN2 <> N'#808080'
            OR ISNULL(colorLetra,N'') COLLATE Latin1_General_100_BIN2 <> N'White');

    SET @FilasActualizadas = @FilasActualizadas + @@ROWCOUNT;

    IF (
        SELECT COUNT(*)
        FROM dbo.bf_RepConf_Tabla
        WHERE idEmpresa = 0
          AND catReportesId = @CatReportesNum
          AND UPPER(LTRIM(RTRIM(grupo))) COLLATE Latin1_General_100_BIN2 = N'INFORMACION'
          AND colorFondo COLLATE Latin1_General_100_BIN2 = N'#808080'
          AND colorLetra COLLATE Latin1_General_100_BIN2 = N'White'
    ) <> 1
        THROW 52203, 'La configuracion global de Informacion no quedo gris con letra blanca.', 1;

    IF (
        SELECT COUNT(*)
        FROM dbo.bf_RepConf_Tabla
        WHERE idEmpresa = 0
          AND catReportesId = @CatReportesNum
          AND UPPER(LTRIM(RTRIM(grupo))) COLLATE Latin1_General_100_BIN2 <> N'INFORMACION'
          AND colorFondo COLLATE Latin1_General_100_BIN2 = N'#808080'
          AND colorLetra COLLATE Latin1_General_100_BIN2 = N'White'
    ) <> 11
        THROW 52204, 'No se encontraron los once bloques globales de Cobranza en gris con letra blanca.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.bf_RepConf_Tabla
        WHERE catReportesId = @CatReportesNum
          AND (ISNULL(colorFondo,N'') COLLATE Latin1_General_100_BIN2 <> N'#808080'
               OR ISNULL(colorLetra,N'') COLLATE Latin1_General_100_BIN2 <> N'White')
    )
        THROW 52205, 'Aun existen configuraciones de Cobranza B3 sin el gris o la letra blanca.', 1;

    COMMIT TRANSACTION;

    SELECT @FilasActualizadas AS FilasActualizadas,
           N'#808080' AS ColorPortada,
           N'#808080' AS ColorEncabezados,
           N'White' AS ColorLetra,
           N'Generar una cobranza nueva despues de desplegar API Reports.' AS SiguientePaso;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
