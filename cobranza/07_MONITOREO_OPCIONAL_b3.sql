/*
   MONITOR EN VIVO DE LA CARGA REAL B3 - SOLO LECTURA

   Ejecutar repetidamente en otra ventana de SSMS. Detecta primero la carga
   mas reciente cuyo ultimo evento continua en CARGANDO; si no existe, muestra
   la cache mas recientemente atendida de la empresa.
*/
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @IdEmpresa int=186,
        @CacheId bigint=NULL,       -- NULL = detectar automaticamente
        @IdVigencia int,
        @Inicio datetime2(3),
        @Estado varchar(20),
        @SesionId smallint,
        @Ahora datetime2(3)=SYSDATETIME();

IF OBJECT_ID(N'dbo.bf_CobranzaCache_ConsultaV2',N'U') IS NULL
    THROW 52920,'Falta dbo.bf_CobranzaCache_ConsultaV2.',1;
IF OBJECT_ID(N'dbo.bf_CobranzaCache_Log',N'U') IS NULL
    THROW 52921,'Falta dbo.bf_CobranzaCache_Log.',1;

/* El ultimo evento CARGANDO es mas confiable que el estado de una cache que
   ya existia y esta siendo reconstruida con @ForzarRecarga=1. */
IF @CacheId IS NULL
BEGIN
    ;WITH UltimoEvento AS
    (
        SELECT L.CacheId,L.IdVigencia,L.Estado,L.Fecha,L.LogId,
               ROW_NUMBER() OVER(PARTITION BY L.CacheId ORDER BY L.LogId DESC) AS RN
        FROM dbo.bf_CobranzaCache_Log AS L WITH (NOLOCK)
        WHERE L.IdEmpresa=@IdEmpresa AND L.CacheId IS NOT NULL
          AND L.Fecha>=DATEADD(DAY,-1,@Ahora)
    )
    SELECT TOP (1) @CacheId=CacheId
    FROM UltimoEvento
    WHERE RN=1 AND Estado='CARGANDO'
    ORDER BY LogId DESC;
END;

IF @CacheId IS NULL
BEGIN
    SELECT TOP (1) @CacheId=CacheId
    FROM dbo.bf_CobranzaCache_ConsultaV2 WITH (NOLOCK)
    WHERE IdEmpresa=@IdEmpresa
    ORDER BY FechaCargaInicio DESC,CacheId DESC;
END;

IF @CacheId IS NULL
    THROW 52922,'No hay cargas de cobranza para la empresa 186.',1;

SELECT @IdVigencia=C.IdVigencia,@Estado=C.Estado,@Inicio=C.FechaCargaInicio
FROM dbo.bf_CobranzaCache_ConsultaV2 AS C WITH (NOLOCK)
WHERE C.CacheId=@CacheId AND C.IdEmpresa=@IdEmpresa;

SELECT TOP (1) @Inicio=L.Fecha
FROM dbo.bf_CobranzaCache_Log AS L WITH (NOLOCK)
WHERE L.CacheId=@CacheId AND L.Etapa='SP_ORIGINAL_INICIO'
ORDER BY L.LogId DESC;

SELECT TOP (1) @SesionId=L.SesionId
FROM dbo.bf_CobranzaCache_Log AS L WITH (NOLOCK)
WHERE L.CacheId=@CacheId AND L.Fecha>=@Inicio AND L.SesionId IS NOT NULL
ORDER BY L.LogId DESC;

/* 1. Vigencia que se esta atendiendo y tiempo transcurrido. */
SELECT C.CacheId,C.IdEmpresa,C.IdVigencia,C.Estado,
       C.FechaCargaInicio,C.FechaCargaFin,
       DATEDIFF(SECOND,@Inicio,@Ahora) AS SegundosEjecucionActual,
       CAST(DATEDIFF(SECOND,@Inicio,@Ahora)/60.0 AS decimal(10,2)) AS MinutosEjecucionActual,
       C.FilasConcentrada,C.FilasDesglosada,C.Mensaje,
       @SesionId AS SesionSql
FROM dbo.bf_CobranzaCache_ConsultaV2 AS C WITH (NOLOCK)
WHERE C.CacheId=@CacheId;

/* 2. Estado reciente de las cuatro vigencias del lote. */
;WITH U AS
(
    SELECT C.*,
           ROW_NUMBER() OVER
           (PARTITION BY C.IdVigencia ORDER BY C.FechaCargaInicio DESC,C.CacheId DESC) AS RN
    FROM dbo.bf_CobranzaCache_ConsultaV2 AS C WITH (NOLOCK)
    WHERE C.IdEmpresa=@IdEmpresa AND C.EsUniverso=1
)
SELECT TOP (4) CacheId,IdVigencia,Estado,FechaCargaInicio,FechaCargaFin,
       DATEDIFF(SECOND,FechaCargaInicio,
                CASE WHEN Estado='CARGANDO' THEN @Ahora
                     ELSE ISNULL(FechaCargaFin,@Ahora) END) AS Segundos,
       FilasConcentrada,FilasDesglosada,Mensaje
FROM U
WHERE RN=1
ORDER BY FechaCargaInicio DESC,CacheId DESC;

/* 3. Eventos estructurados de la cache actual, en orden cronologico. */
;WITH Eventos AS
(
    SELECT TOP (200) L.LogId,L.Fecha,L.Etapa,L.Estado,L.Detalle,L.SesionId
    FROM dbo.bf_CobranzaCache_Log AS L WITH (NOLOCK)
    WHERE L.CacheId=@CacheId AND L.Fecha>=@Inicio
    ORDER BY L.LogId DESC
), Tiempos AS
(
    SELECT E.*,
           LAG(E.Fecha) OVER(ORDER BY E.LogId) AS FechaAnterior
    FROM Eventos AS E
)
SELECT LogId,Fecha,Etapa,Estado,
       DATEDIFF(MILLISECOND,FechaAnterior,Fecha) AS MilisegundosDesdeEventoAnterior,
       Detalle,SesionId
FROM Tiempos
ORDER BY LogId;

/* 4. Paso interno mas reciente del motor SET y cronologia de sus etapas.
      Las etapas sin empresa se acotan a la ventana de la carga seleccionada. */
;WITH Internos AS
(
    SELECT TOP (200) D.id,D.fecha,D.etapa,D.detalle
    FROM dbo.bf_RepConf_Debug AS D WITH (NOLOCK)
    WHERE D.fecha>=@Inicio AND D.fecha<=@Ahora
      AND D.etapa LIKE 'cobranza%'
      AND
      (
          D.detalle LIKE CONCAT('%empresa=',@IdEmpresa,'%')
          OR D.detalle LIKE CONCAT('%idEmpresa=',@IdEmpresa,'%')
          OR D.etapa LIKE 'cobranza_bf3_%set%'
          OR D.etapa IN
             ('cobranza_obten_pre_sinc','cobranza_obten_pre_sinc_exec',
              'cobranza_obten_post_sinc','cobranza_obten_pre_empleados',
              'cobranza_obten_post_empleados','cobranza_obten_post_insert',
              'cobranza_obten_pre_desglosada','cobranza_desg_pre_division',
              'cobranza_obten_post_desglosada','cobranza_obten_fin')
      )
    ORDER BY D.id DESC
), Tiempos AS
(
    SELECT I.*,
           LAG(I.fecha) OVER(ORDER BY I.id) AS FechaAnterior
    FROM Internos AS I
)
SELECT id,fecha,etapa,
       CASE
         WHEN etapa='cobranza_bf3_ruta_sql' THEN 'Entrada al motor SET unico'
         WHEN etapa IN('cobranza_obten_pre_sinc','cobranza_obten_pre_sinc_exec') THEN 'Sincronizando datos fuente'
         WHEN etapa='cobranza_obten_post_sinc' THEN 'Sincronizacion terminada'
         WHEN etapa='cobranza_obten_pre_empleados' THEN 'Preparando empleados'
         WHEN etapa='cobranza_obten_post_empleados' THEN 'Empleados preparados'
         WHEN etapa LIKE 'cobranza_bf3_conc%' OR etapa='cobranza_obten_post_insert' THEN 'Construyendo concentrada'
         WHEN etapa='cobranza_obten_pre_desglosada' OR etapa LIKE 'cobranza_bf3_desg%' THEN 'Construyendo desglosada'
         WHEN etapa LIKE 'cobranza_bf3_division_set%' THEN 'Distribuyendo importes en forma SET'
         WHEN etapa IN('cobranza_obten_post_desglosada','cobranza_obten_fin') THEN 'Finalizando resultados'
         ELSE 'Procesando cobranza B3'
       END AS PasoInterpretado,
       DATEDIFF(MILLISECOND,FechaAnterior,fecha) AS MilisegundosDesdePasoAnterior,
       detalle
FROM Tiempos
ORDER BY id;

/* 5. Espera, consumo y bloqueo de la sesion real. Requiere VIEW SERVER STATE. */
IF HAS_PERMS_BY_NAME(NULL,NULL,'VIEW SERVER STATE')=1
BEGIN
    SELECT R.session_id,R.status,R.command,R.wait_type,R.wait_time,
           R.last_wait_type,R.cpu_time,R.total_elapsed_time,R.logical_reads,
           R.reads,R.writes,R.blocking_session_id,
           DB_NAME(R.database_id) AS BaseDatos,
           SUBSTRING(T.text,(R.statement_start_offset/2)+1,
             ((CASE R.statement_end_offset WHEN -1 THEN DATALENGTH(T.text)
                    ELSE R.statement_end_offset END-R.statement_start_offset)/2)+1) AS SentenciaActual
    FROM sys.dm_exec_requests AS R
    OUTER APPLY sys.dm_exec_sql_text(R.sql_handle) AS T
    WHERE R.session_id=@SesionId;

    SELECT R.session_id AS SesionCarga,R.blocking_session_id AS SesionBloqueadora,
           B.status AS EstadoBloqueador,B.login_name,B.host_name,B.program_name
    FROM sys.dm_exec_requests AS R
    LEFT JOIN sys.dm_exec_sessions AS B ON B.session_id=R.blocking_session_id
    WHERE R.session_id=@SesionId AND R.blocking_session_id<>0;
END
ELSE
    SELECT N'El resumen y las etapas estan disponibles. Para ver waits/bloqueos se requiere VIEW SERVER STATE.' AS Aviso;

