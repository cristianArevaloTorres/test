/*
   SELECCION DE EMPRESA/VIGENCIA PARA PRUEBAS DE COBRANZA B3

   OBJETIVO
   - Cambiar solamente @IdEmpresa para conocer las vigencias disponibles.
   - Contar filas de las tablas que mas influyen en el costo del flujo B3.
   - Clasificar cada vigencia para decidir si conviene usarla en el piloto.
   - Informar si existe un cache completo que permita probar la lectura CACHE.

   IMPORTANTE
   - Es un diagnostico de solo lectura; no crea ni modifica datos permanentes.
   - "FilasEstrategicas" es un indicador de volumen, no una estimacion exacta
     de segundos. Los limites se deben recalibrar despues de medir DEV.
   - Los conteos de EdoCuenta incluyen filas enlazadas a solicitudes de la
     empresa y vigencia analizadas.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @IdEmpresa int=186,
        @IdVigenciaEspecifica int=NULL, -- NULL = analizar las mas recientes
        @CantidadVigencias int=12,

        /* Limites iniciales para escoger un piloto. Son configurables. */
        @LimiteIdeal bigint=500000,
        @LimiteUtilizable bigint=2000000,
        @LimitePesada bigint=5000000,

        @IdConfiguracion int,
        @EmpleadosActivos bigint,
        @PerfilesActivos bigint;

IF @CantidadVigencias NOT BETWEEN 1 AND 20
    THROW 53900,'CantidadVigencias debe estar entre 1 y 20.',1;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.ff_Empresa
    WHERE EMidEmpresa=@IdEmpresa
)
    THROW 53901,'La empresa solicitada no existe.',1;

SELECT @IdConfiguracion=EMidConfiguracion
FROM dbo.ff_Empresa
WHERE EMidEmpresa=@IdEmpresa;

SELECT @EmpleadosActivos=COUNT_BIG(*)
FROM dbo.ff_Empleado
WHERE EMIdEmpresa=@IdEmpresa
  AND EMIdEstatus=1
  AND EMNumeroEmpleado NOT LIKE 'TEST%';

SELECT @PerfilesActivos=COUNT_BIG(*)
FROM dbo.ff_Perfil
WHERE PEIdEmpresa=@IdEmpresa
  AND PEIdEstatus=1
  AND PEAdministrador=0;

CREATE TABLE #Vigencias
(
    IdVigencia int NOT NULL PRIMARY KEY,
    VigenciaInicio datetime NULL,
    VigenciaFin datetime NULL,
    FechaInicioConsulta varchar(16) NOT NULL,
    FechaFinConsulta varchar(16) NOT NULL
);

IF @IdVigenciaEspecifica IS NULL
BEGIN
    INSERT #Vigencias
    (
        IdVigencia,VigenciaInicio,VigenciaFin,
        FechaInicioConsulta,FechaFinConsulta
    )
    SELECT TOP (@CantidadVigencias)
           V.VIidVigencia,
           V.VIVigenciaIni,
           V.VIVigenciaFin,
           CONVERT(varchar(16),
             CASE WHEN V.VIEnrollmentIni IS NOT NULL
                       AND V.VIEnrollmentIni<V.VIVigenciaIni
                  THEN V.VIEnrollmentIni ELSE V.VIVigenciaIni END,120),
           CONVERT(varchar(16),
             CASE WHEN V.VIVigenciaFin<GETDATE() THEN V.VIVigenciaFin
                  ELSE DATEADD(MINUTE,-1,
                       DATEADD(DAY,1,CONVERT(datetime,CONVERT(date,GETDATE()))))
             END,120)
    FROM dbo.ff_Vigencia AS V
    WHERE V.VIidConfiguracion=@IdConfiguracion
      AND V.VITipoNegocio=1
    ORDER BY V.VIVigenciaIni DESC,V.VIidVigencia DESC;
END
ELSE
BEGIN
    INSERT #Vigencias
    (
        IdVigencia,VigenciaInicio,VigenciaFin,
        FechaInicioConsulta,FechaFinConsulta
    )
    SELECT V.VIidVigencia,
           V.VIVigenciaIni,
           V.VIVigenciaFin,
           CONVERT(varchar(16),
             CASE WHEN V.VIEnrollmentIni IS NOT NULL
                       AND V.VIEnrollmentIni<V.VIVigenciaIni
                  THEN V.VIEnrollmentIni ELSE V.VIVigenciaIni END,120),
           CONVERT(varchar(16),
             CASE WHEN V.VIVigenciaFin<GETDATE() THEN V.VIVigenciaFin
                  ELSE DATEADD(MINUTE,-1,
                       DATEADD(DAY,1,CONVERT(datetime,CONVERT(date,GETDATE()))))
             END,120)
    FROM dbo.ff_Vigencia AS V
    WHERE V.VIidVigencia=@IdVigenciaEspecifica
      AND V.VIidConfiguracion=@IdConfiguracion
      AND V.VITipoNegocio=1;
END;

IF NOT EXISTS(SELECT 1 FROM #Vigencias)
    THROW 53902,'No hay vigencias B3 para la empresa y filtros indicados.',1;

RAISERROR(N'[PERFIL B3] Contando solicitudes de empresa %d.',0,1,@IdEmpresa)
    WITH NOWAIT;

CREATE TABLE #Solicitud
(
    IdVigencia int NOT NULL PRIMARY KEY,
    Solicitudes bigint NOT NULL,
    EmpleadosSolicitud bigint NOT NULL
);

INSERT #Solicitud(IdVigencia,Solicitudes,EmpleadosSolicitud)
SELECT S.SOIdVigencia,
       COUNT_BIG(*) AS Solicitudes,
       COUNT(DISTINCT S.SOIdEmpleado) AS EmpleadosSolicitud
FROM dbo.ff_Solicitud AS S WITH(NOLOCK)
INNER JOIN #Vigencias AS V ON V.IdVigencia=S.SOIdVigencia
WHERE S.SOIdEmpresa=@IdEmpresa
GROUP BY S.SOIdVigencia
OPTION(RECOMPILE);

/* Llaves de solicitud usadas para enlazar los estados de cuenta sin recorrer
   solicitudes de otras empresas/vigencias en cada conteo. */
CREATE TABLE #SolicitudLlave
(
    IdSolicitud int NOT NULL,
    IdVigencia int NOT NULL,
    PRIMARY KEY(IdSolicitud,IdVigencia)
);

INSERT #SolicitudLlave(IdSolicitud,IdVigencia)
SELECT DISTINCT S.SOIdSolicitud,S.SOIdVigencia
FROM dbo.ff_Solicitud AS S WITH(NOLOCK)
INNER JOIN #Vigencias AS V ON V.IdVigencia=S.SOIdVigencia
WHERE S.SOIdEmpresa=@IdEmpresa
  AND S.SOIdSolicitud IS NOT NULL;

CREATE INDEX IX_SolicitudLlave_Vigencia
    ON #SolicitudLlave(IdVigencia,IdSolicitud);

CREATE TABLE #Seleccion1
(
    IdVigencia int NOT NULL PRIMARY KEY,
    Selecciones bigint NOT NULL,
    PlanOpciones bigint NOT NULL
);

INSERT #Seleccion1(IdVigencia,Selecciones,PlanOpciones)
SELECT P.POIdVigencia,COUNT_BIG(*),COUNT(DISTINCT P.POIdPlanOpcion)
FROM dbo.ff_PlanOpcionSeleccionCobranza AS P WITH(NOLOCK)
INNER JOIN #Vigencias AS V ON V.IdVigencia=P.POIdVigencia
WHERE P.POIdEmpresa=@IdEmpresa
GROUP BY P.POIdVigencia
OPTION(RECOMPILE);

CREATE TABLE #Seleccion2
(
    IdVigencia int NOT NULL PRIMARY KEY,
    Selecciones bigint NOT NULL,
    PlanOpciones bigint NOT NULL
);

INSERT #Seleccion2(IdVigencia,Selecciones,PlanOpciones)
SELECT P.POIdVigencia,COUNT_BIG(*),COUNT(DISTINCT P.POIdPlanOpcion)
FROM dbo.ff_PlanOpcionSeleccionCobranza2 AS P WITH(NOLOCK)
INNER JOIN #Vigencias AS V ON V.IdVigencia=P.POIdVigencia
WHERE P.POIdEmpresa=@IdEmpresa
GROUP BY P.POIdVigencia
OPTION(RECOMPILE);

RAISERROR(N'[PERFIL B3] Contando estados de cuenta relacionados.',0,1)
    WITH NOWAIT;

CREATE TABLE #EdoCuenta1
(
    IdVigencia int NOT NULL PRIMARY KEY,
    Filas bigint NOT NULL
);

INSERT #EdoCuenta1(IdVigencia,Filas)
SELECT K.IdVigencia,COUNT_BIG(*)
FROM dbo.ff_EdoCuentaCobranza AS EC WITH(NOLOCK)
INNER JOIN #SolicitudLlave AS K ON K.IdSolicitud=EC.ECidSolicitud
WHERE EC.ECidEmpresa=@IdEmpresa
GROUP BY K.IdVigencia
OPTION(RECOMPILE);

CREATE TABLE #EdoCuenta2
(
    IdVigencia int NOT NULL PRIMARY KEY,
    Filas bigint NOT NULL
);

INSERT #EdoCuenta2(IdVigencia,Filas)
SELECT K.IdVigencia,COUNT_BIG(*)
FROM dbo.ff_EdoCuentaCobranza2 AS EC WITH(NOLOCK)
INNER JOIN #SolicitudLlave AS K ON K.IdSolicitud=EC.ECidSolicitud
WHERE EC.ECidEmpresa=@IdEmpresa
GROUP BY K.IdVigencia
OPTION(RECOMPILE);

CREATE TABLE #Tarifas
(
    IdVigencia int NOT NULL PRIMARY KEY,
    Tarifas bigint NOT NULL,
    TarifasCosto bigint NOT NULL
);

INSERT #Tarifas(IdVigencia,Tarifas,TarifasCosto)
SELECT V.IdVigencia,
       COUNT(DISTINCT T.TAIdTarifa) AS Tarifas,
       COUNT_BIG(TC.TCIdTarifa) AS TarifasCosto
FROM #Vigencias AS V
LEFT JOIN dbo.ff_Tarifa AS T WITH(NOLOCK)
       ON T.TAIdVigencia=V.IdVigencia
LEFT JOIN dbo.ff_TarifaCosto AS TC WITH(NOLOCK)
       ON TC.TCIdTarifa=T.TAIdTarifa
GROUP BY V.IdVigencia
OPTION(RECOMPILE);

CREATE TABLE #ValidaSA
(
    IdVigencia int NOT NULL PRIMARY KEY,
    Filas bigint NOT NULL
);

INSERT #ValidaSA(IdVigencia,Filas)
SELECT V.IdVigencia,COUNT_BIG(SA.VSIdVigencia)
FROM #Vigencias AS V
LEFT JOIN dbo.ff_ValidaSAVida AS SA WITH(NOLOCK)
       ON SA.VSIdVigencia=V.IdVigencia
GROUP BY V.IdVigencia
OPTION(RECOMPILE);

CREATE TABLE #Cache
(
    IdVigencia int NOT NULL PRIMARY KEY,
    CacheId bigint NULL,
    Estado varchar(20) NULL,
    FechaCargaInicio datetime NULL,
    FechaCargaFin datetime NULL,
    FilasConcentrada bigint NULL,
    FilasDesglosada bigint NULL
);

IF OBJECT_ID(N'dbo.bf_CobranzaCache_ConsultaV2',N'U') IS NOT NULL
BEGIN
    INSERT #Cache
    (
        IdVigencia,CacheId,Estado,FechaCargaInicio,FechaCargaFin,
        FilasConcentrada,FilasDesglosada
    )
    SELECT IdVigencia,CacheId,Estado,FechaCargaInicio,FechaCargaFin,
           FilasConcentrada,FilasDesglosada
    FROM
    (
        SELECT C.IdVigencia,C.CacheId,C.Estado,
               C.FechaCargaInicio,C.FechaCargaFin,
               C.FilasConcentrada,C.FilasDesglosada,
               ROW_NUMBER() OVER
               (
                   PARTITION BY C.IdVigencia
                   ORDER BY COALESCE(C.FechaCargaFin,C.FechaCargaInicio) DESC,
                            C.CacheId DESC
               ) AS RN
        FROM dbo.bf_CobranzaCache_ConsultaV2 AS C WITH(NOLOCK)
        INNER JOIN #Vigencias AS V ON V.IdVigencia=C.IdVigencia
        WHERE C.IdEmpresa=@IdEmpresa
          AND C.EsUniverso=1
          AND C.Estado='COMPLETA'
    ) AS X
    WHERE RN=1;
END;

CREATE TABLE #Resumen
(
    IdVigencia int NOT NULL PRIMARY KEY,
    VigenciaInicio datetime NULL,
    VigenciaFin datetime NULL,
    FechaInicioConsulta varchar(16) NOT NULL,
    FechaFinConsulta varchar(16) NOT NULL,
    Solicitudes bigint NOT NULL,
    EmpleadosSolicitud bigint NOT NULL,
    SeleccionesB2 bigint NOT NULL,
    SeleccionesB3 bigint NOT NULL,
    PlanOpcionesB3 bigint NOT NULL,
    EdoCuentaB2 bigint NOT NULL,
    EdoCuentaB3 bigint NOT NULL,
    Tarifas bigint NOT NULL,
    TarifasCosto bigint NOT NULL,
    ValidaSAVida bigint NOT NULL,
    FilasEstrategicas bigint NOT NULL,
    Nivel tinyint NOT NULL,
    Clasificacion varchar(30) NOT NULL,
    Recomendacion varchar(200) NOT NULL,
    CacheId bigint NULL,
    EstadoCache varchar(20) NULL,
    FilasCache bigint NULL
);

INSERT #Resumen
SELECT V.IdVigencia,V.VigenciaInicio,V.VigenciaFin,
       V.FechaInicioConsulta,V.FechaFinConsulta,
       ISNULL(S.Solicitudes,0),ISNULL(S.EmpleadosSolicitud,0),
       ISNULL(P1.Selecciones,0),ISNULL(P2.Selecciones,0),
       ISNULL(P2.PlanOpciones,0),
       ISNULL(E1.Filas,0),ISNULL(E2.Filas,0),
       ISNULL(T.Tarifas,0),ISNULL(T.TarifasCosto,0),
       ISNULL(SA.Filas,0),W.FilasEstrategicas,
       C.Nivel,C.Clasificacion,C.Recomendacion,
       CA.CacheId,CA.Estado,
       ISNULL(CA.FilasConcentrada,0)+ISNULL(CA.FilasDesglosada,0)
FROM #Vigencias AS V
LEFT JOIN #Solicitud AS S ON S.IdVigencia=V.IdVigencia
LEFT JOIN #Seleccion1 AS P1 ON P1.IdVigencia=V.IdVigencia
LEFT JOIN #Seleccion2 AS P2 ON P2.IdVigencia=V.IdVigencia
LEFT JOIN #EdoCuenta1 AS E1 ON E1.IdVigencia=V.IdVigencia
LEFT JOIN #EdoCuenta2 AS E2 ON E2.IdVigencia=V.IdVigencia
LEFT JOIN #Tarifas AS T ON T.IdVigencia=V.IdVigencia
LEFT JOIN #ValidaSA AS SA ON SA.IdVigencia=V.IdVigencia
LEFT JOIN #Cache AS CA ON CA.IdVigencia=V.IdVigencia
CROSS APPLY
(
    VALUES
    (
        ISNULL(S.Solicitudes,0)+ISNULL(P1.Selecciones,0)
       +ISNULL(P2.Selecciones,0)+ISNULL(E1.Filas,0)
       +ISNULL(E2.Filas,0)+ISNULL(T.TarifasCosto,0)
       +ISNULL(SA.Filas,0)
    )
) AS W(FilasEstrategicas)
CROSS APPLY
(
    SELECT
      CASE
        WHEN ISNULL(S.Solicitudes,0)=0 THEN 5
        WHEN ISNULL(P2.Selecciones,0)=0 OR ISNULL(E2.Filas,0)=0 THEN 5
        WHEN W.FilasEstrategicas<=@LimiteIdeal THEN 1
        WHEN W.FilasEstrategicas<=@LimiteUtilizable THEN 2
        WHEN W.FilasEstrategicas<=@LimitePesada THEN 3
        ELSE 4
      END,
      CASE
        WHEN ISNULL(S.Solicitudes,0)=0 THEN 'SIN DATOS'
        WHEN ISNULL(P2.Selecciones,0)=0 OR ISNULL(E2.Filas,0)=0
          THEN 'INCOMPLETA PARA B3'
        WHEN W.FilasEstrategicas<=@LimiteIdeal THEN 'IDEAL PARA PILOTO'
        WHEN W.FilasEstrategicas<=@LimiteUtilizable THEN 'UTILIZABLE'
        WHEN W.FilasEstrategicas<=@LimitePesada THEN 'PESADA'
        ELSE 'MUY PESADA'
      END,
      CASE
        WHEN ISNULL(S.Solicitudes,0)=0
          THEN 'No usar: la vigencia no tiene solicitudes para esta empresa.'
        WHEN ISNULL(P2.Selecciones,0)=0 OR ISNULL(E2.Filas,0)=0
          THEN 'No usar para validar B3 completo: faltan selecciones o estado de cuenta B3.'
        WHEN W.FilasEstrategicas<=@LimiteIdeal
          THEN 'Primera opcion para ejecutar DIRECTO y despues CACHE.'
        WHEN W.FilasEstrategicas<=@LimiteUtilizable
          THEN 'Puede usarse; medir IO y tiempo antes de probar otra vigencia.'
        WHEN W.FilasEstrategicas<=@LimitePesada
          THEN 'Usar con precaucion y fuera de horario de carga.'
        ELSE 'No usar como primer piloto; elegir una vigencia mas pequena.'
      END
) AS C(Nivel,Clasificacion,Recomendacion);

/* 00. Datos generales de la empresa. */
SELECT N'EMPRESA' AS Resultado,
       E.EMidEmpresa AS IdEmpresa,
       E.EMNombre AS Empresa,
       E.EMidEstatus AS EstatusEmpresa,
       @IdConfiguracion AS IdConfiguracion,
       @EmpleadosActivos AS EmpleadosActivos,
       @PerfilesActivos AS PerfilesActivosNoAdministradores,
       (SELECT COUNT(*) FROM #Vigencias) AS VigenciasAnalizadas,
       @LimiteIdeal AS LimiteIdeal,
       @LimiteUtilizable AS LimiteUtilizable,
       @LimitePesada AS LimitePesada
FROM dbo.ff_Empresa AS E
WHERE E.EMidEmpresa=@IdEmpresa;

/* 01. Todas las vigencias analizadas y sus conteos. */
SELECT ROW_NUMBER() OVER
       (
           ORDER BY R.Nivel,
                    CASE WHEN R.EstadoCache='COMPLETA' THEN 0 ELSE 1 END,
                    R.FilasEstrategicas,
                    R.VigenciaInicio DESC
       ) AS OrdenSugerido,
       R.*,
       CASE WHEN R.EstadoCache='COMPLETA'
            THEN 'SI: se puede medir CACHE caliente'
            ELSE 'NO: la primera prueba CACHE tendra que construirlo'
       END AS DisponibilidadCache
FROM #Resumen AS R
ORDER BY OrdenSugerido;

/* 02. Recomendacion corta: hasta tres candidatos para el piloto. */
SELECT TOP (3)
       R.IdVigencia,R.FechaInicioConsulta,R.FechaFinConsulta,
       R.Clasificacion,R.FilasEstrategicas,R.Solicitudes,
       R.EmpleadosSolicitud,R.EdoCuentaB3,R.SeleccionesB3,
       R.EstadoCache,R.CacheId,R.Recomendacion
FROM #Resumen AS R
WHERE R.Nivel<=2
ORDER BY R.Nivel,
         CASE WHEN R.EstadoCache='COMPLETA' THEN 0 ELSE 1 END,
         R.FilasEstrategicas,
         R.VigenciaInicio DESC;

RAISERROR(N'[PERFIL B3] Diagnostico terminado.',0,1) WITH NOWAIT;
