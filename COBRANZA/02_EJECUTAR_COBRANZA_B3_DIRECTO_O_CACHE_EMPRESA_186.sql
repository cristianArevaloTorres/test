/*
   COBRANZA B3 REAL - EMPRESA 186 / VIGENCIA 4235

   OBJETIVO
   - Ejecutar exactamente una de las dos rutas de datos usadas por Java B3.
   - DIRECTO: dbo.ObtenCobranzaConcentrada_otro_V2_BF3
   - CACHE:   dbo.ReporteCobranzaConcentrada_BF3_Cache
   - Devolver todos sus resultsets y medir duracion, CPU y lecturas.
   - No cambia el parametro COBRANZA_CACHE; selecciona la ruta explicitamente.

   COMO EJECUTAR
   1. Dejar @Escenario='DIRECTO', ejecutar y guardar los resultsets.
   2. Cambiar a @Escenario='CACHE' y ejecutar.
   3. Ejecutar CACHE una segunda vez sin cambiar nada. Esa segunda corrida
      representa la lectura de cache caliente; la primera puede incluir la
      construccion del cache si la combinacion exacta aun no existia.

   MEDICION EN SSMS
   - La pestana Mensajes muestra SQL Server Execution Times y logical reads.
   - El ultimo resultset, MEDICION_B3, muestra la duracion total en ms/segundos.

   NOTA
   - Los perfiles, fechas y demas parametros son los mismos usados en la
     validacion Java para empresa 186 y vigencia 4235.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

DECLARE @Escenario varchar(10)='DIRECTO', -- DIRECTO o CACHE
        @IdEmpresa int=186,
        @IdVigencia int=4235,
        @IdSolTipo int=0,
        @FecIni varchar(16)='2026-05-22 00:00',
        @FecFin varchar(16)='2026-08-22 23:59',
        @IdVencida int=1,
        @Inicio datetime2(3),
        @Fin datetime2(3),
        @Procedimiento sysname,
        @ErrorNumero int=NULL,
        @ErrorProcedimiento sysname=NULL,
        @ErrorLinea int=NULL,
        @ErrorMensaje nvarchar(4000)=NULL;

SET @Escenario=UPPER(LTRIM(RTRIM(@Escenario)));

IF @Escenario NOT IN('DIRECTO','CACHE')
    THROW 53810,'Escenario invalido. Use DIRECTO o CACHE.',1;

SET @Procedimiento=CASE WHEN @Escenario='CACHE'
                        THEN N'dbo.ReporteCobranzaConcentrada_BF3_Cache'
                        ELSE N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3' END;

IF OBJECT_ID(@Procedimiento,N'P') IS NULL
    THROW 53811,'No existe el procedimiento requerido para el escenario B3.',1;

IF TYPE_ID(N'dbo.ListInt') IS NULL
    THROW 53812,'No existe el tipo de tabla dbo.ListInt requerido por B3.',1;

DECLARE @Perfiles dbo.ListInt;

INSERT @Perfiles(IdTipoNotificacionCorreo)
VALUES (678),(680),(683),(684),(685),(711),(712),(713),(714),(3085),(6218);

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
       CONVERT(decimal(18,3),DATEDIFF_BIG(millisecond,@Inicio,@Fin)/1000.0)
           AS DuracionSegundos,
       CASE WHEN @ErrorNumero IS NULL THEN N'OK' ELSE N'ERROR' END AS Estado,
       @ErrorNumero AS ErrorNumero,
       @ErrorProcedimiento AS ErrorProcedimiento,
       @ErrorLinea AS ErrorLinea,
       @ErrorMensaje AS ErrorMensaje;

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

