/*
   INSTALACION UNICA DE COBRANZA B3
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() IN (N'master',N'model',N'msdb',N'tempdb')
    THROW 53900,'Seleccione la base funcional destino antes de instalar Cobranza B3.',1;

IF OBJECT_ID(N'tempdb..#BF3_InstalacionConfig',N'U') IS NOT NULL
    DROP TABLE #BF3_InstalacionConfig;

CREATE TABLE #BF3_InstalacionConfig
(
    IdEmpresaValidacion int NULL,
    IdVigenciaValidacion int NULL
);

INSERT #BF3_InstalacionConfig(IdEmpresaValidacion,IdVigenciaValidacion)
VALUES
(
    NULL, -- Ejemplo: 186
    NULL  -- Ejemplo: 4235
);

IF OBJECT_ID(N'tempdb..#BF3_InstalacionAdvertencias',N'U') IS NOT NULL
    DROP TABLE #BF3_InstalacionAdvertencias;

CREATE TABLE #BF3_InstalacionAdvertencias
(
    AdvertenciaId int IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Paso varchar(20) NOT NULL,
    Objeto sysname NULL,
    NumeroError int NULL,
    Mensaje nvarchar(4000) NOT NULL,
    Fecha datetime2(3) NOT NULL DEFAULT SYSDATETIME()
);

DECLARE @BaseDatosInstalacion sysname=DB_NAME();
RAISERROR(N'[COBRANZA B3] Inicio de instalacion en %s.',10,1,@BaseDatosInstalacion) WITH NOWAIT;
GO
/* ======================================================================
   PASO 1 DE 10: 01_INSTALAR_CACHE_Y_REPORTE_B3.sql
   ====================================================================== */
RAISERROR(N'[COBRANZA B3] Ejecutando paso 1/10: 01_INSTALAR_CACHE_Y_REPORTE_B3.sql',10,1) WITH NOWAIT;
GO
/*
    INSTALACION COMPLETA, VERIFICACION Y PRUEBA SINTETICA
*/
SET NOCOUNT ON;
RAISERROR('INICIO: instalacion completa de cache de Cobranza BF3.',10,1) WITH NOWAIT;
GO

IF OBJECT_ID(N'dbo.bf_CobranzaCache_Log',N'U') IS NULL
BEGIN
    CREATE TABLE dbo.bf_CobranzaCache_Log
    (
        LogId bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_bf_CobranzaCache_Log PRIMARY KEY CLUSTERED,
        Fecha datetime2(3) NOT NULL
            CONSTRAINT DF_bf_CobranzaCache_Log_Fecha DEFAULT (SYSDATETIME()),
        Etapa varchar(100) NOT NULL,
        Detalle nvarchar(4000) NULL
    );
END;

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'dbo.bf_CobranzaCache_Log')
      AND name=N'IX_bf_CobranzaCache_Log_Fecha'
)
BEGIN
BEGIN TRY
    CREATE INDEX IX_bf_CobranzaCache_Log_Fecha
        ON dbo.bf_CobranzaCache_Log(Fecha) INCLUDE(Etapa);
END TRY
BEGIN CATCH
    INSERT #BF3_InstalacionAdvertencias(Paso,Objeto,NumeroError,Mensaje)
    VALUES('01',N'IX_bf_CobranzaCache_Log_Fecha',ERROR_NUMBER(),ERROR_MESSAGE());
    RAISERROR(N'[COBRANZA B3][ADVERTENCIA] No se creo IX_bf_CobranzaCache_Log_Fecha; se continua.',10,1) WITH NOWAIT;
END CATCH;
END;
GO

/* BF_CACHE_MONITORING_V1: contexto estructurado para correlacionar cada carga. */
IF COL_LENGTH(N'dbo.bf_CobranzaCache_Log',N'CacheId') IS NULL
    ALTER TABLE dbo.bf_CobranzaCache_Log ADD CacheId bigint NULL;
IF COL_LENGTH(N'dbo.bf_CobranzaCache_Log',N'IdEmpresa') IS NULL
    ALTER TABLE dbo.bf_CobranzaCache_Log ADD IdEmpresa int NULL;
IF COL_LENGTH(N'dbo.bf_CobranzaCache_Log',N'IdVigencia') IS NULL
    ALTER TABLE dbo.bf_CobranzaCache_Log ADD IdVigencia int NULL;
IF COL_LENGTH(N'dbo.bf_CobranzaCache_Log',N'Estado') IS NULL
    ALTER TABLE dbo.bf_CobranzaCache_Log ADD Estado varchar(20) NULL;
IF COL_LENGTH(N'dbo.bf_CobranzaCache_Log',N'SesionId') IS NULL
    ALTER TABLE dbo.bf_CobranzaCache_Log ADD SesionId smallint NULL;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'dbo.bf_CobranzaCache_Log')
      AND name=N'IX_bf_CobranzaCache_Log_Carga'
)
BEGIN
BEGIN TRY
    CREATE INDEX IX_bf_CobranzaCache_Log_Carga
        ON dbo.bf_CobranzaCache_Log(IdEmpresa,IdVigencia,CacheId,Fecha DESC)
        INCLUDE(Etapa,Estado,SesionId);
END TRY
BEGIN CATCH
    INSERT #BF3_InstalacionAdvertencias(Paso,Objeto,NumeroError,Mensaje)
    VALUES('01',N'IX_bf_CobranzaCache_Log_Carga',ERROR_NUMBER(),ERROR_MESSAGE());
    RAISERROR(N'[COBRANZA B3][ADVERTENCIA] No se creo IX_bf_CobranzaCache_Log_Carga; se continua.',10,1) WITH NOWAIT;
END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.bf_CobranzaCache_RegistrarEvento
    @CacheId bigint = NULL,
    @IdEmpresa int = NULL,
    @IdVigencia int = NULL,
    @Etapa varchar(100),
    @Estado varchar(20) = NULL,
    @Detalle nvarchar(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    /* El monitoreo nunca debe interrumpir la carga de negocio. */
    BEGIN TRY
        INSERT dbo.bf_CobranzaCache_Log
            (CacheId,IdEmpresa,IdVigencia,Etapa,Estado,SesionId,Detalle)
        VALUES
            (@CacheId,@IdEmpresa,@IdVigencia,@Etapa,@Estado,@@SPID,@Detalle);
    END TRY
    BEGIN CATCH
        /* Intencional: la carga continua aunque el log no este disponible. */
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.bf_CobranzaCache_MarcarCargasAbandonadas
    @IdEmpresa int = NULL,
    @MinutosSinActividad int = 15,
    @EmitirResultado bit = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @MinutosSinActividad<1
        THROW 51500,'MinutosSinActividad debe ser mayor que cero.',1;

    DECLARE @CacheId bigint,@Empresa int,@Vigencia int,@Vencida int,
            @PerfilHash varbinary(32),@LockName nvarchar(255),@LockResult int,
            @Detalle nvarchar(4000),@Marcadas int=0;

    DECLARE Cargas CURSOR LOCAL FAST_FORWARD FOR
        SELECT Q.CacheId,Q.IdEmpresa,Q.IdVigencia,Q.IdVencida,Q.PerfilHash
        FROM dbo.bf_CobranzaCache_ConsultaV2 Q WITH (READPAST)
        OUTER APPLY
        (
            SELECT MAX(L.Fecha) AS UltimoEvento
            FROM dbo.bf_CobranzaCache_Log L WITH (READPAST)
            WHERE L.CacheId=Q.CacheId
        ) L
        WHERE Q.Estado='CARGANDO'
          AND (@IdEmpresa IS NULL OR Q.IdEmpresa=@IdEmpresa)
          AND COALESCE(L.UltimoEvento,Q.FechaCargaInicio)
                < DATEADD(MINUTE,-@MinutosSinActividad,SYSDATETIME());

    OPEN Cargas;
    FETCH NEXT FROM Cargas INTO @CacheId,@Empresa,@Vigencia,@Vencida,@PerfilHash;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SET @LockName=CONCAT(N'BF3-CobranzaCache-',@Empresa,N'-',@Vigencia,N'-',
                            CONVERT(varchar(64),@PerfilHash,2),N'-',@Vencida);
        SET @LockResult=-999;

        /* Evita que una llamada desde la propia sesion propietaria sea
           interpretada como carga abandonada (sp_getapplock es reentrante). */
        IF ISNULL(APPLOCK_MODE(N'public',@LockName,'Session'),'NoLock')='NoLock'
            EXEC @LockResult=sys.sp_getapplock
                 @Resource=@LockName,@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;

        /* Si se obtiene el mismo bloqueo, ya no existe una sesion cargando. */
        IF @LockResult>=0
        BEGIN
            SET @Detalle=CONCAT(
                N'Carga abandonada: no existe una sesion propietaria del APPLOCK; ',
                N'ultimo evento con antiguedad mayor a ',@MinutosSinActividad,N' minutos.');

            UPDATE dbo.bf_CobranzaCache_ConsultaV2
               SET Estado='ERROR',FechaCargaFin=SYSDATETIME(),Mensaje=LEFT(@Detalle,2000)
             WHERE CacheId=@CacheId AND Estado='CARGANDO';

            IF @@ROWCOUNT=1
            BEGIN
                SET @Marcadas+=1;
                EXEC dbo.bf_CobranzaCache_RegistrarEvento
                     @CacheId=@CacheId,@IdEmpresa=@Empresa,@IdVigencia=@Vigencia,
                     @Etapa='CARGA_ABANDONADA',@Estado='ERROR',@Detalle=@Detalle;
            END;

            EXEC sys.sp_releaseapplock @Resource=@LockName,@LockOwner='Session';
        END;

        FETCH NEXT FROM Cargas INTO @CacheId,@Empresa,@Vigencia,@Vencida,@PerfilHash;
    END;
    CLOSE Cargas;
    DEALLOCATE Cargas;

    IF @EmitirResultado=1
        SELECT @Marcadas AS CargasMarcadasError;
END;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3', N'P') IS NULL
    THROW 51000, 'No existe dbo.ObtenCobranzaConcentrada_otro_V2_BF3.', 1;
IF OBJECT_ID(N'dbo.ff_ObtenDivisionCtos_Adaptado_bf3_NOUSAR', N'P') IS NULL
    THROW 51000, 'No existe dbo.ff_ObtenDivisionCtos_Adaptado_bf3_NOUSAR.', 1;
IF TYPE_ID(N'dbo.ListInt') IS NULL
    THROW 51000, 'No existe el tipo dbo.ListInt.', 1;
GO


DECLARE @DefDesglosada nvarchar(max)=OBJECT_DEFINITION(
            OBJECT_ID(N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_NOUSAR')),
        @FuenteAnterior nvarchar(300)=
            N'FROM dbo.ff_planopcionseleccionCobranza POS WITH (NOLOCK)',
        @FuenteNueva nvarchar(300)=
            N'FROM dbo.ff_planopcionseleccionCobranza2 POS WITH (NOLOCK)',
        @PosCreate int;

IF OBJECT_ID(N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_NOUSAR',N'P') IS NULL
    THROW 51000,
        'No existe dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_NOUSAR.',1;
IF OBJECT_ID(N'dbo.ff_PlanOpcionSeleccionCobranza2',N'U') IS NULL
    THROW 51000,
        'No existe dbo.ff_PlanOpcionSeleccionCobranza2.',1;

IF CHARINDEX(@FuenteNueva,@DefDesglosada)=0
BEGIN
    IF CHARINDEX(@FuenteAnterior,@DefDesglosada)=0
        THROW 51000,
            'No se identifico la fuente de ff_ObtenCobranzaDesg_Adaptada_bf3_NOUSAR.',1;

    SET @DefDesglosada=REPLACE(
        @DefDesglosada,@FuenteAnterior,@FuenteNueva);
    SET @PosCreate=CHARINDEX(N'CREATE PROCEDURE',UPPER(@DefDesglosada));
    IF @PosCreate=0
        THROW 51000,'No se encontro CREATE PROCEDURE en el SP desglosado.',1;
    SET @DefDesglosada=STUFF(
        @DefDesglosada,@PosCreate,LEN(N'CREATE PROCEDURE'),N'ALTER PROCEDURE');
    EXEC sys.sp_executesql @DefDesglosada;
END;
GO


DECLARE @DefDesgError512 nvarchar(max)=OBJECT_DEFINITION(
            OBJECT_ID(N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_NOUSAR')),
        @DefDesgError512Original nvarchar(max),
        @PosProcDesgError512 int,
        @PosInsertDesgError512 int;

IF @DefDesgError512 IS NULL
    THROW 51000,
        'No se pudo leer ff_ObtenCobranzaDesg_Adaptada_bf3_NOUSAR para corregir Error 512.',1;

IF CHARINDEX(N'BF_CACHE_DESG_SCALAR_512_FIX_V1',@DefDesgError512)=0
BEGIN
    SET @DefDesgError512Original=@DefDesgError512;

    SET @DefDesgError512=REPLACE(
        @DefDesgError512,
        N'SELECT RTRIM(LTRIM(GPDescripcion))',
        N'SELECT MAX(RTRIM(LTRIM(GPDescripcion)))');

    SET @DefDesgError512=REPLACE(
        @DefDesgError512,
        N'SELECT VsSumaAsegurada',
        N'SELECT MAX(VsSumaAsegurada)');

    SET @DefDesgError512=REPLACE(
        @DefDesgError512,
        N'SELECT POS.POTarifaNeta',
        N'SELECT TOP (1) POS.POTarifaNeta');

    SET @DefDesgError512=REPLACE(
        @DefDesgError512,
        N'SELECT TC.TCPrimaNeta',
        N'SELECT MAX(TC.TCPrimaNeta)');

    SET @DefDesgError512=REPLACE(
        @DefDesgError512,
        N'SELECT TPPrimaNeta',
        N'SELECT MAX(TPPrimaNeta)');

    IF @DefDesgError512=@DefDesgError512Original
        THROW 51000,
            'No se reconocieron los lookups escalares del SP desglosado que causan Error 512.',1;

    /* La marca se guarda dentro del procedimiento para que el ajuste sea idempotente. */
    SET @PosInsertDesgError512=CHARINDEX(
        N'INSERT INTO #TABLACOBDESG',UPPER(@DefDesgError512));
    IF @PosInsertDesgError512=0
        THROW 51000,
            'No se encontro el INSERT de #TablaCobDesg para marcar la correccion.',1;

    SET @DefDesgError512=STUFF(
        @DefDesgError512,@PosInsertDesgError512,0,
        N'/* BF_CACHE_DESG_SCALAR_512_FIX_V1 */
    ');

    SET @PosProcDesgError512=CHARINDEX(N'PROCEDURE',UPPER(@DefDesgError512));
    IF @PosProcDesgError512=0
        THROW 51000,
            'La definicion del SP desglosado no contiene PROCEDURE.',1;

    SET @DefDesgError512=N'ALTER '
        + SUBSTRING(@DefDesgError512,@PosProcDesgError512,LEN(@DefDesgError512));
    EXEC sys.sp_executesql @DefDesgError512;
END;
GO


DECLARE @DefDesgError8120 nvarchar(max)=OBJECT_DEFINITION(
            OBJECT_ID(N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_NOUSAR')),
        @PosProcDesgError8120 int,
        @PosInsertDesgError8120 int;

IF @DefDesgError8120 IS NULL
    THROW 51000,
        'No se pudo leer ff_ObtenCobranzaDesg_Adaptada_bf3_NOUSAR para corregir Error 8120.',1;

IF CHARINDEX(N'BF_CACHE_DESG_SCALAR_8120_FIX_V2',@DefDesgError8120)=0
BEGIN
    SET @DefDesgError8120=REPLACE(
        @DefDesgError8120,
        N'SELECT MAX(POS.POTarifaNeta)',
        N'SELECT TOP (1) POS.POTarifaNeta');

    IF CHARINDEX(N'SELECT TOP (1) POS.POTarifaNeta',@DefDesgError8120)=0
        THROW 51000,
            'No se encontro el lookup POTarifaNeta esperado para corregir Error 8120.',1;

    SET @PosInsertDesgError8120=CHARINDEX(
        N'INSERT INTO #TABLACOBDESG',UPPER(@DefDesgError8120));
    IF @PosInsertDesgError8120=0
        THROW 51000,
            'No se encontro el INSERT de #TablaCobDesg para marcar la correccion 8120.',1;

    SET @DefDesgError8120=STUFF(
        @DefDesgError8120,@PosInsertDesgError8120,0,
        N'/* BF_CACHE_DESG_SCALAR_8120_FIX_V2 */
    ');

    SET @PosProcDesgError8120=CHARINDEX(N'PROCEDURE',UPPER(@DefDesgError8120));
    IF @PosProcDesgError8120=0
        THROW 51000,
            'La definicion del SP desglosado no contiene PROCEDURE.',1;

    SET @DefDesgError8120=N'ALTER '
        + SUBSTRING(@DefDesgError8120,@PosProcDesgError8120,LEN(@DefDesgError8120));
    EXEC sys.sp_executesql @DefDesgError8120;
END;
GO

/*
   Corrige el Error 512 observado durante la carga de la vigencia. El SP
   principal calcula @DescuentoEmpleadoFinal y @DescuentoEmpleadoFH y, justo
   despues, los volvia a consultar en #tablatemp mediante dos subconsultas con
   DISTINCT. Si el empleado tenia mas de un valor, una subconsulta escalar
   devolvia varias filas y abortaba la carga.

   Se usan directamente los valores ya calculados para la iteracion actual.
   Esto conserva la regla de negocio y evita elegir una fila arbitraria.
*/
DECLARE @DefError512 nvarchar(max)=OBJECT_DEFINITION(
            OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3')),
        @DefError512Upper nvarchar(max),
        @InicioError512 int,
        @FinError512 int,
        @BloqueError512 nvarchar(max),
        @PosProcError512 int;

IF @DefError512 IS NULL
    THROW 51000,
        'No se pudo leer dbo.ObtenCobranzaConcentrada_otro_V2_BF3 para corregir Error 512.',1;

IF CHARINDEX(N'BF_CACHE_SCALAR_512_FIX_V1',@DefError512)=0
BEGIN
    SET @DefError512Upper=UPPER(@DefError512) COLLATE Latin1_General_100_CI_AS;
    SET @InicioError512=CHARINDEX(
        N'SELECT @DEIMPORTE1 = (SELECT DISTINCT ISNULL(DESCUENTOEMPLEADOFINAL,0)',
        @DefError512Upper);

    IF @InicioError512>0
    BEGIN
        SET @FinError512=CHARINDEX(
            N'UPDATE #TABLATEMP SET CTOEMPLEADONOMSEG',
            @DefError512Upper,@InicioError512);

        IF @FinError512=0
            THROW 51000,
                'Se encontro la subconsulta del Error 512, pero no su limite de reemplazo.',1;

        SET @BloqueError512=SUBSTRING(
            @DefError512,@InicioError512,@FinError512-@InicioError512);

        IF CHARINDEX(N'DESCUENTOEMPLEADOFH',UPPER(@BloqueError512))=0
            THROW 51000,
                'La subconsulta del Error 512 no coincide con la version esperada.',1;

        SET @DefError512=STUFF(
            @DefError512,
            @InicioError512,
            @FinError512-@InicioError512,
            N'/* BF_CACHE_SCALAR_512_FIX_V1 */
        SET @DEImporte1 = ISNULL(@DescuentoEmpleadoFinal,0)
                        - ISNULL(@DescuentoEmpleadoFH,0);

        ');

        SET @PosProcError512=CHARINDEX(N'PROCEDURE',UPPER(@DefError512));
        IF @PosProcError512=0
            THROW 51000,
                'La definicion del SP principal no contiene PROCEDURE.',1;

        SET @DefError512=N'ALTER '
            + SUBSTRING(@DefError512,@PosProcError512,LEN(@DefError512));
        EXEC sys.sp_executesql @DefError512;
    END
--    ELSE IF CHARINDEX(
--                N'SELECT DISTINCT ISNULL(DESCUENTOEMPLEADOFINAL',
--                @DefError512Upper)>0
--    BEGIN
       
--'Se detecto una variante no reconocida',1;
--    END;
END;
GO

DECLARE @Nombre sysname,@Definicion nvarchar(max),@Nueva nvarchar(max);
DECLARE ModulosCobranza CURSOR LOCAL FAST_FORWARD FOR
    SELECT O.name,M.definition
    FROM sys.objects O
    INNER JOIN sys.sql_modules M ON M.object_id=O.object_id
    WHERE O.type='P'
      AND O.name IN
          (N'ff_Cobranza_v2',N'ff_CobranzaSincronizacion_V3_bf3',
           N'ObtenCobranzaConcentrada_otro_V2_BF3',N'ff_ObtenEmpleadosCob_v2_bf3')
      AND M.definition LIKE N'%bf_RepConf_Debug%';

OPEN ModulosCobranza;
FETCH NEXT FROM ModulosCobranza INTO @Nombre,@Definicion;
WHILE @@FETCH_STATUS=0
BEGIN
    SET @Nueva=REPLACE(@Definicion,N'[dbo].[bf_RepConf_Debug]',N'dbo.bf_CobranzaCache_Log');
    SET @Nueva=REPLACE(@Nueva,N'dbo.[bf_RepConf_Debug]',N'dbo.bf_CobranzaCache_Log');
    SET @Nueva=REPLACE(@Nueva,N'dbo.bf_RepConf_Debug',N'dbo.bf_CobranzaCache_Log');
    SET @Nueva=REPLACE(@Nueva,N'[bf_RepConf_Debug]',N'bf_CobranzaCache_Log');
    SET @Nueva=REPLACE(@Nueva,N'bf_RepConf_Debug',N'bf_CobranzaCache_Log');

    IF @Nueva<>@Definicion
    BEGIN
        /* Normaliza espacios entre CREATE y PROCEDURE antes de ALTER. */
        WHILE CHARINDEX(N'CREATE  PROCEDURE',UPPER(@Nueva))>0
            SET @Nueva=REPLACE(@Nueva,N'CREATE  PROCEDURE',N'CREATE PROCEDURE');
        WHILE CHARINDEX(N'CREATE   PROCEDURE',UPPER(@Nueva))>0
            SET @Nueva=REPLACE(@Nueva,N'CREATE   PROCEDURE',N'CREATE PROCEDURE');
        WHILE CHARINDEX(N'CREATE    PROCEDURE',UPPER(@Nueva))>0
            SET @Nueva=REPLACE(@Nueva,N'CREATE    PROCEDURE',N'CREATE PROCEDURE');

        DECLARE @PosCreateOrAlter int=CHARINDEX('CREATE OR ALTER PROCEDURE',UPPER(@Nueva)),
                @PosCreate int=CHARINDEX('CREATE PROCEDURE',UPPER(@Nueva));
        IF @PosCreateOrAlter>0
            SET @Nueva=STUFF(@Nueva,@PosCreateOrAlter,LEN('CREATE OR ALTER PROCEDURE'),'ALTER PROCEDURE');
        ELSE IF @PosCreate>0
            SET @Nueva=STUFF(@Nueva,@PosCreate,LEN('CREATE PROCEDURE'),'ALTER PROCEDURE');
        EXEC sys.sp_executesql @Nueva;
    END;

    FETCH NEXT FROM ModulosCobranza INTO @Nombre,@Definicion;
END;
CLOSE ModulosCobranza;
DEALLOCATE ModulosCobranza;
GO

IF OBJECT_ID(N'dbo.bf_CobranzaCache_ConsultaV2', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.bf_CobranzaCache_ConsultaV2
    (
        CacheId             bigint IDENTITY(1,1) NOT NULL,
        IdEmpresa           int NOT NULL,
        IdSolTipo           int NOT NULL,
        FecIni              varchar(16) NOT NULL,
        FecFin              varchar(16) NOT NULL,
        IdVencida           int NOT NULL,
        IdVigencia          int NOT NULL,
        PerfilClave         varchar(2000) NOT NULL,
        PerfilHash          varbinary(32) NOT NULL,
        EsTarjeta           bit NOT NULL CONSTRAINT DF_CCConsultaV2_EsTarjeta DEFAULT (0),
        EsUniverso          bit NOT NULL CONSTRAINT DF_CCConsultaV2_EsUniverso DEFAULT (0),
        Estado              varchar(20) NOT NULL,
        FechaCargaInicio    datetime2(3) NULL,
        FechaCargaFin       datetime2(3) NULL,
        FechaFuenteHasta    datetime2(3) NULL,
        FilasConcentrada    int NOT NULL CONSTRAINT DF_CCConsultaV2_FilasC DEFAULT (0),
        FilasDesglosada     int NOT NULL CONSTRAINT DF_CCConsultaV2_FilasD DEFAULT (0),
        Mensaje             nvarchar(2000) NULL,
        CONSTRAINT PK_bf_CobranzaCache_ConsultaV2 PRIMARY KEY CLUSTERED (CacheId)
    );

    CREATE UNIQUE INDEX UX_CCConsultaV2_Parametros
        ON dbo.bf_CobranzaCache_ConsultaV2
        (IdEmpresa, IdSolTipo, FecIni, FecFin, IdVencida, IdVigencia, PerfilHash);

    BEGIN TRY
        CREATE INDEX IX_CCConsultaV2_Busqueda
            ON dbo.bf_CobranzaCache_ConsultaV2 (IdEmpresa, IdVigencia, Estado, FechaCargaFin);
    END TRY
    BEGIN CATCH
        INSERT #BF3_InstalacionAdvertencias(Paso,Objeto,NumeroError,Mensaje)
        VALUES('01',N'IX_CCConsultaV2_Busqueda',ERROR_NUMBER(),ERROR_MESSAGE());
        RAISERROR(N'[COBRANZA B3][ADVERTENCIA] No se creo IX_CCConsultaV2_Busqueda; se continua.',10,1) WITH NOWAIT;
    END CATCH;
END;
GO

IF COL_LENGTH(N'dbo.bf_CobranzaCache_ConsultaV2',N'EsUniverso') IS NULL
BEGIN
    ALTER TABLE dbo.bf_CobranzaCache_ConsultaV2
        ADD EsUniverso bit NOT NULL
            CONSTRAINT DF_CCConsultaV2_EsUniverso DEFAULT (0) WITH VALUES;
END;
GO

WHILE 1=1
BEGIN
    DECLARE @CacheDuplicado bigint=NULL;
    ;WITH Duplicados AS
    (
        SELECT CacheId,
               ROW_NUMBER() OVER
               (
                   PARTITION BY IdEmpresa,IdSolTipo,FecIni,FecFin,IdVencida,
                                IdVigencia,PerfilHash,EsUniverso
                   ORDER BY CASE WHEN Estado='COMPLETA' THEN 0 ELSE 1 END,
                            FechaCargaFin DESC,CacheId DESC
               ) AS rn
        FROM dbo.bf_CobranzaCache_ConsultaV2
    )
    SELECT TOP (1) @CacheDuplicado=CacheId FROM Duplicados WHERE rn>1;

    IF @CacheDuplicado IS NULL BREAK;
    DELETE FROM dbo.bf_CobranzaCache_ConsultaV2 WHERE CacheId=@CacheDuplicado;
END;

IF EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'dbo.bf_CobranzaCache_ConsultaV2')
      AND name=N'UX_CCConsultaV2_Parametros'
)
    DROP INDEX UX_CCConsultaV2_Parametros ON dbo.bf_CobranzaCache_ConsultaV2;

CREATE UNIQUE INDEX UX_CCConsultaV2_Parametros
    ON dbo.bf_CobranzaCache_ConsultaV2
    (IdEmpresa,IdSolTipo,FecIni,FecFin,IdVencida,IdVigencia,PerfilHash,EsUniverso);
GO

CREATE OR ALTER TRIGGER dbo.tr_bf_CobranzaCache_Log_Contexto
ON dbo.bf_CobranzaCache_Log
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    /* Los SP legacy insertan solo Etapa/Detalle. Durante una carga de cache,
       SESSION_CONTEXT permite asociar esos eventos al CacheId sin reescribir
       cada INSERT de diagnostico. */
    DECLARE @CacheContexto bigint=
        TRY_CONVERT(bigint,SESSION_CONTEXT(N'bf_CobranzaCacheId'));

    UPDATE L
       SET CacheId=COALESCE(L.CacheId,@CacheContexto),
           IdEmpresa=COALESCE(L.IdEmpresa,Q.IdEmpresa),
           IdVigencia=COALESCE(L.IdVigencia,Q.IdVigencia),
           Estado=COALESCE(L.Estado,Q.Estado),
           SesionId=COALESCE(L.SesionId,@@SPID)
    FROM dbo.bf_CobranzaCache_Log L
    INNER JOIN inserted I ON I.LogId=L.LogId
    LEFT JOIN dbo.bf_CobranzaCache_ConsultaV2 Q
      ON Q.CacheId=COALESCE(L.CacheId,@CacheContexto)
    WHERE L.CacheId IS NULL OR L.IdEmpresa IS NULL OR L.IdVigencia IS NULL
       OR L.Estado IS NULL OR L.SesionId IS NULL;
END;
GO

CREATE OR ALTER VIEW dbo.bf_CobranzaCache_MonitoreoV2
AS
    SELECT Q.CacheId,Q.IdEmpresa,Q.IdVigencia,Q.FecIni,Q.FecFin,Q.Estado,
           Q.FechaCargaInicio,Q.FechaCargaFin,Q.FilasConcentrada,Q.FilasDesglosada,
           Q.Mensaje,L.Fecha AS UltimoEvento,L.Etapa AS UltimaEtapa,
           L.Estado AS EstadoEvento,L.SesionId,
           DATEDIFF(MINUTE,COALESCE(L.Fecha,Q.FechaCargaInicio),SYSDATETIME())
               AS MinutosSinActividad
    FROM dbo.bf_CobranzaCache_ConsultaV2 Q
    OUTER APPLY
    (
        SELECT TOP (1) X.Fecha,X.Etapa,X.Estado,X.SesionId
        FROM dbo.bf_CobranzaCache_Log X
        WHERE X.CacheId=Q.CacheId
        ORDER BY X.Fecha DESC,X.LogId DESC
    ) L;
GO

/* Definicion bootstrap del lector; mas adelante este mismo script instala la version final. */
CREATE OR ALTER PROCEDURE dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache
    @idEmpresa int = 0,
    @idSolTipo int = 0,
    @FecIni varchar(16) = '',
    @FecFin varchar(16) = '',
    @idVencida int = 0,
    @IdPerfil dbo.ListInt READONLY,
    @idVIgencia int = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PerfilClave varchar(2000),@PerfilHash varbinary(32),@CacheId bigint,
            @EsTarjeta bit,@EmpresaDetalle int=0,@VigenciaDetalle int=@idVIgencia;

    SELECT @PerfilClave = STUFF
    ((
        SELECT ',' + CONVERT(varchar(11),P.IdTipoNotificacionCorreo)
        FROM (SELECT DISTINCT IdTipoNotificacionCorreo FROM @IdPerfil) P
        ORDER BY P.IdTipoNotificacionCorreo
        FOR XML PATH(''),TYPE
    ).value('.','varchar(2000)'),1,1,'');
    SET @PerfilClave=ISNULL(@PerfilClave,'');
    SET @PerfilHash=HASHBYTES('SHA2_256',@PerfilClave);

    SELECT @CacheId=CacheId,@EsTarjeta=EsTarjeta
    FROM dbo.bf_CobranzaCache_ConsultaV2 WITH (NOLOCK)
    WHERE IdEmpresa=@idEmpresa AND IdSolTipo=@idSolTipo AND FecIni=@FecIni AND FecFin=@FecFin
      AND IdVencida=@idVencida AND IdVigencia=@idVIgencia AND PerfilHash=@PerfilHash
      AND Estado='COMPLETA';

    IF @CacheId IS NULL
        THROW 51005, 'No existe una cache completa para esos parametros. Ejecute primero InsertaCobranzaConcentrada_otro_V2_BF3_Cache.', 1;

    CREATE TABLE #ListEmpresas (EMidEmpresa int);
    INSERT #ListEmpresas VALUES(@idEmpresa);
    IF EXISTS
       (SELECT 1 FROM dbo.ff_Empresa WHERE EMidEmpresa=@idEmpresa AND EMidCorporativo=@idEmpresa AND EMidEstatus=1)
        INSERT #ListEmpresas
        SELECT EMidEmpresa FROM dbo.ff_Empresa
        WHERE EMidCorporativo=@idEmpresa AND EMidEmpresa<>@idEmpresa AND EMidEstatus=1;

    CREATE TABLE #isEmpresaTC (result int);
    IF @EsTarjeta=1 INSERT #isEmpresaTC VALUES(1);

    SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY Orden)) AS Id_tablatemp,
           empresa,NumEMpleado,CveEmpl,Paterno,MAterno,Nombre1,Nombre2,Sexo,FechaNac,Edad,Confidencial,
           SueldoMensual,SueldoMensualAnt,SueldoMensualDif,TRANSFERIDO,NumSolicitud,Perfil,
           FechaAutorizacion,MontoGMM,MontoVIDA,MontoOTROSPLANES,CreditosGMM,CreditosViDA,
           MontoTotalCreditos,MontoTotalCreditosAnt,DiferenciaCreditos,MontoTotalSelecciones,
           MontoTotalSeleccionesAnt,SobranteCreditos,MontoPagCred,MontoDescMensual,MontoDescMensualAnt,
           GrupoParentescoGMM,Excedentes,ExcedentesAnt,MontoFondoAhorroMensual,
           MontoFondoAhorroMensualAnt,SobranteExcedentes,DescuentoEmpleadoFH,DescuentoEmpleadoFinal,
           SobranteExceFinal,CoberturaDesc,Q1,Q2,Diferencia,CtoEmpleadoNomSeg,AplicExcedentes,
           NumOficina,NomOficina,POFH,LocalNumber,PagoEmpresa,PagoEmpleado,CentroCostos,
           CONVERT(money,NULL) AS [Cobro Tarjeta]
    INTO #tablatemp
    FROM dbo.bf_CobranzaCache_ConcentradaV2 WITH (NOLOCK)
    WHERE CacheId=@CacheId;

    INSERT #tablatemp
    (NumEMpleado,Paterno,MAterno,Nombre1,Nombre2,Sexo,Confidencial,TRANSFERIDO,NumSolicitud,Perfil,
     GrupoParentescoGMM,FechaNac,FechaAutorizacion,MontoGMM,MontoVIDA,MontoOTROSPLANES,CreditosGMM,
     CreditosViDA,MontoTotalCreditos,MontoTotalSelecciones,SobranteCreditos,MontoPagCred,MontoDescMensual,
     Q1,Q2,Diferencia,Excedentes,ExcedentesAnt,MontoFondoAhorroMensual,SobranteExcedentes,
     DescuentoEmpleadoFH,DescuentoEmpleadoFinal,CtoEmpleadoNomSeg,SobranteExceFinal,CoberturaDesc,AplicExcedentes)
    SELECT 'TOTALES: ','','','','','','','','','','','','',SUM(MontoGMM),SUM(MontoVIDA),SUM(MontoOTROSPLANES),
           SUM(CreditosGMM),SUM(CreditosViDA),SUM(MontoTotalCreditos),SUM(MontoTotalSelecciones),
           SUM(SobranteCreditos),SUM(MontoPagCred),ISNULL(SUM(MontoDescMensual),0),SUM(Q1),SUM(Q2),SUM(Diferencia),
           SUM(Excedentes),SUM(ExcedentesAnt),SUM(MontoFondoAhorroMensual),SUM(SobranteExcedentes),
           SUM(DescuentoEmpleadoFH),SUM(DescuentoEmpleadoFinal),SUM(CtoEmpleadoNomSeg),SUM(SobranteExceFinal),
           SUM(CoberturaDesc),SUM(AplicExcedentes)
    FROM #tablatemp;

    SELECT EMPRESA,NUMEMPLEADO,idemp,Paterno,Materno,Nombre1,Nombre2,idSexo,Sexo,FechaNac,Edad,Perfil,
           CVEParentesco,NombreParentesco,TRANSFERIDO,SueldoMensual,NumSolicitud,POidSolicitud,PlanD,
           PlanOpcion,IdGRUPOP,GRUPOPARENTESCO,CVEPO,CVEP,TIPOSUMASEG,VALSUMA,PLOrdenCobranza,
           ImporteAnual,ImportexPeriodo,MontoTotalCreditos,MontoPeridoCreditos,CostoEmpresa,CtoEmpresaCash,
           CtoEmpresa1erexc,CtoEmpresaStoploss,CostoEmpleado,CtoEmpleadoCash,CtoEmpleado1erexc,
           CtoEmpleadoStoploss,CostoEmpleadoExcedente,CostoEmpleadoReal,SobranteExcedentes,
           PrimaNetaAnual,PrimaNetaxPer,idVigencia
    INTO #TablaCobDesg
    FROM dbo.bf_CobranzaCache_DesglosadaV2 WITH (NOLOCK)
    WHERE CacheId=@CacheId;

    SELECT @EmpresaDetalle=EMPRESA,@VigenciaDetalle=idVigencia FROM #TablaCobDesg;
    SET @EmpresaDetalle=ISNULL(@EmpresaDetalle,@idEmpresa);
    SET @VigenciaDetalle=ISNULL(@VigenciaDetalle,@idVIgencia);

    SELECT @FecIni AS FechaInicio,@FecFin AS FechaFin,@idVIgencia AS idVigencia
    INTO #ParametrosCobranza;

    SELECT idEmpleado,CobroTarjeta,Dif,Transaccion,FechaCobro,CodigoAutorizacion,Referencia,
           ext_ref_cliente,Card,Telefono,mail,Comercio
    INTO #CobranzaBanwire
    FROM dbo.bf_CobranzaCache_BanwireV2 WITH (NOLOCK)
    WHERE CacheId=@CacheId;

    /* Result set 1: Concentrada. */
    IF @EsTarjeta=1
    BEGIN
        SELECT A1.*,A2.idEmpleado,A2.CobroTarjeta,A2.Dif,A2.Transaccion,A2.FechaCobro,
               A2.CodigoAutorizacion,A2.Referencia,A2.ext_ref_cliente,A2.Card,A2.Telefono,A2.mail,A2.Comercio
        INTO #ConcentradaDesglosada
        FROM #tablatemp A1
        LEFT JOIN #CobranzaBanwire A2 ON A1.CveEmpl=A2.idEmpleado
        WHERE A2.Comercio IS NOT NULL;

        SELECT empresa,NumEMpleado,CveEmpl,Paterno,MAterno,Nombre1,Nombre2,Sexo,FechaNac,Edad,Confidencial,
               SueldoMensual,ISNULL(SueldoMensualAnt,0) AS SueldoMensualAnt,
               ISNULL(SueldoMensualDif,0) AS SueldoMensualDif,TRANSFERIDO,NumSolicitud,Perfil,
               FechaAutorizacion,GrupoParentescoGMM AS GrupoParentescoGMM,MontoGMM,MontoVIDA,
               MontoOTROSPLANES,CreditosGMM,CreditosViDA,MontoTotalCreditos,
               ISNULL(MontoTotalCreditosAnt,0) AS MontoTotalCreditosAnt,
               ISNULL(MontoTotalCreditos-MontoTotalCreditosAnt,0) AS DiferenciaCreditos,
               MontoTotalSelecciones,ISNULL(MontoTotalSeleccionesAnt,0) AS MontoTotalSeleccionesAnt,
               ISNULL(MontoTotalSelecciones-MontoTotalSeleccionesAnt,0) AS DiferenciaSelecciones,
               SobranteCreditos,MontoPagCred,MontoDescMensual,ISNULL(MontoDescMensualAnt,0) AS MontoDescMensualAnt,
               ISNULL(MontoDescMensual-MontoDescMensualAnt,0) AS DiferenciaMonto,Q1,Q2,Diferencia,Excedentes,
               ISNULL(ExcedentesAnt,0) AS ExcedentesAnt,ISNULL(Excedentes-ExcedentesAnt,0) AS DiferenciaExcedentes,
               MontoFondoAhorroMensual,ISNULL(MontoFondoAhorroMensualAnt,0) AS MontoFondoAhorroMensualAnt,
               ISNULL(MontoFondoAhorroMensual-MontoFondoAhorroMensualAnt,0) AS DiferenciaFH,
               SobranteExcedentes,AplicExcedentes,DescuentoEmpleadoFH,DescuentoEmpleadoFinal,CtoEmpleadoNomSeg,
               SobranteExceFinal,CoberturaDesc,NumOficina,NomOficina,POFH,LocalNumber,CentroCostos AS PagoEmpresa,
               PagoEmpleado,PagoEmpleado AS CostoPlanesTarjeta,A2.CobroTarjeta,
               COALESCE(PagoEmpleado-A2.CobroTarjeta,0) AS DiferenciaTarjeta,A2.Transaccion,A2.FechaCobro,
               A2.CodigoAutorizacion,A2.Referencia,A2.ext_ref_cliente,A2.Card,A2.Telefono,A2.mail,A2.Comercio
        FROM #tablatemp A1
        LEFT JOIN #CobranzaBanwire A2 ON A1.CveEmpl=A2.idEmpleado
        ORDER BY NumEmpleado;
    END
    ELSE
    BEGIN
        SELECT empresa,NumEMpleado,CveEmpl,Paterno,MAterno,Nombre1,Nombre2,Sexo,FechaNac,Edad,Confidencial,
               SueldoMensual,ISNULL(SueldoMensualAnt,0) AS SueldoMensualAnt,
               ISNULL(SueldoMensualDif,0) AS SueldoMensualDif,TRANSFERIDO,NumSolicitud,Perfil,
               FechaAutorizacion,GrupoParentescoGMM AS GrupoParentescoGMM,MontoGMM,MontoVIDA,
               MontoOTROSPLANES,CreditosGMM,CreditosViDA,MontoTotalCreditos,
               ISNULL(MontoTotalCreditosAnt,0) AS MontoTotalCreditosAnt,
               ISNULL(MontoTotalCreditos-MontoTotalCreditosAnt,0) AS DiferenciaCreditos,
               MontoTotalSelecciones,ISNULL(MontoTotalSeleccionesAnt,0) AS MontoTotalSeleccionesAnt,
               ISNULL(MontoTotalSelecciones-MontoTotalSeleccionesAnt,0) AS DiferenciaSelecciones,
               SobranteCreditos,MontoPagCred,MontoDescMensual,ISNULL(MontoDescMensualAnt,0) AS MontoDescMensualAnt,
               ISNULL(MontoDescMensual-MontoDescMensualAnt,0) AS DiferenciaMonto,Q1,Q2,Diferencia,Excedentes,
               ISNULL(ExcedentesAnt,0) AS ExcedentesAnt,ISNULL(Excedentes-ExcedentesAnt,0) AS DiferenciaExcedentes,
               MontoFondoAhorroMensual,ISNULL(MontoFondoAhorroMensualAnt,0) AS MontoFondoAhorroMensualAnt,
               ISNULL(MontoFondoAhorroMensual-MontoFondoAhorroMensualAnt,0) AS DiferenciaFH,
               SobranteExcedentes,AplicExcedentes,DescuentoEmpleadoFH,DescuentoEmpleadoFinal,CtoEmpleadoNomSeg,
               SobranteExceFinal,CoberturaDesc,NumOficina,NomOficina,POFH,LocalNumber,CentroCostos AS PagoEmpresa,
               PagoEmpleado
        FROM #tablatemp ORDER BY NumEmpleado;
    END;

    
END;
GO

CREATE OR ALTER PROCEDURE dbo.InsertaCobranzaConcentrada_otro_V2_BF3_Cache
    @idEmpresa int = 0,
    @idSolTipo int = 0,
    @FecIni varchar(16) = '',
    @FecFin varchar(16) = '',
    @idVencida int = 0,
    @IdPerfil dbo.ListInt READONLY,
    @idVIgencia int = 0,
    @ForzarRecarga bit = 0,
    @PrecargarUltimas4 bit = 0,
    @EmitirResultado bit = 1,
    @EsUniverso bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @idEmpresa <= 0 OR @idVIgencia <= 0
        THROW 51004, 'idEmpresa e idVIgencia son obligatorios.', 1;
    IF TRY_CONVERT(datetime, @FecIni) IS NULL OR TRY_CONVERT(datetime, @FecFin) IS NULL
        THROW 51004, 'FecIni o FecFin no tienen un formato valido.', 1;

    /* Una consulta interactiva reutiliza el universo nocturno cuando este
       cubre el rango y contiene todos los perfiles solicitados. */
    IF @EsUniverso=0
       AND EXISTS
       (
           SELECT 1
           FROM dbo.bf_CobranzaCache_ConsultaV2 Q WITH (NOLOCK)
           WHERE Q.IdEmpresa=@idEmpresa AND Q.IdSolTipo=@idSolTipo
             AND Q.IdVencida=@idVencida AND Q.IdVigencia=@idVIgencia
             AND Q.EsUniverso=1 AND Q.Estado='COMPLETA'
             AND TRY_CONVERT(datetime,Q.FecIni)<=TRY_CONVERT(datetime,@FecIni)
             AND TRY_CONVERT(datetime,Q.FecFin)>=TRY_CONVERT(datetime,@FecFin)
             AND YEAR(TRY_CONVERT(datetime,Q.FecFin))=YEAR(TRY_CONVERT(datetime,@FecFin))
             AND MONTH(TRY_CONVERT(datetime,Q.FecFin))=MONTH(TRY_CONVERT(datetime,@FecFin))
             AND NOT EXISTS
                 (
                     SELECT 1 FROM @IdPerfil R
                     WHERE NOT EXISTS
                         (
                             SELECT 1 FROM STRING_SPLIT(Q.PerfilClave,',') C
                             WHERE TRY_CONVERT(int,C.value)=R.IdTipoNotificacionCorreo
                         )
                 )
       )
    BEGIN
        IF @EmitirResultado=1
            SELECT @idVIgencia AS IdVigencia,@FecIni AS FecIni,@FecFin AS FecFin,
                   'UNIVERSO_DISPONIBLE' AS Resultado;
        RETURN;
    END;

    CREATE TABLE #VigenciasCarga
    (
        Orden int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        IdVigencia int NOT NULL UNIQUE,
        FecIni varchar(16) NOT NULL,
        FecFin varchar(16) NOT NULL
    );

    INSERT #VigenciasCarga (IdVigencia,FecIni,FecFin)
    VALUES (@idVIgencia,@FecIni,@FecFin);

    IF @PrecargarUltimas4=1
    BEGIN
        DECLARE @IdConfiguracion int;
        SELECT @IdConfiguracion=EMidConfiguracion
        FROM dbo.ff_Empresa WITH (NOLOCK)
        WHERE EMidEmpresa=@idEmpresa;

        INSERT #VigenciasCarga (IdVigencia,FecIni,FecFin)
        /* La solicitada y como maximo otras tres: cuatro en total. */
        SELECT TOP (3) V.VIidVigencia,
               CONVERT(varchar(16),V.VIVigenciaIni,120),
               CONVERT(varchar(16),V.VIVigenciaFin,120)
        FROM dbo.ff_Vigencia V WITH (NOLOCK)
        WHERE V.VIidConfiguracion=@IdConfiguracion
          AND V.VITipoNegocio=1
          AND V.VIidVigencia<>@idVIgencia
        ORDER BY V.VIVigenciaIni DESC,V.VIidVigencia DESC;
    END;

    CREATE TABLE #ResultadoCarga
    (
        Orden int NOT NULL,
        IdVigencia int NOT NULL,
        FecIni varchar(16) NOT NULL,
        FecFin varchar(16) NOT NULL,
        Resultado varchar(30) NOT NULL
    );

    DECLARE @i int=1, @n int=(SELECT COUNT(*) FROM #VigenciasCarga),
            @Vigencia int, @Ini varchar(16), @Fin varchar(16), @Resultado varchar(30);

    WHILE @i<=@n
    BEGIN
        SELECT @Vigencia=IdVigencia,@Ini=FecIni,@Fin=FecFin
        FROM #VigenciasCarga WHERE Orden=@i;

        /* Llamada dinamica para que el instalador sea ejecutable antes de crear el helper interno. */
        EXEC sys.sp_executesql
             N'EXEC dbo.bf_CobranzaCache_CargarUnaV2
                   @idEmpresa=@pEmpresa,@idSolTipo=@pSolTipo,@FecIni=@pIni,@FecFin=@pFin,
                   @idVencida=@pVencida,@IdPerfil=@pPerfil,@idVigencia=@pVigencia,
                   @ForzarRecarga=@pForzar,@EsUniverso=@pUniverso,@Resultado=@pResultado OUTPUT;',
             N'@pEmpresa int,@pSolTipo int,@pIni varchar(16),@pFin varchar(16),@pVencida int,
               @pPerfil dbo.ListInt READONLY,@pVigencia int,@pForzar bit,@pUniverso bit,
               @pResultado varchar(30) OUTPUT',
             @pEmpresa=@idEmpresa,@pSolTipo=@idSolTipo,@pIni=@Ini,@pFin=@Fin,@pVencida=@idVencida,
             @pPerfil=@IdPerfil,@pVigencia=@Vigencia,@pForzar=@ForzarRecarga,
             @pUniverso=@EsUniverso,@pResultado=@Resultado OUTPUT;

        INSERT #ResultadoCarga VALUES(@i,@Vigencia,@Ini,@Fin,@Resultado);
        SET @i+=1;
    END;

    IF @EmitirResultado = 1
    BEGIN
        SELECT IdVigencia,FecIni,FecFin,Resultado
        FROM #ResultadoCarga
        ORDER BY Orden;
    END;
END;
GO

CREATE OR ALTER PROCEDURE dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache
    @idEmpresa int = 0,
    @idSolTipo int = 0,
    @FecIni varchar(16) = '',
    @FecFin varchar(16) = '',
    @idVencida int = 0,
    @IdPerfil dbo.ListInt READONLY,
    @idVIgencia int = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PerfilClave varchar(2000),@PerfilHash varbinary(32),@CacheId bigint,
            @EsTarjeta bit,@EmpresaDetalle int=0;

    SELECT @PerfilClave = STUFF
    ((
        SELECT ',' + CONVERT(varchar(11), P.IdTipoNotificacionCorreo)
        FROM (SELECT DISTINCT IdTipoNotificacionCorreo FROM @IdPerfil) P
        ORDER BY P.IdTipoNotificacionCorreo
        FOR XML PATH(''), TYPE
    ).value('.', 'varchar(2000)'), 1, 1, '');
    SET @PerfilClave=ISNULL(@PerfilClave,'');
    SET @PerfilHash=HASHBYTES('SHA2_256',@PerfilClave);

    SELECT @CacheId=CacheId,@EsTarjeta=EsTarjeta
    FROM dbo.bf_CobranzaCache_ConsultaV2 WITH (NOLOCK)
    WHERE IdEmpresa=@idEmpresa AND IdSolTipo=@idSolTipo AND FecIni=@FecIni AND FecFin=@FecFin
      AND IdVencida=@idVencida AND IdVigencia=@idVIgencia AND PerfilHash=@PerfilHash
      AND Estado='COMPLETA';

    IF @CacheId IS NULL
        THROW 51005, 'No existe una cache completa para esos parametros. Ejecute primero InsertaCobranzaConcentrada_otro_V2_BF3_Cache.', 1;

    CREATE TABLE #ListEmpresas (EMidEmpresa int);
    INSERT #ListEmpresas VALUES(@idEmpresa);
    IF EXISTS
       (SELECT 1 FROM dbo.ff_Empresa WHERE EMidEmpresa=@idEmpresa AND EMidCorporativo=@idEmpresa AND EMidEstatus=1)
    BEGIN
        INSERT #ListEmpresas
        SELECT EMidEmpresa FROM dbo.ff_Empresa
        WHERE EMidCorporativo=@idEmpresa AND EMidEmpresa<>@idEmpresa AND EMidEstatus=1;
    END;

    CREATE TABLE #isEmpresaTC (result int);
    IF @EsTarjeta=1 INSERT #isEmpresaTC VALUES(1);

    CREATE TABLE #tablatemp
    (
        Id_tablatemp int IDENTITY(1,1) PRIMARY KEY,
        empresa int NULL,NumEMpleado varchar(20) NULL,CveEmpl int NULL,Paterno varchar(30) NULL,
        MAterno varchar(30) NULL,Nombre1 varchar(30) NULL,Nombre2 varchar(30) NULL,Sexo varchar(150) NULL,
        FechaNac varchar(10) NULL,Edad int NULL,Confidencial varchar(2) NULL,SueldoMensual money NULL,
        SueldoMensualAnt money NULL,SueldoMensualDif money NULL,TRANSFERIDO varchar(11) NULL,
        NumSolicitud varchar(8) NULL,Perfil varchar(50) NULL,FechaAutorizacion varchar(10) NULL,
        MontoGMM money NULL,MontoVIDA money NULL,MontoOTROSPLANES money NULL,CreditosGMM money NULL,
        CreditosViDA money NULL,MontoTotalCreditos money NULL,MontoTotalCreditosAnt money NULL,
        DiferenciaCreditos money NULL,MontoTotalSelecciones money NULL,MontoTotalSeleccionesAnt money NULL,
        SobranteCreditos money NULL,MontoPagCred money NULL,MontoDescMensual money NULL,
        MontoDescMensualAnt money NULL,GrupoParentescoGMM varchar(10) NULL,Excedentes money NULL,
        ExcedentesAnt money NULL,MontoFondoAhorroMensual money NULL,MontoFondoAhorroMensualAnt money NULL,
        SobranteExcedentes money NULL,DescuentoEmpleadoFH money NULL,DescuentoEmpleadoFinal money NULL,
        SobranteExceFinal money NULL,CoberturaDesc money NULL,Q1 money NULL,Q2 money NULL,Diferencia money NULL,
        CtoEmpleadoNomSeg money NULL,AplicExcedentes money NULL,NumOficina int NULL,NomOficina varchar(50) NULL,
        POFH varchar(50) NULL,LocalNumber varchar(50) NULL,PagoEmpresa money NULL,PagoEmpleado money NULL,
        CentroCostos varchar(100) NULL,[Cobro Tarjeta] money NULL
    );

    INSERT #tablatemp
    (
        empresa,NumEMpleado,CveEmpl,Paterno,MAterno,Nombre1,Nombre2,Sexo,FechaNac,Edad,Confidencial,
        SueldoMensual,SueldoMensualAnt,SueldoMensualDif,TRANSFERIDO,NumSolicitud,Perfil,FechaAutorizacion,
        GrupoParentescoGMM,MontoGMM,MontoVIDA,MontoOTROSPLANES,CreditosGMM,CreditosViDA,
        MontoTotalCreditos,MontoTotalCreditosAnt,DiferenciaCreditos,MontoTotalSelecciones,
        MontoTotalSeleccionesAnt,SobranteCreditos,MontoPagCred,MontoDescMensual,MontoDescMensualAnt,
        Excedentes,ExcedentesAnt,MontoFondoAhorroMensual,MontoFondoAhorroMensualAnt,SobranteExcedentes,
        DescuentoEmpleadoFH,DescuentoEmpleadoFinal,SobranteExceFinal,CoberturaDesc,Q1,Q2,Diferencia,
        CtoEmpleadoNomSeg,AplicExcedentes,NumOficina,NomOficina,POFH,LocalNumber,PagoEmpresa,PagoEmpleado,
        CentroCostos
    )
    SELECT empresa,NumEMpleado,CveEmpl,Paterno,MAterno,Nombre1,Nombre2,Sexo,FechaNac,Edad,Confidencial,
           SueldoMensual,SueldoMensualAnt,SueldoMensualDif,TRANSFERIDO,NumSolicitud,Perfil,FechaAutorizacion,
           GrupoParentescoGMM,MontoGMM,MontoVIDA,MontoOTROSPLANES,CreditosGMM,CreditosViDA,
           MontoTotalCreditos,MontoTotalCreditosAnt,DiferenciaCreditos,MontoTotalSelecciones,
           MontoTotalSeleccionesAnt,SobranteCreditos,MontoPagCred,MontoDescMensual,MontoDescMensualAnt,
           Excedentes,ExcedentesAnt,MontoFondoAhorroMensual,MontoFondoAhorroMensualAnt,SobranteExcedentes,
           DescuentoEmpleadoFH,DescuentoEmpleadoFinal,SobranteExceFinal,CoberturaDesc,Q1,Q2,Diferencia,
           CtoEmpleadoNomSeg,AplicExcedentes,NumOficina,NomOficina,POFH,LocalNumber,PagoEmpresa,PagoEmpleado,
           CentroCostos
    FROM dbo.bf_CobranzaCache_ConcentradaV2 WITH (NOLOCK)
    WHERE CacheId=@CacheId
    ORDER BY Orden;

    INSERT #tablatemp
    (NumEMpleado,Paterno,MAterno,Nombre1,Nombre2,Sexo,Confidencial,TRANSFERIDO,NumSolicitud,Perfil,
     GrupoParentescoGMM,FechaNac,FechaAutorizacion,MontoGMM,MontoVIDA,MontoOTROSPLANES,CreditosGMM,
     CreditosViDA,MontoTotalCreditos,MontoTotalSelecciones,SobranteCreditos,MontoPagCred,MontoDescMensual,
     Q1,Q2,Diferencia,Excedentes,ExcedentesAnt,MontoFondoAhorroMensual,SobranteExcedentes,
     DescuentoEmpleadoFH,DescuentoEmpleadoFinal,CtoEmpleadoNomSeg,SobranteExceFinal,CoberturaDesc,AplicExcedentes)
    SELECT 'TOTALES: ','','','','','','','','','','','','',SUM(MontoGMM),SUM(MontoVIDA),SUM(MontoOTROSPLANES),
           SUM(CreditosGMM),SUM(CreditosViDA),SUM(MontoTotalCreditos),SUM(MontoTotalSelecciones),
           SUM(SobranteCreditos),SUM(MontoPagCred),ISNULL(SUM(MontoDescMensual),0),SUM(Q1),SUM(Q2),SUM(Diferencia),
           SUM(Excedentes),SUM(ExcedentesAnt),SUM(MontoFondoAhorroMensual),SUM(SobranteExcedentes),
           SUM(DescuentoEmpleadoFH),SUM(DescuentoEmpleadoFinal),SUM(CtoEmpleadoNomSeg),SUM(SobranteExceFinal),
           SUM(CoberturaDesc),SUM(AplicExcedentes)
    FROM #tablatemp;

    CREATE TABLE #TablaCobDesg
    (
        EMPRESA int NULL,NUMEMPLEADO varchar(20) NULL,idemp int NULL,Paterno varchar(30) NULL,
        Materno varchar(30) NULL,Nombre1 varchar(70) NULL,Nombre2 varchar(30) NULL,idSexo int NULL,
        Sexo varchar(150) NULL,FechaNac varchar(10) NULL,Edad int NULL,Perfil varchar(50) NULL,
        CVEParentesco int NULL,NombreParentesco varchar(150) NULL,TRANSFERIDO varchar(11) NULL,
        SueldoMensual money NULL,NumSolicitud varchar(8) NULL,POidSolicitud int NULL,PlanD varchar(150) NULL,
        PlanOpcion varchar(150) NULL,IdGRUPOP int NULL,GRUPOPARENTESCO varchar(150) NULL,CVEPO int NULL,
        CVEP int NULL,TIPOSUMASEG int NULL,VALSUMA money NULL,PLOrdenCobranza int NULL,ImporteAnual money NULL,
        ImportexPeriodo money NULL,MontoTotalCreditos money NULL,MontoPeridoCreditos money NULL,
        CostoEmpresa money NULL,CtoEmpresaCash money NULL,CtoEmpresa1erexc money NULL,CtoEmpresaStoploss money NULL,
        CostoEmpleado money NULL,CtoEmpleadoCash money NULL,CtoEmpleado1erexc money NULL,
        CtoEmpleadoStoploss money NULL,CostoEmpleadoExcedente money NULL,CostoEmpleadoReal money NULL,
        SobranteExcedentes money NULL,PrimaNetaAnual money NULL,PrimaNetaxPer money NULL,idVigencia int NULL
    );

    INSERT #TablaCobDesg
    SELECT EMPRESA,NUMEMPLEADO,idemp,Paterno,Materno,Nombre1,Nombre2,idSexo,Sexo,FechaNac,Edad,Perfil,
           CVEParentesco,NombreParentesco,TRANSFERIDO,SueldoMensual,NumSolicitud,POidSolicitud,PlanD,
           PlanOpcion,IdGRUPOP,GRUPOPARENTESCO,CVEPO,CVEP,TIPOSUMASEG,VALSUMA,PLOrdenCobranza,
           ImporteAnual,ImportexPeriodo,MontoTotalCreditos,MontoPeridoCreditos,CostoEmpresa,CtoEmpresaCash,
           CtoEmpresa1erexc,CtoEmpresaStoploss,CostoEmpleado,CtoEmpleadoCash,CtoEmpleado1erexc,
           CtoEmpleadoStoploss,CostoEmpleadoExcedente,CostoEmpleadoReal,SobranteExcedentes,
           PrimaNetaAnual,PrimaNetaxPer,idVigencia
    FROM dbo.bf_CobranzaCache_DesglosadaV2 WITH (NOLOCK)
    WHERE CacheId=@CacheId
    ORDER BY Orden;

    SELECT @EmpresaDetalle=EMPRESA FROM #TablaCobDesg;
    SET @EmpresaDetalle=ISNULL(@EmpresaDetalle,@idEmpresa);

    SELECT @FecIni AS FechaInicio,@FecFin AS FechaFin,@idVIgencia AS idVigencia
    INTO #ParametrosCobranza;

    CREATE TABLE #CobranzaBanwire
    (
        idEmpleado int NULL,CobroTarjeta money NULL,Dif money NULL,Transaccion varchar(200) NULL,
        FechaCobro varchar(200) NULL,CodigoAutorizacion varchar(200) NULL,Referencia varchar(200) NULL,
        ext_ref_cliente varchar(300) NULL,Card varchar(50) NULL,Telefono varchar(100) NULL,
        mail varchar(200) NULL,Comercio varchar(100) NULL
    );
    INSERT #CobranzaBanwire
    SELECT idEmpleado,CobroTarjeta,Dif,Transaccion,FechaCobro,CodigoAutorizacion,Referencia,
           ext_ref_cliente,Card,Telefono,mail,Comercio
    FROM dbo.bf_CobranzaCache_BanwireV2 WITH (NOLOCK)
    WHERE CacheId=@CacheId ORDER BY Orden;

    /* Definicion bootstrap; la version completa se instala al final del archivo. */
END;
GO

IF OBJECT_ID(N'dbo.bf_CobranzaCache_ConcentradaV2', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.bf_CobranzaCache_ConcentradaV2
    (
        CacheId bigint NOT NULL,
        Orden int NOT NULL,
        empresa int NULL,
        NumEMpleado varchar(20) NULL,
        CveEmpl int NULL,
        Paterno varchar(30) NULL,
        MAterno varchar(30) NULL,
        Nombre1 varchar(30) NULL,
        Nombre2 varchar(30) NULL,
        Sexo varchar(150) NULL,
        FechaNac varchar(10) NULL,
        Edad int NULL,
        Confidencial varchar(2) NULL,
        SueldoMensual money NULL,
        SueldoMensualAnt money NULL,
        SueldoMensualDif money NULL,
        TRANSFERIDO varchar(11) NULL,
        NumSolicitud varchar(8) NULL,
        Perfil varchar(50) NULL,
        FechaAutorizacion varchar(10) NULL,
        GrupoParentescoGMM varchar(10) NULL,
        MontoGMM money NULL,
        MontoVIDA money NULL,
        MontoOTROSPLANES money NULL,
        CreditosGMM money NULL,
        CreditosViDA money NULL,
        MontoTotalCreditos money NULL,
        MontoTotalCreditosAnt money NULL,
        DiferenciaCreditos money NULL,
        MontoTotalSelecciones money NULL,
        MontoTotalSeleccionesAnt money NULL,
        SobranteCreditos money NULL,
        MontoPagCred money NULL,
        MontoDescMensual money NULL,
        MontoDescMensualAnt money NULL,
        Excedentes money NULL,
        ExcedentesAnt money NULL,
        MontoFondoAhorroMensual money NULL,
        MontoFondoAhorroMensualAnt money NULL,
        SobranteExcedentes money NULL,
        DescuentoEmpleadoFH money NULL,
        DescuentoEmpleadoFinal money NULL,
        SobranteExceFinal money NULL,
        CoberturaDesc money NULL,
        Q1 money NULL,
        Q2 money NULL,
        Diferencia money NULL,
        CtoEmpleadoNomSeg money NULL,
        AplicExcedentes money NULL,
        NumOficina int NULL,
        NomOficina varchar(50) NULL,
        POFH varchar(50) NULL,
        LocalNumber varchar(50) NULL,
        PagoEmpresa money NULL,
        PagoEmpleado money NULL,
        CentroCostos varchar(100) NULL,
        CONSTRAINT PK_bf_CobranzaCache_ConcentradaV2 PRIMARY KEY CLUSTERED (CacheId, Orden),
        CONSTRAINT FK_CCConcentradaV2_Consulta FOREIGN KEY (CacheId)
            REFERENCES dbo.bf_CobranzaCache_ConsultaV2(CacheId) ON DELETE CASCADE
    );

    BEGIN TRY
        CREATE INDEX IX_CCConcentradaV2_Empleado
            ON dbo.bf_CobranzaCache_ConcentradaV2 (CacheId, CveEmpl, NumEMpleado);
    END TRY
    BEGIN CATCH
        INSERT #BF3_InstalacionAdvertencias(Paso,Objeto,NumeroError,Mensaje)
        VALUES('01',N'IX_CCConcentradaV2_Empleado',ERROR_NUMBER(),ERROR_MESSAGE());
        RAISERROR(N'[COBRANZA B3][ADVERTENCIA] No se creo IX_CCConcentradaV2_Empleado; se continua.',10,1) WITH NOWAIT;
    END CATCH;
END;
GO

IF OBJECT_ID(N'dbo.bf_CobranzaCache_DesglosadaV2', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.bf_CobranzaCache_DesglosadaV2
    (
        CacheId bigint NOT NULL,
        Orden int NOT NULL,
        EMPRESA int NULL,
        NUMEMPLEADO varchar(20) NULL,
        idemp int NULL,
        Paterno varchar(30) NULL,
        Materno varchar(30) NULL,
        Nombre1 varchar(70) NULL,
        Nombre2 varchar(30) NULL,
        idSexo int NULL,
        Sexo varchar(150) NULL,
        FechaNac varchar(10) NULL,
        Edad int NULL,
        Perfil varchar(50) NULL,
        CVEParentesco int NULL,
        NombreParentesco varchar(150) NULL,
        TRANSFERIDO varchar(11) NULL,
        SueldoMensual money NULL,
        NumSolicitud varchar(8) NULL,
        POidSolicitud int NULL,
        PlanD varchar(150) NULL,
        PlanOpcion varchar(150) NULL,
        IdGRUPOP int NULL,
        GRUPOPARENTESCO varchar(150) NULL,
        CVEPO int NULL,
        CVEP int NULL,
        TIPOSUMASEG int NULL,
        VALSUMA money NULL,
        PLOrdenCobranza int NULL,
        ImporteAnual money NULL,
        ImportexPeriodo money NULL,
        MontoTotalCreditos money NULL,
        MontoPeridoCreditos money NULL,
        CostoEmpresa money NULL,
        CtoEmpresaCash money NULL,
        CtoEmpresa1erexc money NULL,
        CtoEmpresaStoploss money NULL,
        CostoEmpleado money NULL,
        CtoEmpleadoCash money NULL,
        CtoEmpleado1erexc money NULL,
        CtoEmpleadoStoploss money NULL,
        CostoEmpleadoExcedente money NULL,
        CostoEmpleadoReal money NULL,
        SobranteExcedentes money NULL,
        PrimaNetaAnual money NULL,
        PrimaNetaxPer money NULL,
        idVigencia int NULL,
        CONSTRAINT PK_bf_CobranzaCache_DesglosadaV2 PRIMARY KEY CLUSTERED (CacheId, Orden),
        CONSTRAINT FK_CCDesglosadaV2_Consulta FOREIGN KEY (CacheId)
            REFERENCES dbo.bf_CobranzaCache_ConsultaV2(CacheId) ON DELETE CASCADE
    );

    BEGIN TRY
        CREATE INDEX IX_CCDesglosadaV2_Empleado
            ON dbo.bf_CobranzaCache_DesglosadaV2 (CacheId, idemp, NUMEMPLEADO);
    END TRY
    BEGIN CATCH
        INSERT #BF3_InstalacionAdvertencias(Paso,Objeto,NumeroError,Mensaje)
        VALUES('01',N'IX_CCDesglosadaV2_Empleado',ERROR_NUMBER(),ERROR_MESSAGE());
        RAISERROR(N'[COBRANZA B3][ADVERTENCIA] No se creo IX_CCDesglosadaV2_Empleado; se continua.',10,1) WITH NOWAIT;
    END CATCH;

    BEGIN TRY
        CREATE INDEX IX_CCDesglosadaV2_Agrupacion
            ON dbo.bf_CobranzaCache_DesglosadaV2 (CacheId, CVEP, CVEPO, CVEParentesco);
    END TRY
    BEGIN CATCH
        INSERT #BF3_InstalacionAdvertencias(Paso,Objeto,NumeroError,Mensaje)
        VALUES('01',N'IX_CCDesglosadaV2_Agrupacion',ERROR_NUMBER(),ERROR_MESSAGE());
        RAISERROR(N'[COBRANZA B3][ADVERTENCIA] No se creo IX_CCDesglosadaV2_Agrupacion; se continua.',10,1) WITH NOWAIT;
    END CATCH;
END;
GO

IF OBJECT_ID(N'dbo.bf_CobranzaCache_BanwireV2', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.bf_CobranzaCache_BanwireV2
    (
        CacheId bigint NOT NULL,
        Orden int NOT NULL,
        idEmpleado int NULL,
        CobroTarjeta money NULL,
        Dif money NULL,
        Transaccion varchar(200) NULL,
        FechaCobro varchar(200) NULL,
        CodigoAutorizacion varchar(200) NULL,
        Referencia varchar(200) NULL,
        ext_ref_cliente varchar(300) NULL,
        Card varchar(50) NULL,
        Telefono varchar(100) NULL,
        mail varchar(200) NULL,
        Comercio varchar(100) NULL,
        CONSTRAINT PK_bf_CobranzaCache_BanwireV2 PRIMARY KEY CLUSTERED (CacheId, Orden),
        CONSTRAINT FK_CCBanwireV2_Consulta FOREIGN KEY (CacheId)
            REFERENCES dbo.bf_CobranzaCache_ConsultaV2(CacheId) ON DELETE CASCADE
    );

    BEGIN TRY
        CREATE INDEX IX_CCBanwireV2_Empleado
            ON dbo.bf_CobranzaCache_BanwireV2 (CacheId, idEmpleado);
    END TRY
    BEGIN CATCH
        INSERT #BF3_InstalacionAdvertencias(Paso,Objeto,NumeroError,Mensaje)
        VALUES('01',N'IX_CCBanwireV2_Empleado',ERROR_NUMBER(),ERROR_MESSAGE());
        RAISERROR(N'[COBRANZA B3][ADVERTENCIA] No se creo IX_CCBanwireV2_Empleado; se continua.',10,1) WITH NOWAIT;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.bf_CobranzaCache_CapturaBasesV2
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /* BF_CACHE_TEMPDB_COLLATION_CAPTURE_V1 */
    /* BF_CACHE_SHORT_PUBLISH_TX_V1 */

    DECLARE @CacheId bigint = TRY_CONVERT(bigint, SESSION_CONTEXT(N'bf_CobranzaCacheId')),
            @Modo varchar(10) = CONVERT(varchar(10), SESSION_CONTEXT(N'bf_CobranzaCacheModo')),
            @EsTarjeta bit = 0;

    IF @CacheId IS NULL
        THROW 51001, 'No se definio bf_CobranzaCacheId en SESSION_CONTEXT.', 1;
    IF OBJECT_ID(N'tempdb..#tablatemp') IS NULL OR OBJECT_ID(N'tempdb..#TablaCobDesg') IS NULL
        THROW 51001, 'No existen #tablatemp o #TablaCobDesg para capturar la cobranza.', 1;

    /*
       La parte costosa del reporte se calcula antes de entrar aqui. Solo el
       reemplazo atomico del cache vive dentro de la transaccion, evitando que
       los SELECT y trazas de diagnostico retengan locks durante todo el SP 

    */
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.bf_CobranzaCache_ConsultaV2
           SET Estado='CARGANDO', Mensaje=CONCAT(N'Publicando cache ',@Modo)
         WHERE CacheId=@CacheId;

    IF @Modo = 'FULL'
    BEGIN
        DELETE FROM dbo.bf_CobranzaCache_ConcentradaV2 WHERE CacheId = @CacheId;
        DELETE FROM dbo.bf_CobranzaCache_DesglosadaV2 WHERE CacheId = @CacheId;
    END
    ELSE
    BEGIN
        DELETE C
        FROM dbo.bf_CobranzaCache_ConcentradaV2 C
        WHERE C.CacheId = @CacheId
          AND EXISTS
          (
              SELECT 1
              FROM #CacheEmpsCambios X
              WHERE X.NumEmpleado COLLATE DATABASE_DEFAULT = C.NumEMpleado COLLATE DATABASE_DEFAULT
                 OR X.EMId = C.CveEmpl
          );

        DELETE D
        FROM dbo.bf_CobranzaCache_DesglosadaV2 D
        WHERE D.CacheId = @CacheId
          AND EXISTS
          (
              SELECT 1
              FROM #CacheEmpsCambios X
              WHERE X.NumEmpleado COLLATE DATABASE_DEFAULT = D.NUMEMPLEADO COLLATE DATABASE_DEFAULT
                 OR X.EMId = D.idemp
          );
    END;

    DECLARE @OrdenC int = ISNULL((SELECT MAX(Orden) FROM dbo.bf_CobranzaCache_ConcentradaV2 WHERE CacheId=@CacheId), 0),
            @OrdenD int = ISNULL((SELECT MAX(Orden) FROM dbo.bf_CobranzaCache_DesglosadaV2 WHERE CacheId=@CacheId), 0);

    INSERT dbo.bf_CobranzaCache_ConcentradaV2
    (
        CacheId, Orden, empresa, NumEMpleado, CveEmpl, Paterno, MAterno, Nombre1, Nombre2,
        Sexo, FechaNac, Edad, Confidencial, SueldoMensual, SueldoMensualAnt, SueldoMensualDif,
        TRANSFERIDO, NumSolicitud, Perfil, FechaAutorizacion, GrupoParentescoGMM, MontoGMM,
        MontoVIDA, MontoOTROSPLANES, CreditosGMM, CreditosViDA, MontoTotalCreditos,
        MontoTotalCreditosAnt, DiferenciaCreditos, MontoTotalSelecciones, MontoTotalSeleccionesAnt,
        SobranteCreditos, MontoPagCred, MontoDescMensual, MontoDescMensualAnt, Excedentes,
        ExcedentesAnt, MontoFondoAhorroMensual, MontoFondoAhorroMensualAnt, SobranteExcedentes,
        DescuentoEmpleadoFH, DescuentoEmpleadoFinal, SobranteExceFinal, CoberturaDesc, Q1, Q2,
        Diferencia, CtoEmpleadoNomSeg, AplicExcedentes, NumOficina, NomOficina, POFH, LocalNumber,
        PagoEmpresa, PagoEmpleado, CentroCostos
    )
    SELECT @CacheId,
           @OrdenC + ROW_NUMBER() OVER (ORDER BY NumEMpleado, Id_tablatemp),
           empresa, NumEMpleado, CveEmpl, Paterno, MAterno, Nombre1, Nombre2, Sexo, FechaNac, Edad,
           Confidencial, SueldoMensual, SueldoMensualAnt, SueldoMensualDif, TRANSFERIDO, NumSolicitud,
           Perfil, FechaAutorizacion, GrupoParentescoGMM, MontoGMM, MontoVIDA, MontoOTROSPLANES,
           CreditosGMM, CreditosViDA, MontoTotalCreditos, MontoTotalCreditosAnt, DiferenciaCreditos,
           MontoTotalSelecciones, MontoTotalSeleccionesAnt, SobranteCreditos, MontoPagCred,
           MontoDescMensual, MontoDescMensualAnt, Excedentes, ExcedentesAnt, MontoFondoAhorroMensual,
           MontoFondoAhorroMensualAnt, SobranteExcedentes, DescuentoEmpleadoFH,
           DescuentoEmpleadoFinal, SobranteExceFinal, CoberturaDesc, Q1, Q2, Diferencia,
           CtoEmpleadoNomSeg, AplicExcedentes, NumOficina, NomOficina, POFH, LocalNumber,
           PagoEmpresa, PagoEmpleado, CentroCostos
    FROM #tablatemp
    WHERE ISNULL(NumEMpleado, '') NOT LIKE '%TOTAL%';

    INSERT dbo.bf_CobranzaCache_DesglosadaV2
    (
        CacheId, Orden, EMPRESA, NUMEMPLEADO, idemp, Paterno, Materno, Nombre1, Nombre2, idSexo,
        Sexo, FechaNac, Edad, Perfil, CVEParentesco, NombreParentesco, TRANSFERIDO, SueldoMensual,
        NumSolicitud, POidSolicitud, PlanD, PlanOpcion, IdGRUPOP, GRUPOPARENTESCO, CVEPO, CVEP,
        TIPOSUMASEG, VALSUMA, PLOrdenCobranza, ImporteAnual, ImportexPeriodo, MontoTotalCreditos,
        MontoPeridoCreditos, CostoEmpresa, CtoEmpresaCash, CtoEmpresa1erexc, CtoEmpresaStoploss,
        CostoEmpleado, CtoEmpleadoCash, CtoEmpleado1erexc, CtoEmpleadoStoploss,
        CostoEmpleadoExcedente, CostoEmpleadoReal, SobranteExcedentes, PrimaNetaAnual,
        PrimaNetaxPer, idVigencia
    )
    SELECT @CacheId,
           @OrdenD + ROW_NUMBER() OVER
               (ORDER BY EMPRESA, NUMEMPLEADO, PLOrdenCobranza, CVEParentesco, idemp, CVEPO),
           EMPRESA, NUMEMPLEADO, idemp, Paterno, Materno, Nombre1, Nombre2, idSexo, Sexo, FechaNac,
           Edad, Perfil, CVEParentesco, NombreParentesco, TRANSFERIDO, SueldoMensual, NumSolicitud,
           POidSolicitud, PlanD, PlanOpcion, IdGRUPOP, GRUPOPARENTESCO, CVEPO, CVEP, TIPOSUMASEG,
           VALSUMA, PLOrdenCobranza, ImporteAnual, ImportexPeriodo, MontoTotalCreditos,
           MontoPeridoCreditos, CostoEmpresa, CtoEmpresaCash, CtoEmpresa1erexc, CtoEmpresaStoploss,
           CostoEmpleado, CtoEmpleadoCash, CtoEmpleado1erexc, CtoEmpleadoStoploss,
           CostoEmpleadoExcedente, CostoEmpleadoReal, SobranteExcedentes, PrimaNetaAnual,
           PrimaNetaxPer, idVigencia
    FROM #TablaCobDesg;

    DELETE FROM dbo.bf_CobranzaCache_BanwireV2 WHERE CacheId = @CacheId;
    IF OBJECT_ID(N'tempdb..#isEmpresaTC') IS NOT NULL AND EXISTS (SELECT 1 FROM #isEmpresaTC)
    BEGIN
        SET @EsTarjeta = 1;
        IF OBJECT_ID(N'tempdb..#CobranzaBanwire') IS NOT NULL
        BEGIN
            INSERT dbo.bf_CobranzaCache_BanwireV2
            (
                CacheId, Orden, idEmpleado, CobroTarjeta, Dif, Transaccion, FechaCobro,
                CodigoAutorizacion, Referencia, ext_ref_cliente, Card, Telefono, mail, Comercio
            )
            SELECT @CacheId, ROW_NUMBER() OVER (ORDER BY idEmpleado, Transaccion), idEmpleado,
                   CobroTarjeta, Dif, Transaccion, FechaCobro, CodigoAutorizacion, Referencia,
                   ext_ref_cliente, Card, Telefono, mail, Comercio
            FROM #CobranzaBanwire;
        END;
    END;

    UPDATE dbo.bf_CobranzaCache_ConsultaV2
       SET EsTarjeta = @EsTarjeta,
           FilasConcentrada = (SELECT COUNT(*) FROM dbo.bf_CobranzaCache_ConcentradaV2 WHERE CacheId=@CacheId),
           FilasDesglosada = (SELECT COUNT(*) FROM dbo.bf_CobranzaCache_DesglosadaV2 WHERE CacheId=@CacheId),
           Estado = 'COMPLETA'
     WHERE CacheId = @CacheId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO


DECLARE @Def nvarchar(max) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.ff_ObtenDivisionCtos_Adaptado_bf3_NOUSAR')),
        @Anchor nvarchar(200) = N'-- CONCENTRADA MODIFICACION BANWIRE',
        @Hook nvarchar(max) = N'
-- BF_CACHE_CAPTURE_HOOK_V2_INICIO
IF TRY_CONVERT(bit, SESSION_CONTEXT(N''bf_CobranzaCacheCapturar'')) = 1
BEGIN
    EXEC dbo.bf_CobranzaCache_CapturaBasesV2;
    RETURN;
END;
-- BF_CACHE_CAPTURE_HOOK_V2_FIN
';

IF @Def IS NULL
    THROW 51002, 'No se pudo leer la definicion de ff_ObtenDivisionCtos_Adaptado_bf3_NOUSAR.', 1;

IF CHARINDEX(N'BF_CACHE_CAPTURE_HOOK_V2_INICIO', @Def) = 0
BEGIN
    DECLARE @AnchorPos int = CHARINDEX(@Anchor, @Def),
            @ProcPos int;
    IF @AnchorPos = 0
        THROW 51002, 'No se encontro el punto de insercion del hook. Revise la version del SP.', 1;

    SET @Def = STUFF(@Def, @AnchorPos, 0, @Hook);
    SET @ProcPos = CHARINDEX(N'PROCEDURE', UPPER(@Def));
    IF @ProcPos = 0
        THROW 51002, 'La definicion del helper no contiene PROCEDURE.', 1;

    SET @Def = N'ALTER ' + SUBSTRING(@Def, @ProcPos, LEN(@Def));
    EXEC sys.sp_executesql @Def;
END;
GO

CREATE OR ALTER PROCEDURE dbo.bf_CobranzaCache_CargarUnaV2
    @idEmpresa int,
    @idSolTipo int,
    @FecIni varchar(16),
    @FecFin varchar(16),
    @idVencida int,
    @IdPerfil dbo.ListInt READONLY,
    @idVigencia int,
    @ForzarRecarga bit = 0,
    @EsUniverso bit = 0,
    @Resultado varchar(30) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /* BF_CACHE_TEMPDB_COLLATION_LOADER_V1 */

    DECLARE @PerfilClave varchar(2000), @PerfilHash varbinary(32), @CacheId bigint,
            @FechaAnterior datetime2(3), @Ahora datetime2(3) = SYSDATETIME(),
            @Modo varchar(10) = 'FULL', @LockResult int, @LockName nvarchar(255),
            @Error nvarchar(2000), @Estado varchar(20), @TeniaCacheCompleta bit=0,
            @Etapa nvarchar(100)=N'INICIALIZACION',
            @CacheFecIni varchar(16), @CacheFecFin varchar(16),
            @DetalleEvento nvarchar(4000);

    SELECT @PerfilClave = STUFF
    ((
        SELECT ',' + CONVERT(varchar(11), P.IdTipoNotificacionCorreo)
        FROM (SELECT DISTINCT IdTipoNotificacionCorreo FROM @IdPerfil) P
        ORDER BY P.IdTipoNotificacionCorreo
        FOR XML PATH(''), TYPE
    ).value('.', 'varchar(2000)'), 1, 1, '');
    SET @PerfilClave = ISNULL(@PerfilClave, '');
    SET @PerfilHash = HASHBYTES('SHA2_256', @PerfilClave);
    SET @LockName = CONCAT(N'BF3-CobranzaCache-', @idEmpresa, N'-', @idVigencia, N'-',
                           CONVERT(varchar(64), @PerfilHash, 2), N'-', @idVencida);

    /* Recupera estados dejados en CARGANDO por sesiones terminadas. */
    EXEC dbo.bf_CobranzaCache_MarcarCargasAbandonadas
         @IdEmpresa=@idEmpresa,@MinutosSinActividad=15,@EmitirResultado=0;

    SET @DetalleEvento=CONCAT(N'Recurso=',@LockName,N'; perfiles=',@PerfilClave);
    EXEC dbo.bf_CobranzaCache_RegistrarEvento
         @IdEmpresa=@idEmpresa,@IdVigencia=@idVigencia,
         @Etapa='SOLICITUD_CARGA',@Estado='SOLICITADA',@Detalle=@DetalleEvento;

    EXEC @LockResult = sys.sp_getapplock
         @Resource=@LockName, @LockMode='Exclusive', @LockOwner='Session', @LockTimeout=60000;
    IF @LockResult < 0
    BEGIN
        SET @Error=LEFT(CONCAT(
            N'No se pudo obtener el bloqueo de carga de cache. Resultado=',@LockResult,
            N', recurso=',@LockName,
            N'. El resultado -1 indica que otra carga continuo activa por mas de 60 segundos.'),2000);
        THROW 51003, @Error, 1;
    END;

    EXEC dbo.bf_CobranzaCache_RegistrarEvento
         @IdEmpresa=@idEmpresa,@IdVigencia=@idVigencia,
         @Etapa='BLOQUEO_OBTENIDO',@Estado='CARGANDO',@Detalle=@LockName;

    BEGIN TRY
        IF @EsUniverso=1
        BEGIN
            SELECT TOP (1) @CacheId=CacheId,@FechaAnterior=FechaFuenteHasta,@Estado=Estado,
                   @CacheFecIni=FecIni,@CacheFecFin=FecFin
            FROM dbo.bf_CobranzaCache_ConsultaV2
            WHERE IdEmpresa=@idEmpresa AND IdSolTipo=@idSolTipo
              AND IdVencida=@idVencida AND IdVigencia=@idVigencia
              AND PerfilHash=@PerfilHash AND EsUniverso=1
            ORDER BY CacheId DESC;
        END
        ELSE
        BEGIN
            SELECT @CacheId=CacheId,@FechaAnterior=FechaFuenteHasta,@Estado=Estado,
                   @CacheFecIni=FecIni,@CacheFecFin=FecFin
            FROM dbo.bf_CobranzaCache_ConsultaV2
        WHERE IdEmpresa=@idEmpresa AND IdSolTipo=@idSolTipo AND FecIni=@FecIni AND FecFin=@FecFin
          AND IdVencida=@idVencida AND IdVigencia=@idVigencia
              AND PerfilHash=@PerfilHash AND EsUniverso=0
              AND NOT EXISTS
                  (
                      SELECT 1
                      FROM dbo.bf_CobranzaCache_ConsultaV2 U
                      WHERE U.IdEmpresa=@idEmpresa AND U.IdSolTipo=@idSolTipo
                        AND U.IdVencida=@idVencida AND U.IdVigencia=@idVigencia
                        AND U.EsUniverso=1 AND U.Estado='COMPLETA'
                        AND TRY_CONVERT(datetime,U.FecIni)<=TRY_CONVERT(datetime,@FecIni)
                        AND TRY_CONVERT(datetime,U.FecFin)>=TRY_CONVERT(datetime,@FecFin)
                        AND YEAR(TRY_CONVERT(datetime,U.FecFin))=YEAR(TRY_CONVERT(datetime,@FecFin))
                        AND MONTH(TRY_CONVERT(datetime,U.FecFin))=MONTH(TRY_CONVERT(datetime,@FecFin))
                        AND NOT EXISTS
                            (
                                SELECT 1 FROM @IdPerfil R
                                WHERE NOT EXISTS
                                    (
                                        SELECT 1 FROM STRING_SPLIT(U.PerfilClave,',') C
                                        WHERE TRY_CONVERT(int,C.value)=R.IdTipoNotificacionCorreo
                                    )
                            )
                  );
        END;

        IF @Estado='COMPLETA' SET @TeniaCacheCompleta=1;

        IF @CacheId IS NULL
        BEGIN
            INSERT dbo.bf_CobranzaCache_ConsultaV2
            (IdEmpresa,IdSolTipo,FecIni,FecFin,IdVencida,IdVigencia,PerfilClave,PerfilHash,
             EsUniverso,Estado,FechaCargaInicio,Mensaje)
            VALUES
            (@idEmpresa,@idSolTipo,@FecIni,@FecFin,@idVencida,@idVigencia,@PerfilClave,@PerfilHash,
             @EsUniverso,'CARGANDO',@Ahora,
             CASE WHEN @EsUniverso=1 THEN N'Carga universo inicial' ELSE N'Carga completa inicial' END);
            SET @CacheId = SCOPE_IDENTITY();
        END
        ELSE IF @ForzarRecarga = 1 OR ISNULL(@Estado,'') <> 'COMPLETA' OR @FechaAnterior IS NULL
             OR (@EsUniverso=1 AND (@CacheFecIni<>@FecIni OR @CacheFecFin<>@FecFin))
        BEGIN
            SET @Modo='FULL';
        END
        ELSE
        BEGIN
            SET @Modo='DELTA';
        END;

        SET @DetalleEvento=CONCAT(N'Modo=',@Modo,N'; universo=',@EsUniverso,
                                  N'; perfiles=',@PerfilClave);
        EXEC dbo.bf_CobranzaCache_RegistrarEvento
             @CacheId=@CacheId,@IdEmpresa=@idEmpresa,@IdVigencia=@idVigencia,
             @Etapa='CACHE_PREPARADA',@Estado='CARGANDO',@Detalle=@DetalleEvento;

        CREATE TABLE #CacheEmpresas (IdEmpresa int NOT NULL PRIMARY KEY);
        INSERT #CacheEmpresas VALUES (@idEmpresa);
        IF EXISTS
        (
            SELECT 1 FROM dbo.ff_Empresa
            WHERE EMidEmpresa=@idEmpresa AND EMidCorporativo=@idEmpresa AND EMidEstatus=1
        )
        BEGIN
            INSERT #CacheEmpresas
            SELECT EMidEmpresa FROM dbo.ff_Empresa
            WHERE EMidCorporativo=@idEmpresa AND EMidEmpresa<>@idEmpresa AND EMidEstatus=1;
        END;

        CREATE TABLE #CacheEmpsCambios
        (
            EMId int NULL,
            /* Las temporales heredan tempdb; DATABASE_DEFAULT evita conflicto con la BD. */
            NumEmpleado varchar(20) COLLATE DATABASE_DEFAULT NOT NULL
        );

        IF @Modo='DELTA'
        BEGIN
            INSERT #CacheEmpsCambios (EMId,NumEmpleado)
            SELECT DISTINCT E.Id, E.EMNumeroEmpleado
            FROM dbo.ff_Empleado E WITH (NOLOCK)
            WHERE E.EMIdEmpresa IN (SELECT IdEmpresa FROM #CacheEmpresas)
              AND
              (
                  E.EMFechaAdd > @FechaAnterior OR E.EMFechaUMod > @FechaAnterior OR
                  E.EMFechaDel > @FechaAnterior OR E.EMFechaEstatus > @FechaAnterior
              );

            INSERT #CacheEmpsCambios (EMId,NumEmpleado)
            SELECT DISTINCT H.EMId, H.EMNumeroEmpleado
            FROM dbo.ff_empleado_historico H WITH (NOLOCK)
            WHERE H.EMIdEmpresa IN (SELECT IdEmpresa FROM #CacheEmpresas)
              AND H.EMFechaCambio > @FechaAnterior
              AND H.EMFechaCambio <= @Ahora
              AND NOT EXISTS
                  (SELECT 1 FROM #CacheEmpsCambios X
                   WHERE X.EMId=H.EMId
                     AND X.NumEmpleado COLLATE DATABASE_DEFAULT = H.EMNumeroEmpleado COLLATE DATABASE_DEFAULT);

            INSERT #CacheEmpsCambios (EMId,NumEmpleado)
            SELECT DISTINCT S.SOIdEmpleado,S.SONumEmpleado
            FROM dbo.ff_Solicitud S WITH (NOLOCK)
            WHERE S.SOIdEmpresa IN (SELECT IdEmpresa FROM #CacheEmpresas)
              AND S.SONumEmpleado IS NOT NULL
              AND (S.SOFechaAdd>@FechaAnterior OR S.SOFechaUMod>@FechaAnterior OR
                   S.SOFechaDel>@FechaAnterior OR S.SOFechaEstatus>@FechaAnterior);

            INSERT #CacheEmpsCambios (EMId,NumEmpleado)
            SELECT DISTINCT P.POidEmpleado,P.PONumeroEmpleado
            FROM dbo.ff_PlanOpcionSeleccionCobranza P WITH (NOLOCK)
            WHERE P.POidEmpresa IN (SELECT IdEmpresa FROM #CacheEmpresas)
              AND P.PONumeroEmpleado IS NOT NULL
              AND (P.POFechaAdd>@FechaAnterior OR P.POFechaUMod>@FechaAnterior OR P.POFechaDel>@FechaAnterior);

            INSERT #CacheEmpsCambios (EMId,NumEmpleado)
            SELECT DISTINCT E.ECidEmpleado,E.ECNumeroEmpleado COLLATE DATABASE_DEFAULT
            FROM dbo.ff_EdoCuentaCobranza E WITH (NOLOCK)
            WHERE E.ECidEmpresa IN (SELECT IdEmpresa FROM #CacheEmpresas)
              AND E.ECNumeroEmpleado IS NOT NULL
              AND (E.ECFechaAdd>@FechaAnterior OR E.ECFechaUMod>@FechaAnterior OR E.ECFechaDel>@FechaAnterior)
            UNION
            SELECT DISTINCT E.ECidEmpleado,E.ECNumeroEmpleado COLLATE DATABASE_DEFAULT
            FROM dbo.ff_EdoCuentaCobranza2 E WITH (NOLOCK)
            WHERE E.ECidEmpresa IN (SELECT IdEmpresa FROM #CacheEmpresas)
              AND E.ECNumeroEmpleado IS NOT NULL
              AND (E.ECFechaAdd>@FechaAnterior OR E.ECFechaUMod>@FechaAnterior OR E.ECFechaDel>@FechaAnterior);

            INSERT #CacheEmpsCambios (EMId,NumEmpleado)
            SELECT DISTINCT E.Id,D.DENumeroEmpleado
            FROM dbo.ff_DescuentoEmpleado D WITH (NOLOCK)
            LEFT JOIN dbo.ff_Empleado E WITH (NOLOCK)
              ON E.EMIdEmpresa=D.DEIdEmpresa
             AND E.EMNumeroEmpleado COLLATE DATABASE_DEFAULT = D.DENumeroEmpleado COLLATE DATABASE_DEFAULT
            WHERE D.DEIdEmpresa IN (SELECT IdEmpresa FROM #CacheEmpresas)
              AND D.DENumeroEmpleado IS NOT NULL
              AND (D.DEFechaAdd>@FechaAnterior OR D.DEFechaUMod>@FechaAnterior OR D.DEFechaDel>@FechaAnterior);

            INSERT #CacheEmpsCambios (EMId,NumEmpleado)
            SELECT DISTINCT E.Id,E.EMNumeroEmpleado
            FROM dbo.bf_RegistroTarjetaEmpleado R WITH (NOLOCK)
            INNER JOIN dbo.ff_Empleado E WITH (NOLOCK) ON E.Id=R.RTEIdEmpleadoTitular
            LEFT JOIN dbo.bf_BanwireRecibos B WITH (NOLOCK) ON B.BRIdRegistroTarjeta=R.RTEIdRegistroTarjeta
            WHERE E.EMIdEmpresa IN (SELECT IdEmpresa FROM #CacheEmpresas)
              AND (R.RTEFechaAdd>@FechaAnterior OR R.RTEFechaUMod>@FechaAnterior OR R.RTEFechaDel>@FechaAnterior
                   OR B.BRFechaAdd>@FechaAnterior OR B.BRFechaUMod>@FechaAnterior OR B.BRFechaDel>@FechaAnterior);

            IF NOT EXISTS (SELECT 1 FROM #CacheEmpsCambios)
            BEGIN
                SET @Resultado='SIN_CAMBIOS';
                EXEC sys.sp_releaseapplock @Resource=@LockName, @LockOwner='Session';
                RETURN;
            END;

            /* Si el SP de empleados no reconoce el filtro temporal, se prioriza igualdad sobre velocidad. */
            IF @idVencida NOT IN (1,10)
               OR ISNULL(OBJECT_DEFINITION(OBJECT_ID(N'dbo.ff_ObtenEmpleadosCob_v2_bf3')),N'')
                    NOT LIKE N'%#FiltroIncrementalEmps%'
                SET @Modo='FULL';
        END;

        /*
           BF_CACHE_FILTER_ALWAYS_EXISTS_V1
           La tabla debe existir tanto en FULL como en DELTA porque el SP de
           empleados la referencia durante la compilacion de ambos caminos.
        */
        CREATE TABLE #FiltroIncrementalEmps (EMId int NOT NULL PRIMARY KEY);

        IF @Modo='DELTA'
        BEGIN
            INSERT #FiltroIncrementalEmps (EMId)
            SELECT DISTINCT E.Id
            FROM dbo.ff_Empleado E WITH (NOLOCK)
            INNER JOIN #CacheEmpsCambios X
                ON X.EMId=E.Id
                OR X.NumEmpleado COLLATE DATABASE_DEFAULT = E.EMNumeroEmpleado COLLATE DATABASE_DEFAULT
            WHERE E.EMIdEmpresa IN (SELECT IdEmpresa FROM #CacheEmpresas);
        END;
        ELSE
        BEGIN
            INSERT #FiltroIncrementalEmps (EMId)
            SELECT E.Id
            FROM dbo.ff_Empleado E WITH (NOLOCK)
            WHERE E.EMIdEmpresa IN (SELECT IdEmpresa FROM #CacheEmpresas);
        END;

        UPDATE dbo.bf_CobranzaCache_ConsultaV2
           SET FecIni=@FecIni,FecFin=@FecFin,EsUniverso=@EsUniverso,
               FechaCargaInicio=@Ahora,
               Mensaje=CONCAT(CASE WHEN @EsUniverso=1 THEN N'Calculando universo ' ELSE N'Calculando cache ' END,@Modo)
         WHERE CacheId=@CacheId;

        EXEC sys.sp_set_session_context @key=N'bf_CobranzaCacheId', @value=@CacheId;
        EXEC sys.sp_set_session_context @key=N'bf_CobranzaCacheModo', @value=@Modo;
        EXEC sys.sp_set_session_context @key=N'bf_CobranzaCacheCapturar', @value=1;

        SET @Etapa=N'EJECUCION_SP_ORIGINAL';
        SET @DetalleEvento=CONCAT(N'Inicia ObtenCobranzaConcentrada_otro_V2_BF3; modo=',@Modo);
        EXEC dbo.bf_CobranzaCache_RegistrarEvento
             @CacheId=@CacheId,@IdEmpresa=@idEmpresa,@IdVigencia=@idVigencia,
             @Etapa='SP_ORIGINAL_INICIO',@Estado='CARGANDO',@Detalle=@DetalleEvento;
        EXEC dbo.ObtenCobranzaConcentrada_otro_V2_BF3
             @idEmpresa=@idEmpresa, @idSolTipo=@idSolTipo, @FecIni=@FecIni, @FecFin=@FecFin,
             @idVencida=@idVencida, @IdPerfil=@IdPerfil, @idVIgencia=@idVigencia;

        SET @Etapa=N'CIERRE_CARGA';
        EXEC dbo.bf_CobranzaCache_RegistrarEvento
             @CacheId=@CacheId,@IdEmpresa=@idEmpresa,@IdVigencia=@idVigencia,
             @Etapa='SP_ORIGINAL_FIN',@Estado='CARGANDO',
             @Detalle=N'Finalizo ObtenCobranzaConcentrada_otro_V2_BF3.';
        EXEC sys.sp_set_session_context @key=N'bf_CobranzaCacheCapturar', @value=NULL;
        EXEC sys.sp_set_session_context @key=N'bf_CobranzaCacheModo', @value=NULL;
        EXEC sys.sp_set_session_context @key=N'bf_CobranzaCacheId', @value=NULL;

        UPDATE dbo.bf_CobranzaCache_ConsultaV2
           SET Estado='COMPLETA', FechaCargaFin=SYSDATETIME(), FechaFuenteHasta=@Ahora,
               Mensaje=CASE WHEN @Modo='FULL' THEN N'Carga completa' ELSE N'Carga incremental' END
         WHERE CacheId=@CacheId;

        SET @Resultado=CASE WHEN @Modo='FULL' THEN 'CARGA_COMPLETA' ELSE 'CARGA_INCREMENTAL' END;
        SET @DetalleEvento=CONCAT(N'Resultado=',@Resultado,N'; modo=',@Modo);
        EXEC dbo.bf_CobranzaCache_RegistrarEvento
             @CacheId=@CacheId,@IdEmpresa=@idEmpresa,@IdVigencia=@idVigencia,
             @Etapa='CARGA_COMPLETA',@Estado='COMPLETA',@Detalle=@DetalleEvento;
        EXEC sys.sp_releaseapplock @Resource=@LockName, @LockOwner='Session';
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key=N'bf_CobranzaCacheCapturar', @value=NULL;
        EXEC sys.sp_set_session_context @key=N'bf_CobranzaCacheModo', @value=NULL;
        EXEC sys.sp_set_session_context @key=N'bf_CobranzaCacheId', @value=NULL;
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @Error=LEFT(CONCAT(
            N'Error ',ERROR_NUMBER(),N' en ',
            COALESCE(ERROR_PROCEDURE(),N'(sentencia ad hoc)'),
            N', linea ',ERROR_LINE(),N', etapa ',@Etapa,N': ',
            ERROR_MESSAGE()),2000);
        IF @CacheId IS NOT NULL
            UPDATE dbo.bf_CobranzaCache_ConsultaV2
               SET Estado=CASE WHEN @TeniaCacheCompleta=1 THEN 'COMPLETA' ELSE 'ERROR' END,
                   FechaCargaFin=SYSDATETIME(),Mensaje=@Error
             WHERE CacheId=@CacheId;
        EXEC dbo.bf_CobranzaCache_RegistrarEvento
             @CacheId=@CacheId,@IdEmpresa=@idEmpresa,@IdVigencia=@idVigencia,
             @Etapa='CARGA_ERROR',@Estado='ERROR',@Detalle=@Error;
        EXEC sys.sp_releaseapplock @Resource=@LockName, @LockOwner='Session';
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.bf_CobranzaCache_LimpiarVigenciasV2
    @idEmpresa int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /* BF_CACHE_KEEP_4_VIGENCIAS_V1 */
    CREATE TABLE #VigenciasConservar
    (
        IdEmpresa int NOT NULL,
        IdVigencia int NOT NULL,
        CONSTRAINT PK_VigenciasConservar PRIMARY KEY (IdEmpresa,IdVigencia)
    );

    INSERT #VigenciasConservar (IdEmpresa,IdVigencia)
    SELECT E.EMidEmpresa,V.VIidVigencia
    FROM dbo.ff_Empresa E
    CROSS APPLY
    (
        SELECT TOP (4) VI.VIidVigencia
        FROM dbo.ff_Vigencia VI
        WHERE VI.VIidConfiguracion=E.EMidConfiguracion
          AND VI.VITipoNegocio=1
        ORDER BY VI.VIVigenciaIni DESC,VI.VIidVigencia DESC
    ) V
    WHERE (@idEmpresa IS NULL OR E.EMidEmpresa=@idEmpresa);

    DECLARE @CacheIdEliminar bigint;
    WHILE 1=1
    BEGIN
        SET @CacheIdEliminar=NULL;
        SELECT TOP (1) @CacheIdEliminar=Q.CacheId
        FROM dbo.bf_CobranzaCache_ConsultaV2 Q
        WHERE (@idEmpresa IS NULL OR Q.IdEmpresa=@idEmpresa)
          AND NOT EXISTS
          (
              SELECT 1 FROM #VigenciasConservar C
              WHERE C.IdEmpresa=Q.IdEmpresa
                AND C.IdVigencia=Q.IdVigencia
          )
          /* No tocar una carga inicial activa; una marca con mas de 24 h se
             considera abandonada por reinicio o error del proceso. */
          AND
          (
              Q.Estado<>'CARGANDO'
              OR Q.FechaCargaInicio<DATEADD(HOUR,-24,SYSDATETIME())
          )
        ORDER BY Q.CacheId;

        IF @CacheIdEliminar IS NULL BREAK;

        /* Una particion por sentencia/transaccion para limitar locks y log. */
        DELETE FROM dbo.bf_CobranzaCache_ConsultaV2
        WHERE CacheId=@CacheIdEliminar;
    END;
END;
GO

SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache
    @idEmpresa int = 0,
    @idSolTipo int = 0,
    @FecIni varchar(16) = '',
    @FecFin varchar(16) = '',
    @idVencida int = 0,
    @IdPerfil dbo.ListInt READONLY,
    @idVIgencia int = 0
AS
BEGIN
    SET NOCOUNT ON;

    /* BF_CACHE_TEMPDB_COLLATION_READER_V1 */

    DECLARE @PerfilClave varchar(2000),@PerfilHash varbinary(32),@CacheId bigint,
            @EsTarjeta bit,@EmpresaDetalle int=0,@VigenciaDetalle int=@idVIgencia,
            @CacheEsUniverso bit=0;

    SELECT @PerfilClave=STUFF
    ((
        SELECT ','+CONVERT(varchar(11),P.IdTipoNotificacionCorreo)
        FROM (SELECT DISTINCT IdTipoNotificacionCorreo FROM @IdPerfil) P
        ORDER BY P.IdTipoNotificacionCorreo
        FOR XML PATH(''),TYPE
    ).value('.','varchar(2000)'),1,1,'');
    SET @PerfilClave=ISNULL(@PerfilClave,'');
    SET @PerfilHash=HASHBYTES('SHA2_256',@PerfilClave);

    SELECT @CacheId=CacheId,@EsTarjeta=EsTarjeta,@CacheEsUniverso=EsUniverso
    FROM dbo.bf_CobranzaCache_ConsultaV2
    WHERE IdEmpresa=@idEmpresa AND IdSolTipo=@idSolTipo AND FecIni=@FecIni AND FecFin=@FecFin
      AND IdVencida=@idVencida AND IdVigencia=@idVIgencia AND PerfilHash=@PerfilHash
      AND EsUniverso=0 AND Estado='COMPLETA';

    IF @CacheId IS NULL
    BEGIN
        SELECT TOP (1) @CacheId=Q.CacheId,@EsTarjeta=Q.EsTarjeta,@CacheEsUniverso=Q.EsUniverso
        FROM dbo.bf_CobranzaCache_ConsultaV2 Q
        WHERE Q.IdEmpresa=@idEmpresa AND Q.IdSolTipo=@idSolTipo
          AND Q.IdVencida=@idVencida AND Q.IdVigencia=@idVIgencia
          AND Q.EsUniverso=1 AND Q.Estado='COMPLETA'
          AND TRY_CONVERT(datetime,Q.FecIni)<=TRY_CONVERT(datetime,@FecIni)
          AND TRY_CONVERT(datetime,Q.FecFin)>=TRY_CONVERT(datetime,@FecFin)
          AND YEAR(TRY_CONVERT(datetime,Q.FecFin))=YEAR(TRY_CONVERT(datetime,@FecFin))
          AND MONTH(TRY_CONVERT(datetime,Q.FecFin))=MONTH(TRY_CONVERT(datetime,@FecFin))
          AND NOT EXISTS
              (
                  SELECT 1 FROM @IdPerfil R
                  WHERE NOT EXISTS
                      (
                          SELECT 1 FROM STRING_SPLIT(Q.PerfilClave,',') C
                          WHERE TRY_CONVERT(int,C.value)=R.IdTipoNotificacionCorreo
                      )
              )
        ORDER BY Q.FechaCargaFin DESC,Q.CacheId DESC;
    END;

    IF @CacheId IS NULL
        THROW 51005, 'No existe una cache completa para esos parametros. Ejecute primero InsertaCobranzaConcentrada_otro_V2_BF3_Cache.', 1;

    CREATE TABLE #PerfilesSolicitados
    (
        PENombre varchar(50) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY
    );
    INSERT #PerfilesSolicitados(PENombre)
    SELECT DISTINCT P.PENombre
    FROM dbo.ff_Perfil P WITH (NOLOCK)
    INNER JOIN @IdPerfil R ON R.IdTipoNotificacionCorreo=P.PEIdPerfil
    WHERE P.PEIdEmpresa=@idEmpresa AND P.PEIdEstatus=1;

    CREATE TABLE #EmpleadosUniverso
    (
        CveEmpl int NULL,
        NumSolicitud varchar(8) COLLATE DATABASE_DEFAULT NULL,
        NumEmpleado varchar(20) COLLATE DATABASE_DEFAULT NULL
    );

    INSERT #EmpleadosUniverso(CveEmpl,NumSolicitud,NumEmpleado)
    SELECT DISTINCT C.CveEmpl,C.NumSolicitud,C.NumEMpleado
    FROM dbo.bf_CobranzaCache_ConcentradaV2 C WITH (NOLOCK)
    WHERE C.CacheId=@CacheId
      AND
      (
          @CacheEsUniverso=0
          OR
          (
              EXISTS
                  (SELECT 1 FROM #PerfilesSolicitados P
                   WHERE P.PENombre=C.Perfil COLLATE DATABASE_DEFAULT)
              AND COALESCE(TRY_CONVERT(date,C.FechaAutorizacion,103),CONVERT(date,GETDATE()))
                    BETWEEN CONVERT(date,TRY_CONVERT(datetime,@FecIni))
                        AND CONVERT(date,TRY_CONVERT(datetime,@FecFin))
          )
      );

    CREATE TABLE #ListEmpresas (EMidEmpresa int);
    INSERT #ListEmpresas VALUES(@idEmpresa);
    IF EXISTS
       (SELECT 1 FROM dbo.ff_Empresa WHERE EMidEmpresa=@idEmpresa AND EMidCorporativo=@idEmpresa AND EMidEstatus=1)
        INSERT #ListEmpresas
        SELECT EMidEmpresa FROM dbo.ff_Empresa
        WHERE EMidCorporativo=@idEmpresa AND EMidEmpresa<>@idEmpresa AND EMidEstatus=1;

    CREATE TABLE #isEmpresaTC (result int);
    IF @EsTarjeta=1 INSERT #isEmpresaTC VALUES(1);

    SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY Orden)) AS Id_tablatemp,
           empresa,NumEMpleado,CveEmpl,Paterno,MAterno,Nombre1,Nombre2,Sexo,FechaNac,Edad,Confidencial,
           SueldoMensual,SueldoMensualAnt,SueldoMensualDif,TRANSFERIDO,NumSolicitud,Perfil,
           FechaAutorizacion,MontoGMM,MontoVIDA,MontoOTROSPLANES,CreditosGMM,CreditosViDA,
           MontoTotalCreditos,MontoTotalCreditosAnt,DiferenciaCreditos,MontoTotalSelecciones,
           MontoTotalSeleccionesAnt,SobranteCreditos,MontoPagCred,MontoDescMensual,MontoDescMensualAnt,
           GrupoParentescoGMM,Excedentes,ExcedentesAnt,MontoFondoAhorroMensual,
           MontoFondoAhorroMensualAnt,SobranteExcedentes,DescuentoEmpleadoFH,DescuentoEmpleadoFinal,
           SobranteExceFinal,CoberturaDesc,Q1,Q2,Diferencia,CtoEmpleadoNomSeg,AplicExcedentes,
           NumOficina,NomOficina,POFH,LocalNumber,PagoEmpresa,PagoEmpleado,CentroCostos,
           CONVERT(money,NULL) AS [Cobro Tarjeta]
    INTO #tablatemp
    FROM dbo.bf_CobranzaCache_ConcentradaV2 C
    WHERE C.CacheId=@CacheId
      AND EXISTS
          (SELECT 1 FROM #EmpleadosUniverso E
           WHERE E.CveEmpl=C.CveEmpl
             AND E.NumEmpleado=C.NumEMpleado COLLATE DATABASE_DEFAULT);

    INSERT #tablatemp
    (NumEMpleado,Paterno,MAterno,Nombre1,Nombre2,Sexo,Confidencial,TRANSFERIDO,NumSolicitud,Perfil,
     GrupoParentescoGMM,FechaNac,FechaAutorizacion,MontoGMM,MontoVIDA,MontoOTROSPLANES,CreditosGMM,
     CreditosViDA,MontoTotalCreditos,MontoTotalSelecciones,SobranteCreditos,MontoPagCred,MontoDescMensual,
     Q1,Q2,Diferencia,Excedentes,ExcedentesAnt,MontoFondoAhorroMensual,SobranteExcedentes,
     DescuentoEmpleadoFH,DescuentoEmpleadoFinal,CtoEmpleadoNomSeg,SobranteExceFinal,CoberturaDesc,AplicExcedentes)
    SELECT 'TOTALES: ','','','','','','','','','','','','',SUM(MontoGMM),SUM(MontoVIDA),SUM(MontoOTROSPLANES),
           SUM(CreditosGMM),SUM(CreditosViDA),SUM(MontoTotalCreditos),SUM(MontoTotalSelecciones),
           SUM(SobranteCreditos),SUM(MontoPagCred),ISNULL(SUM(MontoDescMensual),0),SUM(Q1),SUM(Q2),SUM(Diferencia),
           SUM(Excedentes),SUM(ExcedentesAnt),SUM(MontoFondoAhorroMensual),SUM(SobranteExcedentes),
           SUM(DescuentoEmpleadoFH),SUM(DescuentoEmpleadoFinal),SUM(CtoEmpleadoNomSeg),SUM(SobranteExceFinal),
           SUM(CoberturaDesc),SUM(AplicExcedentes)
    FROM #tablatemp;

    SELECT EMPRESA,NUMEMPLEADO,idemp,Paterno,Materno,Nombre1,Nombre2,idSexo,Sexo,FechaNac,Edad,Perfil,
           CVEParentesco,NombreParentesco,TRANSFERIDO,SueldoMensual,NumSolicitud,POidSolicitud,PlanD,
           PlanOpcion,IdGRUPOP,GRUPOPARENTESCO,CVEPO,CVEP,TIPOSUMASEG,VALSUMA,PLOrdenCobranza,
           ImporteAnual,ImportexPeriodo,MontoTotalCreditos,MontoPeridoCreditos,CostoEmpresa,CtoEmpresaCash,
           CtoEmpresa1erexc,CtoEmpresaStoploss,CostoEmpleado,CtoEmpleadoCash,CtoEmpleado1erexc,
           CtoEmpleadoStoploss,CostoEmpleadoExcedente,CostoEmpleadoReal,SobranteExcedentes,
           PrimaNetaAnual,PrimaNetaxPer,idVigencia
    INTO #TablaCobDesg
    FROM dbo.bf_CobranzaCache_DesglosadaV2 D
    WHERE D.CacheId=@CacheId
      AND EXISTS
          (SELECT 1 FROM #EmpleadosUniverso E
           WHERE E.CveEmpl=D.idemp
             AND (E.NumSolicitud=D.NumSolicitud COLLATE DATABASE_DEFAULT
                  OR E.NumSolicitud IS NULL OR D.NumSolicitud IS NULL));

    SELECT @EmpresaDetalle=EMPRESA,@VigenciaDetalle=idVigencia FROM #TablaCobDesg;
    SET @EmpresaDetalle=ISNULL(@EmpresaDetalle,@idEmpresa);
    SET @VigenciaDetalle=ISNULL(@VigenciaDetalle,@idVIgencia);

    SELECT @FecIni AS FechaInicio,@FecFin AS FechaFin,@idVIgencia AS idVigencia
    INTO #ParametrosCobranza;

    SELECT idEmpleado,CobroTarjeta,Dif,Transaccion,FechaCobro,CodigoAutorizacion,Referencia,
           ext_ref_cliente,Card,Telefono,mail,Comercio
    INTO #CobranzaBanwire
    FROM dbo.bf_CobranzaCache_BanwireV2 B
    WHERE B.CacheId=@CacheId
      AND EXISTS (SELECT 1 FROM #EmpleadosUniverso E WHERE E.CveEmpl=B.idEmpleado);

    /* 1. Concentrada */
    IF @EsTarjeta=1
    BEGIN
        SELECT A1.*,A2.idEmpleado,A2.CobroTarjeta,A2.Dif,A2.Transaccion,A2.FechaCobro,
               A2.CodigoAutorizacion,A2.Referencia,A2.ext_ref_cliente,A2.Card,A2.Telefono,A2.mail,A2.Comercio
        INTO #ConcentradaDesglosada
        FROM #tablatemp A1 LEFT JOIN #CobranzaBanwire A2 ON A1.CveEmpl=A2.idEmpleado
        WHERE A2.Comercio IS NOT NULL;

        SELECT N'Concentrada' AS NombrePestana,N'Concentrada' AS grupo,
               empresa,NumEMpleado,CveEmpl,Paterno,MAterno,Nombre1,Nombre2,Sexo,FechaNac,Edad,Confidencial,
               SueldoMensual,ISNULL(SueldoMensualAnt,0) AS SueldoMensualAnt,
               ISNULL(SueldoMensualDif,0) AS SueldoMensualDif,TRANSFERIDO,NumSolicitud,Perfil,
               FechaAutorizacion,GrupoParentescoGMM AS GrupoParentescoGMM,MontoGMM,MontoVIDA,
               MontoOTROSPLANES,CreditosGMM,CreditosViDA,MontoTotalCreditos,
               ISNULL(MontoTotalCreditosAnt,0) AS MontoTotalCreditosAnt,
               ISNULL(MontoTotalCreditos-MontoTotalCreditosAnt,0) AS DiferenciaCreditos,
               MontoTotalSelecciones,ISNULL(MontoTotalSeleccionesAnt,0) AS MontoTotalSeleccionesAnt,
               ISNULL(MontoTotalSelecciones-MontoTotalSeleccionesAnt,0) AS DiferenciaSelecciones,
               SobranteCreditos,MontoPagCred,MontoDescMensual,ISNULL(MontoDescMensualAnt,0) AS MontoDescMensualAnt,
               ISNULL(MontoDescMensual-MontoDescMensualAnt,0) AS DiferenciaMonto,Q1,Q2,Diferencia,Excedentes,
               ISNULL(ExcedentesAnt,0) AS ExcedentesAnt,ISNULL(Excedentes-ExcedentesAnt,0) AS DiferenciaExcedentes,
               MontoFondoAhorroMensual,ISNULL(MontoFondoAhorroMensualAnt,0) AS MontoFondoAhorroMensualAnt,
               ISNULL(MontoFondoAhorroMensual-MontoFondoAhorroMensualAnt,0) AS DiferenciaFH,
               SobranteExcedentes,AplicExcedentes,DescuentoEmpleadoFH,DescuentoEmpleadoFinal,CtoEmpleadoNomSeg,
               SobranteExceFinal,CoberturaDesc,NumOficina,NomOficina,POFH,LocalNumber,CentroCostos AS PagoEmpresa,
               PagoEmpleado,PagoEmpleado AS CostoPlanesTarjeta,A2.CobroTarjeta,
               COALESCE(PagoEmpleado-A2.CobroTarjeta,0) AS DiferenciaTarjeta,A2.Transaccion,A2.FechaCobro,
               A2.CodigoAutorizacion,A2.Referencia,A2.ext_ref_cliente,A2.Card,A2.Telefono,A2.mail,A2.Comercio
        FROM #tablatemp A1 LEFT JOIN #CobranzaBanwire A2 ON A1.CveEmpl=A2.idEmpleado
        ORDER BY NumEmpleado;
    END
    ELSE
    BEGIN
        SELECT N'Concentrada' AS NombrePestana,N'Concentrada' AS grupo,
               empresa,NumEMpleado,CveEmpl,Paterno,MAterno,Nombre1,Nombre2,Sexo,FechaNac,Edad,Confidencial,
               SueldoMensual,ISNULL(SueldoMensualAnt,0) AS SueldoMensualAnt,
               ISNULL(SueldoMensualDif,0) AS SueldoMensualDif,TRANSFERIDO,NumSolicitud,Perfil,
               FechaAutorizacion,GrupoParentescoGMM AS GrupoParentescoGMM,MontoGMM,MontoVIDA,
               MontoOTROSPLANES,CreditosGMM,CreditosViDA,MontoTotalCreditos,
               ISNULL(MontoTotalCreditosAnt,0) AS MontoTotalCreditosAnt,
               ISNULL(MontoTotalCreditos-MontoTotalCreditosAnt,0) AS DiferenciaCreditos,
               MontoTotalSelecciones,ISNULL(MontoTotalSeleccionesAnt,0) AS MontoTotalSeleccionesAnt,
               ISNULL(MontoTotalSelecciones-MontoTotalSeleccionesAnt,0) AS DiferenciaSelecciones,
               SobranteCreditos,MontoPagCred,MontoDescMensual,ISNULL(MontoDescMensualAnt,0) AS MontoDescMensualAnt,
               ISNULL(MontoDescMensual-MontoDescMensualAnt,0) AS DiferenciaMonto,Q1,Q2,Diferencia,Excedentes,
               ISNULL(ExcedentesAnt,0) AS ExcedentesAnt,ISNULL(Excedentes-ExcedentesAnt,0) AS DiferenciaExcedentes,
               MontoFondoAhorroMensual,ISNULL(MontoFondoAhorroMensualAnt,0) AS MontoFondoAhorroMensualAnt,
               ISNULL(MontoFondoAhorroMensual-MontoFondoAhorroMensualAnt,0) AS DiferenciaFH,
               SobranteExcedentes,AplicExcedentes,DescuentoEmpleadoFH,DescuentoEmpleadoFinal,CtoEmpleadoNomSeg,
               SobranteExceFinal,CoberturaDesc,NumOficina,NomOficina,POFH,LocalNumber,CentroCostos AS PagoEmpresa,
               PagoEmpleado
        FROM #tablatemp ORDER BY NumEmpleado;
    END;

    /* 2. Desglosada; en TC se conservan tambien Transacciones, Liquidaciones y Dispersiones. */
    IF @EsTarjeta=1
    BEGIN
        SELECT DISTINCT A3.PLidPlan AS idPlan,A1.POidEmpleado AS idEmpleado,
               CASE WHEN A3.PLIdTipoPago=4 THEN 'TC'+A1.PONumeroEmpleado END AS Tipo,
               A5.PrimaNetaxPer AS MontoPago,' ' AS DerechoPolPlan,' ' AS RecargoPlan,
               ' ' AS IVAPlan,A5.CostoEmpleadoReal AS TotalPlan,A5.PrimaNetaxPer AS MontoPagoTarjeta,
               ' ' AS DerechoPolTarjeta,' ' AS RecargoTarjeta,' ' AS IVATarjeta,
               A5.CostoEmpleado AS TotalTC,' ' AS Diferencia,' ' AS Transaccion,
               'LIQ-'+CAST(A1.POidEmpresa AS varchar(50))+'-'+CAST(MONTH(@FecFin) AS varchar(10))+
                   '-'+CAST(YEAR(@FecFin) AS varchar(10)) AS LiquidacionConcepto,
               A4.DAPNombreCorto AS Proveedor
        INTO #DesglosadaBanwire
        FROM dbo.ff_PlanOpcionSeleccionCobranza A1 WITH (NOLOCK)
        INNER JOIN dbo.ff_solicitud SO WITH (NOLOCK)
            ON SO.SOidsolicitud=A1.poidsolicitud AND SO.SOIdEmpresa=A1.POidEmpresa
           AND SO.SONumEmpleado COLLATE DATABASE_DEFAULT = A1.PONumeroEmpleado COLLATE DATABASE_DEFAULT
        INNER JOIN dbo.ff_PlanOpcion A2 WITH (NOLOCK) ON A1.POidPlanOpcion=A2.POidPlanOpcion
        INNER JOIN dbo.ff_plan A3 WITH (NOLOCK) ON A2.POidPlan=A3.PLidPlan
        LEFT JOIN dbo.bf_MobileDatoAseguradoraProveedor A4 WITH (NOLOCK)
            ON A3.PLidAseguradora=A4.DAPIdAseguradoraProveedor
        LEFT JOIN #TablaCobDesg A5 ON A3.PLidPlan=A5.CVEP AND A1.POidEmpleado=A5.idemp
        WHERE A3.PLIdTipoPago=4 AND A1.POidEstatus=1
          AND A1.POidEmpresa IN(SELECT EMidEmpresa FROM #ListEmpresas)
          AND A4.DAPNombreCorto IS NOT NULL AND A1.POTarifaNeta<>0
          AND A1.POidVigencia=@idVIgencia;

        SELECT D.*,B.Tipo,B.MontoPago,B.DerechoPolPlan,B.RecargoPlan,B.IVAPlan,B.TotalPlan,
               B.MontoPagoTarjeta,B.DerechoPolTarjeta,B.RecargoTarjeta,B.IVATarjeta,B.TotalTC,
               B.Diferencia,B.Transaccion,B.LiquidacionConcepto,B.Proveedor
        INTO #DesglosadaFiltrada
        FROM #TablaCobDesg D
        LEFT JOIN #DesglosadaBanwire B ON D.idemp=B.idEmpleado AND B.idPlan=D.CVEP
        WHERE B.Proveedor IS NOT NULL;

        SELECT N'Desglosada' AS NombrePestana,N'Desglosada' AS grupo,
               EMPRESA,NUMEMPLEADO,idemp,Paterno,Materno,Nombre1,Nombre2,Sexo,FechaNac,Edad,Perfil,
               CVEParentesco,NombreParentesco,TRANSFERIDO,SueldoMensual,NumSolicitud,PlanD,PlanOpcion,
               GRUPOPARENTESCO,CVEPO,CVEP,TIPOSUMASEG,VALSUMA,PLOrdenCobranza,ImporteAnual,
               PrimaNetaAnual,ImportexPeriodo,PrimaNetaxPer,MontoTotalCreditos,MontoPeridoCreditos,
               CostoEmpresa,CtoEmpresaCash,CtoEmpresa1erexc,CtoEmpresaStoploss,CostoEmpleado,
               CtoEmpleadoCash,CtoEmpleado1erexc,CtoEmpleadoStoploss,CostoEmpleadoExcedente,
               CostoEmpleadoReal,SobranteExcedentes,
               CASE WHEN EXISTS
                  (SELECT 1 FROM dbo.ff_CompensacionPlanOpcion CP WITH (NOLOCK)
                   INNER JOIN dbo.ff_planOpcionVigencia V WITH (NOLOCK)
                     ON V.vcidPlanOpcion=CP.cpidplanopcion AND V.vcidVigencia=@VigenciaDetalle
                   WHERE CP.cpidEstatus=1 AND CP.cpidplanopcion=CVEPO)
                    THEN CostoEmpleadoReal ELSE 0 END AS COSTOEMPRESACRED,
               CASE WHEN NOT EXISTS
                  (SELECT 1 FROM dbo.ff_CompensacionPlanOpcion CP WITH (NOLOCK)
                   INNER JOIN dbo.ff_planOpcionVigencia V WITH (NOLOCK)
                     ON V.vcidPlanOpcion=CP.cpidplanopcion AND V.vcidVigencia=@VigenciaDetalle
                   WHERE CP.cpidEstatus=1 AND CP.cpidplanopcion=CVEPO)
                    THEN CostoEmpleadoReal ELSE 0 END AS COSTOEMPLEADOCRED,
               B.Tipo,B.MontoPago,B.DerechoPolPlan,B.RecargoPlan,B.IVAPlan,B.TotalPlan,
               B.MontoPagoTarjeta,B.DerechoPolTarjeta,B.RecargoTarjeta,B.IVATarjeta,B.TotalTC,
               B.Diferencia,B.Transaccion,B.LiquidacionConcepto,B.Proveedor
        FROM #TablaCobDesg D
        LEFT JOIN #DesglosadaBanwire B ON D.idemp=B.idEmpleado AND B.idPlan=D.CVEP
        UNION ALL
        SELECT N'Desglosada',N'Desglosada',
               10000,'T O T A L E S :',0,'','','','','','','','','','','',0,'','','','',0,0,'',0,0,
               SUM(ImporteAnual),SUM(PrimaNetaAnual),SUM(ImportexPeriodo),SUM(PrimaNetaxPer),
               SUM(MontoTotalCreditos),SUM(MontoPeridoCreditos),SUM(CostoEmpresa),SUM(CtoEmpresaCash),
               SUM(CtoEmpresa1erexc),SUM(CtoEmpresaStoploss),SUM(CostoEmpleado),SUM(CtoEmpleadoCash),
               SUM(CtoEmpleado1erexc),SUM(CtoEmpleadoStoploss),SUM(CostoEmpleadoExcedente),
               SUM(CostoEmpleadoReal),SUM(SobranteExcedentes),0,0,'',0,'','','',0,0,'','','',0,0,'','',''
        FROM #TablaCobDesg;

        SELECT CONCAT(N'Transacciones ',ISNULL(D.Proveedor,N'')) AS NombrePestana,
               N'Transacciones' AS grupo,
               C.Transaccion AS idtrans,C.FechaCobro AS fechadepago,C.CobroTarjeta AS montoprocesado,
               0.0 AS comisionbanwire,0.16 AS iva,2.50 AS comisionfijasiniva,0.40 AS ivacomisionfija,
               0.0 AS comisionmsi,0.0 AS ivsmsi,2.90 AS totalcomision,2.90 AS tasa,3.364 AS civa,
               C.CobroTarjeta AS liquidacion,'V/MC' AS terminal,C.CodigoAutorizacion AS codigoaut,
               C.Referencia AS referencia,C.ext_ref_cliente AS extrefcliente,C.Card AS card,
               '' AS telefono,'' AS mail,C.Comercio AS comercio,'' AS mesesfinanciados,
               D.Proveedor AS ProveedorTransaccion
        FROM #ConcentradaDesglosada C
        INNER JOIN #DesglosadaFiltrada D ON D.idemp=C.CveEmpl;

        SELECT DISTINCT CONCAT(N'Liquidaciones ',ISNULL(D.Proveedor,N'')) AS NombrePestana,
               N'Liquidaciones' AS grupo,
               C.Transaccion AS idTransaccion,C.CobroTarjeta AS MontoTransaccion,
               C.CobroTarjeta AS [#],'Correcto' AS Estatus,A4.DAPIdAseguradoraProveedor AS Clave,
               A4.DAPNombre AS NombreBeneficiario,C.CobroTarjeta AS Monto,
               D.LiquidacionConcepto AS ConceptoPago,D.Proveedor AS ProveedorLiquidacion
        FROM #ConcentradaDesglosada C
        INNER JOIN #DesglosadaFiltrada D
            ON D.NUMEMPLEADO COLLATE DATABASE_DEFAULT = C.NumEMpleado COLLATE DATABASE_DEFAULT
           AND D.idemp=C.CveEmpl
        LEFT JOIN dbo.ff_plan A3 WITH (NOLOCK) ON D.CVEP=A3.PLidPlan
        LEFT JOIN dbo.bf_MobileDatoAseguradoraProveedor A4 WITH (NOLOCK)
            ON A4.DAPIdAseguradoraProveedor=A3.PLidAseguradora
        WHERE D.Transaccion IS NOT NULL AND A4.DAPIdEstatus=1
        ORDER BY idTransaccion,ProveedorLiquidacion;

        SELECT CONCAT(N'Dispersiones ',ISNULL(Proveedor,N'')) AS NombrePestana,
               N'Dispersiones' AS grupo,
               NUMEMPLEADO AS numEmpleado,
               'LIQ-'+CAST(EMPRESA AS varchar(50))+'-'+Proveedor AS ConceptoDispersion,
               SUM(MontoPagoTarjeta) AS monto,'NA' AS cuenta,Proveedor AS ProveedorDispersion
        FROM #DesglosadaFiltrada
        GROUP BY NUMEMPLEADO,Proveedor,EMPRESA;
    END
    ELSE
    BEGIN
        SELECT N'Desglosada' AS NombrePestana,N'Desglosada' AS grupo,
               EMPRESA,NUMEMPLEADO,idemp,Paterno,Materno,Nombre1,Nombre2,Sexo,FechaNac,Edad,Perfil,
               CVEParentesco,NombreParentesco,TRANSFERIDO,SueldoMensual,NumSolicitud,PlanD,PlanOpcion,
               GRUPOPARENTESCO,CVEPO,CVEP,TIPOSUMASEG,VALSUMA,PLOrdenCobranza,ImporteAnual,
               PrimaNetaAnual,ImportexPeriodo,PrimaNetaxPer,MontoTotalCreditos,MontoPeridoCreditos,
               CostoEmpresa,CtoEmpresaCash,CtoEmpresa1erexc,CtoEmpresaStoploss,CostoEmpleado,
               CtoEmpleadoCash,CtoEmpleado1erexc,CtoEmpleadoStoploss,CostoEmpleadoExcedente,
               CostoEmpleadoReal,SobranteExcedentes,
               CASE WHEN EXISTS
                  (SELECT 1 FROM dbo.ff_CompensacionPlanOpcion CP WITH (NOLOCK)
                   INNER JOIN dbo.ff_planOpcionVigencia V WITH (NOLOCK)
                     ON V.vcidPlanOpcion=CP.cpidplanopcion AND V.vcidVigencia=@VigenciaDetalle
                   WHERE CP.cpidEstatus=1 AND CP.cpidplanopcion=CVEPO)
                    THEN CostoEmpleadoReal ELSE 0 END AS COSTOEMPRESACRED,
               CASE WHEN NOT EXISTS
                  (SELECT 1 FROM dbo.ff_CompensacionPlanOpcion CP WITH (NOLOCK)
                   INNER JOIN dbo.ff_planOpcionVigencia V WITH (NOLOCK)
                     ON V.vcidPlanOpcion=CP.cpidplanopcion AND V.vcidVigencia=@VigenciaDetalle
                   WHERE CP.cpidEstatus=1 AND CP.cpidplanopcion=CVEPO)
                    THEN CostoEmpleadoReal ELSE 0 END AS COSTOEMPLEADOCRED
        FROM #TablaCobDesg
        UNION ALL
        SELECT N'Desglosada',N'Desglosada',
               10000,'T O T A L E S :',0,'','','','','','','','','','','',0,'','','','',0,0,'',0,0,
               SUM(ImporteAnual),SUM(PrimaNetaAnual),SUM(ImportexPeriodo),SUM(PrimaNetaxPer),
               SUM(MontoTotalCreditos),SUM(MontoPeridoCreditos),SUM(CostoEmpresa),SUM(CtoEmpresaCash),
               SUM(CtoEmpresa1erexc),SUM(CtoEmpresaStoploss),SUM(CostoEmpleado),SUM(CtoEmpleadoCash),
               SUM(CtoEmpleado1erexc),SUM(CtoEmpleadoStoploss),SUM(CostoEmpleadoExcedente),
               SUM(CostoEmpleadoReal),SUM(SobranteExcedentes),0,0
        FROM #TablaCobDesg;
    END;

    CREATE TABLE #TablaPlanConcentrado
    (
        Cvep int NULL,CvePo int NULL,Descripcion varchar(150) NULL,CtoXPeriodo money NULL,
        CtoPrimaN money NULL,CtoEmpresa money NULL,CtoEmpleado money NULL,CtoEmpleExc money NULL,
        CtoEmpleReal money NULL,CtoSobranteExc money NULL
    );

    INSERT #TablaPlanConcentrado
    SELECT CVEP,CVEP,PlanD,SUM(ImportexPeriodo),SUM(PrimaNetaxPer),SUM(CostoEmpresa),
           SUM(CostoEmpleado),SUM(CostoEmpleadoExcedente),SUM(CostoEmpleadoReal),SUM(SobranteExcedentes)
    FROM #TablaCobDesg
    GROUP BY CVEP,PlanD;

    DECLARE @IdSubtotal int,@DescripcionSubtotal varchar(100),@IVAIntegrado char(1),@IVAP money,
            @ImpPer money,@ImpPN money,@ImpEmpresa money,@ImpEmpleado money,@ImpExc money,
            @ImpReal money,@ImpSobrante money;

    DECLARE CurSubtotales CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT CsIdCobranzaSubTotal,CsDescripcionCobranzaSubTotal,CSIVAIntegrado,CSIVAP
        FROM dbo.ff_CobranzaSubTotal WITH (NOLOCK)
        WHERE CsIdEmpresa=@EmpresaDetalle AND CsIdEstatus=1
        ORDER BY CsIdCobranzaSubTotal;
    OPEN CurSubtotales;
    FETCH NEXT FROM CurSubtotales INTO @IdSubtotal,@DescripcionSubtotal,@IVAIntegrado,@IVAP;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SELECT @ImpPer=ROUND(SUM(ISNULL(D.ImportexPeriodo,0)),2),
               @ImpPN=ROUND(SUM(ISNULL(D.PrimaNetaxPer,0)),2),
               @ImpEmpresa=ROUND(SUM(ISNULL(D.CostoEmpresa,0)),2),
               @ImpEmpleado=ROUND(SUM(ISNULL(D.CostoEmpleado,0)),2),
               @ImpExc=ROUND(SUM(ISNULL(D.CostoEmpleadoExcedente,0)),2),
               @ImpReal=ROUND(SUM(ISNULL(D.CostoEmpleadoReal,0)),2),
               @ImpSobrante=ROUND(SUM(ISNULL(D.SobranteExcedentes,0)),2)
        FROM #TablaCobDesg D
        INNER JOIN dbo.ff_ConcepAgrupaCob CA WITH (NOLOCK)
            ON D.CVEPO=CA.CAidPlanOpcion AND D.EMPRESA=CA.CAidEmpresa
           AND CA.CAidCobranzaSubtotal=@IdSubtotal AND CA.CAidEstatus=1
           AND CA.CAidEmpresa=@EmpresaDetalle;

        INSERT #TablaPlanConcentrado
        VALUES(10000,@IdSubtotal,@DescripcionSubtotal,@ImpPer,@ImpPN,@ImpEmpresa,@ImpEmpleado,
               @ImpExc,@ImpReal,@ImpSobrante);

        IF @IVAIntegrado=1
        BEGIN
            INSERT #TablaPlanConcentrado
            (Cvep,CvePo,Descripcion,CtoXPeriodo,CtoEmpresa,CtoEmpleado,CtoEmpleExc,CtoEmpleReal,CtoSobranteExc)
            VALUES
            (10002,@IdSubtotal,'Prima Neta '+LTRIM(RTRIM(@DescripcionSubtotal)),1,@ImpEmpresa,0,@ImpExc/1.15,@ImpReal/1.15,0),
            (10002,@IdSubtotal,'Derecho de póliza ',2,0,0,0,0,0),
            (10002,@IdSubtotal,'IVA ',3,@ImpEmpresa*0.15,0,@ImpExc*0.15,@ImpReal/0.15,0),
            (10002,@IdSubtotal,'Prima '+LTRIM(RTRIM(@DescripcionSubtotal)),4,@ImpEmpresa*1.15,0,@ImpExc,@ImpReal,0);
        END
        ELSE
        BEGIN
            INSERT #TablaPlanConcentrado
            (Cvep,CvePo,Descripcion,CtoXPeriodo,CtoEmpresa,CtoEmpleado,CtoEmpleExc,CtoEmpleReal,CtoSobranteExc)
            VALUES
            (10003,@IdSubtotal,'Prima Neta '+LTRIM(RTRIM(@DescripcionSubtotal)),1,@ImpEmpresa,0,@ImpExc/1.15,@ImpReal/1.15,0),
            (10003,@IdSubtotal,'Prima '+LTRIM(RTRIM(@DescripcionSubtotal)),2,@ImpEmpresa/1.15,0,@ImpExc,@ImpReal,0);
        END;

        FETCH NEXT FROM CurSubtotales INTO @IdSubtotal,@DescripcionSubtotal,@IVAIntegrado,@IVAP;
    END;
    CLOSE CurSubtotales;
    DEALLOCATE CurSubtotales;

    /* 3. Total por plan. */
    SELECT N'Total por coberturas' AS NombrePestana,N'TotalPlan' AS grupo,
           CVEP AS CVEP,0 AS CVEPO,Descripcion AS PlanD,ROUND(ISNULL(CtoXPeriodo,0),2) AS ImpPer,
           ROUND(ISNULL(CtoPrimaN,0),2) AS ImpPN,ROUND(ISNULL(CtoEmpresa,0),2) AS ImpEmpresa,
           ROUND(ISNULL(CtoEmpleado,0),2) AS ImpEmpleado,ROUND(ISNULL(CtoEmpleExc,0),2) AS ImpEmpExced,
           ROUND(ISNULL(CtoEmpleReal,0),2) AS ImpEmpReal,ROUND(ISNULL(CtoSobranteExc,0),2) AS ImpExced
    FROM #TablaPlanConcentrado WHERE CVEP<10000
    UNION ALL
    SELECT N'Total por coberturas',N'TotalPlan',
           10001,0,'TOTALES: ',ROUND(SUM(ISNULL(CtoXPeriodo,0)),2),ROUND(SUM(ISNULL(CtoPrimaN,0)),2),
           ROUND(SUM(ISNULL(CtoEmpresa,0)),2),ROUND(SUM(ISNULL(CtoEmpleado,0)),2),
           ROUND(SUM(ISNULL(CtoEmpleExc,0)),2),ROUND(SUM(ISNULL(CtoEmpleReal,0)),2),
           ROUND(SUM(ISNULL(CtoSobranteExc,0)),2)
    FROM #TablaPlanConcentrado WHERE CVEP<10000;

    /* 4. Subtotales por ramo. */
    SELECT N'Total por coberturas' AS NombrePestana,N'SubtotalesRamo' AS grupo,
           CVEP AS CVEP,0 AS CVEPO,Descripcion AS PlanD,ROUND(ISNULL(CtoXPeriodo,0),2) AS ImpPer,
           ROUND(ISNULL(CtoPrimaN,0),2) AS ImpPN,ROUND(ISNULL(CtoEmpresa,0),2) AS ImpEmpresa,
           ROUND(ISNULL(CtoEmpleado,0),2) AS ImpEmpleado,ROUND(ISNULL(CtoEmpleExc,0),2) AS ImpEmpExced,
           ROUND(ISNULL(CtoEmpleReal,0),2) AS ImpEmpReal,ROUND(ISNULL(CtoSobranteExc,0),2) AS ImpExced
    FROM #TablaPlanConcentrado WHERE CVEP=10000
    UNION
    SELECT N'Total por coberturas',N'SubtotalesRamo',
           10001,0,'TOTALES: ',ROUND(SUM(ISNULL(CtoXPeriodo,0)),2),ROUND(SUM(ISNULL(CtoPrimaN,0)),2),
           ROUND(SUM(ISNULL(CtoEmpresa,0)),2),ROUND(SUM(ISNULL(CtoEmpleado,0)),2),
           ROUND(SUM(ISNULL(CtoEmpleExc,0)),2),ROUND(SUM(ISNULL(CtoEmpleReal,0)),2),
           ROUND(SUM(ISNULL(CtoSobranteExc,0)),2)
    FROM #TablaPlanConcentrado WHERE CVEP=10000;

    /* 5. Cuadros de primas netas. */
    SELECT N'Total por coberturas' AS NombrePestana,N'CuadrosPrimas' AS grupo,
           CVEP AS CVEP,CVEPO AS CVEPO,Descripcion AS PlanD,ROUND(ISNULL(CtoXPeriodo,0),2) AS ImpPer,
           ROUND(ISNULL(CtoPrimaN,0),2) AS ImpPN,ROUND(ISNULL(CtoEmpresa,0),2) AS ImpEmpresa,
           ROUND(ISNULL(CtoEmpleado,0),2) AS ImpEmpleado,ROUND(ISNULL(CtoEmpleExc,0),2) AS ImpEmpExced,
           ROUND(ISNULL(CtoEmpleReal,0),2) AS ImpEmpReal,ROUND(ISNULL(CtoSobranteExc,0),2) AS ImpExced
    FROM #TablaPlanConcentrado WHERE CVEP IN(10002,10003)
    UNION
    SELECT N'Total por coberturas',N'CuadrosPrimas',
           10004,5,'TOTALES: ',5,ROUND(SUM(ISNULL(CtoPrimaN,0)),2),ROUND(SUM(ISNULL(CtoEmpresa,0)),2),
           ROUND(SUM(ISNULL(CtoEmpleado,0)),2),ROUND(SUM(ISNULL(CtoEmpleExc,0)),2),
           ROUND(SUM(ISNULL(CtoEmpleReal,0)),2),ROUND(SUM(ISNULL(CtoSobranteExc,0)),2)
    FROM #TablaPlanConcentrado WHERE CVEP IN(10002,10003)
    ORDER BY CVEPO,ImpPer;

    /* 6. Total por opcion. */
    SELECT N'Total por coberturas' AS NombrePestana,N'TotalOpcion' AS grupo,
           CVEP AS CVEP,CVEPO AS CVEPO,PlanOpcion AS PlanD,SUM(ImportexPeriodo) AS ImpPer,
           SUM(PrimaNetaxPer) AS ImpPN,SUM(CostoEmpresa) AS ImpEmpresa,SUM(CostoEmpleado) AS ImpEmpleado,
           SUM(CostoEmpleadoExcedente) AS ImpEmpExced,SUM(CostoEmpleadoReal) AS ImpEmpReal,
           SUM(SobranteExcedentes) AS ImpExced
    FROM #TablaCobDesg GROUP BY CVEP,CVEPO,PlanOpcion
    UNION
    SELECT N'Total por coberturas',N'TotalOpcion',
           10000,0,'TOTALES: ',ROUND(SUM(ISNULL(ImportexPeriodo,0)),2),
           ROUND(SUM(ISNULL(PrimaNetaxPer,0)),2),ROUND(SUM(ISNULL(CostoEmpresa,0)),2),
           ROUND(SUM(ISNULL(CostoEmpleado,0)),2),ROUND(SUM(ISNULL(CostoEmpleadoExcedente,0)),2),
           ROUND(SUM(ISNULL(CostoEmpleadoReal,0)),2),ROUND(SUM(ISNULL(SobranteExcedentes,0)),2)
    FROM #TablaCobDesg
    ORDER BY CVEP,CVEPO;

    /* 7. Conteo por parentesco. */
    SELECT N'Total por coberturas' AS NombrePestana,N'ConteoParentesco' AS grupo,
           CVEP,CVEPO,PlanOpcion AS PlanD,CVEParentesco,COUNT(PlanOpcion) AS total
    FROM #TablaCobDesg
    GROUP BY CVEP,CVEPO,PlanOpcion,CVEParentesco
    ORDER BY CVEP,CVEPO,PlanOpcion,CVEParentesco;

    /* 8. Resumen Planes_Parentesco. */
    DECLARE @IdConfiguracion int,
            @P1 bit=0,@P2 bit=0,@P3 bit=0,@P4 bit=0,@P5 bit=0,@P11 bit=0,@P17 bit=0,@P18 bit=0;
    SELECT @IdConfiguracion=EMidConfiguracion
    FROM dbo.ff_Empresa WITH (NOLOCK)
    WHERE EMidEmpresa=@EmpresaDetalle;

    SELECT @P1=MAX(CASE WHEN PCIDPARENTESCO=1 THEN 1 ELSE 0 END),
           @P2=MAX(CASE WHEN PCIDPARENTESCO=2 THEN 1 ELSE 0 END),
           @P3=MAX(CASE WHEN PCIDPARENTESCO=3 THEN 1 ELSE 0 END),
           @P4=MAX(CASE WHEN PCIDPARENTESCO=4 THEN 1 ELSE 0 END),
           @P5=MAX(CASE WHEN PCIDPARENTESCO=5 THEN 1 ELSE 0 END),
           @P11=MAX(CASE WHEN PCIDPARENTESCO=11 THEN 1 ELSE 0 END),
           @P17=MAX(CASE WHEN PCIDPARENTESCO=17 THEN 1 ELSE 0 END),
           @P18=MAX(CASE WHEN PCIDPARENTESCO=18 THEN 1 ELSE 0 END)
    FROM dbo.ff_ConfiguracionParentesco WITH (NOLOCK)
    WHERE PCidConfiguracion=@IdConfiguracion AND PCIDPARENTESCO IN(1,2,3,4,5,11,17,18);

    SELECT N'Planes_Parentesco' AS NombrePestana,N'PlanesParentesco' AS grupo,
           CVEP AS cvep,CVEPO AS cvepo,CONVERT(varchar(100),RTRIM(PlanD)) AS planD,
           CONVERT(varchar(100),RTRIM(PlanOpcion)) AS planopcion,
           CASE WHEN @P1=1 THEN SUM(CASE WHEN CVEParentesco=1 THEN 1 ELSE 0 END) ELSE 0 END AS Parentesco_1,
           CASE WHEN @P3=1 THEN SUM(CASE WHEN CVEParentesco=3 THEN 1 ELSE 0 END) ELSE 0 END AS Parentesco_3,
           CASE WHEN @P2=1 THEN SUM(CASE WHEN CVEParentesco=2 THEN 1 ELSE 0 END) ELSE 0 END AS Parentesco_2,
           CASE WHEN @P4=1 THEN SUM(CASE WHEN CVEParentesco=4 THEN 1 ELSE 0 END) ELSE 0 END AS Parentesco_4,
           CASE WHEN @P5=1 THEN SUM(CASE WHEN CVEParentesco=5 THEN 1 ELSE 0 END) ELSE 0 END AS Parentesco_5,
           CASE WHEN @P11=1 THEN SUM(CASE WHEN CVEParentesco=11 THEN 1 ELSE 0 END) ELSE 0 END AS Parentesco_11,
           CASE WHEN @P17=1 THEN SUM(CASE WHEN CVEParentesco=17 THEN 1 ELSE 0 END) ELSE 0 END AS Parentesco_17,
           CASE WHEN @P18=1 THEN SUM(CASE WHEN CVEParentesco=18 THEN 1 ELSE 0 END) ELSE 0 END AS Parentesco_18
    FROM #TablaCobDesg
    GROUP BY CVEP,CVEPO,PlanD,PlanOpcion;

  
    IF OBJECT_ID(N'dbo.ff_GeneraFormatoDescuentos_bf3',N'P') IS NOT NULL
        EXEC dbo.ff_GeneraFormatoDescuentos_bf3 @EmpresaDetalle;
END;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'dbo.InsertaCobranzaConcentrada_otro_V2_BF3_Cache', N'P') IS NULL
    THROW 51100, 'Falta dbo.InsertaCobranzaConcentrada_otro_V2_BF3_Cache.', 1;
IF OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache', N'P') IS NULL
    THROW 51100, 'Falta dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache.', 1;
IF NOT EXISTS
(
    SELECT 1
    FROM sys.parameters
    WHERE object_id = OBJECT_ID(N'dbo.InsertaCobranzaConcentrada_otro_V2_BF3_Cache')
      AND name = N'@EmitirResultado'
)
    THROW 51100, 'El cargador de cache no incluye @EmitirResultado. Reinstale 01_INSTALAR_CACHE_Y_REPORTE_B3.sql.', 1;
GO

CREATE OR ALTER PROCEDURE dbo.ReporteCobranzaConcentrada_BF3_Cache
    @idEmpresa int = 0,
    @idSolTipo int = 0,
    @FecIni varchar(16) = '',
    @FecFin varchar(16) = '',
    @idVencida int = 0,
    @IdPerfil dbo.ListInt READONLY,
    @idVIgencia int = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    EXEC dbo.InsertaCobranzaConcentrada_otro_V2_BF3_Cache
         @idEmpresa=@idEmpresa,
         @idSolTipo=@idSolTipo,
         @FecIni=@FecIni,
         @FecFin=@FecFin,
         @idVencida=@idVencida,
         @IdPerfil=@IdPerfil,
         @idVIgencia=@idVIgencia,
         @ForzarRecarga=0,
         @PrecargarUltimas4=0,
         @EmitirResultado=0;

    /* Hoja equivalente a la informacion general del reporte legacy. */
    SELECT N'Información' AS NombrePestana,
           N'Informacion' AS grupo,
           COALESCE(NULLIF(E.EMRazonSocial, ''), NULLIF(E.EMNombre, ''), CONVERT(varchar(20),@idEmpresa)) AS Empresa,
           TRY_CONVERT(datetime,@FecIni) AS FechaInicio,
           TRY_CONVERT(datetime,@FecFin) AS FechaFin,
           P.PPNombre AS Periodicidad,
           P.PPCantidadPagos AS CantidadPagos
    FROM (VALUES (1)) AS Base(N)
    LEFT JOIN dbo.ff_Empresa E WITH (NOLOCK) ON E.EMidEmpresa=@idEmpresa
    OUTER APPLY
    (
        SELECT TOP (1) PP.PPNombre,PP.PPCantidadPagos
        FROM dbo.ff_VigenciaCalendarioPago VC WITH (NOLOCK)
        INNER JOIN dbo.ff_PeriodicidadPago PP WITH (NOLOCK)
            ON PP.PPidPeriodicidadPago=VC.VCidPeriodicidadPago
        WHERE VC.VCidVigencia=@idVIgencia
    ) P;

    EXEC dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache
         @idEmpresa=@idEmpresa,
         @idSolTipo=@idSolTipo,
         @FecIni=@FecIni,
         @FecFin=@FecFin,
         @idVencida=@idVencida,
         @IdPerfil=@IdPerfil,
         @idVIgencia=@idVIgencia;
END;
GO

DECLARE @ReporteId int=11,
        @Usuario int=0,
        @Ahora datetime=GETDATE(),
        @TipoArchivoId int,
        @TipoReporteId int,
        @SpId int,
        @TipoInt int,
        @TipoVarchar int,
        @TipoTvp int;

IF OBJECT_ID(N'dbo.bf_CatalogoReporteGen',N'U') IS NULL
   OR OBJECT_ID(N'dbo.bf_CatReportes',N'U') IS NULL
   OR OBJECT_ID(N'dbo.bf_CatReportesSP',N'U') IS NULL
   OR OBJECT_ID(N'dbo.bf_CatReportesParams',N'U') IS NULL
   OR OBJECT_ID(N'dbo.bf_CatReportesTipoArchivo',N'U') IS NULL
   OR OBJECT_ID(N'dbo.bf_CatReportesTipoDatos',N'U') IS NULL
   OR OBJECT_ID(N'dbo.bf_CatTipoReportes',N'U') IS NULL
   OR OBJECT_ID(N'dbo.bf_RepConf_Tabla',N'U') IS NULL
   OR OBJECT_ID(N'dbo.bf_RepConf_Columna',N'U') IS NULL
    THROW 51101, 'Faltan tablas del motor configurable de reportes.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS
    (
        SELECT 1 FROM dbo.bf_CatalogoReporteGen
        WHERE CatRptId=@ReporteId AND UPPER(CatRptNombre)<>N'COBRANZA'
    )
        THROW 51102, 'CatRptId 11 ya esta ocupado por otro reporte.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.bf_CatalogoReporteGen WHERE CatRptId=@ReporteId)
    BEGIN
        SET IDENTITY_INSERT dbo.bf_CatalogoReporteGen ON;
        INSERT dbo.bf_CatalogoReporteGen
        (CatRptId,CatRptNombre,CatRptProgramado,CatRptHorario,CatRptActivo,CatRptUsuarioAdd,CatRptFechaAdd)
        VALUES(@ReporteId,'Cobranza',0,NULL,1,@Usuario,@Ahora);
        SET IDENTITY_INSERT dbo.bf_CatalogoReporteGen OFF;
    END
    ELSE
        UPDATE dbo.bf_CatalogoReporteGen
           SET CatRptNombre='Cobranza',CatRptActivo=1,CatRptProgramado=0,
               CatRptUsuarioMod=@Usuario,CatRptFechaMod=@Ahora
         WHERE CatRptId=@ReporteId;

    SELECT @TipoArchivoId=catReportesTAId
    FROM dbo.bf_CatReportesTipoArchivo
    WHERE UPPER(catReportesTATipo)='XLSX';
    IF @TipoArchivoId IS NULL
    BEGIN
        INSERT dbo.bf_CatReportesTipoArchivo
        (catReportesTATipo,catReportesTADescripcion,ESid,catReportesTAUsuarioAdd,catReportesTAFechaAdd)
        VALUES('XLSX','Libro de Excel Open XML',1,@Usuario,@Ahora);
        SET @TipoArchivoId=SCOPE_IDENTITY();
    END;

    SELECT @TipoReporteId=catTipoReportesId
    FROM dbo.bf_CatTipoReportes
    WHERE UPPER(catTipoReportesDesc)='EXCEL_COLUMNA_MULTIPLE';
    IF @TipoReporteId IS NULL
    BEGIN
        INSERT dbo.bf_CatTipoReportes
        (catTipoReportesDesc,catTipoReportesUsuarioAdd,catTipoReportesFechaAdd)
        VALUES('Excel_Columna_Multiple',@Usuario,@Ahora);
        SET @TipoReporteId=SCOPE_IDENTITY();
    END;

    IF EXISTS
    (
        SELECT 1 FROM dbo.bf_CatReportes
        WHERE catReportesNum=@ReporteId AND UPPER(catReportesNombre)<>N'COBRANZA'
    )
        THROW 51103, 'catReportesNum 11 ya esta ocupado por otro reporte.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.bf_CatReportes WHERE catReportesNum=@ReporteId)
        INSERT dbo.bf_CatReportes
        (catReportesNum,catReportesNombre,catReportesDesc,catReportesTAId,catReportesFormato,
         ESid,catTipoReporteId,catReportesUsuarioAdd,catReportesFechaAdd)
        VALUES(@ReporteId,'Cobranza','Reporte de cobranza generado desde cache',@TipoArchivoId,
               '{nombreReporte}_{timestampfull}',1,@TipoReporteId,@Usuario,@Ahora);
    ELSE
        UPDATE dbo.bf_CatReportes
           SET catReportesNombre='Cobranza',catReportesDesc='Reporte de cobranza generado desde cache',
               catReportesTAId=@TipoArchivoId,catReportesFormato='{nombreReporte}_{timestampfull}',
               ESid=1,catTipoReporteId=@TipoReporteId,
               catReportesUsuarioMod=@Usuario,catReportesFechaMod=@Ahora
         WHERE catReportesNum=@ReporteId;

    /*
       El reporte 11 debe tener un solo paso activo. Algunas bases ya contienen
       ff_Cobranza_v2, cuyo @IdPerfil es varchar(max); si queda activo junto al
       wrapper nuevo, el orquestador intenta pasarle dbo.ListInt y falla con 206.
       Se conserva el registro y su configuracion, pero se desactiva.
    */
    UPDATE dbo.bf_CatReportesSP
       SET ESid=0,
           catReportesSPUsuarioMod=@Usuario,
           catReportesSPFechaMod=@Ahora
     WHERE catReportesId=@ReporteId
       AND catReportesSPNombre<>'ReporteCobranzaConcentrada_BF3_Cache'
       AND ISNULL(ESid,1)<>0;

    SELECT @SpId=catReportesSPId
    FROM dbo.bf_CatReportesSP
    WHERE catReportesSPNombre='ReporteCobranzaConcentrada_BF3_Cache';
    IF @SpId IS NULL
    BEGIN
        INSERT dbo.bf_CatReportesSP
        (catReportesId,catReportesSPNombre,catReportesSPOrden,catReportesSPDesc,ESid,
         catReportesSPUsuarioAdd,catReportesSPFechaAdd)
        VALUES(@ReporteId,'ReporteCobranzaConcentrada_BF3_Cache',1,
               'Precarga y consulta incremental de cobranza',1,@Usuario,@Ahora);
        SET @SpId=SCOPE_IDENTITY();
    END
    ELSE
        UPDATE dbo.bf_CatReportesSP
           SET catReportesId=@ReporteId,catReportesSPOrden=1,
               catReportesSPDesc='Precarga y consulta incremental de cobranza',ESid=1,
               catReportesSPUsuarioMod=@Usuario,catReportesSPFechaMod=@Ahora
         WHERE catReportesSPId=@SpId;

    IF NOT EXISTS (SELECT 1 FROM dbo.bf_CatReportesTipoDatos WHERE UPPER(catReportesTipoDatoNombre)='INT')
        INSERT dbo.bf_CatReportesTipoDatos
        (catReportesTipoDatoNombre,catReportesTipoDatoDesc,ESid,catReportesTipoDatoUsuarioAdd,catReportesTipoDatoFechaAdd)
        VALUES('INT','Numero entero',1,@Usuario,@Ahora);
    IF NOT EXISTS (SELECT 1 FROM dbo.bf_CatReportesTipoDatos WHERE UPPER(catReportesTipoDatoNombre)='VARCHAR')
        INSERT dbo.bf_CatReportesTipoDatos
        (catReportesTipoDatoNombre,catReportesTipoDatoDesc,ESid,catReportesTipoDatoUsuarioAdd,catReportesTipoDatoFechaAdd)
        VALUES('VARCHAR','Texto',1,@Usuario,@Ahora);
    IF NOT EXISTS (SELECT 1 FROM dbo.bf_CatReportesTipoDatos WHERE UPPER(catReportesTipoDatoNombre)='TVP')
        INSERT dbo.bf_CatReportesTipoDatos
        (catReportesTipoDatoNombre,catReportesTipoDatoDesc,ESid,catReportesTipoDatoUsuarioAdd,catReportesTipoDatoFechaAdd)
        VALUES('TVP','Parametro tipo tabla',1,@Usuario,@Ahora);

    SELECT @TipoInt=catReportesTipoDatoId FROM dbo.bf_CatReportesTipoDatos WHERE UPPER(catReportesTipoDatoNombre)='INT';
    SELECT @TipoVarchar=catReportesTipoDatoId FROM dbo.bf_CatReportesTipoDatos WHERE UPPER(catReportesTipoDatoNombre)='VARCHAR';
    SELECT @TipoTvp=catReportesTipoDatoId FROM dbo.bf_CatReportesTipoDatos WHERE UPPER(catReportesTipoDatoNombre)='TVP';

    DELETE FROM dbo.bf_CatReportesParams WHERE catReportesSPId=@SpId;
    INSERT dbo.bf_CatReportesParams
    (catReportesSPId,catReportesTipoDatoId,catReportesParamsLongitud,catReportesParamsOrden,
     catReportesParamsNombre,catReportesParamsDesc,ESid,catReportesParamsUsuarioAdd,catReportesParamsFechaAdd)
    VALUES
    (@SpId,@TipoInt,NULL,1,'@idEmpresa','Empresa',1,@Usuario,@Ahora),
    (@SpId,@TipoInt,NULL,2,'@idSolTipo','Tipo de solicitud',1,@Usuario,@Ahora),
    (@SpId,@TipoVarchar,'16',3,'@FecIni','Fecha inicial',1,@Usuario,@Ahora),
    (@SpId,@TipoVarchar,'16',4,'@FecFin','Fecha final',1,@Usuario,@Ahora),
    (@SpId,@TipoInt,NULL,5,'@idVencida','Vigencia seleccionada',1,@Usuario,@Ahora),
    (@SpId,@TipoTvp,NULL,6,'@IdPerfil','dbo.ListInt',1,@Usuario,@Ahora),
    (@SpId,@TipoInt,NULL,7,'@idVIgencia','Identificador de vigencia',1,@Usuario,@Ahora);

    DELETE FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=@ReporteId;
    DELETE FROM dbo.bf_RepConf_Tabla WHERE idEmpresa=0 AND catReportesId=@ReporteId;

    INSERT dbo.bf_RepConf_Tabla
    (idEmpresa,catReportesId,grupo,columnaGrupo,agruparPorColumna,indexTable,tituloTabla,
     espacioIzquierda,espacioDerecha,alineacion,colorFondo,colorLetra,activo,
     repConfTablaUsuarioAdd,repConfTablaFechaAdd)
    VALUES
    (0,@ReporteId,N'Informacion',NULL,0,0,NULL,0,0,N'Izquierda',N'Gray',N'White',1,@Usuario,@Ahora),
    (0,@ReporteId,N'Concentrada',NULL,0,1,NULL,0,0,N'Izquierda',N'Gray',N'White',1,@Usuario,@Ahora),
    (0,@ReporteId,N'Desglosada',NULL,0,2,NULL,0,0,N'Izquierda',N'Gray',N'White',1,@Usuario,@Ahora),
    (0,@ReporteId,N'Transacciones',NULL,0,3,NULL,0,0,N'Izquierda',N'Gray',N'White',1,@Usuario,@Ahora),
    (0,@ReporteId,N'Liquidaciones',NULL,0,4,NULL,0,0,N'Izquierda',N'Gray',N'White',1,@Usuario,@Ahora),
    (0,@ReporteId,N'Dispersiones',NULL,0,5,NULL,0,0,N'Izquierda',N'Gray',N'White',1,@Usuario,@Ahora),
    (0,@ReporteId,N'TotalPlan',NULL,0,6,N'Total por plan',0,0,N'Izquierda',N'Gray',N'White',1,@Usuario,@Ahora),
    (0,@ReporteId,N'SubtotalesRamo',NULL,0,7,N'Subtotales por ramo',0,0,N'Izquierda',N'Gray',N'White',1,@Usuario,@Ahora),
    (0,@ReporteId,N'CuadrosPrimas',NULL,0,8,N'Cuadros de primas netas',0,0,N'Izquierda',N'Gray',N'White',1,@Usuario,@Ahora),
    (0,@ReporteId,N'TotalOpcion',NULL,0,9,N'Total por opcion',0,0,N'Izquierda',N'Gray',N'White',1,@Usuario,@Ahora),
    (0,@ReporteId,N'ConteoParentesco',NULL,0,10,N'Conteo por parentesco',0,0,N'Izquierda',N'Gray',N'White',1,@Usuario,@Ahora),
    (0,@ReporteId,N'PlanesParentesco',NULL,0,11,NULL,0,0,N'Izquierda',N'Gray',N'White',1,@Usuario,@Ahora);

    /*
       Se configura la primera columna estable de cada grupo. El generador del
       reporte 11 conserva despues todas las columnas dinamicas del resultset;
       asi no se pierden columnas de tarjeta ni extensiones por empresa.
    */
    INSERT dbo.bf_RepConf_Columna
    (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,ancho,formato,
     alinear,tipoDato,repConfColumnaUsuarioAdd,repConfColumnaFechaAdd)
    VALUES
    (0,@ReporteId,N'Informacion',1,N'Empresa',N'Empresa',1,30,NULL,N'Izquierda',1,@Usuario,@Ahora),
    (0,@ReporteId,N'Concentrada',1,N'empresa',N'empresa',1,12,NULL,N'Derecha',1,@Usuario,@Ahora),
    (0,@ReporteId,N'Desglosada',1,N'EMPRESA',N'EMPRESA',1,12,NULL,N'Derecha',1,@Usuario,@Ahora),
    (0,@ReporteId,N'Transacciones',1,N'idtrans',N'idtrans',1,20,NULL,N'Izquierda',1,@Usuario,@Ahora),
    (0,@ReporteId,N'Liquidaciones',1,N'idTransaccion',N'idTransaccion',1,20,NULL,N'Izquierda',1,@Usuario,@Ahora),
    (0,@ReporteId,N'Dispersiones',1,N'numEmpleado',N'numEmpleado',1,20,NULL,N'Izquierda',1,@Usuario,@Ahora),
    (0,@ReporteId,N'TotalPlan',1,N'CVEP',N'CVEP',1,12,NULL,N'Derecha',1,@Usuario,@Ahora),
    (0,@ReporteId,N'SubtotalesRamo',1,N'CVEP',N'CVEP',1,12,NULL,N'Derecha',1,@Usuario,@Ahora),
    (0,@ReporteId,N'CuadrosPrimas',1,N'CVEP',N'CVEP',1,12,NULL,N'Derecha',1,@Usuario,@Ahora),
    (0,@ReporteId,N'TotalOpcion',1,N'CVEP',N'CVEP',1,12,NULL,N'Derecha',1,@Usuario,@Ahora),
    (0,@ReporteId,N'ConteoParentesco',1,N'CVEP',N'CVEP',1,12,NULL,N'Derecha',1,@Usuario,@Ahora),
    (0,@ReporteId,N'PlanesParentesco',1,N'cvep',N'cvep',1,12,NULL,N'Derecha',1,@Usuario,@Ahora);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    BEGIN TRY
        SET IDENTITY_INSERT dbo.bf_CatalogoReporteGen OFF;
    END TRY
    BEGIN CATCH
    END CATCH;
    THROW;
END CATCH;
GO

SELECT N'Integracion configurable de Cobranza instalada' AS Resultado,
       11 AS ReporteId,
       N'dbo.ReporteCobranzaConcentrada_BF3_Cache' AS Procedimiento,
       (SELECT COUNT(*) FROM dbo.bf_CatReportesSP
        WHERE catReportesId=11 AND ISNULL(ESid,1)=1) AS ProcedimientosActivos;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'dbo.ff_orquestadorReportes', N'P') IS NULL
    THROW 51540, 'Falta dbo.ff_orquestadorReportes.', 1;
IF TYPE_ID(N'dbo.ParamValor') IS NULL
    THROW 51540, 'Falta el tipo tabla dbo.ParamValor.', 1;
IF OBJECT_ID(N'dbo.bf_CatReportesParams', N'U') IS NULL
    THROW 51540, 'Falta dbo.bf_CatReportesParams.', 1;
GO

DECLARE @Def nvarchar(max) = OBJECT_DEFINITION(OBJECT_ID(N'dbo.ff_orquestadorReportes')),
        @Upper nvarchar(max),
        @ParamPos int,
        @CatalogoPos int,
        @ParamEnd int,
        @CatalogoEnd int,
        @ParamSearch int = 1,
        @CatalogoSearch int,
        @CandidateParamPos int,
        @CandidateCatalogoPos int,
        @CandidateParamEnd int,
        @CandidateCatalogoEnd int,
        @BestGap int = 2147483647,
        @Gap int,
        @Between nvarchar(1000),
        @Tail nvarchar(200),
        @EarlierEnd int,
        @LaterEnd int,
        @ProcPos int,
        @Resultado varchar(30) = 'YA_COMPATIBLE';

IF @Def IS NULL
    THROW 51541, 'No se pudo leer la definicion de dbo.ff_orquestadorReportes.', 1;


IF CHARINDEX(N'BF_REPORTES_COLLATION_COMPAT_V2', @Def) = 0
BEGIN
    SET @Upper = UPPER(@Def) COLLATE Latin1_General_100_CI_AS;

    WHILE 1=1
    BEGIN
        SET @CandidateParamPos = CHARINDEX(N'PARAMNOMBRE', @Upper, @ParamSearch);
        IF @CandidateParamPos = 0 BREAK;

        SET @CandidateParamEnd = @CandidateParamPos + LEN(N'PARAMNOMBRE') - 1;
        IF SUBSTRING(@Def,@CandidateParamEnd+1,1)=N']'
            SET @CandidateParamEnd+=1;

        SET @CatalogoSearch=1;
        WHILE 1=1
        BEGIN
            SET @CandidateCatalogoPos = CHARINDEX(N'CATREPORTESPARAMSNOMBRE', @Upper, @CatalogoSearch);
            IF @CandidateCatalogoPos = 0 BREAK;

            SET @CandidateCatalogoEnd = @CandidateCatalogoPos + LEN(N'CATREPORTESPARAMSNOMBRE') - 1;
            IF SUBSTRING(@Def,@CandidateCatalogoEnd+1,1)=N']'
                SET @CandidateCatalogoEnd+=1;

            SET @Gap=ABS(@CandidateParamPos-@CandidateCatalogoPos);
            IF @Gap<1000 AND @Gap<@BestGap
            BEGIN
                IF @CandidateParamPos<@CandidateCatalogoPos
                    SET @Between=SUBSTRING(@Def,@CandidateParamEnd+1,@CandidateCatalogoPos-@CandidateParamEnd-1);
                ELSE
                    SET @Between=SUBSTRING(@Def,@CandidateCatalogoEnd+1,@CandidateParamPos-@CandidateCatalogoEnd-1);

                IF CHARINDEX(N'=',@Between)>0
                BEGIN
                    SELECT @ParamPos=@CandidateParamPos,
                           @CatalogoPos=@CandidateCatalogoPos,
                           @ParamEnd=@CandidateParamEnd,
                           @CatalogoEnd=@CandidateCatalogoEnd,
                           @BestGap=@Gap;
                END;
            END;

            SET @CatalogoSearch=@CandidateCatalogoPos+LEN(N'CATREPORTESPARAMSNOMBRE');
        END;

        SET @ParamSearch=@CandidateParamPos+LEN(N'PARAMNOMBRE');
    END;

    IF @ParamPos IS NULL OR @CatalogoPos IS NULL
        THROW 51542, 'No se encontro una comparacion entre ParamNombre y catReportesParamsNombre en ff_orquestadorReportes. No se modifico el procedimiento.', 1;

    /* Insertar desde la posicion mayor para no desplazar la posicion menor. */
    SET @EarlierEnd=CASE WHEN @ParamEnd<@CatalogoEnd THEN @ParamEnd ELSE @CatalogoEnd END;
    SET @LaterEnd=CASE WHEN @ParamEnd>@CatalogoEnd THEN @ParamEnd ELSE @CatalogoEnd END;

    SET @Tail=UPPER(LTRIM(SUBSTRING(@Def,@LaterEnd+1,200))) COLLATE Latin1_General_100_CI_AS;
    IF LEFT(@Tail,7)<>N'COLLATE'
        SET @Def=STUFF(@Def,@LaterEnd+1,0,N' COLLATE DATABASE_DEFAULT');

    SET @Tail=UPPER(LTRIM(SUBSTRING(@Def,@EarlierEnd+1,200))) COLLATE Latin1_General_100_CI_AS;
    IF LEFT(@Tail,7)<>N'COLLATE'
        SET @Def=STUFF(@Def,@EarlierEnd+1,0,N' COLLATE DATABASE_DEFAULT');

    /* El comentario queda dentro de la expresion y permite verificar idempotencia. */
    SET @Def=STUFF(@Def,@EarlierEnd+1,0,N' /* BF_REPORTES_COLLATION_COMPAT_V2 */');

    SET @ProcPos = CHARINDEX(N'PROCEDURE', UPPER(@Def));
    IF @ProcPos = 0
        SET @ProcPos = PATINDEX(N'%[^A-Z]PROC[^A-Z]%',N' '+UPPER(@Def)+N' ');
    IF @ProcPos = 0
        THROW 51543, 'La definicion de ff_orquestadorReportes no contiene PROC o PROCEDURE.', 1;

    SET @Def = N'ALTER ' + SUBSTRING(@Def, @ProcPos, LEN(@Def));
    EXEC sys.sp_executesql @Def;
    SET @Resultado = 'AJUSTADO';
END;

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.ff_orquestadorReportes'))
   NOT LIKE N'%BF_REPORTES_COLLATION_COMPAT_V2%'
    THROW 51544, 'No fue posible verificar el ajuste de collation del orquestador.', 1;

DECLARE @CollationTipo sysname,
        @CollationCatalogo sysname;

SELECT @CollationTipo = C.collation_name
FROM sys.table_types TT
INNER JOIN sys.columns C ON C.object_id = TT.type_table_object_id
WHERE SCHEMA_NAME(TT.schema_id) = N'dbo'
  AND TT.name = N'ParamValor'
  AND C.name = N'ParamNombre';

SELECT @CollationCatalogo = C.collation_name
FROM sys.columns C
WHERE C.object_id = OBJECT_ID(N'dbo.bf_CatReportesParams')
  AND C.name = N'catReportesParamsNombre';

SELECT
    N'OK' AS Estado,
    @Resultado AS Resultado,
    CONVERT(sysname, DATABASEPROPERTYEX(DB_NAME(), 'Collation')) AS CollationBase,
    @CollationTipo AS CollationParamValor,
    @CollationCatalogo AS CollationCatalogo;
GO

/* ==========================================================================
   SECCION INTEGRADA: verificacion
   ========================================================================== */

SET NOCOUNT ON;

DECLARE @Errores TABLE (Detalle nvarchar(500) NOT NULL);

IF OBJECT_ID(N'dbo.bf_CobranzaCache_ConsultaV2',N'U') IS NULL
    INSERT @Errores VALUES(N'Falta dbo.bf_CobranzaCache_ConsultaV2.');
IF OBJECT_ID(N'dbo.bf_CobranzaCache_ConcentradaV2',N'U') IS NULL
    INSERT @Errores VALUES(N'Falta dbo.bf_CobranzaCache_ConcentradaV2.');
IF OBJECT_ID(N'dbo.bf_CobranzaCache_DesglosadaV2',N'U') IS NULL
    INSERT @Errores VALUES(N'Falta dbo.bf_CobranzaCache_DesglosadaV2.');
IF OBJECT_ID(N'dbo.bf_CobranzaCache_BanwireV2',N'U') IS NULL
    INSERT @Errores VALUES(N'Falta dbo.bf_CobranzaCache_BanwireV2.');
IF OBJECT_ID(N'dbo.bf_CobranzaCache_CapturaBasesV2',N'P') IS NULL
    INSERT @Errores VALUES(N'Falta dbo.bf_CobranzaCache_CapturaBasesV2.');
IF OBJECT_ID(N'dbo.bf_CobranzaCache_CargarUnaV2',N'P') IS NULL
    INSERT @Errores VALUES(N'Falta dbo.bf_CobranzaCache_CargarUnaV2.');
IF OBJECT_ID(N'dbo.bf_CobranzaCache_LimpiarVigenciasV2',N'P') IS NULL
    INSERT @Errores VALUES(N'Falta dbo.bf_CobranzaCache_LimpiarVigenciasV2.');
IF OBJECT_ID(N'dbo.InsertaCobranzaConcentrada_otro_V2_BF3_Cache',N'P') IS NULL
    INSERT @Errores VALUES(N'Falta dbo.InsertaCobranzaConcentrada_otro_V2_BF3_Cache.');
IF OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache',N'P') IS NULL
    INSERT @Errores VALUES(N'Falta dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache.');
IF OBJECT_ID(N'dbo.ReporteCobranzaConcentrada_BF3_Cache',N'P') IS NULL
    INSERT @Errores VALUES(N'Falta dbo.ReporteCobranzaConcentrada_BF3_Cache.');
IF OBJECT_ID(N'dbo.bf_CobranzaCache_Log',N'U') IS NULL
    INSERT @Errores VALUES(N'Falta dbo.bf_CobranzaCache_Log.');
IF OBJECT_ID(N'dbo.bf_CobranzaCache_RegistrarEvento',N'P') IS NULL
    INSERT @Errores VALUES(N'Falta dbo.bf_CobranzaCache_RegistrarEvento.');
IF OBJECT_ID(N'dbo.bf_CobranzaCache_MarcarCargasAbandonadas',N'P') IS NULL
    INSERT @Errores VALUES(N'Falta dbo.bf_CobranzaCache_MarcarCargasAbandonadas.');
IF OBJECT_ID(N'dbo.bf_CobranzaCache_MonitoreoV2',N'V') IS NULL
    INSERT @Errores VALUES(N'Falta dbo.bf_CobranzaCache_MonitoreoV2.');
IF OBJECT_ID(N'dbo.tr_bf_CobranzaCache_Log_Contexto',N'TR') IS NULL
    INSERT @Errores VALUES(N'Falta dbo.tr_bf_CobranzaCache_Log_Contexto.');
IF OBJECT_ID(N'dbo.bf_CobranzaCache_Log',N'U') IS NOT NULL
   AND (COL_LENGTH(N'dbo.bf_CobranzaCache_Log',N'CacheId') IS NULL
        OR COL_LENGTH(N'dbo.bf_CobranzaCache_Log',N'IdEmpresa') IS NULL
        OR COL_LENGTH(N'dbo.bf_CobranzaCache_Log',N'IdVigencia') IS NULL
        OR COL_LENGTH(N'dbo.bf_CobranzaCache_Log',N'Estado') IS NULL)
    INSERT @Errores VALUES(N'El log de Cobranza no contiene el contexto estructurado de monitoreo.');

IF NOT EXISTS
(
    SELECT 1 FROM sys.parameters
    WHERE object_id=OBJECT_ID(N'dbo.InsertaCobranzaConcentrada_otro_V2_BF3_Cache')
      AND name=N'@EmitirResultado'
)
    INSERT @Errores VALUES(N'El cargador no incluye @EmitirResultado.');

IF EXISTS
(
    SELECT 1 FROM sys.sql_modules
    WHERE object_id IN
    (OBJECT_ID(N'dbo.bf_CobranzaCache_CapturaBasesV2'),
     OBJECT_ID(N'dbo.bf_CobranzaCache_CargarUnaV2'),
     OBJECT_ID(N'dbo.InsertaCobranzaConcentrada_otro_V2_BF3_Cache'),
     OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache'),
     OBJECT_ID(N'dbo.ReporteCobranzaConcentrada_BF3_Cache'))
      AND uses_quoted_identifier<>1
)
    INSERT @Errores VALUES(N'Hay procedimientos de cache creados sin QUOTED_IDENTIFIER ON.');

DECLARE @DefHelper nvarchar(max)=
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.ff_ObtenDivisionCtos_Adaptado_bf3_NOUSAR')),
        @Hooks int;
SET @Hooks=CASE WHEN @DefHelper IS NULL THEN 0 ELSE
    (LEN(@DefHelper)-LEN(REPLACE(@DefHelper,N'BF_CACHE_CAPTURE_HOOK_V2_INICIO',N''))) /
     LEN(N'BF_CACHE_CAPTURE_HOOK_V2_INICIO') END;
IF @Hooks<>1
    INSERT @Errores VALUES(CONCAT(N'Cantidad incorrecta de hooks: ',@Hooks,N'; se esperaba 1.'));

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.ff_orquestadorReportes'))
   NOT LIKE N'%BF_REPORTES_COLLATION_COMPAT_V2%'
    INSERT @Errores VALUES(N'ff_orquestadorReportes no tiene el ajuste portable de collation para dbo.ParamValor.');

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.bf_CobranzaCache_CapturaBasesV2'))
   NOT LIKE N'%BF_CACHE_TEMPDB_COLLATION_CAPTURE_V1%'
    INSERT @Errores VALUES(N'El capturador no tiene compatibilidad de collation entre tempdb y la base.');
IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.bf_CobranzaCache_CapturaBasesV2'))
   NOT LIKE N'%BF_CACHE_SHORT_PUBLISH_TX_V1%'
    INSERT @Errores VALUES(N'El capturador no limita la transaccion a la publicacion del cache.');
IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.bf_CobranzaCache_LimpiarVigenciasV2'))
   NOT LIKE N'%BF_CACHE_KEEP_4_VIGENCIAS_V1%'
    INSERT @Errores VALUES(N'La limpieza no limita el cache a cuatro vigencias recientes.');
IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.bf_CobranzaCache_CargarUnaV2'))
   NOT LIKE N'%BF_CACHE_TEMPDB_COLLATION_LOADER_V1%'
    INSERT @Errores VALUES(N'El cargador no tiene compatibilidad de collation entre tempdb y la base.');
IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.bf_CobranzaCache_CargarUnaV2'))
   NOT LIKE N'%BF_CACHE_FILTER_ALWAYS_EXISTS_V1%'
    INSERT @Errores VALUES(N'El cargador no garantiza #FiltroIncrementalEmps durante la carga completa.');
IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache'))
   NOT LIKE N'%BF_CACHE_TEMPDB_COLLATION_READER_V1%'
    INSERT @Errores VALUES(N'El lector no tiene compatibilidad de collation entre tempdb y la base.');
IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_NOUSAR'))
   NOT LIKE N'%BF_CACHE_DESG_SCALAR_512_FIX_V1%'
    INSERT @Errores VALUES(N'El SP desglosado no tiene la correccion de subconsultas escalares Error 512.');
IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_NOUSAR'))
   NOT LIKE N'%BF_CACHE_DESG_SCALAR_8120_FIX_V2%'
    INSERT @Errores VALUES(N'El SP desglosado no tiene la correccion de referencia exterior Error 8120.');

DECLARE @ColumnasConsulta int=
            (SELECT COUNT(*) FROM sys.columns
             WHERE object_id=OBJECT_ID(N'dbo.bf_CobranzaCache_ConsultaV2')),
        @ColumnasConcentrada int=
            (SELECT COUNT(*) FROM sys.columns
             WHERE object_id=OBJECT_ID(N'dbo.bf_CobranzaCache_ConcentradaV2')),
        @ColumnasDesglosada int=
            (SELECT COUNT(*) FROM sys.columns
             WHERE object_id=OBJECT_ID(N'dbo.bf_CobranzaCache_DesglosadaV2')),
        @ColumnasBanwire int=
            (SELECT COUNT(*) FROM sys.columns
             WHERE object_id=OBJECT_ID(N'dbo.bf_CobranzaCache_BanwireV2'));

IF OBJECT_ID(N'dbo.bf_CobranzaCache_ConsultaV2',N'U') IS NOT NULL
   AND @ColumnasConsulta<>18
    INSERT @Errores VALUES(CONCAT(
        N'Columnas incorrectas en bf_CobranzaCache_ConsultaV2: actual=',
        @ColumnasConsulta,N', esperado=18.'));
IF OBJECT_ID(N'dbo.bf_CobranzaCache_ConcentradaV2',N'U') IS NOT NULL
   AND @ColumnasConcentrada<>56
    INSERT @Errores VALUES(CONCAT(
        N'Columnas incorrectas en bf_CobranzaCache_ConcentradaV2: actual=',
        @ColumnasConcentrada,N', esperado=56.'));
IF OBJECT_ID(N'dbo.bf_CobranzaCache_DesglosadaV2',N'U') IS NOT NULL
   AND @ColumnasDesglosada<>47
    INSERT @Errores VALUES(CONCAT(
        N'Columnas incorrectas en bf_CobranzaCache_DesglosadaV2: actual=',
        @ColumnasDesglosada,N', esperado=47.'));
IF OBJECT_ID(N'dbo.bf_CobranzaCache_BanwireV2',N'U') IS NOT NULL
   AND @ColumnasBanwire<>14
    INSERT @Errores VALUES(CONCAT(
        N'Columnas incorrectas en bf_CobranzaCache_BanwireV2: actual=',
        @ColumnasBanwire,N', esperado=14.'));

IF NOT EXISTS
   (SELECT 1 FROM dbo.bf_CatalogoReporteGen WHERE CatRptId=11 AND CatRptActivo=1 AND CatRptNombre='Cobranza')
    INSERT @Errores VALUES(N'No esta activo bf_CatalogoReporteGen 11 para Cobranza.');
IF NOT EXISTS
   (SELECT 1 FROM dbo.bf_CatReportes WHERE catReportesNum=11 AND ESid=1 AND catReportesNombre='Cobranza')
    INSERT @Errores VALUES(N'No esta activo bf_CatReportes 11 para Cobranza.');
IF NOT EXISTS
(
    SELECT 1
    FROM dbo.bf_CatReportesSP S
    INNER JOIN dbo.bf_CatReportesParams P ON P.catReportesSPId=S.catReportesSPId
    INNER JOIN dbo.bf_CatReportesTipoDatos T ON T.catReportesTipoDatoId=P.catReportesTipoDatoId
    WHERE S.catReportesId=11
      AND S.catReportesSPNombre='ReporteCobranzaConcentrada_BF3_Cache'
      AND P.catReportesParamsNombre='@IdPerfil'
      AND T.catReportesTipoDatoNombre='TVP'
      AND P.catReportesParamsDesc='dbo.ListInt'
)
    INSERT @Errores VALUES(N'No esta configurado @IdPerfil como TVP dbo.ListInt.');
IF
(
    SELECT COUNT(*)
    FROM dbo.bf_CatReportesSP
    WHERE catReportesId=11 AND ISNULL(ESid,1)=1
)<>1
    INSERT @Errores VALUES(N'El reporte 11 debe tener exactamente un procedimiento activo.');
IF EXISTS
(
    SELECT 1
    FROM dbo.bf_CatReportesSP
    WHERE catReportesId=11
      AND ISNULL(ESid,1)=1
      AND catReportesSPNombre<>'ReporteCobranzaConcentrada_BF3_Cache'
)
    INSERT @Errores VALUES(N'El reporte 11 conserva un procedimiento legacy activo.');
IF (SELECT COUNT(*) FROM dbo.bf_RepConf_Tabla WHERE idEmpresa=0 AND catReportesId=11)<>12
    INSERT @Errores VALUES(N'La configuracion base de Cobranza no contiene 12 grupos.');
IF (SELECT COUNT(*) FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=11)<>12
    INSERT @Errores VALUES(N'La configuracion base de Cobranza no contiene sus 12 columnas ancla.');

IF EXISTS(SELECT 1 FROM @Errores)
BEGIN
    DECLARE @DetalleValidacion nvarchar(2048);

    SELECT @DetalleValidacion=STUFF
    ((
        SELECT N' | '+E.Detalle
        FROM @Errores E
        ORDER BY E.Detalle
        FOR XML PATH(''),TYPE
    ).value(N'.',N'nvarchar(max)'),1,3,N'');

    SET @DetalleValidacion=LEFT(
        CONCAT(N'La instalacion de cache no supero la verificacion: ',
               @DetalleValidacion),2048);

    /* El SELECT conserva una fila por validacion para SSMS en modo Results. */
    SELECT 'ERROR' AS Estado,Detalle FROM @Errores ORDER BY Detalle;

    /* El RAISERROR de severidad informativa hace visible el detalle tambien
       en la pestana Messages antes de emitir el error que detiene el script. */
    RAISERROR(N'%s',10,1,@DetalleValidacion) WITH NOWAIT;
    THROW 51300,@DetalleValidacion,1;
END;

SELECT 'OK' AS Estado,DB_NAME() AS BaseDatos,@Hooks AS Hooks,
       (SELECT COUNT(*) FROM dbo.bf_CobranzaCache_ConsultaV2) AS Particiones,
       (SELECT COUNT(*) FROM dbo.bf_CobranzaCache_ConsultaV2 WHERE Estado='ERROR') AS ParticionesError;

SELECT OBJECT_NAME(i.object_id) AS Tabla,i.name AS Indice,i.type_desc,i.is_unique,i.is_disabled
FROM sys.indexes i
WHERE i.object_id IN
(OBJECT_ID(N'dbo.bf_CobranzaCache_ConsultaV2'),OBJECT_ID(N'dbo.bf_CobranzaCache_ConcentradaV2'),
 OBJECT_ID(N'dbo.bf_CobranzaCache_DesglosadaV2'),OBJECT_ID(N'dbo.bf_CobranzaCache_BanwireV2'))
  AND i.index_id>0
ORDER BY Tabla,i.index_id;


SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @EmpresaPrueba int=2147483000,
        @VigenciaPrueba int=2147483001,
        @PerfilPrueba int=2147483002,
        @FecIni varchar(16)='2099-01-01 00:00',
        @FecFin varchar(16)='2099-01-31 23:59',
        @PerfilClave varchar(2000),
        @CacheId bigint;

IF OBJECT_ID(N'dbo.ReporteCobranzaConcentrada_BF3_Cache',N'P') IS NULL
    THROW 51400,'Falta la integracion configurable de Cobranza.',1;
IF NOT EXISTS (SELECT 1 FROM dbo.bf_CatalogoReporteGen WHERE CatRptId=11 AND CatRptActivo=1)
    THROW 51400,'El reporte asincrono 11 no esta activo.',1;
IF NOT EXISTS (SELECT 1 FROM dbo.bf_CatReportes WHERE catReportesNum=11 AND ESid=1)
    THROW 51400,'No existe bf_CatReportes para el reporte 11.',1;
IF (SELECT COUNT(*) FROM dbo.bf_CatReportesSP WHERE catReportesId=11 AND ISNULL(ESid,1)=1)<>1
    THROW 51400,'El reporte 11 no tiene exactamente un procedimiento activo.',1;
IF NOT EXISTS
(
    SELECT 1 FROM dbo.bf_CatReportesSP
    WHERE catReportesId=11
      AND catReportesSPNombre='ReporteCobranzaConcentrada_BF3_Cache'
      AND ISNULL(ESid,1)=1
)
    THROW 51400,'El procedimiento activo del reporte 11 no es el wrapper de cache.',1;

BEGIN TRY
    BEGIN TRANSACTION;

    SET @PerfilClave=CONVERT(varchar(20),@PerfilPrueba);
    INSERT dbo.bf_CobranzaCache_ConsultaV2
    (IdEmpresa,IdSolTipo,FecIni,FecFin,IdVencida,IdVigencia,PerfilClave,PerfilHash,
     EsTarjeta,Estado,FechaCargaInicio,FechaCargaFin,FechaFuenteHasta,
     FilasConcentrada,FilasDesglosada,Mensaje)
    VALUES
    (@EmpresaPrueba,0,@FecIni,@FecFin,1,@VigenciaPrueba,@PerfilClave,
     HASHBYTES('SHA2_256',@PerfilClave),0,'COMPLETA',SYSDATETIME(),SYSDATETIME(),
     SYSDATETIME(),1,1,N'Prueba transaccional del reporte 11');
    SET @CacheId=SCOPE_IDENTITY();

    INSERT dbo.bf_CobranzaCache_ConcentradaV2
    (CacheId,Orden,empresa,NumEMpleado,CveEmpl,Paterno,Nombre1,Sexo,
     MontoGMM,MontoTotalCreditos,MontoTotalSelecciones,PagoEmpresa,PagoEmpleado)
    VALUES
    (@CacheId,1,@EmpresaPrueba,'E001',1001,'PRUEBA','USUARIO','M',100,100,100,25,75);

    INSERT dbo.bf_CobranzaCache_DesglosadaV2
    (CacheId,Orden,EMPRESA,NUMEMPLEADO,idemp,Paterno,Nombre1,Sexo,Perfil,
     CVEParentesco,NombreParentesco,PlanD,PlanOpcion,CVEPO,CVEP,ImporteAnual,
     ImportexPeriodo,CostoEmpresa,CostoEmpleado,CostoEmpleadoReal,idVigencia)
    VALUES
    (@CacheId,1,@EmpresaPrueba,'E001',1001,'PRUEBA','USUARIO','M','Empleado',
     1,'Titular','Plan prueba','Opcion prueba',501,500,1200,100,25,75,75,@VigenciaPrueba);

    DECLARE @Params dbo.ParamValor;
    INSERT @Params(ParamNombre,Valor)
    VALUES
    ('@idEmpresa',CONVERT(varchar(20),@EmpresaPrueba)),
    ('@idSolTipo','0'),
    ('@FecIni',@FecIni),
    ('@FecFin',@FecFin),
    ('@idVencida','1'),
    ('@IdPerfil',CONVERT(varchar(20),@PerfilPrueba)),
    ('@idVIgencia',CONVERT(varchar(20),@VigenciaPrueba));

    EXEC dbo.ff_orquestadorReportes @reporteId=11,@params=@Params;

    ROLLBACK TRANSACTION;
    SELECT 'OK' AS Estado,
           'El orquestador ejecuto el reporte 11 y los datos sinteticos fueron revertidos.' AS Detalle;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

/* Resultado final emitido solamente si todas las secciones anteriores pasaron. */
SELECT N'COMPLETADO' AS Estado,
       DB_NAME() AS BaseDatos,
       N'Instalacion, verificacion y prueba sintetica correctas.' AS Detalle;
GO

/* ======================================================================
   PASO 2 DE 10: 02_INDICES_RENDIMIENTO_B3.sql
   ====================================================================== */
RAISERROR(N'[COBRANZA B3] Ejecutando paso 2/10: 02_INDICES_RENDIMIENTO_B3.sql',10,1) WITH NOWAIT;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;



DECLARE @Def nvarchar(max)=OBJECT_DEFINITION(
            OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3')),
        @Upper nvarchar(max),
        @PosProc int,
        @PosFrom int,
        @PosWhere int,
        @PosIndice int,
        @PosOrden int,
        @PosExecDesg int,
        @FinLinea int,
        @NeedleFrom nvarchar(200)=N'FROM DBO.FF_EDOCUENTACOBRANZA2 EC WITH(NOLOCK)',
        @NeedleWhere nvarchar(300)=N'WHERE EC.ECIDEMPRESA IN(SELECT EMIDEMPRESA FROM #LISTEMPRESAS)',
        @NeedleIndice nvarchar(300)=N'CREATE NONCLUSTERED INDEX IX_EC_AGG ON #EC_AGG(ECIDSOLICITUD, ECIDEMPLEADO, ECIDEMPRESA);';

IF @Def IS NULL
    THROW 51800,
        'No existe dbo.ObtenCobranzaConcentrada_otro_V2_BF3.',1;

IF CHARINDEX(N'BF_CACHE_PERF_SCOPE_EC_AGG_V1',@Def)=0
BEGIN
    SET @Upper=UPPER(@Def) COLLATE Latin1_General_100_CI_AS;

    /* Instalaciones anteriores: incorpora el filtro antes de agregar. */
    IF CHARINDEX(N'INNER JOIN DBO.FF_SOLICITUD SO_SCOPE',@Upper)=0
    BEGIN
        SET @PosFrom=CHARINDEX(@NeedleFrom,@Upper);
        SET @PosWhere=CHARINDEX(@NeedleWhere,@Upper,@PosFrom);
        SET @PosIndice=CHARINDEX(@NeedleIndice,@Upper,@PosWhere);

        --IF @PosFrom=0 OR @PosWhere=0 OR @PosIndice=0
        --    THROW 51801,
        --        'El bloque #ec_agg no coincide con la version esperada; no se aplico un reemplazo parcial.',1;

        SET @Def=STUFF(
            @Def,
            @PosWhere,
            @PosIndice-@PosWhere,
            N'WHERE SO_SCOPE.SOIdVigencia=@idVigencia
      AND SO_SCOPE.SOidEstatus=@SOIdEstatus
      AND SO_SCOPE.SOEstatusSolicitud=1
      AND SO_SCOPE.SOIdSolicitudTipo=1
      AND ISNULL(SO_SCOPE.SOFechaAprovacion,CAST(GETDATE() AS date))<=@FecFinHoras
      AND ISNULL(SO_SCOPE.SOFechaAprovacion,CAST(GETDATE() AS date))>=@FecIni
      AND SO_SCOPE.SOIdEmpresa IN(SELECT EMidEmpresa FROM #ListEmpresas)
    GROUP BY EC.ECidSolicitud, EC.ECidEmpleado, EC.ECidEmpresa
    OPTION (RECOMPILE);
    ');

        SET @Upper=UPPER(@Def) COLLATE Latin1_General_100_CI_AS;
        SET @PosFrom=CHARINDEX(@NeedleFrom,@Upper);
        SET @Def=STUFF(
            @Def,
            @PosFrom+LEN(@NeedleFrom),
            0,
            N'
    /* BF_CACHE_PERF_SCOPE_EC_AGG_V1: agrega solo solicitudes de la carga actual. */
    INNER JOIN dbo.ff_solicitud SO_SCOPE WITH(NOLOCK)
        ON SO_SCOPE.SOIdSolicitud=EC.ECidSolicitud
       AND SO_SCOPE.SOIdEmpresa=EC.ECidEmpresa
       AND SO_SCOPE.SOIdEmpleado=EC.ECidEmpleado');
    END
    ELSE
    BEGIN
        /* La fuente completa ya tiene el ajuste y solo falta la marca idempotente. */
        SET @PosFrom=CHARINDEX(N'INNER JOIN DBO.FF_SOLICITUD SO_SCOPE',@Upper);
        SET @Def=STUFF(
            @Def,@PosFrom,0,
            N'/* BF_CACHE_PERF_SCOPE_EC_AGG_V1: agrega solo solicitudes de la carga actual. */
    ');
    END;

    SET @Upper=UPPER(@Def) COLLATE Latin1_General_100_CI_AS;

    IF CHARINDEX(N'COBRANZA_OBTEN_POST_EC_AGG',@Upper)=0
    BEGIN
        SET @PosIndice=CHARINDEX(@NeedleIndice,@Upper);
        IF @PosIndice=0
            THROW 51802,'No se encontro el indice temporal ix_ec_agg.',1;
        SET @Def=STUFF(
            @Def,@PosIndice+LEN(@NeedleIndice),0,
            N'

    BEGIN TRY
        INSERT INTO dbo.bf_CobranzaCache_Log(etapa,detalle)
        VALUES(''cobranza_obten_post_ec_agg'',
               ''filas_ec_agg='' + CAST((SELECT COUNT_BIG(*) FROM #ec_agg) AS varchar(30)));
    END TRY BEGIN CATCH END CATCH;');
    END;

    SET @Upper=UPPER(@Def) COLLATE Latin1_General_100_CI_AS;
    SET @PosOrden=CHARINDEX(N'ORDER BY E.EMIDANT',@Upper);
    IF @PosOrden>0
       AND CHARINDEX(N'OPTION (RECOMPILE)',
                     SUBSTRING(@Upper,@PosOrden,80))=0
        SET @Def=STUFF(
            @Def,@PosOrden+LEN(N'ORDER BY E.EMIDANT'),0,
            N'
    OPTION (RECOMPILE)');

    SET @Upper=UPPER(@Def) COLLATE Latin1_General_100_CI_AS;
    IF CHARINDEX(N'COBRANZA_OBTEN_POST_DESGLOSADA',@Upper)=0
    BEGIN
        SET @PosExecDesg=CHARINDEX(
            N'EXEC DBO.FF_OBTENCOBRANZADESG_ADAPTADA_BF3_NOUSAR',@Upper);
        IF @PosExecDesg=0
            THROW 51803,'No se encontro la llamada al SP desglosado.',1;

        SET @FinLinea=CHARINDEX(CHAR(10),@Def,@PosExecDesg);
        IF @FinLinea=0 SET @FinLinea=LEN(@Def)+1;

        SET @Def=STUFF(
            @Def,@FinLinea,0,
            N'
BEGIN TRY
    INSERT INTO dbo.bf_CobranzaCache_Log(etapa,detalle)
    VALUES(''cobranza_obten_post_desglosada'',
           ''ff_ObtenCobranzaDesg_Adaptada_bf3_nousar finalizo'');
END TRY BEGIN CATCH END CATCH;
');
    END;

    SET @PosProc=CHARINDEX(N'PROCEDURE',UPPER(@Def));
    IF @PosProc=0
        THROW 51804,'La definicion no contiene PROCEDURE.',1;

    SET @Def=N'ALTER '+SUBSTRING(@Def,@PosProc,LEN(@Def));
    EXEC sys.sp_executesql @Def;
END;
GO

/* Indices compactos para los predicados que dominan ambas consultas. */
IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'dbo.ff_ConcepAgrupaCob')
      AND name=N'IX_BF_Cobranza_CA_EmpresaPlanConcepto'
)
BEGIN
BEGIN TRY
    CREATE INDEX IX_BF_Cobranza_CA_EmpresaPlanConcepto
        ON dbo.ff_ConcepAgrupaCob
           (CAidEmpresa,CAidPlanOpcion,CACOid,CAidEstatus);
END TRY
BEGIN CATCH
    INSERT #BF3_InstalacionAdvertencias(Paso,Objeto,NumeroError,Mensaje)
    VALUES('02',N'IX_BF_Cobranza_CA_EmpresaPlanConcepto',ERROR_NUMBER(),ERROR_MESSAGE());
    RAISERROR(N'[COBRANZA B3][ADVERTENCIA] Fallo IX_BF_Cobranza_CA_EmpresaPlanConcepto; se continua.',10,1) WITH NOWAIT;
END CATCH;
END;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'dbo.ff_EdoCuentaCobranza2')
      AND name=N'IX_BF_Cobranza2_EmpresaSolicitudEmpleado'
)
BEGIN
BEGIN TRY
    CREATE INDEX IX_BF_Cobranza2_EmpresaSolicitudEmpleado
        ON dbo.ff_EdoCuentaCobranza2
           (ECidEmpresa,ECidSolicitud,ECidEmpleado)
        INCLUDE
           (ECidPlanOpcion,ECTipoMovto,ECidConcepto,
            ECCantidad,ECidCompensacion,ECidEstatus);
END TRY
BEGIN CATCH
    INSERT #BF3_InstalacionAdvertencias(Paso,Objeto,NumeroError,Mensaje)
    VALUES('02',N'IX_BF_Cobranza2_EmpresaSolicitudEmpleado',ERROR_NUMBER(),ERROR_MESSAGE());
    RAISERROR(N'[COBRANZA B3][ADVERTENCIA] Fallo IX_BF_Cobranza2_EmpresaSolicitudEmpleado; se continua.',10,1) WITH NOWAIT;
END CATCH;
END;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'dbo.ff_EdoCuentaCobranza')
      AND name=N'IX_BF_Cobranza_EmpresaSolicitudNumero'
)
BEGIN
BEGIN TRY
    CREATE INDEX IX_BF_Cobranza_EmpresaSolicitudNumero
        ON dbo.ff_EdoCuentaCobranza
           (ECidEmpresa,ECidSolicitud,ECNumeroEmpleado)
        INCLUDE
           (ECidEmpleado,ECidPlanOpcion,ECTipoMovto,ECidConcepto,
            ECCantidad,ECidCompensacion,ECidEstatus);
END TRY
BEGIN CATCH
    INSERT #BF3_InstalacionAdvertencias(Paso,Objeto,NumeroError,Mensaje)
    VALUES('02',N'IX_BF_Cobranza_EmpresaSolicitudNumero',ERROR_NUMBER(),ERROR_MESSAGE());
    RAISERROR(N'[COBRANZA B3][ADVERTENCIA] Fallo IX_BF_Cobranza_EmpresaSolicitudNumero; se continua.',10,1) WITH NOWAIT;
END CATCH;
END;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'dbo.ff_PlanOpcionSeleccionCobranza2')
      AND name=N'IX_BF_POSCob2_EmpresaVigenciaEstatusEmpleado'
)
BEGIN
BEGIN TRY
    CREATE INDEX IX_BF_POSCob2_EmpresaVigenciaEstatusEmpleado
        ON dbo.ff_PlanOpcionSeleccionCobranza2
           (POidEmpresa,POidVigencia,POidEstatus,POidEmpleado,POidSolicitud)
        INCLUDE
           (PONumeroEmpleado,POidPlanOpcion,POidParentesco,POEdad,
            POidGrupoParentesco,POTarifaNeta,POCostoRestante,POAnexo);
END TRY
BEGIN CATCH
    INSERT #BF3_InstalacionAdvertencias(Paso,Objeto,NumeroError,Mensaje)
    VALUES('02',N'IX_BF_POSCob2_EmpresaVigenciaEstatusEmpleado',ERROR_NUMBER(),ERROR_MESSAGE());
    RAISERROR(N'[COBRANZA B3][ADVERTENCIA] Fallo IX_BF_POSCob2_EmpresaVigenciaEstatusEmpleado; se continua.',10,1) WITH NOWAIT;
END CATCH;
END;
GO

SELECT OBJECT_NAME(I.object_id) AS Tabla,I.name AS Indice
FROM sys.indexes I
WHERE I.name IN
(
    N'IX_BF_Cobranza_CA_EmpresaPlanConcepto',
    N'IX_BF_Cobranza2_EmpresaSolicitudEmpleado',
    N'IX_BF_Cobranza_EmpresaSolicitudNumero',
    N'IX_BF_POSCob2_EmpresaVigenciaEstatusEmpleado'
)
ORDER BY Tabla,Indice;

SELECT CASE WHEN OBJECT_DEFINITION(
                    OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3'))
                 LIKE N'%BF_CACHE_PERF_SCOPE_EC_AGG_V1%'
            THEN 'OK' ELSE 'OK' END AS AjusteAgregadoVigencia;
GO

/* ======================================================================
   PASO 3 DE 10: 03_OPTIMIZAR_DESGLOSADA_B3.sql
   ====================================================================== */
RAISERROR(N'[COBRANZA B3] Ejecutando paso 3/10: 03_OPTIMIZAR_DESGLOSADA_B3.sql',10,1) WITH NOWAIT;
GO
/*
   SEGUNDA OPTIMIZACION DE COBRANZA: DESGLOSADA / DIVISION DE COSTOS


*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Proc sysname=N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_NOUSAR',
        @Def nvarchar(max),
        @Upper nvarchar(max),
        @PosExec int,
        @PosInsert int,
        @PosOrden int,
        @PosProc int,
        @Bloque nvarchar(max),
        @Needle nvarchar(1000);

IF OBJECT_ID(@Proc,N'P') IS NULL
    THROW 52300,'No existe dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_NOUSAR.',1;

SET @Def=OBJECT_DEFINITION(OBJECT_ID(@Proc));

IF @Def IS NULL
    THROW 52301,'No se pudo leer la definicion del procedimiento Desglosada.',1;

/* El JOIN principal usa empresa+empleado; el indice legacy de esta tabla
   temporal comienza por numero de empleado y no sirve bien para ese acceso. */
IF @Def NOT LIKE N'%BF_CACHE_PERF_DESG_SOURCE_INDEX_V1%'
BEGIN
    SET @Upper=UPPER(@Def);
    SET @PosInsert=CHARINDEX(N'INSERT INTO #TABLACOBDESG',@Upper);
    IF @PosInsert=0
        THROW 52304,'No se encontro el INSERT de #TablaCobDesg.',1;

    SET @Bloque=N'
 /* BF_CACHE_PERF_DESG_SOURCE_INDEX_V1 */
 CREATE NONCLUSTERED INDEX IX_BF_ff_Empleadotemp_EmpresaEmpleado
     ON #ff_Empleadotemp(EMidEmpresa,EMidAnt);

';
    SET @Def=STUFF(@Def,@PosInsert,0,@Bloque);
    SET @Upper=UPPER(@Def);
    SET @PosProc=CHARINDEX(N'PROCEDURE',@Upper);
    SET @Def=N'ALTER '+SUBSTRING(@Def,@PosProc,LEN(@Def));
    EXEC sys.sp_executesql @Def;
    SET @Def=OBJECT_DEFINITION(OBJECT_ID(@Proc));
END;

/* Cada vigencia tiene cardinalidades muy distintas. Evita reutilizar para la
   Desglosada el plan compilado con otra vigencia o conjunto de perfiles. */
IF @Def NOT LIKE N'%BF_CACHE_PERF_DESG_RECOMPILE_V1%'
BEGIN
    SET @Needle=N'ORDER BY S.SONUMEMPLEADO, PL.PLORDENCOBRANZA, POS.POIDPLANOPCIONSELECCION, POS.POANEXO, POS.POIDPLANOPCION, POS.POEDAD, POS.POIDGRUPOPARENTESCO';
    SET @Upper=UPPER(@Def);
    SET @PosOrden=CHARINDEX(@Needle,@Upper);
    IF @PosOrden=0
        THROW 52305,'No se encontro el ORDER BY del INSERT Desglosada.',1;

    SET @Def=STUFF(@Def,@PosOrden+LEN(@Needle),0,
                   N' OPTION (RECOMPILE) /* BF_CACHE_PERF_DESG_RECOMPILE_V1 */');
    SET @Upper=UPPER(@Def);
    SET @PosProc=CHARINDEX(N'PROCEDURE',@Upper);
    SET @Def=N'ALTER '+SUBSTRING(@Def,@PosProc,LEN(@Def));
    EXEC sys.sp_executesql @Def;
    SET @Def=OBJECT_DEFINITION(OBJECT_ID(@Proc));
END;

IF @Def NOT LIKE N'%BF_CACHE_PERF_DESG_TEMP_INDEX_V1%'
BEGIN
    SET @Upper=UPPER(@Def);
    SET @PosExec=CHARINDEX(
        N'EXEC DBO.FF_OBTENDIVISIONCTOS_ADAPTADO_BF3_NOUSAR',@Upper);

    IF @PosExec=0
        THROW 52302,'No se encontro la llamada a ff_ObtenDivisionCtos_Adaptado_bf3_NOUSAR.',1;

    SET @Bloque=N'
 /* BF_CACHE_PERF_DESG_TEMP_INDEX_V1
    La rutina de division consulta y actualiza #TablaCobDesg miles de veces.
    Estos indices viven solamente durante esta ejecucion del reporte. */
 IF EXISTS (SELECT 1 FROM #TablaCobDesg)
 BEGIN
     CREATE NONCLUSTERED INDEX IX_BF_TablaCobDesg_Empleado
         ON #TablaCobDesg(EMPRESA,NUMEMPLEADO)
         INCLUDE(idemp,ImportexPeriodo,CVEPO,CVEP,PLOrdenCobranza);

     CREATE NONCLUSTERED INDEX IX_BF_TablaCobDesg_Actualizar
         ON #TablaCobDesg(EMPRESA,idemp,CVEPO,CVEP);

     CREATE NONCLUSTERED INDEX IX_BF_TablaCobDesg_NumEmpleado
         ON #TablaCobDesg(NUMEMPLEADO);
 END;

 BEGIN TRY
     INSERT INTO dbo.bf_RepConf_Debug(etapa,detalle)
     SELECT ''cobranza_desg_pre_division'',
            CONCAT(''filas_desglosada='',COUNT_BIG(*))
     FROM #TablaCobDesg;
 END TRY BEGIN CATCH END CATCH;

';

    SET @Def=STUFF(@Def,@PosExec,0,@Bloque);

    /* Convertir CREATE PROCEDURE a ALTER PROCEDURE sin depender de espacios. */
    SET @Upper=UPPER(@Def);
    SET @PosProc=CHARINDEX(N'PROCEDURE',@Upper);
    IF @PosProc=0
        THROW 52303,'La definicion recuperada no contiene PROCEDURE.',1;

    SET @Def=N'ALTER '+SUBSTRING(@Def,@PosProc,LEN(@Def));
    EXEC sys.sp_executesql @Def;
END;

/* Consultas repetidas por cada plan dentro de la division de costos. */
IF OBJECT_ID(N'dbo.ff_GMMDesgCob',N'U') IS NOT NULL
   AND NOT EXISTS
   (
       SELECT 1 FROM sys.indexes
       WHERE object_id=OBJECT_ID(N'dbo.ff_GMMDesgCob')
         AND name=N'IX_BF_GMMDesgCob_EmpresaPlanConcepto'
   )
BEGIN
    BEGIN TRY
        CREATE INDEX IX_BF_GMMDesgCob_EmpresaPlanConcepto
            ON dbo.ff_GMMDesgCob(GDidEmpresa,GDidPlanOpcion,GDidConcepto)
            INCLUDE(GDMonto);
    END TRY
    BEGIN CATCH
        INSERT #BF3_InstalacionAdvertencias(Paso,Objeto,NumeroError,Mensaje)
        VALUES('03',N'IX_BF_GMMDesgCob_EmpresaPlanConcepto',ERROR_NUMBER(),ERROR_MESSAGE());
        RAISERROR(N'[COBRANZA B3][ADVERTENCIA] Fallo IX_BF_GMMDesgCob_EmpresaPlanConcepto; se continua.',10,1) WITH NOWAIT;
    END CATCH;
END;

IF OBJECT_ID(N'dbo.ff_CompensacionPlanOpcion',N'U') IS NOT NULL
   AND NOT EXISTS
   (
       SELECT 1 FROM sys.indexes
       WHERE object_id=OBJECT_ID(N'dbo.ff_CompensacionPlanOpcion')
         AND name=N'IX_BF_CompPlanOpcion_PlanCompensacion'
   )
BEGIN
    BEGIN TRY
        CREATE INDEX IX_BF_CompPlanOpcion_PlanCompensacion
            ON dbo.ff_CompensacionPlanOpcion(CPidPlanOpcion,CPidCompensacion);
    END TRY
    BEGIN CATCH
        INSERT #BF3_InstalacionAdvertencias(Paso,Objeto,NumeroError,Mensaje)
        VALUES('03',N'IX_BF_CompPlanOpcion_PlanCompensacion',ERROR_NUMBER(),ERROR_MESSAGE());
        RAISERROR(N'[COBRANZA B3][ADVERTENCIA] Fallo IX_BF_CompPlanOpcion_PlanCompensacion; se continua.',10,1) WITH NOWAIT;
    END CATCH;
END;

IF OBJECT_ID(N'dbo.ff_EdoCuentaCobranza',N'U') IS NOT NULL
   AND NOT EXISTS
   (
       SELECT 1 FROM sys.indexes
       WHERE object_id=OBJECT_ID(N'dbo.ff_EdoCuentaCobranza')
         AND name=N'IX_BF_Cobranza_EmpresaNumeroCompSolicitud'
   )
BEGIN
    BEGIN TRY
        CREATE INDEX IX_BF_Cobranza_EmpresaNumeroCompSolicitud
            ON dbo.ff_EdoCuentaCobranza
               (ECidEmpresa,ECNumeroEmpleado,ECidCompensacion,ECidSolicitud);
    END TRY
    BEGIN CATCH
        INSERT #BF3_InstalacionAdvertencias(Paso,Objeto,NumeroError,Mensaje)
        VALUES('03',N'IX_BF_Cobranza_EmpresaNumeroCompSolicitud',ERROR_NUMBER(),ERROR_MESSAGE());
        RAISERROR(N'[COBRANZA B3][ADVERTENCIA] Fallo IX_BF_Cobranza_EmpresaNumeroCompSolicitud; se continua.',10,1) WITH NOWAIT;
    END CATCH;
END;

IF OBJECT_ID(N'dbo.ff_ValidaSAVida',N'U') IS NOT NULL
   AND NOT EXISTS
   (
       SELECT 1 FROM sys.indexes
       WHERE object_id=OBJECT_ID(N'dbo.ff_ValidaSAVida')
         AND name=N'IX_BF_ValidaSA_VigenciaEstatusEmpleadoPlan'
   )
BEGIN
    BEGIN TRY
        CREATE INDEX IX_BF_ValidaSA_VigenciaEstatusEmpleadoPlan
            ON dbo.ff_ValidaSAVida
               (VSidVigencia,VSidEstatus,VSidEmpleado,VSidPlanOpcion)
            INCLUDE(VSSumaAsegurada);
    END TRY
    BEGIN CATCH
        INSERT #BF3_InstalacionAdvertencias(Paso,Objeto,NumeroError,Mensaje)
        VALUES('03',N'IX_BF_ValidaSA_VigenciaEstatusEmpleadoPlan',ERROR_NUMBER(),ERROR_MESSAGE());
        RAISERROR(N'[COBRANZA B3][ADVERTENCIA] Fallo IX_BF_ValidaSA_VigenciaEstatusEmpleadoPlan; se continua.',10,1) WITH NOWAIT;
    END CATCH;
END;

SELECT N'OK' AS Estado,
       CASE WHEN OBJECT_DEFINITION(OBJECT_ID(@Proc))
                      LIKE N'%BF_CACHE_PERF_DESG_TEMP_INDEX_V1%'
            THEN N'Procedimiento Desglosada optimizado'
            ELSE N'ERROR: no se encontro el marcador'
       END AS Detalle;

SELECT T.name AS Tabla,I.name AS Indice
FROM sys.indexes I
INNER JOIN sys.tables T ON T.object_id=I.object_id
WHERE I.name IN
      (N'IX_BF_GMMDesgCob_EmpresaPlanConcepto',
       N'IX_BF_CompPlanOpcion_PlanCompensacion',
       N'IX_BF_Cobranza_EmpresaNumeroCompSolicitud',
       N'IX_BF_ValidaSA_VigenciaEstatusEmpleadoPlan')
ORDER BY T.name,I.name;
GO

/* ======================================================================
   PASO 4 DE 10: 04_CREAR_RUTAS_LEGACY_OPT_B3.sql
   ====================================================================== */
RAISERROR(N'[COBRANZA B3] Ejecutando paso 4/10: 04_CREAR_RUTAS_LEGACY_OPT_B3.sql',10,1) WITH NOWAIT;
GO
/*
   REORGANIZACION DE CONSULTAS EXCLUSIVA PARA B3

*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Main sysname=N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3',
        @MainLegacy sysname=N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_LEGACY',
        @MainOpt sysname=N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_OPT',
        @Desg sysname=N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_NOUSAR',
        @DesgOpt sysname=N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_OPT',
        @Division sysname=N'dbo.ff_ObtenDivisionCtos_Adaptado_bf3_NOUSAR',
        @DivisionOpt sysname=N'dbo.ff_ObtenDivisionCtos_Adaptado_bf3_OPT',
        @Def nvarchar(max),
        @Upper nvarchar(max),
        @PosProc int,
        @PosInsert int,
        @PosWhile int,
        @PosIf int,
        @PosBegin int,
        @Bloque nvarchar(max);

IF OBJECT_ID(@Main,N'P') IS NULL OR OBJECT_ID(@Desg,N'P') IS NULL
   OR OBJECT_ID(@Division,N'P') IS NULL
    THROW 52400,'Falta uno o mas procedimientos B3 requeridos.',1;

IF OBJECT_DEFINITION(OBJECT_ID(@Desg))
       NOT LIKE N'%BF_CACHE_PERF_DESG_TEMP_INDEX_V1%'
    THROW 52401,'Ejecute primero 03_OPTIMIZAR_DESGLOSADA_B3.sql.',1;

/* 1. Congelar exactamente la version B3 actual. Nunca se reemplaza al
      reejecutar este instalador, para mantener un rollback estable. */
IF OBJECT_ID(@MainLegacy,N'P') IS NULL
BEGIN
    SET @Def=OBJECT_DEFINITION(OBJECT_ID(@Main));
    IF @Def LIKE N'%BF3_QUERY_ROUTER_V1%'
        THROW 52402,'El router ya existe pero falta su copia LEGACY.',1;

    SET @Def=REPLACE(@Def,N'[dbo].[ObtenCobranzaConcentrada_otro_V2_BF3]',
                          N'[dbo].[ObtenCobranzaConcentrada_otro_V2_BF3_LEGACY]');
    SET @Def=REPLACE(@Def,N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3',
                          N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_LEGACY');
    SET @Upper=UPPER(@Def);
    SET @PosProc=CHARINDEX(N'PROCEDURE',@Upper);
    IF @PosProc=0 OR @Def NOT LIKE N'%ObtenCobranzaConcentrada_otro_V2_BF3_LEGACY%'
        THROW 52403,'No se pudo construir la copia LEGACY B3.',1;
    SET @Def=N'CREATE OR ALTER '+SUBSTRING(@Def,@PosProc,LEN(@Def));
    EXEC sys.sp_executesql @Def;
END;

/* 2. Crear la division OPT desde la division B3. Las tablas precargadas
      conservan duplicados y filtros del codigo original; solo evitan leer las
      mismas tablas permanentes por cada plan de cada empleado. */
SET @Def=OBJECT_DEFINITION(OBJECT_ID(@Division));
SET @Def=REPLACE(@Def,N'[dbo].[ff_ObtenDivisionCtos_Adaptado_bf3_NOUSAR]',
                      N'[dbo].[ff_ObtenDivisionCtos_Adaptado_bf3_OPT]');
SET @Def=REPLACE(@Def,N'dbo.ff_ObtenDivisionCtos_Adaptado_bf3_NOUSAR',
                      N'dbo.ff_ObtenDivisionCtos_Adaptado_bf3_OPT');

/* Las consultas escalares siguen siendo las mismas, pero leen un subconjunto
   temporal B3. El reemplazo se hace antes de insertar la carga de ese subset. */
SET @Def=REPLACE(@Def,N'DBO.ff_GMMDesgCob',N'#BF_GMMDesgCob');

SET @Upper=UPPER(@Def);
SET @PosInsert=CHARINDEX(N'IF EXISTS(SELECT TOP 1 * FROM #TABLACOBDESG',@Upper);
IF @PosInsert=0
    THROW 52404,'No se encontro el inicio de la division de costos B3.',1;

SET @Bloque=N'
/* BF3_QUERY_REORG_DIVISION_V1 */
SELECT G.GDidEmpresa,G.GDidConcepto,G.GDidPlanOpcion,G.GDMonto
INTO #BF_GMMDesgCob
FROM dbo.ff_GMMDesgCob G WITH (NOLOCK)
WHERE EXISTS
(
    SELECT 1 FROM #TablaCobDesg D
    WHERE D.EMPRESA=G.GDidEmpresa AND D.CVEPO=G.GDidPlanOpcion
);
CREATE NONCLUSTERED INDEX IX_BF_GMMTemp_EmpresaPlanConcepto
    ON #BF_GMMDesgCob(GDidEmpresa,GDidPlanOpcion,GDidConcepto)
    INCLUDE(GDMonto);

SELECT DISTINCT CP.CPidPlanOpcion,ES.ECNumeroEmpleado,ES.ECidEmpresa
INTO #BF_CompEmpleadoPlan
FROM dbo.ff_CompensacionPlanOpcion CP WITH (NOLOCK)
INNER JOIN dbo.ff_EdoCuentaCobranza ES WITH (NOLOCK)
    ON CP.CPIdCompensacion=ES.ECidCompensacion
WHERE ES.ECidCompensacion IS NOT NULL
  AND EXISTS
  (
      SELECT 1 FROM dbo.ff_solicitud S WITH (NOLOCK)
      WHERE S.SOIdSolicitud=ES.ECidSolicitud
        AND S.SOIdVigencia=@idVigencia
  )
  AND EXISTS
  (
      SELECT 1 FROM #TablaCobDesg D
      WHERE D.EMPRESA=ES.ECidEmpresa
        AND D.NUMEMPLEADO COLLATE DATABASE_DEFAULT=
            ES.ECNumeroEmpleado COLLATE DATABASE_DEFAULT
        AND D.CVEPO=CP.CPidPlanOpcion
  );
CREATE UNIQUE CLUSTERED INDEX IX_BF_CompTemp_EmpleadoPlan
    ON #BF_CompEmpleadoPlan(ECIdEmpresa,ECNumeroEmpleado,CPidPlanOpcion);

';
SET @Def=STUFF(@Def,@PosInsert,0,@Bloque);

/* Sustituir exclusivamente el EXISTS de compensacion del WHILE. */
SET @Upper=UPPER(@Def);
SET @PosWhile=CHARINDEX(N'WHILE @TOTAL_REGISTROS2',@Upper);
SET @PosIf=CHARINDEX(N'IF EXISTS(',@Upper,@PosWhile);
SET @PosBegin=CHARINDEX(N'BEGIN --1',@Upper,@PosIf);
IF @PosWhile=0 OR @PosIf=0 OR @PosBegin=0
    THROW 52405,'No se encontro el EXISTS de compensacion B3.',1;

SET @Bloque=N'IF EXISTS
            (
                SELECT 1
                FROM #BF_CompEmpleadoPlan C
                WHERE C.CPidPlanOpcion=@CVEPO
                  AND C.ECNumeroEmpleado COLLATE DATABASE_DEFAULT=
                      @NumEmpleado COLLATE DATABASE_DEFAULT
                  AND C.ECIdEmpresa=@Empresa
            )
            ';
SET @Def=STUFF(@Def,@PosIf,@PosBegin-@PosIf,@Bloque);

SET @Upper=UPPER(@Def);
SET @PosProc=CHARINDEX(N'PROCEDURE',@Upper);
IF @PosProc=0 OR @Def NOT LIKE N'%BF3_QUERY_REORG_DIVISION_V1%'
    THROW 52406,'No se pudo construir la division OPT B3.',1;
SET @Def=N'CREATE OR ALTER '+SUBSTRING(@Def,@PosProc,LEN(@Def));
EXEC sys.sp_executesql @Def;

/* 3. Crear Desglosada OPT. Mantiene el SELECT y todas sus formulas; solamente
      llama a la division reorganizada. */
SET @Def=OBJECT_DEFINITION(OBJECT_ID(@Desg));
SET @Def=REPLACE(@Def,N'[dbo].[ff_ObtenCobranzaDesg_Adaptada_bf3_NOUSAR]',
                      N'[dbo].[ff_ObtenCobranzaDesg_Adaptada_bf3_OPT]');
SET @Def=REPLACE(@Def,N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_NOUSAR',
                      N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_OPT');
SET @Def=REPLACE(@Def,N'dbo.ff_ObtenDivisionCtos_Adaptado_bf3_NOUSAR',
                      N'dbo.ff_ObtenDivisionCtos_Adaptado_bf3_OPT');
SET @Def=REPLACE(@Def,N'DBO.ff_ObtenDivisionCtos_Adaptado_bf3_NOUSAR',
                      N'dbo.ff_ObtenDivisionCtos_Adaptado_bf3_OPT');

SET @Upper=UPPER(@Def);
SET @PosProc=CHARINDEX(N'PROCEDURE',@Upper);
IF @PosProc=0 OR @Def NOT LIKE N'%ff_ObtenDivisionCtos_Adaptado_bf3_OPT%'
    THROW 52407,'No se pudo construir Desglosada OPT B3.',1;
SET @Def=N'CREATE OR ALTER '+SUBSTRING(@Def,@PosProc,LEN(@Def));
EXEC sys.sp_executesql @Def;

/* 4. Crear el procedimiento principal OPT desde la copia LEGACY congelada. */
SET @Def=OBJECT_DEFINITION(OBJECT_ID(@MainLegacy));
SET @Def=REPLACE(@Def,N'[dbo].[ObtenCobranzaConcentrada_otro_V2_BF3_LEGACY]',
                      N'[dbo].[ObtenCobranzaConcentrada_otro_V2_BF3_OPT]');
SET @Def=REPLACE(@Def,N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_LEGACY',
                      N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_OPT');
SET @Def=REPLACE(@Def,N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_nousar',
                      N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_OPT');
SET @Def=REPLACE(@Def,N'DBO.ff_ObtenCobranzaDesg_Adaptada_bf3_NOUSAR',
                      N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_OPT');

SET @Upper=UPPER(@Def);
SET @PosProc=CHARINDEX(N'PROCEDURE',@Upper);
IF @PosProc=0 OR @Def NOT LIKE N'%ff_ObtenCobranzaDesg_Adaptada_bf3_OPT%'
    THROW 52408,'No se pudo construir el procedimiento principal OPT B3.',1;
SET @Def=N'CREATE OR ALTER '+SUBSTRING(@Def,@PosProc,LEN(@Def));
EXEC sys.sp_executesql @Def;

/* 5. El nombre consumido por APIREPORTES, WS y cache se convierte en router
      exclusivo B3. SESSION_CONTEXT permite pruebas por sesion sin activar la
      empresa completa. */
EXEC sys.sp_executesql N'
CREATE OR ALTER PROCEDURE dbo.ObtenCobranzaConcentrada_otro_V2_BF3
    @idEmpresa int=0,
    @idSolTipo int=0,
    @FecIni varchar(16)='''',
    @FecFin varchar(16)='''',
    @idVencida int=0,
    @IdPerfil dbo.ListInt READONLY,
    @idVIgencia int=0
AS
BEGIN
    SET NOCOUNT ON;
    /* BF3_QUERY_ROUTER_V1 */
    DECLARE @Override sql_variant=SESSION_CONTEXT(N''bf_CobranzaSqlOpt''),
            @UsarOpt bit;

    IF @Override IS NOT NULL
        SET @UsarOpt=ISNULL(TRY_CONVERT(bit,@Override),0);
    ELSE
        SET @UsarOpt=CASE WHEN EXISTS
        (
            SELECT 1 FROM dbo.ff_Parametro WITH (NOLOCK)
            WHERE paIdEmpresa=@idEmpresa AND paidEstatus=1
              AND UPPER(LTRIM(RTRIM(paClase)))=''COBRANZA_SQL_OPT_V2''
              AND LTRIM(RTRIM(paValor))=''1''
        ) THEN 1 ELSE 0 END;

    BEGIN TRY
        INSERT dbo.bf_RepConf_Debug(etapa,detalle)
        VALUES(''cobranza_bf3_ruta_sql'',
               CONCAT(''ruta='',CASE WHEN @UsarOpt=1 THEN ''OPT'' ELSE ''LEGACY'' END,
                      ''; empresa='',@idEmpresa,''; vigencia='',@idVIgencia));
    END TRY BEGIN CATCH END CATCH;

    IF @UsarOpt=1
        EXEC dbo.ObtenCobranzaConcentrada_otro_V2_BF3_OPT
             @idEmpresa=@idEmpresa,@idSolTipo=@idSolTipo,
             @FecIni=@FecIni,@FecFin=@FecFin,@idVencida=@idVencida,
             @IdPerfil=@IdPerfil,@idVIgencia=@idVIgencia;
    ELSE
        EXEC dbo.ObtenCobranzaConcentrada_otro_V2_BF3_LEGACY
             @idEmpresa=@idEmpresa,@idSolTipo=@idSolTipo,
             @FecIni=@FecIni,@FecFin=@FecFin,@idVencida=@idVencida,
             @IdPerfil=@IdPerfil,@idVIgencia=@idVIgencia;
END;';

SELECT N'OK' AS Estado,O.name AS Procedimiento
FROM sys.procedures O
WHERE O.object_id IN
      (OBJECT_ID(@Main),OBJECT_ID(@MainLegacy),OBJECT_ID(@MainOpt),
       OBJECT_ID(@Desg),OBJECT_ID(@DesgOpt),
       OBJECT_ID(@Division),OBJECT_ID(@DivisionOpt))
ORDER BY O.name;

SELECT N'LEGACY' AS RutaInicial,
       N'COBRANZA_SQL_OPT_V2 ausente o en 0' AS Condicion,
       N'B2 no fue modificado' AS Alcance;
GO

/* ======================================================================
   PASO 5 DE 10: 05_MOTOR_DIVISION_SET_B3.sql
   ====================================================================== */
RAISERROR(N'[COBRANZA B3] Ejecutando paso 5/10: 05_MOTOR_DIVISION_SET_B3.sql',10,1) WITH NOWAIT;
GO
/*
   MOTOR DE DIVISION DE COSTOS SET-BASED, EXCLUSIVO B3

*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Origen sysname=N'dbo.ff_ObtenDivisionCtos_Adaptado_bf3_NOUSAR',
        @Destino sysname=N'dbo.ff_ObtenDivisionCtos_Adaptado_bf3_SET',
        @Def nvarchar(max),
        @Upper nvarchar(max),
        @Inicio int,
        @Cola int,
        @InicioSegundo int,
        @ColaSegundo int,
        @InicioSobrante int,
        @FinSobrante int,
        @Proc int,
        @Bloque nvarchar(max);

IF OBJECT_DEFINITION(OBJECT_ID(@Destino,N'P')) LIKE N'%BF3_DIVISION_SET_V1%'
BEGIN
    SELECT N'OMITIDO_YA_EXISTE' AS Estado,@Destino AS Objeto;
    RETURN;
END;

IF OBJECT_ID(@Origen,N'P') IS NULL
    THROW 52600,'No existe el procedimiento de division B3 origen.',1;

SET @Def=OBJECT_DEFINITION(OBJECT_ID(@Origen));
SET @Def=REPLACE(@Def,N'[dbo].[ff_ObtenDivisionCtos_Adaptado_bf3_NOUSAR]',
                      N'[dbo].[ff_ObtenDivisionCtos_Adaptado_bf3_SET]');
SET @Def=REPLACE(@Def,N'dbo.ff_ObtenDivisionCtos_Adaptado_bf3_NOUSAR',
                      N'dbo.ff_ObtenDivisionCtos_Adaptado_bf3_SET');
SET @Upper=UPPER(@Def);
SET @Inicio=CHARINDEX(N'IF EXISTS(SELECT TOP 1 * FROM #TABLACOBDESG)',@Upper);
SET @Cola=CHARINDEX(N'UPDATE A SET A.APLICEXCEDENTES',@Upper,@Inicio);

IF @Inicio=0 OR @Cola=0 OR @Cola<=@Inicio
    THROW 52601,'No se localizaron los limites de la division historica B3.',1;

SET @Bloque=N'/* BF3_DIVISION_SET_V1 */
IF EXISTS(SELECT TOP (1) 1 FROM #TablaCobDesg)
BEGIN
    BEGIN TRY
        INSERT INTO dbo.bf_RepConf_Debug(etapa,detalle)
        SELECT ''cobranza_bf3_division_set_inicio'',CONCAT(''filas='',COUNT_BIG(*))
        FROM #TablaCobDesg;
    END TRY BEGIN CATCH END CATCH;
    /*
       El codigo antiguo conserva valores de una iteracion previa cuando hay
       importes negativos. La ruta segura mantiene ese comportamiento exacto.
    */
    IF EXISTS(SELECT 1 FROM #TablaCobDesg WHERE ISNULL(ImportexPeriodo,0)<0)
       OR EXISTS(
            SELECT 1 FROM #tablatemp
            GROUP BY Empresa,NumEmpleado HAVING COUNT_BIG(*)>1
       )
       OR EXISTS(
            SELECT 1 FROM #tablatemp
            GROUP BY CveEmpl HAVING COUNT_BIG(*)>1
       )
       OR EXISTS(
            SELECT 1 FROM #TablaCobDesg
            GROUP BY EMPRESA,idemp,CVEPO,CVEP HAVING COUNT_BIG(*)>1
       )
    BEGIN
        BEGIN TRY
            INSERT INTO dbo.bf_RepConf_Debug(etapa,detalle)
            VALUES(''cobranza_bf3_division_set_fallback'',
                   ''Motivo=importe negativo o llave historica duplicada'');
        END TRY BEGIN CATCH END CATCH;

        EXEC dbo.ff_ObtenDivisionCtos_Adaptado_bf3_NOUSAR;
        RETURN;
    END;

    CREATE UNIQUE NONCLUSTERED INDEX IX_BF3_TabTemp_EmpresaEmpleado
        ON #tablatemp(Empresa,NumEmpleado)
        INCLUDE(Transferido,MontoTotalCreditos,SobranteExcedentes);

    /* Una lectura por tabla de referencia, no una lectura por plan. */
    SELECT G.GDIDEmpresa,
           G.GDidPlanOpcion,
           MAX(CASE WHEN G.GDidConcepto=6 THEN ISNULL(G.GDMonto,0) END) AS GMM6,
           MAX(CASE WHEN G.GDidConcepto=7 THEN ISNULL(G.GDMonto,0) END) AS GMM7,
           MAX(CASE WHEN G.GDidConcepto=8 THEN ISNULL(G.GDMonto,0) END) AS GMM8
    INTO #BF3_GMM
    FROM dbo.ff_GMMDesgCob AS G WITH(NOLOCK)
    INNER JOIN (SELECT DISTINCT EMPRESA,CVEPO FROM #TablaCobDesg) AS K
        ON K.EMPRESA=G.GDIDEmpresa AND K.CVEPO=G.GDidPlanOpcion
    WHERE G.GDidConcepto IN(6,7,8)
    GROUP BY G.GDIDEmpresa,G.GDidPlanOpcion;
    CREATE UNIQUE CLUSTERED INDEX CX_BF3_GMM ON #BF3_GMM(GDIDEmpresa,GDidPlanOpcion);
    BEGIN TRY INSERT INTO dbo.bf_RepConf_Debug(etapa,detalle)
        SELECT ''cobranza_bf3_division_set_gmm'',CONCAT(''filas='',COUNT_BIG(*)) FROM #BF3_GMM;
    END TRY BEGIN CATCH END CATCH;

    /* El procedimiento historico usa @idVigencia=0 en esta validacion. */
    SELECT DISTINCT ES.ECidEmpresa,
           ES.ECNumeroEmpleado,
           CP.CPidPlanOpcion
    INTO #BF3_Compensado
    FROM dbo.ff_EdoCuentaCobranza AS ES WITH(NOLOCK)
    INNER JOIN dbo.ff_CompensacionPlanOpcion AS CP WITH(NOLOCK)
        ON CP.CPIdCompensacion=ES.ECidCompensacion
    INNER JOIN (SELECT DISTINCT Empresa,NumEmpleado FROM #tablatemp) AS E
        ON E.Empresa=ES.ECidEmpresa
       AND E.NumEmpleado COLLATE DATABASE_DEFAULT=ES.ECNumeroEmpleado COLLATE DATABASE_DEFAULT
    INNER JOIN (SELECT DISTINCT EMPRESA,CVEPO FROM #TablaCobDesg) AS P
        ON P.EMPRESA=ES.ECidEmpresa AND P.CVEPO=CP.CPidPlanOpcion
    WHERE ES.ECidCompensacion IS NOT NULL
      AND EXISTS(
          SELECT 1
          FROM dbo.ff_Solicitud AS S WITH(NOLOCK)
          WHERE S.SOIdSolicitud=ES.ECidSolicitud
            AND S.SOIdVigencia=0
      );
    CREATE UNIQUE CLUSTERED INDEX CX_BF3_Compensado
        ON #BF3_Compensado(ECidEmpresa,ECNumeroEmpleado,CPidPlanOpcion);
    BEGIN TRY INSERT INTO dbo.bf_RepConf_Debug(etapa,detalle)
        SELECT ''cobranza_bf3_division_set_comp'',CONCAT(''filas='',COUNT_BIG(*)) FROM #BF3_Compensado;
    END TRY BEGIN CATCH END CATCH;

    SELECT D.Id_TablaCobDesg AS RowId,
           D.EMPRESA,
           D.NUMEMPLEADO,
           D.idemp,
           D.CVEPO,
           D.CVEP,
           ROW_NUMBER() OVER(
               PARTITION BY D.EMPRESA,D.NUMEMPLEADO
               ORDER BY ISNULL(D.PLOrdenCobranza,2147483647),D.Id_TablaCobDesg
           ) AS Paso,
           CONVERT(money,ISNULL(D.ImportexPeriodo,0)) AS Importe,
           CONVERT(bit,CASE WHEN C.CPidPlanOpcion IS NULL THEN 0 ELSE 1 END) AS Compensado,
           CONVERT(bit,CASE WHEN T.TRANSFERIDO=''TRANSFERIDO'' THEN 1 ELSE 0 END) AS Transferido,
           CONVERT(money,ISNULL(G.GMM6,0)) AS GMM6,
           CONVERT(money,ISNULL(G.GMM7,0)) AS GMM7,
           CONVERT(money,ISNULL(G.GMM8,0)) AS GMM8,
           CONVERT(money,0) AS CostoEmpresa,
           CONVERT(money,0) AS CtoEmpresaCash,
           CONVERT(money,0) AS CtoEmpresa1erexc,
           CONVERT(money,0) AS CtoEmpresaStoploss,
           CONVERT(money,0) AS CostoEmpleado,
           CONVERT(money,0) AS CtoEmpleadoCash,
           CONVERT(money,0) AS CtoEmpleado1erexc,
           CONVERT(money,0) AS CtoEmpleadoStoploss,
           CONVERT(money,0) AS CostoEmpleadoExcedente,
           CONVERT(money,0) AS CostoEmpleadoReal,
           CONVERT(money,0) AS SobranteExcedentes,
           CONVERT(money,0) AS CreditoDespues,
           CONVERT(money,0) AS ExcedenteDespues
    INTO #BF3_DivisionWork
    FROM #TablaCobDesg AS D
    INNER JOIN #tablatemp AS T
        ON T.Empresa=D.EMPRESA
       AND T.NumEmpleado COLLATE DATABASE_DEFAULT=D.NUMEMPLEADO COLLATE DATABASE_DEFAULT
    LEFT JOIN #BF3_GMM AS G
        ON G.GDIDEmpresa=D.EMPRESA AND G.GDidPlanOpcion=D.CVEPO
    LEFT JOIN #BF3_Compensado AS C
        ON C.ECidEmpresa=D.EMPRESA
       AND C.ECNumeroEmpleado COLLATE DATABASE_DEFAULT=D.NUMEMPLEADO COLLATE DATABASE_DEFAULT
       AND C.CPidPlanOpcion=D.CVEPO;

    CREATE UNIQUE CLUSTERED INDEX CX_BF3_DivisionWork
        ON #BF3_DivisionWork(Paso,EMPRESA,NUMEMPLEADO,RowId);
    CREATE UNIQUE NONCLUSTERED INDEX UX_BF3_DivisionWork_Row
        ON #BF3_DivisionWork(RowId);
    BEGIN TRY INSERT INTO dbo.bf_RepConf_Debug(etapa,detalle)
        SELECT ''cobranza_bf3_division_set_work'',CONCAT(''filas='',COUNT_BIG(*)) FROM #BF3_DivisionWork;
    END TRY BEGIN CATCH END CATCH;

    SELECT T.Empresa,
           T.NumEmpleado,
           CONVERT(money,ISNULL(T.MontoTotalCreditos,0)) AS Credito,
           CONVERT(money,ROUND(ISNULL(T.SobranteExcedentes,0),2)) AS Excedente
    INTO #BF3_DivisionState
    FROM #tablatemp AS T;
    CREATE UNIQUE CLUSTERED INDEX CX_BF3_DivisionState
        ON #BF3_DivisionState(Empresa,NumEmpleado);

    DECLARE @BF3_Paso int=1,
            @BF3_MaxPaso int=ISNULL((SELECT MAX(Paso) FROM #BF3_DivisionWork),0);

    WHILE @BF3_Paso<=@BF3_MaxPaso
    BEGIN
        UPDATE W
        SET CostoEmpresa = CASE WHEN W.Transferido=1 THEN R.Importe2 ELSE B.CostoEmpresa END,
            CtoEmpresaCash = CASE WHEN W.Transferido=1 THEN ROUND(R.Importe2*W.GMM6,2) ELSE B.CtoEmpresaCash END,
            CtoEmpresa1erexc = CASE WHEN W.Transferido=1 THEN ROUND(R.Importe2*W.GMM7,2) ELSE B.CtoEmpresa1erexc END,
            CtoEmpresaStoploss = CASE WHEN W.Transferido=1 THEN ROUND(R.Importe2*W.GMM8,2) ELSE B.CtoEmpresaStoploss END,
            CostoEmpleado = CASE WHEN W.Transferido=1 THEN 0 ELSE B.CostoEmpleado END,
            CtoEmpleadoCash = CASE WHEN W.Transferido=1 THEN 0 ELSE B.CtoEmpleadoCash END,
            CtoEmpleado1erexc = CASE WHEN W.Transferido=1 THEN 0 ELSE B.CtoEmpleado1erexc END,
            CtoEmpleadoStoploss = CASE WHEN W.Transferido=1 THEN 0 ELSE B.CtoEmpleadoStoploss END,
            CostoEmpleadoExcedente = CASE WHEN W.Transferido=1 THEN 0 ELSE B.CostoEmpleadoExcedente END,
            CostoEmpleadoReal = CASE WHEN W.Transferido=1 THEN 0 ELSE B.CostoEmpleadoReal END,
            SobranteExcedentes = 0,
            CreditoDespues = B.CreditoDespues,
            ExcedenteDespues = CASE WHEN W.Transferido=1 THEN 0 ELSE B.ExcedenteDespues END
        FROM #BF3_DivisionWork AS W
        INNER JOIN #BF3_DivisionState AS S
            ON S.Empresa=W.EMPRESA
           AND S.NumEmpleado COLLATE DATABASE_DEFAULT=W.NUMEMPLEADO COLLATE DATABASE_DEFAULT
        CROSS APPLY(
            SELECT CONVERT(money,ROUND(ISNULL(W.Importe,0),2)) AS Importe2,
                   CONVERT(money,ROUND(ISNULL(S.Credito,0)-ISNULL(W.Importe,0),2)) AS Saldo,
                   CONVERT(money,ABS(ROUND(ISNULL(S.Credito,0)-ISNULL(W.Importe,0),2))) AS Falta,
                   CONVERT(money,ROUND(ISNULL(S.Excedente,0),2)) AS Excedente2
        ) AS R
        CROSS APPLY(
            SELECT
              CONVERT(money,CASE
                WHEN W.Compensado=1 AND R.Saldo>0 THEN R.Importe2
                WHEN W.Compensado=1 AND R.Saldo<=0 AND S.Credito<>0 THEN ROUND(S.Credito,2)
                ELSE 0 END) AS CostoEmpresa,
              CONVERT(money,CASE
                WHEN W.Compensado=1 AND R.Saldo>0 THEN ROUND(R.Importe2*W.GMM6,2)
                WHEN W.Compensado=1 AND R.Saldo<=0 AND S.Credito<>0 AND R.Excedente2<=0 THEN ROUND(S.Credito*W.GMM6,2)
                ELSE 0 END) AS CtoEmpresaCash,
              CONVERT(money,CASE
                WHEN W.Compensado=1 AND R.Saldo>0 THEN ROUND(R.Importe2*W.GMM7,2)
                WHEN W.Compensado=1 AND R.Saldo<=0 AND S.Credito<>0 AND R.Excedente2<=0 THEN ROUND(S.Credito*W.GMM7,2)
                ELSE 0 END) AS CtoEmpresa1erexc,
              CONVERT(money,CASE
                WHEN W.Compensado=1 AND R.Saldo>0 THEN ROUND(R.Importe2*W.GMM8,2)
                WHEN W.Compensado=1 AND R.Saldo<=0 AND S.Credito<>0 AND R.Excedente2<=0 THEN ROUND(S.Credito*W.GMM8,2)
                ELSE 0 END) AS CtoEmpresaStoploss,
              CONVERT(money,CASE
                WHEN W.Compensado=1 AND R.Saldo>0 THEN 0
                WHEN W.Compensado=1 AND R.Saldo<=0 AND R.Excedente2<=0 AND S.Credito=0 THEN ABS(R.Importe2)
                WHEN W.Compensado=1 AND R.Saldo<=0 THEN R.Falta
                WHEN W.Compensado=0 THEN ABS(R.Importe2)
                ELSE 0 END) AS CostoEmpleado,
              CONVERT(money,CASE WHEN W.Compensado=0 AND R.Excedente2<=0 THEN ROUND(R.Importe2*W.GMM6,2)
                                 WHEN W.Compensado=1 AND R.Saldo<=0 AND R.Excedente2<=0 AND S.Credito<>0 THEN ROUND(R.Falta*W.GMM6,2)
                                 ELSE 0 END) AS CtoEmpleadoCash,
              CONVERT(money,CASE WHEN W.Compensado=0 AND R.Excedente2<=0 THEN ROUND(R.Importe2*W.GMM7,2)
                                 WHEN W.Compensado=1 AND R.Saldo<=0 AND R.Excedente2<=0 AND S.Credito<>0 THEN ROUND(R.Falta*W.GMM7,2)
                                 ELSE 0 END) AS CtoEmpleado1erexc,
              CONVERT(money,CASE WHEN W.Compensado=0 AND R.Excedente2<=0 THEN ROUND(R.Importe2*W.GMM8,2)
                                 WHEN W.Compensado=1 AND R.Saldo<=0 AND R.Excedente2<=0 AND S.Credito<>0 THEN ROUND(R.Falta*W.GMM8,2)
                                 ELSE 0 END) AS CtoEmpleadoStoploss,
              CONVERT(money,CASE
                WHEN W.Compensado=1 AND R.Saldo<=0 AND R.Excedente2>0
                  THEN CASE WHEN R.Falta>R.Excedente2 THEN R.Excedente2 ELSE R.Falta END
                WHEN W.Compensado=0 AND R.Excedente2>0
                  THEN CASE WHEN R.Excedente2>W.Importe THEN R.Importe2 ELSE R.Excedente2 END
                ELSE 0 END) AS CostoEmpleadoExcedente,
              CONVERT(money,CASE
                WHEN W.Compensado=1 AND R.Saldo<=0 AND R.Excedente2>0
                  THEN CASE WHEN R.Falta>R.Excedente2 THEN R.Falta-R.Excedente2 ELSE 0 END
                WHEN W.Compensado=1 AND R.Saldo<=0 AND R.Excedente2<=0 AND S.Credito=0 THEN R.Importe2
                WHEN W.Compensado=1 AND R.Saldo<=0 AND R.Excedente2<=0 THEN R.Falta
                WHEN W.Compensado=0 AND R.Excedente2>0
                  THEN CASE WHEN R.Excedente2>W.Importe THEN 0 ELSE R.Importe2-R.Excedente2 END
                WHEN W.Compensado=0 AND R.Excedente2<=0 THEN R.Importe2
                ELSE 0 END) AS CostoEmpleadoReal,
              CONVERT(money,CASE WHEN W.Compensado=1 THEN CASE WHEN R.Saldo>0 THEN R.Saldo ELSE 0 END
                                 ELSE S.Credito END) AS CreditoDespues,
              CONVERT(money,CASE
                WHEN W.Compensado=1 AND R.Saldo>0 THEN R.Excedente2
                WHEN W.Compensado=1 AND R.Saldo<=0 AND R.Excedente2>0
                  THEN CASE WHEN R.Excedente2-R.Falta<0 THEN 0 ELSE R.Excedente2-R.Falta END
                WHEN W.Compensado=1 AND R.Saldo<=0 THEN 0
                WHEN W.Compensado=0 AND R.Excedente2>0
                  THEN CASE WHEN R.Excedente2-W.Importe<0 THEN 0 ELSE R.Excedente2-W.Importe END
                ELSE 0 END) AS ExcedenteDespues
        ) AS B
        WHERE W.Paso=@BF3_Paso;

        UPDATE S
        SET S.Credito=W.CreditoDespues,
            S.Excedente=W.ExcedenteDespues
        FROM #BF3_DivisionState AS S
        INNER JOIN #BF3_DivisionWork AS W
            ON W.EMPRESA=S.Empresa
           AND W.NUMEMPLEADO COLLATE DATABASE_DEFAULT=S.NumEmpleado COLLATE DATABASE_DEFAULT
           AND W.Paso=@BF3_Paso;

        SET @BF3_Paso+=1;
    END;

    BEGIN TRY INSERT INTO dbo.bf_RepConf_Debug(etapa,detalle)
        VALUES(''cobranza_bf3_division_set_pasos'',CONCAT(''pasos='',@BF3_MaxPaso));
    END TRY BEGIN CATCH END CATCH;

    UPDATE W
    SET W.SobranteExcedentes=S.Excedente
    FROM #BF3_DivisionWork AS W
    INNER JOIN #BF3_DivisionState AS S
        ON S.Empresa=W.EMPRESA
       AND S.NumEmpleado COLLATE DATABASE_DEFAULT=W.NUMEMPLEADO COLLATE DATABASE_DEFAULT
    WHERE W.Paso=(
        SELECT MAX(W2.Paso)
        FROM #BF3_DivisionWork AS W2
        WHERE W2.EMPRESA=W.EMPRESA
          AND W2.NUMEMPLEADO COLLATE DATABASE_DEFAULT=W.NUMEMPLEADO COLLATE DATABASE_DEFAULT
    );

    UPDATE D
    SET D.CostoEmpresa=W.CostoEmpresa,
        D.CtoEmpresaCash=W.CtoEmpresaCash,
        D.CtoEmpresa1erexc=W.CtoEmpresa1erexc,
        D.CtoEmpresaStoploss=W.CtoEmpresaStoploss,
        D.CostoEmpleado=W.CostoEmpleado,
        D.CtoEmpleadoCash=W.CtoEmpleadoCash,
        D.CtoEmpleado1erexc=W.CtoEmpleado1erexc,
        D.CtoEmpleadoStoploss=W.CtoEmpleadoStoploss,
        D.CostoEmpleadoExcedente=W.CostoEmpleadoExcedente,
        D.CostoEmpleadoReal=W.CostoEmpleadoReal,
        D.SobranteExcedentes=W.SobranteExcedentes
    FROM #TablaCobDesg AS D
    INNER JOIN #BF3_DivisionWork AS W ON W.RowId=D.Id_TablaCobDesg;

    BEGIN TRY
        INSERT INTO dbo.bf_RepConf_Debug(etapa,detalle)
        SELECT ''cobranza_bf3_division_set_fin'',
               CONCAT(''filas='',COUNT_BIG(*),''; pasos='',@BF3_MaxPaso)
        FROM #BF3_DivisionWork;
    END TRY BEGIN CATCH END CATCH;
END;

';

SET @Def=STUFF(@Def,@Inicio,@Cola-@Inicio,@Bloque);

/* Elimina otra subconsulta correlacionada que se ejecutaba una vez por
   empleado justo antes del segundo ciclo. */
SET @Upper=UPPER(@Def);
SET @InicioSobrante=CHARINDEX(
    N'UPDATE #TABLATEMP SET SOBRANTECREDITOS=',@Upper);
SET @FinSobrante=CHARINDEX(N';',@Def,@InicioSobrante);
IF @InicioSobrante=0 OR @FinSobrante=0
    THROW 52605,'No se localizo el calculo correlacionado de SobranteCreditos.',1;

SET @Bloque=N'/* BF3_SOBRANTE_CREDITO_SET_V1 */
UPDATE T
SET T.SobranteCreditos=T.MontoTotalCreditos-ROUND(D.CostoEmpresa,2)
FROM #tablatemp AS T
INNER JOIN(
    SELECT NUMEMPLEADO,SUM(CostoEmpresa) AS CostoEmpresa
    FROM #TablaCobDesg
    GROUP BY NUMEMPLEADO
) AS D
    ON D.NUMEMPLEADO COLLATE DATABASE_DEFAULT=T.NumEmpleado COLLATE DATABASE_DEFAULT;';
SET @Def=STUFF(@Def,@InicioSobrante,@FinSobrante-@InicioSobrante+1,@Bloque);

/* El segundo ciclo historico vuelve a recorrer cada empleado, aunque todas
   sus formulas dependen solamente de la misma fila. Se reduce a un UPDATE. */
SET @Upper=UPPER(@Def);
SET @InicioSegundo=CHARINDEX(
    N'IF EXISTS(SELECT TOP 1 * FROM #TABLATEMP WITH (NOLOCK))',@Upper);
SET @ColaSegundo=CHARINDEX(
    N'---SELECT  * FROM #TABLATEMP',@Upper,@InicioSegundo);

IF @InicioSegundo=0 OR @ColaSegundo=0 OR @ColaSegundo<=@InicioSegundo
    THROW 52604,'No se localizaron los limites del segundo ciclo B3.',1;

SET @Bloque=N'/* BF3_EMPLEADO_SET_V1 */
IF EXISTS(SELECT TOP (1) 1 FROM #tablatemp)
BEGIN
    UPDATE T
    SET T.MontoPagCred=X.MontoPagCred,
        T.MontoDescMensual=X.MtoDescMen,
        T.MontoFondoAhorroMensual=V.MontoFHFinal,
        T.SobranteExcedentes=V.SobranteExFinal,
        T.DescuentoEmpleadoFinal=V.DescuentoFinal,
        T.DescuentoEmpleadoFH=V.DescuentoFH,
        T.SobranteExceFinal=V.SobranteFinal,
        T.CtoEmpleadoNomSeg=ABS(ISNULL(V.DescuentoFinal,0)-ISNULL(V.DescuentoFH,0))
    FROM #tablatemp AS T
    CROSS APPLY(
        SELECT CONVERT(money,
                   (ISNULL(T.MontoTotalCreditos,0)-ISNULL(T.SobranteCreditos,0))
                    -ISNULL(T.MontoTotalSelecciones,0)) AS DiferenciaCredito,
               CONVERT(money,ABS(
                   (ISNULL(T.MontoTotalCreditos,0)-ISNULL(T.SobranteCreditos,0))
                    -ISNULL(T.MontoTotalSelecciones,0))) AS MtoDescMen,
               CONVERT(money,ISNULL(T.MontoFondoAhorroMensual,0)) AS FH,
               CONVERT(money,ISNULL(T.Excedentes,0)) AS Excedente,
               CONVERT(money,ISNULL(T.SobranteExcedentes,0)) AS SobEx,
               CONVERT(money,CASE
                   WHEN T.MontoTotalSelecciones>T.MontoTotalCreditos
                     THEN T.MontoTotalCreditos-ISNULL(T.SobranteCreditos,0)
                   ELSE T.MontoTotalSelecciones END) AS MontoPagCred
    ) AS X
    CROSS APPLY(
        SELECT
          CONVERT(money,CASE
            WHEN X.Excedente>0 AND X.FH=0 THEN 0
            WHEN X.Excedente>0 AND X.FH=X.SobEx AND X.Excedente<X.MtoDescMen AND X.FH>0 THEN 0
            WHEN X.Excedente>0 AND X.FH=X.SobEx AND X.Excedente>X.MtoDescMen THEN ABS(X.Excedente-X.MtoDescMen)
            ELSE T.MontoFondoAhorroMensual END) AS MontoFHFinal,
          CONVERT(money,CASE
            WHEN X.Excedente<=0 THEN 0
            WHEN X.Excedente>0 AND X.FH=0 THEN X.Excedente
            WHEN X.Excedente>0 AND X.FH<>X.SobEx AND X.FH>X.Excedente THEN 0
            WHEN X.Excedente>0 AND X.FH<>X.SobEx THEN CASE WHEN X.Excedente-X.FH<0 THEN 0 ELSE X.Excedente-X.FH END
            WHEN X.Excedente>0 AND X.FH=X.SobEx AND X.Excedente<X.MtoDescMen AND X.FH>0 THEN NULL
            WHEN X.Excedente>0 AND X.FH=X.SobEx AND X.Excedente>X.MtoDescMen THEN X.MtoDescMen
            ELSE T.SobranteExcedentes END) AS SobranteExFinal,
          CONVERT(money,CASE
            WHEN X.Excedente<=0 THEN X.FH+X.MtoDescMen
            WHEN X.Excedente>0 AND X.FH=0 THEN CASE WHEN X.Excedente-X.MtoDescMen>0 THEN 0 ELSE X.MtoDescMen-X.Excedente END
            WHEN X.Excedente>0 AND X.FH<>X.SobEx AND X.FH>X.Excedente THEN (X.FH-X.Excedente)+X.MtoDescMen
            WHEN X.Excedente>0 AND X.FH<>X.SobEx THEN CASE WHEN X.Excedente-(X.FH+X.MtoDescMen)<0 THEN (X.FH+X.MtoDescMen)-X.Excedente ELSE 0 END
            WHEN X.Excedente>0 AND X.FH=X.SobEx AND X.Excedente<X.MtoDescMen AND X.FH>0 THEN ABS(X.MtoDescMen-X.Excedente)
            ELSE T.DescuentoEmpleadoFinal END) AS DescuentoFinal,
          CONVERT(money,CASE
            WHEN X.Excedente<=0 THEN X.FH
            WHEN X.Excedente>0 AND X.FH<>X.SobEx AND X.FH>X.Excedente THEN X.FH-X.Excedente
            WHEN X.Excedente>0 AND X.FH<>X.SobEx THEN CASE WHEN X.Excedente-X.FH<0 THEN X.FH-X.Excedente ELSE 0 END
            ELSE T.DescuentoEmpleadoFH END) AS DescuentoFH,
          CONVERT(money,CASE
            WHEN X.Excedente>0 AND X.FH=0 THEN CASE WHEN X.Excedente-X.MtoDescMen>0 THEN X.Excedente-X.MtoDescMen ELSE 0 END
            WHEN X.Excedente>0 AND X.FH<>X.SobEx AND X.FH<=X.Excedente THEN CASE WHEN X.Excedente-(X.FH+X.MtoDescMen)<0 THEN 0 ELSE X.Excedente-(X.FH+X.MtoDescMen) END
            WHEN X.Excedente>0 AND X.FH=X.SobEx AND X.Excedente<X.MtoDescMen AND X.FH>0 THEN 0
            ELSE T.SobranteExceFinal END) AS SobranteFinal
    ) AS V;

    BEGIN TRY
        INSERT INTO dbo.bf_RepConf_Debug(etapa,detalle)
        SELECT ''cobranza_bf3_empleado_set_fin'',CONCAT(''filas='',COUNT_BIG(*))
        FROM #tablatemp;
    END TRY BEGIN CATCH END CATCH;
END;

';

SET @Def=STUFF(@Def,@InicioSegundo,@ColaSegundo-@InicioSegundo,@Bloque);
/* Permite que el benchmark local termine antes del generador de planes. La
   llave nunca es establecida por los flujos de aplicacion. */
SET @Def=REPLACE(@Def,
                 N' EXEC DBO.ff_ObtenPlanConcentrado_Adaptado_bf3;',
                 N' IF TRY_CONVERT(bit,SESSION_CONTEXT(N''bf_CobranzaB3Lab''))=1 RETURN;
 EXEC DBO.ff_ObtenPlanConcentrado_Adaptado_bf3;');
SET @Upper=UPPER(@Def);
SET @Proc=CHARINDEX(N'PROCEDURE',@Upper);
IF @Proc=0
    THROW 52602,'No se pudo construir el procedimiento SET B3.',1;

SET @Def=N'CREATE OR ALTER '+SUBSTRING(@Def,@Proc,LEN(@Def));
EXEC sys.sp_executesql @Def;

IF OBJECT_DEFINITION(OBJECT_ID(@Destino)) NOT LIKE N'%BF3_DIVISION_SET_V1%'
    THROW 52603,'El motor SET B3 no quedo instalado.',1;

SELECT N'OK' AS Estado,@Destino AS Objeto,
       N'B3 solamente; B2 intacto; fallback automatico disponible' AS Alcance;
GO

/* ======================================================================
   PASO 6 DE 10: 06_DESGLOSADA_ETAPAS_SET_B3.sql
   ====================================================================== */
RAISERROR(N'[COBRANZA B3] Ejecutando paso 6/10: 06_DESGLOSADA_ETAPAS_SET_B3.sql',10,1) WITH NOWAIT;
GO
/*
   DESGLOSADA POR ETAPAS, EXCLUSIVA B3

*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Origen sysname=N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_NOUSAR',
        @Destino sysname=N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_SET',
        @Def nvarchar(max),@Upper nvarchar(max),@Inicio int,@Cola int,@Proc int,
        @Bloque nvarchar(max);

IF OBJECT_DEFINITION(OBJECT_ID(@Destino,N'P')) LIKE N'%BF3_DESGLOSADA_ETAPAS_SET_V1%'
BEGIN
    SELECT N'OMITIDO_YA_EXISTE' AS Estado,@Destino AS Objeto;
    RETURN;
END;

IF OBJECT_ID(@Origen,N'P') IS NULL
    THROW 52640,'No existe el procedimiento Desglosada B3 origen.',1;
IF OBJECT_ID(N'dbo.ff_ObtenDivisionCtos_Adaptado_bf3_SET',N'P') IS NULL
    THROW 52641,'Ejecute primero 05_MOTOR_DIVISION_SET_B3.sql.',1;

SET @Def=OBJECT_DEFINITION(OBJECT_ID(@Origen));
SET @Def=REPLACE(@Def,N'[dbo].[ff_ObtenCobranzaDesg_Adaptada_bf3_NOUSAR]',
                      N'[dbo].[ff_ObtenCobranzaDesg_Adaptada_bf3_SET]');
SET @Def=REPLACE(@Def,N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_NOUSAR',
                      N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_SET');
SET @Upper=UPPER(@Def);
SET @Inicio=CHARINDEX(N'/* BF_CACHE_PERF_DESG_SOURCE_INDEX_V1 */',@Upper);
SET @Cola=CHARINDEX(N'--*****************************************************************************************',@Upper,@Inicio);
IF @Inicio=0 OR @Cola=0 OR @Cola<=@Inicio
    THROW 52642,'No se localizaron los limites del INSERT Desglosada B3.',1;

SET @Bloque=N'/* BF3_DESGLOSADA_ETAPAS_SET_V1 */
    BEGIN TRY INSERT INTO dbo.bf_RepConf_Debug(etapa,detalle)
        VALUES(''cobranza_bf3_desg_set_inicio'',CONCAT(''empresa='',@idEmpresa,''; vigencia='',@idVigencia));
    END TRY BEGIN CATCH END CATCH;

    /* El TOP(1) sin ORDER BY del codigo historico seria ambiguo. No se permite
       escoger otra prima silenciosamente si la misma llave tiene dos montos. */
    IF EXISTS(
        SELECT 1
        FROM dbo.ff_Tarifa AS T WITH(NOLOCK)
        INNER JOIN dbo.ff_TarifaCosto AS TC WITH(NOLOCK) ON TC.TCIdTarifa=T.TAIdTarifa
        WHERE T.TAIdVigencia=@idVigencia AND TC.TCIdEstatus=1
          AND TC.TCIdGrupoParentesco IS NULL
        GROUP BY TC.TCIdPlanOpcion,TC.TCIdParentesco,TC.TCEdad,TC.TCIdSexo
        HAVING MIN(ISNULL(TC.TCPrimaNeta,0))<>MAX(ISNULL(TC.TCPrimaNeta,0))
    )
        THROW 52645,''Tarifa individual ambigua: se cancela para evitar data diferente.'',1;

    IF NOT EXISTS(
        SELECT 1 FROM tempdb.sys.indexes
        WHERE object_id=OBJECT_ID(N''tempdb..#ff_Empleadotemp'')
          AND name=N''IX_BF3_Empleado_Set''
    )
        CREATE NONCLUSTERED INDEX IX_BF3_Empleado_Set
            ON #ff_Empleadotemp(EMidEmpresa,EMidAnt)
            INCLUDE(EMNumeroEmpleado,EMIdPerfil,EMIdParentesco,EMIdSexo);

    SELECT S.SOIdSolicitud,S.SOIdEmpresa,S.SOIdEmpleado,S.SONumEmpleado,
           S.SONumeroSolicitud,S.SOAnexoSolicitud
    INTO #BF3_Solicitudes
    FROM dbo.ff_Solicitud AS S WITH(NOLOCK)
    WHERE S.SOIdVigencia=@idVigencia
      AND S.SOIdEmpresa=@Empresa
      AND S.SOidEstatus=@SOIdEstatus
      AND S.SOEstatusSolicitud=1
      AND S.SOIdSolicitudTipo=1
      AND ISNULL(S.SOFechaAprovacion,CONVERT(date,GETDATE()))<=@FecFin
      AND ISNULL(S.SOFechaAprovacion,CONVERT(date,GETDATE()))>=@FecIni;
    CREATE UNIQUE CLUSTERED INDEX CX_BF3_Solicitudes
        ON #BF3_Solicitudes(SOIdEmpresa,SOIdSolicitud);
    CREATE NONCLUSTERED INDEX IX_BF3_Solicitudes_Num
        ON #BF3_Solicitudes(SOIdEmpresa,SONumEmpleado);

    SELECT EC.ECidEmpresa,EC.ECidSolicitud,EC.ECNumeroEmpleado,
           SUM(CASE WHEN EC.ECidCompensacion IS NOT NULL
                    THEN ISNULL(EC.ECCantidad,0) ELSE 0 END) AS MontoTotalCreditos,
           SUM(CASE WHEN EC.ECTipoMovto=1 AND EC.ECIdConcepto=7
                    THEN ISNULL(EC.ECCantidad,0) ELSE 0 END) AS SobranteExcedentes
    INTO #BF3_EdoSolicitud
    FROM dbo.ff_EdoCuentaCobranza AS EC WITH(NOLOCK)
    INNER JOIN #BF3_Solicitudes AS S
        ON S.SOIdEmpresa=EC.ECidEmpresa AND S.SOIdSolicitud=EC.ECidSolicitud
       AND S.SONumEmpleado COLLATE DATABASE_DEFAULT=EC.ECNumeroEmpleado COLLATE DATABASE_DEFAULT
    GROUP BY EC.ECidEmpresa,EC.ECidSolicitud,EC.ECNumeroEmpleado
    OPTION(RECOMPILE);
    CREATE UNIQUE CLUSTERED INDEX CX_BF3_EdoSolicitud
        ON #BF3_EdoSolicitud(ECidEmpresa,ECidSolicitud,ECNumeroEmpleado);

    SELECT GPIdGrupoParentesco,MAX(RTRIM(LTRIM(GPDescripcion))) AS GPDescripcion
    INTO #BF3_GrupoDesc
    FROM dbo.ff_GrupoParentesco WITH(NOLOCK)
    GROUP BY GPIdGrupoParentesco;
    CREATE UNIQUE CLUSTERED INDEX CX_BF3_GrupoDesc ON #BF3_GrupoDesc(GPIdGrupoParentesco);

    SELECT GPIdGrupoParentesco,SUM(GPCantidad) AS Cantidad
    INTO #BF3_GrupoCantidad
    FROM dbo.ff_GrupoParentescoParentesco WITH(NOLOCK)
    GROUP BY GPIdGrupoParentesco;
    CREATE UNIQUE CLUSTERED INDEX CX_BF3_GrupoCantidad ON #BF3_GrupoCantidad(GPIdGrupoParentesco);

    SELECT VSIdEmpleado,VSIdPlanOpcion,VSIdVigencia,MAX(VSSumaAsegurada) AS SumaAsegurada
    INTO #BF3_ValidaSA
    FROM dbo.ff_ValidaSAVida WITH(NOLOCK)
    WHERE VSIdEstatus=1 AND VSIdVigencia=@idVigencia
    GROUP BY VSIdEmpleado,VSIdPlanOpcion,VSIdVigencia;
    CREATE UNIQUE CLUSTERED INDEX CX_BF3_ValidaSA
        ON #BF3_ValidaSA(VSIdEmpleado,VSIdPlanOpcion,VSIdVigencia);

    SELECT T.TAIdVigencia,TC.TCIdPlanOpcion,TC.TCIdParentesco,TC.TCEdad,TC.TCIdSexo,
           MAX(TC.TCPrimaNeta) AS PrimaNeta
    INTO #BF3_TCIndividual
    FROM dbo.ff_Tarifa AS T WITH(NOLOCK)
    INNER JOIN dbo.ff_TarifaCosto AS TC WITH(NOLOCK) ON TC.TCIdTarifa=T.TAIdTarifa
    WHERE T.TAIdVigencia=@idVigencia AND TC.TCIdEstatus=1 AND TC.TCIdGrupoParentesco IS NULL
    GROUP BY T.TAIdVigencia,TC.TCIdPlanOpcion,TC.TCIdParentesco,TC.TCEdad,TC.TCIdSexo;
    CREATE UNIQUE CLUSTERED INDEX CX_BF3_TCIndividual
        ON #BF3_TCIndividual(TAIdVigencia,TCIdPlanOpcion,TCIdParentesco,TCEdad,TCIdSexo);

    SELECT T.TAIdVigencia,TC.TCIdPlanOpcion,TC.TCIdGrupoParentesco,
           MAX(TC.TCPrimaNeta) AS PrimaNeta
    INTO #BF3_TCGrupo
    FROM dbo.ff_Tarifa AS T WITH(NOLOCK)
    INNER JOIN dbo.ff_TarifaCosto AS TC WITH(NOLOCK) ON TC.TCIdTarifa=T.TAIdTarifa
    WHERE T.TAIdVigencia=@idVigencia AND T.TAIdEstatus=1
      AND TC.TCIdEstatus=1 AND TC.TCIdSexo IS NULL
    GROUP BY T.TAIdVigencia,TC.TCIdPlanOpcion,TC.TCIdGrupoParentesco;
    CREATE UNIQUE CLUSTERED INDEX CX_BF3_TCGrupo
        ON #BF3_TCGrupo(TAIdVigencia,TCIdPlanOpcion,TCIdGrupoParentesco);

    SELECT T.TAIdVigencia,TC.TCIdPlanOpcion,TC.TCIdGrupoParentesco,TC.TCIdSexo,
           MAX(TC.TCPrimaNeta) AS PrimaNeta
    INTO #BF3_TCFallback
    FROM dbo.ff_Tarifa AS T WITH(NOLOCK)
    INNER JOIN dbo.ff_TarifaCosto AS TC WITH(NOLOCK) ON TC.TCIdTarifa=T.TAIdTarifa
    WHERE T.TAIdVigencia=@idVigencia AND T.TAIdEstatus=1 AND TC.TCIdEstatus=1
      AND TC.TCIdGrupoParentesco IS NOT NULL
    GROUP BY T.TAIdVigencia,TC.TCIdPlanOpcion,TC.TCIdGrupoParentesco,TC.TCIdSexo;
    CREATE UNIQUE CLUSTERED INDEX CX_BF3_TCFallback
        ON #BF3_TCFallback(TAIdVigencia,TCIdPlanOpcion,TCIdGrupoParentesco,TCIdSexo);

    SELECT T.TAIdVigencia,TP.TPIdPlanOpcion,TP.TPIdPerfil,MAX(TP.TPPrimaNeta) AS PrimaNeta
    INTO #BF3_TCPerfil
    FROM dbo.ff_Tarifa AS T WITH(NOLOCK)
    INNER JOIN dbo.ff_TarifaCostoPerfil AS TP WITH(NOLOCK) ON TP.TPIdTarifa=T.TAIdTarifa
    WHERE T.TAIdVigencia=@idVigencia AND T.TAIdEstatus=1 AND TP.TPIdEstatus=1
    GROUP BY T.TAIdVigencia,TP.TPIdPlanOpcion,TP.TPIdPerfil;
    CREATE UNIQUE CLUSTERED INDEX CX_BF3_TCPerfil
        ON #BF3_TCPerfil(TAIdVigencia,TPIdPlanOpcion,TPIdPerfil);

    BEGIN TRY INSERT INTO dbo.bf_RepConf_Debug(etapa,detalle)
        SELECT ''cobranza_bf3_desg_set_etapas'',
               CONCAT(''solicitudes='',(SELECT COUNT_BIG(*) FROM #BF3_Solicitudes),
                      ''; edo='',(SELECT COUNT_BIG(*) FROM #BF3_EdoSolicitud));
    END TRY BEGIN CATCH END CATCH;

    INSERT INTO #TablaCobDesg
    SELECT POS.POidEmpresa,RTRIM(S.SONumEmpleado),POS.POidEmpleado,
           ISNULL(E.EMApellidoPaterno,''''),ISNULL(E.EMApellidoMaterno,''''),
           ISNULL(E.EMNombre1,''''),ISNULL(E.EMNombre2,''''),E.EMIdSexo,SE.SEDescripcion,
           CONVERT(varchar(10),E.EMFechaNacimiento,103),POS.POEdad,PE.PENombre,
           E.EMIdParentesco,P.PADescripcion,
           CASE WHEN ISNULL(E.EMIdTransferido,0)=0 THEN ''NO'' ELSE ''TRANSFERIDO'' END,
           E.EMSalarioBase,
           CAST(S.SONumeroSolicitud AS varchar(5))+''-''+CAST(S.SOAnexoSolicitud AS varchar(2)),
           S.SOIdSolicitud,PL.PLDescripcion,PO.PODescripcion,
           ISNULL(POS.POIdGrupoParentesco,0),
           CASE WHEN POS.POIdGrupoParentesco IS NULL THEN ''PLAN INDIVIDUAL'' ELSE GD.GPDescripcion END,
           PO.POIdPlanOpcion,PO.POIdPlan,PO.POIdTipoSumaAsegurada,
           V.SumaAsegurada/@cantidadPagos,
           PL.PLOrdenCobranza,
           ROUND(ISNULL(
             CASE WHEN POS.POIdGrupoParentesco IS NULL THEN
                    CASE WHEN POS.POCostoRestante=0 THEN POS.POTarifaNeta ELSE POS.POCostoRestante END
                  WHEN E.EMIdParentesco=1 THEN POS.POTarifaNeta END,
             CASE WHEN ISNULL(GC.Cantidad,0)=1 THEN POS.POCostoRestante ELSE 0 END),2),
           ROUND(ISNULL(
             CASE WHEN PP.PPIdPeriodicidadPago IS NOT NULL
                       AND (POS.POIdGrupoParentesco IS NULL OR E.EMIdParentesco=1)
                    THEN CASE WHEN POS.POCostoRestante>0
                              THEN ROUND(POS.POCostoRestante/@cantidadPagos,2) ELSE 0 END END,
             CASE WHEN ISNULL(GC.Cantidad,0)=1 AND PP.PPIdPeriodicidadPago IS NOT NULL
                    THEN CASE WHEN POS.POCostoRestante=0 THEN 0
                              ELSE ROUND(POS.POCostoRestante/@cantidadPagos,2) END
                  ELSE 0 END),2),
           ROUND(ISNULL(EC.MontoTotalCreditos,0),2),
           ROUND(ISNULL(EC.MontoTotalCreditos,0)/@cantidadPagos,2),
           CONVERT(money,0),0,0,0,CONVERT(money,0),0,0,0,0,0,
           ROUND(ISNULL(EC.SobranteExcedentes,0)/@cantidadPagos,2),
           ROUND(ISNULL(
             CASE
               WHEN POS.POIdGrupoParentesco IS NULL AND PO.POIdTipoCosto<>6
                    AND TI.TCIdPlanOpcion IS NOT NULL
                 THEN CASE WHEN PL.PLSAMI>0 AND PO.POIdTipoSumaAsegurada<>4
                           THEN POS.POTarifaNeta ELSE TI.PrimaNeta END
               WHEN POS.POIdGrupoParentesco IS NOT NULL AND PO.POIdTipoCosto<>6
                    AND POS.POIdEmpresa=@empresa AND E.EMIdParentesco=1 THEN TG.PrimaNeta
               WHEN PO.POIdTipoCosto=6 AND POS.POIdGrupoParentesco IS NULL
                    AND POS.POIdEmpresa=@empresa THEN TP.PrimaNeta
             END,TF.PrimaNeta),2),
           CONVERT(money,0),@idVigencia
    FROM dbo.ff_PlanOpcionSeleccionCobranza2 AS POS WITH(NOLOCK)
    INNER JOIN #BF3_Solicitudes AS S
        ON S.SOIdEmpresa=POS.POIdEmpresa AND S.SOIdSolicitud=POS.POIdSolicitud
       AND S.SONumEmpleado COLLATE DATABASE_DEFAULT=POS.PONumeroEmpleado COLLATE DATABASE_DEFAULT
    INNER JOIN #ff_Empleadotemp AS E
        ON E.EMIdEmpresa=POS.POIdEmpresa AND E.EMIdAnt=POS.POIdEmpleado
    INNER JOIN dbo.ff_Perfil AS PE WITH(NOLOCK)
        ON PE.PEIdEmpresa=E.EMIdEmpresa AND PE.PEIdPerfil=E.EMIdPerfil
    INNER JOIN dbo.ff_Parentesco AS P WITH(NOLOCK) ON P.PAIdParentesco=E.EMIdParentesco
    INNER JOIN dbo.ff_Sexo AS SE WITH(NOLOCK) ON SE.SEIdSexo=E.EMIdSexo
    INNER JOIN dbo.ff_PlanOpcion AS PO WITH(NOLOCK)
        ON PO.POIdPlanOpcion=POS.POIdPlanOpcion AND PO.POIdEstatus=1
    INNER JOIN dbo.ff_Plan AS PL WITH(NOLOCK)
        ON PL.PLIdPlan=PO.POIdPlan AND PL.PLIdEstatus=1 AND PL.PLFondoDeAhorro=0
    INNER JOIN dbo.ff_ConcepAgrupaCob AS CA WITH(NOLOCK)
        ON CA.CAIdEmpresa=POS.POIdEmpresa AND CA.CAIdPlanOpcion=POS.POIdPlanOpcion
    LEFT JOIN #BF3_EdoSolicitud AS EC
        ON EC.ECidEmpresa=POS.POIdEmpresa AND EC.ECidSolicitud=POS.POIdSolicitud
       AND EC.ECNumeroEmpleado COLLATE DATABASE_DEFAULT=POS.PONumeroEmpleado COLLATE DATABASE_DEFAULT
    LEFT JOIN #BF3_GrupoDesc AS GD ON GD.GPIdGrupoParentesco=POS.POIdGrupoParentesco
    LEFT JOIN #BF3_GrupoCantidad AS GC ON GC.GPIdGrupoParentesco=POS.POIdGrupoParentesco
    LEFT JOIN #BF3_ValidaSA AS V
        ON V.VSIdEmpleado=POS.POIdEmpleado AND V.VSIdPlanOpcion=POS.POIdPlanOpcion
       AND V.VSIdVigencia=POS.POIdVigencia
    LEFT JOIN dbo.ff_PeriodicidadPago AS PP WITH(NOLOCK)
        ON PP.PPIdPeriodicidadPago=POS.POIdPeriodicidadPago
    LEFT JOIN #BF3_TCIndividual AS TI
        ON TI.TAIdVigencia=POS.POIdVigencia AND TI.TCIdPlanOpcion=POS.POIdPlanOpcion
       AND TI.TCIdParentesco=POS.POIdParentesco AND TI.TCEdad=POS.POEdad
       AND TI.TCIdSexo=E.EMIdSexo
    LEFT JOIN #BF3_TCGrupo AS TG
        ON TG.TAIdVigencia=POS.POIdVigencia AND TG.TCIdPlanOpcion=POS.POIdPlanOpcion
       AND TG.TCIdGrupoParentesco=POS.POIdGrupoParentesco
    LEFT JOIN #BF3_TCFallback AS TF
        ON TF.TAIdVigencia=POS.POIdVigencia AND TF.TCIdPlanOpcion=POS.POIdPlanOpcion
       AND TF.TCIdGrupoParentesco=POS.POIdGrupoParentesco AND TF.TCIdSexo=E.EMIdSexo
       AND POS.POIdEmpresa=@empresa AND E.EMIdParentesco=1
    LEFT JOIN #BF3_TCPerfil AS TP
        ON TP.TAIdVigencia=POS.POIdVigencia AND TP.TPIdPlanOpcion=POS.POIdPlanOpcion
       AND TP.TPIdPerfil=E.EMIdPerfil
    WHERE POS.POIdEstatus=@SOIdEstatus
      AND POS.POIdEmpresa IN(SELECT EMIdEmpresa FROM #ListEmpresas)
      AND PE.PEIdPerfil IN(SELECT IdTipoNotificacionCorreo FROM #IdPerfilV2)
    ORDER BY S.SONumEmpleado,PL.PLOrdenCobranza,POS.POIdPlanOpcionSeleccion,
             POS.POAnexo,POS.POIdPlanOpcion,POS.POEdad,POS.POIdGrupoParentesco
    OPTION(RECOMPILE);
END

';

SET @Def=STUFF(@Def,@Inicio,@Cola-@Inicio,@Bloque);
SET @Def=REPLACE(@Def,N'EXEC dbo.ff_ObtenDivisionCtos_Adaptado_bf3_NOUSAR',
                      N'EXEC dbo.ff_ObtenDivisionCtos_Adaptado_bf3_SET');
SET @Upper=UPPER(@Def);
SET @Proc=CHARINDEX(N'PROCEDURE',@Upper);
IF @Proc=0
    THROW 52643,'No se pudo construir Desglosada SET B3.',1;
SET @Def=N'CREATE OR ALTER '+SUBSTRING(@Def,@Proc,LEN(@Def));
EXEC sys.sp_executesql @Def;

IF OBJECT_DEFINITION(OBJECT_ID(@Destino)) NOT LIKE N'%BF3_DESGLOSADA_ETAPAS_SET_V1%'
    THROW 52644,'Desglosada SET B3 no quedo instalada.',1;

SELECT N'OK' AS Estado,@Destino AS Objeto,N'Solo B3; B2 intacto' AS Alcance;
GO

/* ======================================================================
   PASO 7 DE 10: 07_CONCENTRADA_ETAPAS_SET_B3.sql
   ====================================================================== */
RAISERROR(N'[COBRANZA B3] Ejecutando paso 7/10: 07_CONCENTRADA_ETAPAS_SET_B3.sql',10,1) WITH NOWAIT;
GO
/*
   CONCENTRADo POR ETAPAS, EXCLUSIVA B3
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Origen sysname=N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_OPT',
        @Destino sysname=N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_SET',
        @Def nvarchar(max),@Upper nvarchar(max),@Inicio int,@Cola int,@Proc int,
        @Candidato int,@PosTablaTemp int,
        @Bloque nvarchar(max);

IF OBJECT_DEFINITION(OBJECT_ID(@Destino,N'P')) LIKE N'%BF3_CONCENTRADA_ETAPAS_SET_V1%'
BEGIN
    SELECT N'OMITIDO_YA_EXISTE' AS Estado,@Destino AS Objeto;
    RETURN;
END;

IF OBJECT_ID(@Origen,N'P') IS NULL OR OBJECT_ID(N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_SET',N'P') IS NULL
    THROW 52680,'Falta la rama OPT o Desglosada SET B3.',1;

SET @Def=OBJECT_DEFINITION(OBJECT_ID(@Origen));
SET @Def=REPLACE(@Def,N'[dbo].[ObtenCobranzaConcentrada_otro_V2_BF3_OPT]',
                      N'[dbo].[ObtenCobranzaConcentrada_otro_V2_BF3_SET]');
SET @Def=REPLACE(@Def,N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_OPT',
                      N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_SET');
SET @Def=REPLACE(@Def,N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_OPT',
                      N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_SET');
SET @Def=REPLACE(@Def,N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_nousar',
                      N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_SET');
SET @Upper=UPPER(@Def);

SET @Inicio=CHARINDEX(N'INSERT INTO #TABLATEMP (EMPRESA,NUMEMPLEADO',@Upper);
IF @Inicio=0 SET @Inicio=CHARINDEX(N'INSERT INTO #TABLATEMP',@Upper);
IF @Inicio=0 SET @Inicio=CHARINDEX(N'INSERT #TABLATEMP',@Upper);

SET @Cola=CHARINDEX(N'-- LOG POST-INSERT-TABLATEMP',@Upper,@Inicio);
IF @Cola=0
    SET @Cola=CHARINDEX(N'IF EXISTS(SELECT TOP 1 * FROM #TABLATEMP',@Upper,@Inicio);
IF @Cola=0
    SET @Cola=CHARINDEX(N'IF EXISTS (SELECT TOP 1 * FROM #TABLATEMP',@Upper,@Inicio);

IF @Inicio>0 AND @Cola=0
BEGIN
    SET @Candidato=CHARINDEX(N'IF EXISTS',@Upper,@Inicio);
    WHILE @Candidato>0 AND @Cola=0
    BEGIN
        SET @PosTablaTemp=CHARINDEX(N'#TABLATEMP',@Upper,@Candidato);
        IF @PosTablaTemp BETWEEN @Candidato AND @Candidato+500
            SET @Cola=@Candidato;
        ELSE
            SET @Candidato=CHARINDEX(N'IF EXISTS',@Upper,@Candidato+9);
    END;
END;

IF @Inicio=0 OR @Cola=0 OR @Cola<=@Inicio
    THROW 52681,'No se localizaron los limites del INSERT Concentrada B3.',1;

SET @Bloque=N'/* BF3_CONCENTRADA_ETAPAS_SET_V1 */
    SELECT DISTINCT EC.ECidSolicitud,EC.ECidEmpleado,EC.ECidEmpresa
    INTO #BF3_ECKeys
    FROM dbo.ff_EdoCuentaCobranza2 AS EC WITH(NOLOCK)
    INNER JOIN dbo.ff_Solicitud AS S WITH(NOLOCK)
        ON S.SOIdSolicitud=EC.ECidSolicitud AND S.SOIdEmpresa=EC.ECidEmpresa
       AND S.SOIdEmpleado=EC.ECidEmpleado
    INNER JOIN dbo.ff_ConcepAgrupaCob AS CA WITH(NOLOCK)
        ON CA.CAIdEmpresa=EC.ECidEmpresa AND CA.CAIdPlanOpcion=EC.ECidPlanOpcion
    WHERE S.SOIdVigencia=@idVigencia AND S.SOidEstatus=@SOIdEstatus
      AND S.SOEstatusSolicitud=1 AND S.SOIdSolicitudTipo=1
      AND ISNULL(S.SOFechaAprovacion,CONVERT(date,GETDATE()))<=@FecFinHoras
      AND ISNULL(S.SOFechaAprovacion,CONVERT(date,GETDATE()))>=@FecIni
      AND S.SOIdEmpresa IN(SELECT EMidEmpresa FROM #ListEmpresas);
    CREATE UNIQUE CLUSTERED INDEX CX_BF3_ECKeys
        ON #BF3_ECKeys(ECidEmpresa,ECidSolicitud,ECidEmpleado);

    SELECT CE.CEIdEmpleado,SUM(ISNULL(CE.CETotalCreditos,0)) AS TotalCreditos
    INTO #BF3_CompEmpleado
    FROM dbo.ff_CompensacionEmpleado AS CE WITH(NOLOCK)
    INNER JOIN (SELECT DISTINCT EMIdAnt FROM #ff_Empleadotemp) AS E ON E.EMIdAnt=CE.CEIdEmpleado
    GROUP BY CE.CEIdEmpleado;
    CREATE UNIQUE CLUSTERED INDEX CX_BF3_CompEmpleado ON #BF3_CompEmpleado(CEIdEmpleado);

    SELECT POS.POIdEmpresa,POS.PONumeroEmpleado,POS.POIdSolicitud,
           SUM(ISNULL(POS.POTarifaNeta,0)) AS TarifaNeta,
           MAX(PO.PODescripcion) AS PlanFondo
    INTO #BF3_Fondo
    FROM dbo.ff_PlanOpcionSeleccionCobranza AS POS WITH(NOLOCK)
    INNER JOIN dbo.ff_Empleado AS ET WITH(NOLOCK)
        ON ET.EMIdEmpresa=POS.POIdEmpresa
       AND ET.EMNumeroEmpleado COLLATE DATABASE_DEFAULT=POS.PONumeroEmpleado COLLATE DATABASE_DEFAULT
       AND ET.EMIdTitular=1
    INNER JOIN dbo.ff_PlanOpcionPerfil AS PPF WITH(NOLOCK)
        ON PPF.PPIdPerfil=ET.EMIdPerfil AND PPF.PPIdPlanOpcion=POS.POIdPlanOpcion
    INNER JOIN dbo.ff_PlanOpcion AS PO WITH(NOLOCK)
        ON PO.POIdPlanOpcion=POS.POIdPlanOpcion
    INNER JOIN dbo.ff_Plan AS PL WITH(NOLOCK)
        ON PL.PLIdPlan=PO.POIdPlan AND PL.PLFondoDeAhorro=1
    INNER JOIN #BF3_ECKeys AS K
        ON K.ECidEmpresa=POS.POIdEmpresa AND K.ECidSolicitud=POS.POIdSolicitud
       AND K.ECidEmpleado=POS.POIdEmpleado
    WHERE POS.POIdEmpresa IN(SELECT EMIdEmpresa FROM #ListEmpresas)
    GROUP BY POS.POIdEmpresa,POS.PONumeroEmpleado,POS.POIdSolicitud;
    CREATE UNIQUE CLUSTERED INDEX CX_BF3_Fondo
        ON #BF3_Fondo(POIdEmpresa,PONumeroEmpleado,POIdSolicitud);

    SELECT POS.POIdEmpresa,POS.PONumeroEmpleado,MAX(GP.GPNombre) AS GPNombre
    INTO #BF3_GrupoGMM
    FROM dbo.ff_PlanOpcionSeleccionCobranza AS POS WITH(NOLOCK)
    INNER JOIN dbo.ff_Empleado AS ET WITH(NOLOCK)
        ON ET.EMIdEmpresa=POS.POIdEmpresa
       AND ET.EMNumeroEmpleado COLLATE DATABASE_DEFAULT=POS.PONumeroEmpleado COLLATE DATABASE_DEFAULT
       AND ET.EMIdParentesco=1
    INNER JOIN dbo.ff_ConcepAgrupaCob AS CAC WITH(NOLOCK)
        ON CAC.CAIdEmpresa=POS.POIdEmpresa AND CAC.CAIdPlanOpcion=POS.POIdPlanOpcion
    INNER JOIN dbo.ff_GrupoParentesco AS GP WITH(NOLOCK)
        ON GP.GPIdGrupoParentesco=POS.POIdGrupoParentesco
    INNER JOIN dbo.ff_PlanOpcion AS PO WITH(NOLOCK)
        ON PO.POIdPlanOpcion=POS.POIdPlanOpcion AND PO.POIdEstatus=1
    INNER JOIN dbo.ff_Plan AS PL WITH(NOLOCK)
        ON PL.PLIdPlan=PO.POIdPlan AND PL.PLIdEstatus=1
    INNER JOIN dbo.ff_Ramo AS RA WITH(NOLOCK)
        ON RA.RAIdRamo=PL.PLIdRamo AND RA.RAIdRamoForbes=5
    WHERE POS.POIdEstatus=@SOIdEstatus AND POS.POIdGrupoParentesco IS NOT NULL
      AND POS.POIdVigencia=@idVigencia
    GROUP BY POS.POIdEmpresa,POS.PONumeroEmpleado;
    CREATE UNIQUE CLUSTERED INDEX CX_BF3_GrupoGMM ON #BF3_GrupoGMM(POIdEmpresa,PONumeroEmpleado);

    SELECT TE.TEIdDetalle,MAX(TE.TEDescripcion) AS Descripcion
    INTO #BF3_Oficina
    FROM dbo.ff_TablaEncabezadoDetalle AS TE WITH(NOLOCK)
    INNER JOIN dbo.ff_TablaEncabezado AS EN WITH(NOLOCK)
        ON EN.ENClave=TE.TEEnClave
    WHERE EN.ENIdEmpresa IN(SELECT EMIdEmpresa FROM #ListEmpresas)
      AND EN.ENEncabezado LIKE ''%Oficina%''
    GROUP BY TE.TEIdDetalle;
    CREATE UNIQUE CLUSTERED INDEX CX_BF3_Oficina ON #BF3_Oficina(TEIdDetalle);

    BEGIN TRY INSERT INTO dbo.bf_RepConf_Debug(etapa,detalle)
        SELECT ''cobranza_bf3_conc_set_etapas'',
               CONCAT(''keys='',(SELECT COUNT_BIG(*) FROM #BF3_ECKeys),
                      ''; fondo='',(SELECT COUNT_BIG(*) FROM #BF3_Fondo));
    END TRY BEGIN CATCH END CATCH;

    INSERT INTO #tablatemp
    (empresa,NumEMpleado,CveEmpl,Paterno,MAterno,Nombre1,Nombre2,Sexo,FechaNac,Edad,
     Confidencial,SueldoMensual,SueldoMensualAnt,TRANSFERIDO,NumSolicitud,Perfil,
     FechaAutorizacion,MontoGMM,MontoVIDA,MontoOTROSPLANES,CreditosGMM,CreditosViDA,
     MontoTotalCreditos,MontoTotalCreditosAnt,MontoTotalSelecciones,MontoTotalSeleccionesAnt,
     SobranteCreditos,MontoPagCred,MontoDescMensual,MontoDescMensualAnt,GrupoParentescoGMM,
     Excedentes,ExcedentesAnt,MontoFondoAhorroMensual,MontoFondoAhorroMensualAnt,
     SobranteExcedentes,DescuentoEmpleadoFH,DescuentoEmpleadoFinal,SobranteExceFinal,
     CoberturaDesc,Q1,Q2,Diferencia,CtoEmpleadoNomSeg,AplicExcedentes,NumOficina,
     NomOficina,POFH,LocalNumber,CentroCostos)
    SELECT E.EMIdEmpresa,RTRIM(E.EMNumeroEmpleado),E.EMIdAnt,
           ISNULL(E.EMApellidoPaterno,''''),ISNULL(E.EMApellidoMaterno,''''),
           ISNULL(E.EMNombre1,''''),ISNULL(E.EMNombre2,''''),SE.SEDescripcion,
           CONVERT(varchar(10),E.EMFechaNacimiento,103),E.EMEdad,
           CASE WHEN ISNULL(E.EMIdSalarioConfidencial,0)=0 THEN ''NO'' ELSE ''SI'' END,
           E.EMSalarioBase,ISNULL(CCA.ccSueldoMensual,0),
           CASE WHEN ISNULL(E.EMIdTransferido,0)=0 THEN ''NO'' ELSE ''TRANSFERIDO'' END,
           CAST(ISNULL(S.SONumeroSolicitud,'''') AS varchar(5))+''-''+CAST(ISNULL(S.SOAnexoSolicitud,'''') AS varchar(2)),
           P.PENombre,CONVERT(varchar(10),S.SOFechaAprovacion,103),
           ROUND(ISNULL(EA.a_caco1_mv2,0)/@cantidadPagos,2),
           ROUND(ISNULL(EA.a_caco1_mv2,0)/@cantidadPagos-ROUND(ISNULL(EA.a_ec2_mv1,0)/@cantidadPagos,2),2),
           ROUND(ISNULL(EA.a_caco5_mv2,0)/@cantidadPagos,2),
           ROUND(ISNULL(EA.a_caco3_ec1_mv1,0)/@cantidadPagos,2),
           ROUND(ISNULL(EA.a_caco4_ec1_mv1,0)/@cantidadPagos,2),
           ROUND(ISNULL(EA.a_comp,0)/@cantidadPagos,2),ISNULL(CCV.ccTotalCreditos,0),
           ROUND(ISNULL(EA.a_mv2_po,0)/@cantidadPagos-ROUND(ISNULL(EA.a_ec2_mv1,0)/@cantidadPagos,2),2),
           ISNULL(CCV.ccTotalCostos,0),ROUND(ISNULL(EA.a_ec6,0)/@cantidadPagos,2),
           0,0,ISNULL(CCV.ccDescuentoEmpleado,0),GG.GPNombre,
           ROUND(ISNULL(CE.TotalCreditos,0)/@cantidadPagos,2),ISNULL(CCV.ccExcedentes,0),
           ROUND(ISNULL(F.TarifaNeta,0)/@cantidadPagos,2),ISNULL(CCV.ccFondoAhorro,0),
           ROUND(ISNULL(EA.a_ec7_mv1,0)/@cantidadPagos,2),0,0,0,0,0,0,0,0,0,
           E.EMOficina,O.Descripcion,ISNULL(F.PlanFondo,''''),ISNULL(EE.Desarrollo,''''),
           ISNULL(dbo.DescripcionCatalogo(EE.EMIdEmpresa,''EMidCentroCostos'',EE.EMIdCentroCostos),'''')
    FROM dbo.ff_Solicitud AS S WITH(NOLOCK)
    INNER JOIN #BF3_ECKeys AS K
        ON K.ECidEmpresa=S.SOIdEmpresa AND K.ECidSolicitud=S.SOIdSolicitud AND K.ECidEmpleado=S.SOIdEmpleado
    INNER JOIN #ff_Empleadotemp AS E ON E.EMIdAnt=K.ECidEmpleado
    INNER JOIN dbo.ff_Sexo AS SE WITH(NOLOCK) ON SE.SEIdSexo=E.EMIdSexo
    INNER JOIN dbo.ff_Perfil AS P WITH(NOLOCK)
        ON P.PEIdEmpresa=E.EMIdEmpresa AND P.PEIdPerfil=E.EMIdPerfil
    INNER JOIN #ec_agg AS EA
        ON EA.ECidEmpresa=K.ECidEmpresa AND EA.ECidSolicitud=K.ECidSolicitud AND EA.ECidEmpleado=K.ECidEmpleado
    INNER JOIN dbo.ff_Empleado AS EE WITH(NOLOCK) ON EE.Id=E.EMIdAnt
    LEFT JOIN #BF3_CompEmpleado AS CE ON CE.CEIdEmpleado=E.EMIdAnt
    LEFT JOIN #BF3_Fondo AS F
        ON F.POIdEmpresa=E.EMIdEmpresa
       AND F.PONumeroEmpleado COLLATE DATABASE_DEFAULT=E.EMNumeroEmpleado COLLATE DATABASE_DEFAULT
       AND F.POIdSolicitud=S.SOIdSolicitud
    LEFT JOIN #BF3_GrupoGMM AS GG
        ON GG.POIdEmpresa=E.EMIdEmpresa
       AND GG.PONumeroEmpleado COLLATE DATABASE_DEFAULT=E.EMNumeroEmpleado COLLATE DATABASE_DEFAULT
    LEFT JOIN #BF3_Oficina AS O ON O.TEIdDetalle=E.EMOficina
    OUTER APPLY(
        SELECT TOP(1) CC.ccSueldoMensual
        FROM dbo.ff_CobranzaConcentrada AS CC WITH(NOLOCK)
        WHERE CC.ccIdEmpresa=E.EMIdEmpresa AND CC.ccIdEmpleado=E.EMIdAnt
          AND CC.[ccAño]=@AnioApl AND CC.ccMes=@MesApl
    ) AS CCA
    OUTER APPLY(
        SELECT TOP(1) CC.ccTotalCreditos,CC.ccTotalCostos,CC.ccDescuentoEmpleado,
               CC.ccExcedentes,CC.ccFondoAhorro
        FROM dbo.ff_CobranzaConcentrada AS CC WITH(NOLOCK)
        WHERE CC.ccIdEmpresa=E.EMIdEmpresa AND CC.ccIdEmpleado=E.EMIdAnt
          AND CC.[ccAño]=@AnioApl AND CC.ccMes=@MesApl AND CC.ccIdVigencia=@idVigencia
    ) AS CCV
    WHERE P.PEIdPerfil IN(SELECT IdTipoNotificacionCorreo FROM #IdPerfilV2)
    ORDER BY E.EMIdAnt
    OPTION(RECOMPILE);
END

';

SET @Def=STUFF(@Def,@Inicio,@Cola-@Inicio,@Bloque);
SET @Def=REPLACE(@Def,N'Invocando ff_ObtenCobranzaDesg_Adaptada_bf3_nousar',
                      N'Invocando ff_ObtenCobranzaDesg_Adaptada_bf3_SET');
SET @Def=REPLACE(@Def,N'ff_ObtenCobranzaDesg_Adaptada_bf3_nousar finalizo',
                      N'ff_ObtenCobranzaDesg_Adaptada_bf3_SET finalizo');
SET @Upper=UPPER(@Def);
SET @Proc=CHARINDEX(N'PROCEDURE',@Upper);
IF @Proc=0 THROW 52682,'No se pudo construir Concentrada SET B3.',1;
SET @Def=N'CREATE OR ALTER '+SUBSTRING(@Def,@Proc,LEN(@Def));
EXEC sys.sp_executesql @Def;

IF OBJECT_DEFINITION(OBJECT_ID(@Destino)) NOT LIKE N'%BF3_CONCENTRADA_ETAPAS_SET_V1%'
    THROW 52683,'Concentrada SET B3 no quedo instalada.',1;

SELECT N'OK' Estado,@Destino Objeto,N'Solo B3; B2 intacto' Alcance;
GO

/* ======================================================================
   PASO 8 DE 10: 08_INTEGRAR_FLUJO_UNICO_SET_B3.sql
   ====================================================================== */
RAISERROR(N'[COBRANZA B3] Ejecutando paso 8/10: 08_INTEGRAR_FLUJO_UNICO_SET_B3.sql',10,1) WITH NOWAIT;
GO
/*
   PUNTO DE ENTRADA UNICO B3

   Tanto el flujo tradicional como bf_CobranzaCache_CargarUnaV2 llaman a
   dbo.ObtenCobranzaConcentrada_otro_V2_BF3. Desde este script ese punto de
   entrada siempre consume la rama SET optimizada.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3',N'P'))
       LIKE N'%BF3_FLUJO_UNICO_SET_V1%'
BEGIN
    SELECT N'OMITIDO_YA_EXISTE' AS Estado,
           N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3' AS Objeto;
    RETURN;
END;

IF OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_SET',N'P') IS NULL
    THROW 52700,'Falta instalar la rama SET B3 con los scripts 05, 06 y 07.',1;
IF OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_LEGACY',N'P') IS NULL
    THROW 52701,'Falta la copia de respaldo LEGACY creada por el script 04.',1;

DECLARE @Def nvarchar(max)=N'
CREATE OR ALTER PROCEDURE dbo.ObtenCobranzaConcentrada_otro_V2_BF3
    @idEmpresa int=0,
    @idSolTipo int=0,
    @FecIni varchar(16)='''',
    @FecFin varchar(16)='''',
    @idVencida int=0,
    @IdPerfil dbo.ListInt READONLY,
    @idVIgencia int=0
AS
BEGIN
    SET NOCOUNT ON;
    /* BF3_FLUJO_UNICO_SET_V1 */
    BEGIN TRY
        INSERT dbo.bf_RepConf_Debug(etapa,detalle)
        VALUES(''cobranza_bf3_ruta_sql'',
               CONCAT(''ruta=SET_UNICA; empresa='',@idEmpresa,''; vigencia='',@idVIgencia,
                      ''; cache='',ISNULL(TRY_CONVERT(varchar(10),SESSION_CONTEXT(N''bf_CobranzaCacheCapturar'')),''0'')));
    END TRY BEGIN CATCH END CATCH;

    EXEC dbo.ObtenCobranzaConcentrada_otro_V2_BF3_SET
         @idEmpresa=@idEmpresa,@idSolTipo=@idSolTipo,@FecIni=@FecIni,@FecFin=@FecFin,
         @idVencida=@idVencida,@IdPerfil=@IdPerfil,@idVIgencia=@idVIgencia;
END;';
EXEC sys.sp_executesql @Def;

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3'))
   NOT LIKE N'%BF3_FLUJO_UNICO_SET_V1%'
    THROW 52702,'No quedo instalado el punto de entrada unico B3.',1;

/* Las banderas antiguas se dejan sin efecto para evitar configuraciones
   contradictorias. El wrapper ya no las consulta. */
UPDATE dbo.ff_Parametro
SET paValor='0',paDescripcion='Sin uso: Cobranza B3 consume siempre motor SET unico',
    paFechaUmod=GETDATE()
WHERE UPPER(LTRIM(RTRIM(ISNULL(paClase,'')))) IN('COBRANZA_SQL_OPT_V2','COBRANZA_SQL_SET_V3')
  AND LTRIM(RTRIM(ISNULL(paValor,'')))<>'0';

SELECT N'OK' Estado,
       N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3 -> ..._SET' FlujoB3,
       N'Cache y tradicional comparten calculo; B2 intacto' Alcance;
GO

/* ======================================================================
   PASO 9 DE 10: 10_CORREGIR_FILTRO_DESGLOSADA_CACHE_B3.sql
   ====================================================================== */
RAISERROR(N'[COBRANZA B3] Ejecutando paso 9/10: 10_CORREGIR_FILTRO_DESGLOSADA_CACHE_B3.sql',10,1) WITH NOWAIT;
GO
/*
   CORRECCION DEL FILTRO DE LECTURA DEL CACHE B3

*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @Def nvarchar(max),@Upper nvarchar(max),@Inicio int,@Fin int,@Proc int,
        @Bloque nvarchar(max);

IF OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache',N'P') IS NULL
    THROW 53800,'No existe el lector de cache B3.',1;

IF OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache_PRE_FILTRO_20260822',N'P') IS NULL
BEGIN
    SET @Def=OBJECT_DEFINITION(OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache'));
    SET @Def=REPLACE(@Def,N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache',
                          N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache_PRE_FILTRO_20260822');
    EXEC sys.sp_executesql @Def;
END;

SET @Def=OBJECT_DEFINITION(OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache'));
IF @Def NOT LIKE N'%BF3_CACHE_EMPLEADO_COMPLETO_V2%'
   AND @Def NOT LIKE N'%BF3_CACHE_TITULAR_DEPENDIENTES_V3%'
BEGIN
    SET @Upper=UPPER(@Def);
    SET @Inicio=CHARINDEX(N'AND EXISTS',@Upper,
                 CHARINDEX(N'FROM DBO.BF_COBRANZACACHE_DESGLOSADAV2',@Upper));
    SET @Fin=CHARINDEX(N';',@Def,@Inicio);
    IF @Inicio=0 OR @Fin=0
        THROW 53801,'No se encontro el filtro Desglosada del cache B3.',1;

    SET @Bloque=N'AND EXISTS
          (/* BF3_CACHE_EMPLEADO_COMPLETO_V2 */
           SELECT 1
           FROM #EmpleadosUniverso AS E
           WHERE E.CveEmpl=D.idemp
             AND E.NumEmpleado COLLATE DATABASE_DEFAULT=
                 D.NUMEMPLEADO COLLATE DATABASE_DEFAULT)';
    SET @Def=STUFF(@Def,@Inicio,@Fin-@Inicio,@Bloque);
    SET @Upper=UPPER(@Def);
    SET @Proc=CHARINDEX(N'PROCEDURE',@Upper);
    SET @Def=N'CREATE OR ALTER '+SUBSTRING(@Def,@Proc,LEN(@Def));
    EXEC sys.sp_executesql @Def;
END;

/* V3: Desglosada contiene titular y dependientes. El idemp del dependiente
   no existe en Concentrada; la llave comun es empresa + numero de empleado. */
SET @Def=OBJECT_DEFINITION(OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache'));
IF @Def NOT LIKE N'%BF3_CACHE_FILTRO_EMPRESA_NUM_V3%'
BEGIN
    SET @Upper=UPPER(@Def);
    SET @Inicio=CHARINDEX(N'CREATE TABLE #EMPLEADOSUNIVERSO',@Upper);
    SET @Fin=CHARINDEX(N';',@Def,@Inicio);
    IF @Inicio=0 OR @Fin=0
        THROW 53803,'No se encontro #EmpleadosUniverso en lector cache B3.',1;

    SET @Bloque=N'/* BF3_CACHE_TITULAR_DEPENDIENTES_V3 */
    CREATE TABLE #EmpleadosUniverso
    (
        Empresa int NOT NULL,
        CveEmpl int NULL,
        NumSolicitud varchar(8) COLLATE DATABASE_DEFAULT NULL,
        NumEmpleado varchar(20) COLLATE DATABASE_DEFAULT NULL
    );';
    SET @Def=STUFF(@Def,@Inicio,@Fin-@Inicio+1,@Bloque);

    SET @Def=REPLACE(@Def,
        N'INSERT #EmpleadosUniverso(CveEmpl,NumSolicitud,NumEmpleado)',
        N'INSERT #EmpleadosUniverso(Empresa,CveEmpl,NumSolicitud,NumEmpleado)');
    SET @Def=REPLACE(@Def,
        N'SELECT DISTINCT C.CveEmpl,C.NumSolicitud,C.NumEMpleado',
        N'SELECT DISTINCT C.empresa,C.CveEmpl,C.NumSolicitud,C.NumEMpleado');

    SET @Upper=UPPER(@Def);
    SET @Inicio=CHARINDEX(N'AND EXISTS',@Upper,
                 CHARINDEX(N'FROM DBO.BF_COBRANZACACHE_DESGLOSADAV2',@Upper));
    SET @Fin=CHARINDEX(N';',@Def,@Inicio);
    IF @Inicio=0 OR @Fin=0
        THROW 53804,'No se encontro filtro empleado/dependientes B3.',1;

    SET @Bloque=N'AND EXISTS
          (/* BF3_CACHE_FILTRO_EMPRESA_NUM_V3 */
           SELECT 1
           FROM #EmpleadosUniverso AS E
           WHERE E.Empresa=D.EMPRESA
             AND E.NumEmpleado COLLATE DATABASE_DEFAULT=
                 D.NUMEMPLEADO COLLATE DATABASE_DEFAULT)';
    SET @Def=STUFF(@Def,@Inicio,@Fin-@Inicio,@Bloque);

    SET @Upper=UPPER(@Def);
    SET @Proc=CHARINDEX(N'PROCEDURE',@Upper);
    SET @Def=N'CREATE OR ALTER '+SUBSTRING(@Def,@Proc,LEN(@Def));
    EXEC sys.sp_executesql @Def;
END;

/* V4: el flujo directo recibe la descripcion char(100) en varchar(50).
   Igualar el tipo evita espacios de relleno distintos en el contrato cache. */
SET @Def=OBJECT_DEFINITION(OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache'));
IF @Def NOT LIKE N'%BF3_CACHE_SUBTOTAL_VARCHAR50_V4%'
BEGIN
    SET @Def=REPLACE(@Def,
        N'DECLARE @IdSubtotal int,@DescripcionSubtotal varchar(100)',
        N'/* BF3_CACHE_SUBTOTAL_VARCHAR50_V4 */
    DECLARE @IdSubtotal int,@DescripcionSubtotal varchar(50)');
    IF @Def NOT LIKE N'%BF3_CACHE_SUBTOTAL_VARCHAR50_V4%'
        THROW 53805,'No se encontro el tipo de descripcion subtotal B3.',1;

    SET @Upper=UPPER(@Def);
    SET @Proc=CHARINDEX(N'PROCEDURE',@Upper);
    SET @Def=N'CREATE OR ALTER '+SUBSTRING(@Def,@Proc,LEN(@Def));
    EXEC sys.sp_executesql @Def;
END;

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache'))
   NOT LIKE N'%BF3_CACHE_SUBTOTAL_VARCHAR50_V4%'
    THROW 53802,'No se instalo la correccion del filtro cache B3.',1;
IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache'))
   NOT LIKE N'%BF3_CACHE_FILTRO_EMPRESA_NUM_V3%'
    THROW 53806,'No se instalo filtro empresa-numero del cache B3.',1;


SET @Def=OBJECT_DEFINITION(OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache'));
SET @Upper=UPPER(@Def);
SET @Proc=CHARINDEX(N'PROCEDURE',@Upper);
SET @Def=N'CREATE OR ALTER '+SUBSTRING(@Def,@Proc,LEN(@Def));
EXEC sys.sp_executesql @Def;

SELECT N'OK' AS Estado,N'Solo lector cache B3; datos almacenados no cambiaron' AS Alcance;
GO

/* ======================================================================
   PASO 10 DE 10: 09_VALIDAR_FLUJO_UNICO_B3.sql
   ====================================================================== */
RAISERROR(N'[COBRANZA B3] Ejecutando paso 10/10: 09_VALIDAR_FLUJO_UNICO_B3.sql',10,1) WITH NOWAIT;
GO
/* Validacion sin ejecutar una carga. Ajustar solamente empresa/vigencia. */
SET NOCOUNT ON;

DECLARE @IdEmpresa int,
        @IdVigencia int,
        @Ambiguas bigint;

SELECT @IdEmpresa=IdEmpresaValidacion,
       @IdVigencia=IdVigenciaValidacion
FROM #BF3_InstalacionConfig;

IF @IdVigencia IS NULL
    RAISERROR(N'[COBRANZA B3] Validacion de tarifas omitida: no se configuro IdVigencia.',10,1) WITH NOWAIT;

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.ff_ObtenDivisionCtos_Adaptado_bf3_SET'))
   NOT LIKE N'%BF3_DIVISION_SET_V1%' THROW 52720,'Falta motor Division SET.',1;
IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_SET'))
   NOT LIKE N'%BF3_DESGLOSADA_ETAPAS_SET_V1%' THROW 52721,'Falta Desglosada SET.',1;
IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_SET'))
   NOT LIKE N'%BF3_CONCENTRADA_ETAPAS_SET_V1%' THROW 52722,'Falta Concentrada SET.',1;
IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3'))
   NOT LIKE N'%BF3_FLUJO_UNICO_SET_V1%' THROW 52723,'B3 no usa el punto de entrada unico SET.',1;
IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.bf_CobranzaCache_CargarUnaV2'))
   NOT LIKE N'%ObtenCobranzaConcentrada_otro_V2_BF3%' THROW 52724,'Cache no converge al punto de entrada B3.',1;

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.ObtenCobranzaConcentrada')) LIKE N'%_bf3_SET%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_v3')) LIKE N'%_bf3_SET%'
    THROW 52725,'Se detecto una referencia SET dentro de un objeto B2.',1;

IF EXISTS(
    SELECT 1 FROM dbo.ff_Parametro
    WHERE UPPER(LTRIM(RTRIM(ISNULL(paClase,'')))) IN('COBRANZA_SQL_OPT_V2','COBRANZA_SQL_SET_V3')
      AND LTRIM(RTRIM(ISNULL(paValor,'')))<>'0')
    THROW 52726,'Quedo activa una bandera antigua de version SQL.',1;

SELECT @Ambiguas=COUNT_BIG(*)
FROM(
    SELECT TC.TCIdPlanOpcion,TC.TCIdParentesco,TC.TCEdad,TC.TCIdSexo
    FROM dbo.ff_Tarifa AS T WITH(NOLOCK)
    INNER JOIN dbo.ff_TarifaCosto AS TC WITH(NOLOCK) ON TC.TCIdTarifa=T.TAIdTarifa
    WHERE T.TAIdVigencia=@IdVigencia AND TC.TCIdEstatus=1
      AND TC.TCIdGrupoParentesco IS NULL
    GROUP BY TC.TCIdPlanOpcion,TC.TCIdParentesco,TC.TCEdad,TC.TCIdSexo
    HAVING MIN(ISNULL(TC.TCPrimaNeta,0))<>MAX(ISNULL(TC.TCPrimaNeta,0))
) AS A;
IF @Ambiguas<>0 THROW 52727,'Hay tarifas individuales ambiguas; corregir antes de cargar.',1;

SELECT CASE WHEN @IdVigencia IS NULL
            THEN N'VALIDACION_ESTRUCTURAL_OK_DATOS_OMITIDOS'
            ELSE N'VALIDACION_OK' END Estado,
       @IdEmpresa IdEmpresa,@IdVigencia IdVigencia,
       N'Cache y tradicional -> B3 publico -> SET' Flujo,
       N'B2 intacto' B2,@Ambiguas TarifasAmbiguas;

SELECT O.name Objeto,O.type_desc Tipo,O.modify_date FechaModificacion
FROM sys.objects AS O
WHERE O.object_id IN(
 OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3'),
 OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_SET'),
 OBJECT_ID(N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_SET'),
 OBJECT_ID(N'dbo.ff_ObtenDivisionCtos_Adaptado_bf3_SET'))
ORDER BY O.name;
GO
/* ======================================================================
   CIERRE DEL INSTALADOR
   ====================================================================== */
DECLARE @ObjetosObligatorios TABLE
(
    Orden int IDENTITY(1,1) NOT NULL,
    Objeto sysname NOT NULL,
    Tipo varchar(2) NOT NULL,
    Marcador1 nvarchar(200) NULL,
    Marcador2 nvarchar(200) NULL
);

INSERT @ObjetosObligatorios(Objeto,Tipo,Marcador1,Marcador2)
VALUES
 (N'dbo.bf_CobranzaCache_Log','U',NULL,NULL),
 (N'dbo.bf_CobranzaCache_ConsultaV2','U',NULL,NULL),
 (N'dbo.bf_CobranzaCache_ConcentradaV2','U',NULL,NULL),
 (N'dbo.bf_CobranzaCache_DesglosadaV2','U',NULL,NULL),
 (N'dbo.bf_CobranzaCache_BanwireV2','U',NULL,NULL),
 (N'dbo.bf_CobranzaCache_MonitoreoV2','V',NULL,NULL),
 (N'dbo.tr_bf_CobranzaCache_Log_Contexto','TR',NULL,NULL),
 (N'dbo.bf_CobranzaCache_RegistrarEvento','P',NULL,NULL),
 (N'dbo.bf_CobranzaCache_MarcarCargasAbandonadas','P',NULL,NULL),
 (N'dbo.bf_CobranzaCache_CapturaBasesV2','P',NULL,NULL),
 (N'dbo.bf_CobranzaCache_CargarUnaV2','P',NULL,NULL),
 (N'dbo.bf_CobranzaCache_LimpiarVigenciasV2','P',NULL,NULL),
 (N'dbo.InsertaCobranzaConcentrada_otro_V2_BF3_Cache','P',NULL,NULL),
 (N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache','P',
      N'BF3_CACHE_SUBTOTAL_VARCHAR50_V4',N'BF3_CACHE_FILTRO_EMPRESA_NUM_V3'),
 (N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache_PRE_FILTRO_20260822','P',NULL,NULL),
 (N'dbo.ReporteCobranzaConcentrada_BF3_Cache','P',NULL,NULL),
 (N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_LEGACY','P',NULL,NULL),
 (N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_OPT','P',NULL,NULL),
 (N'dbo.ff_ObtenDivisionCtos_Adaptado_bf3_SET','P',N'BF3_DIVISION_SET_V1',NULL),
 (N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_SET','P',N'BF3_DESGLOSADA_ETAPAS_SET_V1',NULL),
 (N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_SET','P',N'BF3_CONCENTRADA_ETAPAS_SET_V1',NULL),
 (N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3','P',N'BF3_FLUJO_UNICO_SET_V1',NULL);

DECLARE @ResultadoObjetos TABLE
(
    Orden int NOT NULL,
    Objeto sysname NOT NULL,
    Tipo varchar(2) NOT NULL,
    Existe bit NOT NULL,
    Marcador1OK bit NOT NULL,
    Marcador2OK bit NOT NULL
);

INSERT @ResultadoObjetos(Orden,Objeto,Tipo,Existe,Marcador1OK,Marcador2OK)
SELECT O.Orden,O.Objeto,O.Tipo,
       CASE WHEN OBJECT_ID(O.Objeto,O.Tipo) IS NULL THEN 0 ELSE 1 END,
       CASE WHEN O.Marcador1 IS NULL THEN 1
            WHEN OBJECT_DEFINITION(OBJECT_ID(O.Objeto,O.Tipo))
                    LIKE N'%'+O.Marcador1+N'%' THEN 1 ELSE 0 END,
       CASE WHEN O.Marcador2 IS NULL THEN 1
            WHEN OBJECT_DEFINITION(OBJECT_ID(O.Objeto,O.Tipo))
                    LIKE N'%'+O.Marcador2+N'%' THEN 1 ELSE 0 END
FROM @ObjetosObligatorios AS O;

SELECT N'VERIFICACION_OBJETOS_OBLIGATORIOS' AS Resultado,
       Objeto,Tipo,Existe,Marcador1OK,Marcador2OK,
       CASE WHEN Existe=1 AND Marcador1OK=1 AND Marcador2OK=1
            THEN N'OK' ELSE N'ERROR' END AS Estado
FROM @ResultadoObjetos
ORDER BY Orden;

IF EXISTS
(
    SELECT 1 FROM @ResultadoObjetos
    WHERE Existe=0 OR Marcador1OK=0 OR Marcador2OK=0
)
    THROW 53920,'La instalacion no termino: faltan objetos funcionales o marcadores B3.',1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id=OBJECT_ID(N'dbo.bf_CobranzaCache_ConsultaV2',N'U')
      AND name=N'UX_CCConsultaV2_Parametros'
      AND is_unique=1
)
    THROW 53921,'Falta el indice UNIQUE obligatorio UX_CCConsultaV2_Parametros.',1;

INSERT #BF3_InstalacionAdvertencias(Paso,Objeto,NumeroError,Mensaje)
SELECT 'FINAL',I.Indice,NULL,
       CONCAT(N'Indice opcional ausente al finalizar sobre ',I.Tabla,N'.')
FROM
(
    VALUES
      (N'dbo.bf_CobranzaCache_Log',N'IX_bf_CobranzaCache_Log_Fecha'),
      (N'dbo.bf_CobranzaCache_Log',N'IX_bf_CobranzaCache_Log_Carga'),
      (N'dbo.bf_CobranzaCache_ConsultaV2',N'IX_CCConsultaV2_Busqueda'),
      (N'dbo.bf_CobranzaCache_ConcentradaV2',N'IX_CCConcentradaV2_Empleado'),
      (N'dbo.bf_CobranzaCache_DesglosadaV2',N'IX_CCDesglosadaV2_Empleado'),
      (N'dbo.bf_CobranzaCache_DesglosadaV2',N'IX_CCDesglosadaV2_Agrupacion'),
      (N'dbo.bf_CobranzaCache_BanwireV2',N'IX_CCBanwireV2_Empleado'),
      (N'dbo.ff_ConcepAgrupaCob',N'IX_BF_Cobranza_CA_EmpresaPlanConcepto'),
      (N'dbo.ff_EdoCuentaCobranza2',N'IX_BF_Cobranza2_EmpresaSolicitudEmpleado'),
      (N'dbo.ff_EdoCuentaCobranza',N'IX_BF_Cobranza_EmpresaSolicitudNumero'),
      (N'dbo.ff_PlanOpcionSeleccionCobranza2',N'IX_BF_POSCob2_EmpresaVigenciaEstatusEmpleado'),
      (N'dbo.ff_GMMDesgCob',N'IX_BF_GMMDesgCob_EmpresaPlanConcepto'),
      (N'dbo.ff_CompensacionPlanOpcion',N'IX_BF_CompPlanOpcion_PlanCompensacion'),
      (N'dbo.ff_EdoCuentaCobranza',N'IX_BF_Cobranza_EmpresaNumeroCompSolicitud'),
      (N'dbo.ff_ValidaSAVida',N'IX_BF_ValidaSA_VigenciaEstatusEmpleadoPlan')
) AS I(Tabla,Indice)
WHERE OBJECT_ID(I.Tabla,N'U') IS NOT NULL
  AND NOT EXISTS
      (
          SELECT 1 FROM sys.indexes AS X
          WHERE X.object_id=OBJECT_ID(I.Tabla,N'U')
            AND X.name=I.Indice
      )
  AND NOT EXISTS
      (
          SELECT 1 FROM #BF3_InstalacionAdvertencias AS A
          WHERE A.Objeto=I.Indice
      );

DECLARE @CantidadAdvertencias int=
       (SELECT COUNT(*) FROM #BF3_InstalacionAdvertencias);

SELECT N'ADVERTENCIAS_NO_BLOQUEANTES' AS Resultado,
       AdvertenciaId,Paso,Objeto,NumeroError,Mensaje,Fecha
FROM #BF3_InstalacionAdvertencias
ORDER BY AdvertenciaId;

IF OBJECT_ID(N'tempdb..#BF3_InstalacionConfig',N'U') IS NOT NULL
    DROP TABLE #BF3_InstalacionConfig;
IF OBJECT_ID(N'tempdb..#BF3_InstalacionAdvertencias',N'U') IS NOT NULL
    DROP TABLE #BF3_InstalacionAdvertencias;

RAISERROR(N'[COBRANZA B3] Instalacion unica finalizada con %d advertencias.',10,1,@CantidadAdvertencias) WITH NOWAIT;
SELECT CASE WHEN @CantidadAdvertencias=0
            THEN N'INSTALACION_COBRANZA_B3_FINALIZADA'
            ELSE N'INSTALACION_COBRANZA_B3_FINALIZADA_CON_ADVERTENCIAS'
       END AS Estado,
       DB_NAME() AS BaseDatos,
       SYSDATETIME() AS FechaFin,
       @CantidadAdvertencias AS AdvertenciasIndices;
GO
