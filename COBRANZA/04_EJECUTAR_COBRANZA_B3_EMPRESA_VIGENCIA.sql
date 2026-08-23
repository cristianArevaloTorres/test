/*
   EJECUCION GENERICA DE COBRANZA B3 POR EMPRESA/VIGENCIA

   PASOS
   1. Ejecutar primero 03_SELECCIONAR_EMPRESA_VIGENCIA_PILOTO_B3.sql.
   2. Copiar aqui el IdEmpresa y el IdVigencia recomendados.
   3. Ejecutar DIRECTO.
   4. Ejecutar CACHE dos veces: construccion/primera lectura y cache caliente.

   El query obtiene automaticamente:
   - Configuracion de la empresa.
   - Fechas de consulta de la vigencia.
   - Perfiles activos no administradores de la empresa.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

DECLARE @Escenario varchar(10)='DIRECTO', -- DIRECTO o CACHE
        @IdEmpresa int=186,
        @IdVigencia int=4235,
        @IdSolTipo int=0,
        @IdVencida int=1,
        @IdConfiguracion int,
        @FecIni varchar(16),
        @FecFin varchar(16),
        @Inicio datetime2(3),
        @Fin datetime2(3),
        @Procedimiento sysname,
        @ErrorNumero int=NULL,
        @ErrorProcedimiento sysname=NULL,
        @ErrorLinea int=NULL,
        @ErrorMensaje nvarchar(4000)=NULL;

SET @Escenario=UPPER(LTRIM(RTRIM(@Escenario)));

IF @Escenario NOT IN('DIRECTO','CACHE')
    THROW 53910,'Escenario invalido. Use DIRECTO o CACHE.',1;

IF @IdVencida<>1
    THROW 53911,'Esta prueba fue preparada para IdVencida=1.',1;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.ff_Empresa
    WHERE EMidEmpresa=@IdEmpresa
)
    THROW 53912,'La empresa solicitada no existe.',1;

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
    THROW 53913,'La vigencia no pertenece a la configuracion B3 de la empresa.',1;

SET @Procedimiento=CASE WHEN @Escenario='CACHE'
                        THEN N'dbo.ReporteCobranzaConcentrada_BF3_Cache'
                        ELSE N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3' END;

IF OBJECT_ID(@Procedimiento,N'P') IS NULL
    THROW 53914,'No existe el procedimiento requerido para el escenario.',1;

IF TYPE_ID(N'dbo.ListInt') IS NULL
    THROW 53915,'No existe el tipo dbo.ListInt requerido por B3.',1;

DECLARE @Perfiles dbo.ListInt;

INSERT @Perfiles(IdTipoNotificacionCorreo)
SELECT DISTINCT P.PEIdPerfil
FROM dbo.ff_Perfil AS P WITH(NOLOCK)
WHERE P.PEIdEmpresa=@IdEmpresa
  AND P.PEIdEstatus=1
  AND P.PEAdministrador=0;

IF NOT EXISTS(SELECT 1 FROM @Perfiles)
    THROW 53916,'La empresa no tiene perfiles activos no administradores.',1;

SELECT N'PARAMETROS_EJECUCION_B3' AS __Resultado,
       @Escenario AS Escenario,
       @Procedimiento AS Procedimiento,
       E.EMidEmpresa AS IdEmpresa,
       E.EMNombre AS Empresa,
       @IdConfiguracion AS IdConfiguracion,
       @IdVigencia AS IdVigencia,
       @FecIni AS FecIni,
       @FecFin AS FecFin,
       @IdVencida AS IdVencida,
       (SELECT COUNT(*) FROM @Perfiles) AS CantidadPerfiles
FROM dbo.ff_Empresa AS E
WHERE E.EMidEmpresa=@IdEmpresa;

SET @Inicio=SYSDATETIME();

RAISERROR(
    N'[B3 %s] Inicio. Empresa=%d Vigencia=%d Rango=%s a %s.',
    0,1,@Escenario,@IdEmpresa,@IdVigencia,@FecIni,@FecFin
) WITH NOWAIT;

BEGIN TRY
    IF @Escenario='DIRECTO'
    BEGIN
        EXEC dbo.ObtenCobranzaConcentrada_otro_V2_BF3
             @idEmpresa=@IdEmpresa,
             @idSolTipo=@IdSolTipo,
             @FecIni=@FecIni,
             @FecFin=@FecFin,
             @idVencida=@IdVencida,
             @IdPerfil=@Perfiles,
             @idVIgencia=@IdVigencia;
    END
    ELSE
    BEGIN
        EXEC dbo.ReporteCobranzaConcentrada_BF3_Cache
             @idEmpresa=@IdEmpresa,
             @idSolTipo=@IdSolTipo,
             @FecIni=@FecIni,
             @FecFin=@FecFin,
             @idVencida=@IdVencida,
             @IdPerfil=@Perfiles,
             @idVIgencia=@IdVigencia;
    END;
END TRY
BEGIN CATCH
    SELECT @ErrorNumero=ERROR_NUMBER(),
           @ErrorProcedimiento=ERROR_PROCEDURE(),
           @ErrorLinea=ERROR_LINE(),
           @ErrorMensaje=ERROR_MESSAGE();
END CATCH;

SET @Fin=SYSDATETIME();

SELECT N'MEDICION_B3' AS __Resultado,
       @Escenario AS Escenario,
       @Procedimiento AS Procedimiento,
       @IdEmpresa AS IdEmpresa,
       @IdVigencia AS IdVigencia,
       @IdSolTipo AS IdSolTipo,
       @FecIni AS FecIni,
       @FecFin AS FecFin,
       @IdVencida AS IdVencida,
       (SELECT COUNT(*) FROM @Perfiles) AS CantidadPerfiles,
       @Inicio AS FechaInicio,
       @Fin AS FechaFin,
       DATEDIFF_BIG(millisecond,@Inicio,@Fin) AS DuracionMilisegundos,
       CONVERT(decimal(18,3),
               DATEDIFF_BIG(millisecond,@Inicio,@Fin)/1000.0)
           AS DuracionSegundos,
       CASE WHEN @ErrorNumero IS NULL THEN N'OK' ELSE N'ERROR' END AS Estado,
       @ErrorNumero AS ErrorNumero,
       @ErrorProcedimiento AS ErrorProcedimiento,
       @ErrorLinea AS ErrorLinea,
       @ErrorMensaje AS ErrorMensaje;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
