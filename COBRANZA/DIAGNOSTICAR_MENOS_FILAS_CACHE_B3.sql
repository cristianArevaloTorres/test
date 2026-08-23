/*
   DIAGNOSTICO DE MENOS FILAS EN CACHE B3

   - Solo lectura: no crea, actualiza ni elimina datos permanentes.
   - Resuelve el mismo CacheId que usa el lector B3.
   - Compara el filtro anterior por solicitud con el filtro corregido por
     empresa + numero de empleado (titular y dependientes).

   Si FiltroEmpresaNumeroV3=0, ejecutar despues:
   SQL_01_INSTALACION\COBRANZA\10_CORREGIR_FILTRO_DESGLOSADA_CACHE_B3.sql
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @IdEmpresa int=1807,
        @IdVigencia int=4320,
        @IdSolTipo int=0,
        @IdVencida int=1,
        @IdConfiguracion int,
        @FecIni varchar(16),
        @FecFin varchar(16),
        @PerfilClave varchar(2000),
        @PerfilHash varbinary(32),
        @CacheId bigint,
        @CacheEsUniverso bit,
        @DefLector nvarchar(max);

IF NOT EXISTS
(
    SELECT 1 FROM dbo.ff_Empresa WHERE EMidEmpresa=@IdEmpresa
)
    THROW 54100,'La empresa indicada no existe.',1;

SELECT @IdConfiguracion=EMidConfiguracion
FROM dbo.ff_Empresa
WHERE EMidEmpresa=@IdEmpresa;

SELECT @FecIni=CONVERT(varchar(16),
           CASE WHEN V.VIEnrollmentIni IS NOT NULL
                     AND V.VIEnrollmentIni<V.VIVigenciaIni
                THEN V.VIEnrollmentIni ELSE V.VIVigenciaIni END,120),
       @FecFin=CONVERT(varchar(16),
           CASE WHEN V.VIVigenciaFin<GETDATE() THEN V.VIVigenciaFin
                ELSE DATEADD(MINUTE,-1,
                     DATEADD(DAY,1,CONVERT(datetime,CONVERT(date,GETDATE()))))
           END,120)
FROM dbo.ff_Vigencia AS V
WHERE V.VIidVigencia=@IdVigencia
  AND V.VIidConfiguracion=@IdConfiguracion
  AND V.VITipoNegocio=1;

IF @FecIni IS NULL OR @FecFin IS NULL
    THROW 54101,'La vigencia no pertenece a la configuracion B3 de la empresa.',1;

DECLARE @Perfiles dbo.ListInt;

INSERT @Perfiles(IdTipoNotificacionCorreo)
SELECT DISTINCT PEIdPerfil
FROM dbo.ff_Perfil
WHERE PEIdEmpresa=@IdEmpresa
  AND PEIdEstatus=1
  AND PEAdministrador=0;

SELECT @PerfilClave=STUFF
((
    SELECT ','+CONVERT(varchar(11),P.IdTipoNotificacionCorreo)
    FROM
    (
        SELECT DISTINCT IdTipoNotificacionCorreo FROM @Perfiles
    ) AS P
    ORDER BY P.IdTipoNotificacionCorreo
    FOR XML PATH(''),TYPE
).value('.','varchar(2000)'),1,1,'');

SET @PerfilClave=ISNULL(@PerfilClave,'');
SET @PerfilHash=HASHBYTES('SHA2_256',@PerfilClave);
SET @DefLector=OBJECT_DEFINITION(
    OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache')
);

SELECT N'01_PARAMETROS_Y_VERSION' AS Resultado,
       @IdEmpresa AS IdEmpresa,
       @IdVigencia AS IdVigencia,
       @FecIni AS FecIni,
       @FecFin AS FecFin,
       @PerfilClave AS PerfilClave,
       CASE WHEN @DefLector LIKE N'%BF3_CACHE_FILTRO_EMPRESA_NUM_V3%'
            THEN 1 ELSE 0 END AS FiltroEmpresaNumeroV3,
       CASE WHEN @DefLector LIKE N'%BF3_CACHE_SUBTOTAL_VARCHAR50_V4%'
            THEN 1 ELSE 0 END AS SubtotalVarchar50V4,
       LEN(@DefLector) AS LongitudLectorCache;

/* Todos los candidatos permiten detectar si se esta reutilizando otro cache. */
SELECT N'02_CACHES_CANDIDATOS' AS Resultado,
       C.CacheId,C.IdEmpresa,C.IdSolTipo,C.IdVigencia,C.FecIni,C.FecFin,
       C.PerfilClave,C.EsUniverso,C.Estado,C.FechaCargaInicio,C.FechaCargaFin,
       C.FechaFuenteHasta,C.FilasConcentrada,C.FilasDesglosada,C.Mensaje,
       (SELECT COUNT_BIG(*)
        FROM dbo.bf_CobranzaCache_ConcentradaV2 X
        WHERE X.CacheId=C.CacheId) AS ConcentradaAlmacenada,
       (SELECT COUNT_BIG(*)
        FROM dbo.bf_CobranzaCache_DesglosadaV2 X
        WHERE X.CacheId=C.CacheId) AS DesglosadaAlmacenada
FROM dbo.bf_CobranzaCache_ConsultaV2 C
WHERE C.IdEmpresa=@IdEmpresa
  AND C.IdVigencia=@IdVigencia
ORDER BY C.CacheId DESC;

/* Primero se busca el cache exacto, igual que el lector. */
SELECT @CacheId=C.CacheId,
       @CacheEsUniverso=C.EsUniverso
FROM dbo.bf_CobranzaCache_ConsultaV2 C
WHERE C.IdEmpresa=@IdEmpresa
  AND C.IdSolTipo=@IdSolTipo
  AND C.FecIni=@FecIni
  AND C.FecFin=@FecFin
  AND C.IdVencida=@IdVencida
  AND C.IdVigencia=@IdVigencia
  AND C.PerfilHash=@PerfilHash
  AND C.EsUniverso=0
  AND C.Estado='COMPLETA';

/* Si no existe exacto, se resuelve el universo compatible. */
IF @CacheId IS NULL
BEGIN
    SELECT TOP (1)
           @CacheId=C.CacheId,
           @CacheEsUniverso=C.EsUniverso
    FROM dbo.bf_CobranzaCache_ConsultaV2 C
    WHERE C.IdEmpresa=@IdEmpresa
      AND C.IdSolTipo=@IdSolTipo
      AND C.IdVencida=@IdVencida
      AND C.IdVigencia=@IdVigencia
      AND C.EsUniverso=1
      AND C.Estado='COMPLETA'
      AND TRY_CONVERT(datetime,C.FecIni)<=TRY_CONVERT(datetime,@FecIni)
      AND TRY_CONVERT(datetime,C.FecFin)>=TRY_CONVERT(datetime,@FecFin)
      AND YEAR(TRY_CONVERT(datetime,C.FecFin))=YEAR(TRY_CONVERT(datetime,@FecFin))
      AND MONTH(TRY_CONVERT(datetime,C.FecFin))=MONTH(TRY_CONVERT(datetime,@FecFin))
      AND NOT EXISTS
          (
              SELECT 1 FROM @Perfiles R
              WHERE NOT EXISTS
                    (
                        SELECT 1 FROM STRING_SPLIT(C.PerfilClave,',') P
                        WHERE TRY_CONVERT(int,P.value)=R.IdTipoNotificacionCorreo
                    )
          )
    ORDER BY C.FechaCargaFin DESC,C.CacheId DESC;
END;

IF @CacheId IS NULL
    THROW 54102,'No existe un cache completo que el lector pueda utilizar.',1;

CREATE TABLE #PerfilesSolicitados
(
    PENombre varchar(50) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY
);

INSERT #PerfilesSolicitados(PENombre)
SELECT DISTINCT P.PENombre
FROM dbo.ff_Perfil P
INNER JOIN @Perfiles R
        ON R.IdTipoNotificacionCorreo=P.PEIdPerfil
WHERE P.PEIdEmpresa=@IdEmpresa
  AND P.PEIdEstatus=1;

CREATE TABLE #EmpleadosUniverso
(
    Empresa int NOT NULL,
    CveEmpl int NULL,
    NumSolicitud varchar(8) COLLATE DATABASE_DEFAULT NULL,
    NumEmpleado varchar(20) COLLATE DATABASE_DEFAULT NULL
);

INSERT #EmpleadosUniverso(Empresa,CveEmpl,NumSolicitud,NumEmpleado)
SELECT DISTINCT C.empresa,C.CveEmpl,C.NumSolicitud,C.NumEMpleado
FROM dbo.bf_CobranzaCache_ConcentradaV2 C
WHERE C.CacheId=@CacheId
  AND
  (
      @CacheEsUniverso=0
      OR
      (
          EXISTS
              (
                  SELECT 1 FROM #PerfilesSolicitados P
                  WHERE P.PENombre=C.Perfil COLLATE DATABASE_DEFAULT
              )
          AND COALESCE(TRY_CONVERT(date,C.FechaAutorizacion,103),CONVERT(date,GETDATE()))
                BETWEEN CONVERT(date,TRY_CONVERT(datetime,@FecIni))
                    AND CONVERT(date,TRY_CONVERT(datetime,@FecFin))
      )
  );

DECLARE @ConcAlmacenada bigint,
        @ConcSeleccionada bigint,
        @DesgAlmacenada bigint,
        @DesgFiltroV3 bigint,
        @DesgFiltroAnterior bigint;

SELECT @ConcAlmacenada=COUNT_BIG(*)
FROM dbo.bf_CobranzaCache_ConcentradaV2
WHERE CacheId=@CacheId;

SELECT @ConcSeleccionada=COUNT_BIG(*)
FROM dbo.bf_CobranzaCache_ConcentradaV2 C
WHERE C.CacheId=@CacheId
  AND EXISTS
      (
          SELECT 1 FROM #EmpleadosUniverso E
          WHERE E.CveEmpl=C.CveEmpl
            AND E.NumEmpleado=C.NumEMpleado COLLATE DATABASE_DEFAULT
      );

SELECT @DesgAlmacenada=COUNT_BIG(*)
FROM dbo.bf_CobranzaCache_DesglosadaV2
WHERE CacheId=@CacheId;

SELECT @DesgFiltroV3=COUNT_BIG(*)
FROM dbo.bf_CobranzaCache_DesglosadaV2 D
WHERE D.CacheId=@CacheId
  AND EXISTS
      (
          SELECT 1 FROM #EmpleadosUniverso E
          WHERE E.Empresa=D.EMPRESA
            AND E.NumEmpleado=D.NUMEMPLEADO COLLATE DATABASE_DEFAULT
      );

SELECT @DesgFiltroAnterior=COUNT_BIG(*)
FROM dbo.bf_CobranzaCache_DesglosadaV2 D
WHERE D.CacheId=@CacheId
  AND EXISTS
      (
          SELECT 1 FROM #EmpleadosUniverso E
          WHERE E.CveEmpl=D.idemp
            AND
            (
                E.NumSolicitud=D.NumSolicitud COLLATE DATABASE_DEFAULT
                OR E.NumSolicitud IS NULL
                OR D.NumSolicitud IS NULL
            )
      );

SELECT N'03_DIAGNOSTICO_CACHE_ELEGIDO' AS Resultado,
       @CacheId AS CacheIdElegido,
       @CacheEsUniverso AS EsUniverso,
       @ConcAlmacenada AS ConcentradaAlmacenadaSinTotal,
       @ConcSeleccionada AS ConcentradaLeidaSinTotal,
       @ConcSeleccionada+1 AS ConcentradaEsperadaConTotal,
       @DesgAlmacenada AS DesglosadaAlmacenadaSinTotal,
       @DesgFiltroV3 AS DesglosadaLeidaFiltroV3SinTotal,
       @DesgFiltroV3+1 AS DesglosadaEsperadaConTotal,
       @DesgFiltroAnterior AS DesglosadaFiltroAnteriorSinTotal,
       @DesgFiltroV3-@DesgFiltroAnterior AS FilasQuePerdiaFiltroAnterior,
       CASE
         WHEN @DefLector NOT LIKE N'%BF3_CACHE_FILTRO_EMPRESA_NUM_V3%'
              AND @DesgFiltroV3>@DesgFiltroAnterior
           THEN N'CAUSA PROBABLE: lector anterior descarta solicitudes/dependientes. Ejecutar correccion 10.'
         WHEN @DefLector NOT LIKE N'%BF3_CACHE_FILTRO_EMPRESA_NUM_V3%'
           THEN N'El lector V3 no esta instalado; ejecutar correccion 10 y volver a generar/probar.'
         WHEN @ConcSeleccionada<@ConcAlmacenada OR @DesgFiltroV3<@DesgAlmacenada
           THEN N'El lector V3 esta instalado, pero el cache elegido es universo y el filtro solicitado reduce filas.'
         ELSE N'El lector conserva todas las filas almacenadas; comparar estos conteos con la ejecucion DIRECTO.'
       END AS Diagnostico;

/* Ejemplos de filas que descartaba el lector anterior. */
SELECT TOP (100)
       N'04_MUESTRA_PERDIDAS_FILTRO_ANTERIOR' AS Resultado,
       D.EMPRESA,D.NUMEMPLEADO,D.idemp,D.NumSolicitud,D.CVEPO,D.CVEP,
       D.PlanD,D.PlanOpcion
FROM dbo.bf_CobranzaCache_DesglosadaV2 D
WHERE D.CacheId=@CacheId
  AND EXISTS
      (
          SELECT 1 FROM #EmpleadosUniverso E
          WHERE E.Empresa=D.EMPRESA
            AND E.NumEmpleado=D.NUMEMPLEADO COLLATE DATABASE_DEFAULT
      )
  AND NOT EXISTS
      (
          SELECT 1 FROM #EmpleadosUniverso E
          WHERE E.CveEmpl=D.idemp
            AND
            (
                E.NumSolicitud=D.NumSolicitud COLLATE DATABASE_DEFAULT
                OR E.NumSolicitud IS NULL
                OR D.NumSolicitud IS NULL
            )
      )
ORDER BY D.EMPRESA,D.NUMEMPLEADO,D.NumSolicitud,D.CVEPO;
