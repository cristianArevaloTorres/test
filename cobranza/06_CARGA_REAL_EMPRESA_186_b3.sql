/*
   CARGA REAL DE COBRANZA B3 - EMPRESA 186

   Este script SI modifica/reconstruye el cache real de cobranza.
   Por defecto procesa las cuatro vigencias mas recientes para poder comparar
   contra la linea base completa de aproximadamente dos horas.

   Para un piloto de una sola vigencia cambie @CantidadVigencias a 1.
   Ejecute 07_MONITOREO_OPCIONAL_b3.sql en otra ventana para seguimiento.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @IdEmpresa int=186,
        @CantidadVigencias tinyint=4,       -- 1 = piloto; 4 = carga completa comparable
        @SegundosLineaBase int=7200,        -- dos horas; ajuste si tiene una medicion mas precisa
        @ForzarRecarga bit=1,
        @InicioTotal datetime2(3)=SYSDATETIME(),
        @FinTotal datetime2(3),
        @InicioVigencia datetime2(3),
        @FinVigencia datetime2(3),
        @IdVigencia int,
        @FecIni varchar(16),
        @FecFin varchar(16),
        @CacheId bigint,
        @SegundosVigencia int,
        @Orden tinyint=1;

IF @CantidadVigencias NOT BETWEEN 1 AND 4
    THROW 52900,'CantidadVigencias debe estar entre 1 y 4.',1;

IF OBJECT_ID(N'dbo.InsertaCobranzaConcentrada_otro_V2_BF3_Cache',N'P') IS NULL
    THROW 52901,'Falta el procedimiento de carga de cache B3.',1;

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3'))
   NOT LIKE N'%BF3_FLUJO_UNICO_SET_V1%'
    THROW 52902,'No esta instalado el flujo unico SET de B3. Ejecute primero los scripts 01 a 05 del ZIP.',1;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.ff_Empresa
    WHERE EMidEmpresa=@IdEmpresa AND EMidEstatus=1
)
    THROW 52903,'La empresa 186 no existe o no esta activa en esta base.',1;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.ff_Parametro
    WHERE paIdEmpresa=@IdEmpresa
      AND UPPER(LTRIM(RTRIM(paClase)))='COBRANZA_CACHE'
      AND LTRIM(RTRIM(paValor))='1'
      AND paIdEstatus=1
)
    THROW 52904,'La empresa 186 no tiene COBRANZA_CACHE=1.',1;

DECLARE @Perfiles dbo.ListInt;

INSERT @Perfiles(IdTipoNotificacionCorreo)
SELECT DISTINCT PEIdPerfil
FROM dbo.ff_Perfil WITH (NOLOCK)
WHERE PEIdEmpresa=@IdEmpresa
  AND PEIdEstatus=1
  AND PEAdministrador=0;

IF NOT EXISTS (SELECT 1 FROM @Perfiles)
    THROW 52905,'La empresa 186 no tiene perfiles activos no administradores.',1;

DECLARE @Vigencias TABLE
(
    Orden tinyint IDENTITY(1,1) PRIMARY KEY,
    IdVigencia int NOT NULL,
    FecIni varchar(16) NOT NULL,
    FecFin varchar(16) NOT NULL
);

INSERT @Vigencias(IdVigencia,FecIni,FecFin)
SELECT TOP (@CantidadVigencias)
       V.VIidVigencia,
       CONVERT(varchar(16),
           CASE WHEN V.VIEnrollmentIni IS NOT NULL
                     AND V.VIEnrollmentIni<V.VIVigenciaIni
                THEN V.VIEnrollmentIni
                ELSE V.VIVigenciaIni
           END,120),
       CONVERT(varchar(16),
           CASE WHEN V.VIVigenciaFin<GETDATE()
                THEN V.VIVigenciaFin
                ELSE DATEADD(MINUTE,-1,
                     DATEADD(DAY,1,CONVERT(datetime,CONVERT(date,GETDATE()))))
           END,120)
FROM dbo.ff_Empresa AS E WITH (NOLOCK)
INNER JOIN dbo.ff_Vigencia AS V WITH (NOLOCK)
        ON V.VIidConfiguracion=E.EMidConfiguracion
WHERE E.EMidEmpresa=@IdEmpresa
  AND E.EMidEstatus=1
  AND V.VITipoNegocio=1
ORDER BY V.VIVigenciaIni DESC,V.VIidVigencia DESC;

IF (SELECT COUNT(*) FROM @Vigencias)<>@CantidadVigencias
    THROW 52906,'No se encontro la cantidad solicitada de vigencias para la empresa 186.',1;

/* No se libera ni se sobreescribe una carga que todavia aparezca activa. */
IF EXISTS
(
    SELECT 1
    FROM dbo.bf_CobranzaCache_ConsultaV2 AS C
    INNER JOIN @Vigencias AS V ON V.IdVigencia=C.IdVigencia
    WHERE C.IdEmpresa=@IdEmpresa AND C.Estado='CARGANDO'
)
BEGIN
    SELECT C.CacheId,C.IdEmpresa,C.IdVigencia,C.Estado,C.FechaCargaInicio,
           DATEDIFF(MINUTE,C.FechaCargaInicio,SYSDATETIME()) AS MinutosCargando,
           C.Mensaje
    FROM dbo.bf_CobranzaCache_ConsultaV2 AS C
    INNER JOIN @Vigencias AS V ON V.IdVigencia=C.IdVigencia
    WHERE C.IdEmpresa=@IdEmpresa AND C.Estado='CARGANDO'
    ORDER BY C.CacheId DESC;

    THROW 52907,'Existe una carga CARGANDO para una vigencia objetivo. Monitoreela o liberela antes de iniciar otra.',1;
END;

SELECT N'PARAMETROS_CARGA_REAL' AS Resultado,
       @IdEmpresa AS IdEmpresa,
       @CantidadVigencias AS CantidadVigencias,
       (SELECT COUNT(*) FROM @Perfiles) AS PerfilesReales,
       @ForzarRecarga AS ForzarRecarga,
       N'SET_UNICA' AS MotorB3;

SELECT Orden,IdVigencia,FecIni,FecFin
FROM @Vigencias
ORDER BY Orden;

DECLARE @Resultado TABLE
(
    Orden tinyint NOT NULL,
    CacheId bigint NULL,
    IdVigencia int NOT NULL,
    Estado varchar(20) NOT NULL,
    Inicio datetime2(3) NOT NULL,
    Fin datetime2(3) NOT NULL,
    Segundos int NOT NULL,
    FilasConcentrada int NULL,
    FilasDesglosada int NULL,
    Mensaje nvarchar(2000) NULL
);

WHILE @Orden<=@CantidadVigencias
BEGIN
    SELECT @IdVigencia=IdVigencia,@FecIni=FecIni,@FecFin=FecFin
    FROM @Vigencias
    WHERE Orden=@Orden;

    SET @CacheId=NULL;
    SET @InicioVigencia=SYSDATETIME();

    RAISERROR('Iniciando carga REAL %d de %d. Empresa=%d; vigencia=%d; rango=%s a %s',
              10,1,@Orden,@CantidadVigencias,@IdEmpresa,@IdVigencia,@FecIni,@FecFin)
              WITH NOWAIT;

    BEGIN TRY
        /* EmitirResultado=0 evita medir la transferencia de todas las filas a SSMS. */
        EXEC dbo.InsertaCobranzaConcentrada_otro_V2_BF3_Cache
             @idEmpresa=@IdEmpresa,
             @idSolTipo=0,
             @FecIni=@FecIni,
             @FecFin=@FecFin,
             @idVencida=1,
             @IdPerfil=@Perfiles,
             @idVIgencia=@IdVigencia,
             @ForzarRecarga=@ForzarRecarga,
             @PrecargarUltimas4=0,
             @EmitirResultado=0,
             @EsUniverso=1;

        SET @FinVigencia=SYSDATETIME();
        SET @SegundosVigencia=DATEDIFF(SECOND,@InicioVigencia,@FinVigencia);

        SELECT TOP (1) @CacheId=CacheId
        FROM dbo.bf_CobranzaCache_ConsultaV2
        WHERE IdEmpresa=@IdEmpresa
          AND IdVigencia=@IdVigencia
          AND EsUniverso=1
          AND FecIni=@FecIni
          AND FecFin=@FecFin
        ORDER BY CacheId DESC;

        INSERT @Resultado
        SELECT @Orden,@CacheId,@IdVigencia,ISNULL(C.Estado,'SIN_CACHE'),
               @InicioVigencia,@FinVigencia,
               @SegundosVigencia,
               C.FilasConcentrada,C.FilasDesglosada,C.Mensaje
        FROM (VALUES(1)) AS X(N)
        LEFT JOIN dbo.bf_CobranzaCache_ConsultaV2 AS C ON C.CacheId=@CacheId;

        IF @CacheId IS NULL OR NOT EXISTS
        (
            SELECT 1 FROM dbo.bf_CobranzaCache_ConsultaV2
            WHERE CacheId=@CacheId AND Estado='COMPLETA'
        )
            THROW 52908,'La ejecucion termino sin dejar la cache en estado COMPLETA.',1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.bf_RepConf_Debug
            WHERE etapa='cobranza_bf3_ruta_sql'
              AND detalle LIKE CONCAT('%ruta=SET_UNICA; empresa=',@IdEmpresa,
                                      '; vigencia=',@IdVigencia,'%')
              AND fecha>=@InicioVigencia
        )
            THROW 52909,'La carga termino, pero no dejo evidencia de haber usado SET_UNICA.',1;

        RAISERROR('Carga REAL completa. Vigencia=%d; segundos=%d; CacheId=%I64d',
                  10,1,@IdVigencia,@SegundosVigencia,@CacheId)
                  WITH NOWAIT;
    END TRY
    BEGIN CATCH
        SET @FinVigencia=SYSDATETIME();

        IF @CacheId IS NULL
            SELECT TOP (1) @CacheId=CacheId
            FROM dbo.bf_CobranzaCache_ConsultaV2
            WHERE IdEmpresa=@IdEmpresa AND IdVigencia=@IdVigencia
              AND EsUniverso=1
            ORDER BY CacheId DESC;

        SELECT N'CARGA_REAL_FALLO' AS Resultado,ERROR_NUMBER() AS NumeroError,
               ERROR_MESSAGE() AS Error,@IdEmpresa AS IdEmpresa,
               @IdVigencia AS IdVigencia,@CacheId AS CacheId,
               DATEDIFF(SECOND,@InicioVigencia,@FinVigencia) AS SegundosHastaError;

        SELECT TOP (100) LogId,Fecha,CacheId,IdEmpresa,IdVigencia,
               Estado,Etapa,Detalle,SesionId
        FROM dbo.bf_CobranzaCache_Log
        WHERE CacheId=@CacheId
        ORDER BY LogId DESC;

        THROW;
    END CATCH;

    SET @Orden+=1;
END;

SET @FinTotal=SYSDATETIME();

SELECT R.Orden,R.CacheId,R.IdVigencia,R.Estado,R.Inicio,R.Fin,
       R.Segundos,CAST(R.Segundos/60.0 AS decimal(10,2)) AS Minutos,
       R.FilasConcentrada,R.FilasDesglosada,R.Mensaje
FROM @Resultado AS R
ORDER BY R.Orden;

SELECT N'CARGA_REAL_COMPLETA' AS Resultado,
       @IdEmpresa AS IdEmpresa,
       @CantidadVigencias AS VigenciasProcesadas,
       DATEDIFF(SECOND,@InicioTotal,@FinTotal) AS SegundosTotales,
       CAST(DATEDIFF(SECOND,@InicioTotal,@FinTotal)/60.0 AS decimal(10,2)) AS MinutosTotales,
       @SegundosLineaBase AS SegundosLineaBase,
       CAST(100.0*(@SegundosLineaBase-DATEDIFF(SECOND,@InicioTotal,@FinTotal))
            /NULLIF(@SegundosLineaBase,0) AS decimal(10,2)) AS ReduccionPorcentaje;

SELECT TOP (200) L.LogId,L.Fecha,L.CacheId,L.IdVigencia,L.Estado,
       L.Etapa,L.Detalle,L.SesionId
FROM dbo.bf_CobranzaCache_Log AS L
WHERE L.IdEmpresa=@IdEmpresa
  AND L.Fecha>=@InicioTotal
ORDER BY L.LogId DESC;
