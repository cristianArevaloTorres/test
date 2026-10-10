USE [FlexiForbesv2];
GO

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

/* Validación de solo lectura. No genera reportes ni llena el cache. */
CREATE TABLE #Resultado
(
    Orden int NOT NULL,
    Componente nvarchar(100) NOT NULL,
    Estado varchar(10) NOT NULL,
    Valor nvarchar(500) NULL,
    Detalle nvarchar(max) NULL
);

INSERT #Resultado VALUES
(10,N'Contexto',N'INFO',CONCAT(CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')),N' / ',DB_NAME()),N'Confirmar que sea la base utilizada por API Reports.');

DECLARE @Objetos TABLE(Orden int,Nombre sysname,Tipo char(2),Requerido bit);
INSERT @Objetos VALUES
(20,N'ObtenCobranzaConcentrada','P',1),
(21,N'ObtenCobranzaConcentrada_otro_V2_BF3','P',1),
(22,N'ReporteCobranzaConcentrada_BF3_Cache','P',1),
(23,N'ff_orquestadorReportes','P',1),
(24,N'ListInt','TT',1),
(25,N'bf_CatalogoEstatusReporteGen','U',1),
(26,N'bf_ControlReporteGen','U',1),
(27,N'bf_CatReportesSP','U',1),
(28,N'bf_CatReportesParams','U',1),
(29,N'bf_CobranzaCache_ConsultaV2','U',0),
(30,N'ff_Parametro','U',1);

INSERT #Resultado
SELECT O.Orden,N'Objeto '+O.Nombre,
       CASE WHEN O.Requerido=0 THEN 'INFO'
            WHEN OBJECT_ID(N'dbo.'+O.Nombre,O.Tipo) IS NULL THEN 'ALERTA' ELSE 'OK' END,
       CASE WHEN OBJECT_ID(N'dbo.'+O.Nombre,O.Tipo) IS NULL THEN N'NO EXISTE' ELSE N'EXISTE' END,
       CASE WHEN O.Requerido=0 THEN N'Objeto histórico de cache; la ruta final no depende de él.' ELSE NULL END
FROM @Objetos O;

DECLARE @Directo nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3',N'P')),
        @Reporte nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'dbo.ReporteCobranzaConcentrada_BF3_Cache',N'P'));
DECLARE @DirectoNorm nvarchar(max)=UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    ISNULL(@Directo,N''),N'[',N''),N']',N''),N' ',N''),CHAR(9),N''),CHAR(10),N''),CHAR(13),N''));
DECLARE @ReporteNorm nvarchar(max)=UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
    ISNULL(@Reporte,N''),N'[',N''),N']',N''),N' ',N''),CHAR(9),N''),CHAR(10),N''),CHAR(13),N''));

INSERT #Resultado VALUES
(40,N'Ruta B3 homologada con B2',
 CASE WHEN @DirectoNorm LIKE N'%RUTA=B2_HOMOLOGADA%'
            AND @DirectoNorm LIKE N'%EXECDBO.OBTENCOBRANZACONCENTRADA%'
            AND @DirectoNorm NOT LIKE N'%EXECDBO.OBTENCOBRANZACONCENTRADA_OTRO_V2_BF3_SET%'
            AND CHARINDEX(N'BF_COBRANZACACHE_CONSULTAV2',@DirectoNorm)=0
            AND CHARINDEX(N'BF_COBRANZACACHE_CARGAR',@DirectoNorm)=0
            AND CHARINDEX(N'INSERTACOBRANZACONCENTRADA_OTRO_V2_BF3_CACHE',@DirectoNorm)=0
            AND CHARINDEX(N'OBTENCOBRANZACONCENTRADA_OTRO_V2_BF3_CACHE',@DirectoNorm)=0
      THEN 'OK' ELSE 'ALERTA' END,
 N'Delegación directa en B2',N'B3 conserva su nombre público pero utiliza la lógica funcional de B2.'),
(41,N'Wrapper final sin cache',
 CASE WHEN @ReporteNorm LIKE N'%RUTA=B2_HOMOLOGADA_SIN_CACHE%'
            AND @ReporteNorm LIKE N'%EXECDBO.OBTENCOBRANZACONCENTRADA_OTRO_V2_BF3%'
            AND @ReporteNorm NOT LIKE N'%EXECDBO.INSERTACOBRANZACONCENTRADA%'
            AND CHARINDEX(N'BF_COBRANZACACHE_CONSULTAV2',@ReporteNorm)=0
            AND CHARINDEX(N'BF_COBRANZACACHE_CARGAR',@ReporteNorm)=0
            AND CHARINDEX(N'INSERTACOBRANZACONCENTRADA_OTRO_V2_BF3_CACHE',@ReporteNorm)=0
            AND CHARINDEX(N'OBTENCOBRANZACONCENTRADA_OTRO_V2_BF3_CACHE',@ReporteNorm)=0
      THEN 'OK' ELSE 'ALERTA' END,
 N'SIN CACHE',N'La generación solicitada no debe iniciar una precarga de cache.');

IF OBJECT_ID(N'dbo.bf_CatalogoEstatusReporteGen',N'U') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql N'
        DECLARE @Cantidad int=(SELECT COUNT(*) FROM dbo.bf_CatalogoEstatusReporteGen
                               WHERE CatERptId=7
                                 AND UPPER(LTRIM(RTRIM(CatERptNombre)))=N''EN ESPERA'');
        INSERT #Resultado VALUES
        (50,N''Estatus En espera'',CASE WHEN @Cantidad=1 THEN ''OK'' ELSE ''ALERTA'' END,
         CONVERT(nvarchar(20),@Cantidad),N''API Reports utiliza el identificador 7 para solicitudes en cola.'');';
END
ELSE
    INSERT #Resultado VALUES(50,N'Estatus En espera','ALERTA',N'NO VALIDABLE',N'Falta el catálogo de estatus.');

IF OBJECT_ID(N'dbo.bf_CatReportesSP',N'U') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql N'
        DECLARE @Activas int=(SELECT COUNT(*) FROM dbo.bf_CatReportesSP
                              WHERE catReportesId=11 AND ISNULL(ESid,1)=1),
                @Correctas int=(SELECT COUNT(*) FROM dbo.bf_CatReportesSP
                                WHERE catReportesId=11 AND ISNULL(ESid,1)=1
                                  AND catReportesSPNombre=N''ReporteCobranzaConcentrada_BF3_Cache'');
        INSERT #Resultado VALUES
        (51,N''Ruta del reporte 11'',CASE WHEN @Activas=1 AND @Correctas=1 THEN ''OK'' ELSE ''ALERTA'' END,
         CONCAT(N''Activas='',@Activas,N''; correctas='',@Correctas),
         N''Debe existir una sola ruta activa con el wrapper público de Cobranza.'');';
END
ELSE
    INSERT #Resultado VALUES(51,N'Ruta del reporte 11','ALERTA',N'NO VALIDABLE',N'Falta bf_CatReportesSP.');

CREATE TABLE #ParametrosEsperados(Nombre nvarchar(100) PRIMARY KEY);
INSERT #ParametrosEsperados VALUES
(N'@IDEMPRESA'),(N'@IDSOLTIPO'),(N'@FECINI'),(N'@FECFIN'),
(N'@IDVENCIDA'),(N'@IDPERFIL'),(N'@IDVIGENCIA');

IF OBJECT_ID(N'dbo.bf_CatReportesSP',N'U') IS NOT NULL
   AND OBJECT_ID(N'dbo.bf_CatReportesParams',N'U') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql N'
        DECLARE @Faltantes int,
                @Duplicados int,
                @NoEsperados int;
        ;WITH P AS
        (
            SELECT UPPER(LTRIM(RTRIM(X.catReportesParamsNombre))) Nombre,COUNT(*) Cantidad
            FROM dbo.bf_CatReportesParams X
            JOIN dbo.bf_CatReportesSP S ON S.catReportesSPId=X.catReportesSPId
            WHERE S.catReportesId=11 AND S.catReportesSPNombre=N''ReporteCobranzaConcentrada_BF3_Cache''
              AND ISNULL(S.ESid,1)=1 AND ISNULL(X.ESid,1)=1
            GROUP BY UPPER(LTRIM(RTRIM(X.catReportesParamsNombre)))
        )
        SELECT @Faltantes=(SELECT COUNT(*) FROM #ParametrosEsperados E
                           WHERE NOT EXISTS(SELECT 1 FROM P WHERE P.Nombre=E.Nombre)),
               @Duplicados=(SELECT COUNT(*) FROM P WHERE Cantidad>1),
               @NoEsperados=(SELECT COUNT(*) FROM P
                             WHERE NOT EXISTS(SELECT 1 FROM #ParametrosEsperados E WHERE E.Nombre=P.Nombre));
        INSERT #Resultado VALUES
        (52,N''Parámetros del reporte 11'',
         CASE WHEN @Faltantes=0 AND @Duplicados=0 AND @NoEsperados=0 THEN ''OK'' ELSE ''ALERTA'' END,
         CONCAT(N''Faltantes='',@Faltantes,N''; duplicados='',@Duplicados,N''; adicionales='',@NoEsperados),
         N''Se esperan exactamente los siete argumentos del wrapper final.'');';
END
ELSE
    INSERT #Resultado VALUES(52,N'Parámetros del reporte 11','ALERTA',N'NO VALIDABLE',N'Faltan tablas de configuración.');

IF OBJECT_ID(N'dbo.ff_Parametro',N'U') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql N'
        DECLARE @Activas int=(SELECT COUNT(*) FROM dbo.ff_Parametro
                              WHERE UPPER(LTRIM(RTRIM(ISNULL(paClase,'''')))) IN
                                    (N''COBRANZA_CACHE'',N''COBRANZA_CACHE_HORA'')
                                AND ISNULL(paidEstatus,0)=1);
        INSERT #Resultado VALUES
        (53,N''Configuración del worker/cache'',CASE WHEN @Activas=0 THEN ''OK'' ELSE ''ALERTA'' END,
         CONCAT(N''Parámetros activos='',@Activas),
         N''No debe quedar activa ninguna configuración COBRANZA_CACHE o COBRANZA_CACHE_HORA.'');';
END
ELSE
    INSERT #Resultado VALUES(53,N'Configuración del worker/cache','ALERTA',N'NO VALIDABLE',N'Falta dbo.ff_Parametro.');

IF OBJECT_ID(N'dbo.bf_ControlReporteGen',N'U') IS NOT NULL
BEGIN
    EXEC sys.sp_executesql N'
        DECLARE @EnEspera int=(SELECT COUNT(*) FROM dbo.bf_ControlReporteGen
                               WHERE CRptIdReporte=11 AND CRptIdEstatus=7),
                @EnProceso int=(SELECT COUNT(*) FROM dbo.bf_ControlReporteGen
                                WHERE CRptIdReporte=11 AND CRptIdEstatus=1);
        INSERT #Resultado VALUES
        (60,N''Concurrencia observada de Cobranza'',
         CASE WHEN @EnProceso<=1 THEN ''OK'' ELSE ''ALERTA'' END,
         CONCAT(N''En espera='',@EnEspera,N''; en proceso='',@EnProceso),
         N''Con la cola operativa debe observarse como máximo una Cobranza en proceso por vez.'');';
END
ELSE
    INSERT #Resultado VALUES(60,N'Solicitudes activas recientes','ALERTA',N'NO VALIDABLE',N'Falta bf_ControlReporteGen.');

INSERT #Resultado VALUES
(70,N'Worker de cache en API Reports',N'INFO',N'Debe estar deshabilitado',
 N'Confirmar en el WAR desplegado: cobranza.cache.worker.enabled=false. Esta propiedad no puede comprobarse desde SQL Server.');

DECLARE @Alertas int=(SELECT COUNT(*) FROM #Resultado WHERE Estado='ALERTA');
INSERT #Resultado VALUES
(999,N'Resultado general',CASE WHEN @Alertas=0 THEN 'OK' ELSE 'ALERTA' END,
 CONCAT(N'Alertas=',@Alertas),N'La instalación se considera válida solamente cuando Alertas=0.');

SELECT Componente,Estado,Valor,Detalle
FROM #Resultado
ORDER BY Orden,Componente;
GO
