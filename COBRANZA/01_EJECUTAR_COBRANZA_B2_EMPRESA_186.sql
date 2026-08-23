/*
   COBRANZA B2 REAL - EMPRESA 186 / VIGENCIA 4235

   OBJETIVO
   - Ejecutar exactamente el procedimiento que invoca la aplicacion .NET B2.
   - Devolver todos sus resultsets y medir duracion, CPU y lecturas.
   - No modifica parametros, procedimientos, cache ni datos permanentes.

   IMPORTANTE
   - B2 recibe fechas varchar(10), por eso usa YYYY-MM-DD sin hora.
   - En la base local usada para la validacion, el B2 original puede terminar
     con error 512 por subconsultas escalares que encuentran mas de una fila.
     Si sucede, es el comportamiento real de B2 con estos datos; este script
     no lo corrige ni altera objetos para ocultar el problema.

   MEDICION EN SSMS
   - La pestana Mensajes muestra SQL Server Execution Times y logical reads.
   - El ultimo resultset, MEDICION_B2, muestra la duracion total en ms/segundos.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

DECLARE @IdEmpresa int=186,
        @IdVigencia int=4235, -- Solo identifica la prueba; el SP B2 no lo recibe.
        @IdSolTipo int=0,
        @FecIni varchar(10)='2026-05-22',
        @FecFin varchar(10)='2026-08-22',
        @IdVencida int=1,
        @IdPerfil int=NULL,
        @Inicio datetime2(3)=SYSDATETIME(),
        @Fin datetime2(3),
        @ErrorNumero int=NULL,
        @ErrorProcedimiento sysname=NULL,
        @ErrorLinea int=NULL,
        @ErrorMensaje nvarchar(4000)=NULL;

IF OBJECT_ID(N'dbo.ObtenCobranzaConcentrada',N'P') IS NULL
    THROW 53800,'No existe dbo.ObtenCobranzaConcentrada, requerido por B2.',1;

RAISERROR(
    N'[B2] Inicio. Empresa=%d Vigencia=%d Rango=%s a %s.',
    0,1,@IdEmpresa,@IdVigencia,@FecIni,@FecFin
) WITH NOWAIT;

BEGIN TRY
    EXEC dbo.ObtenCobranzaConcentrada
         @idEmpresa=@IdEmpresa,
         @idSolTipo=@IdSolTipo,
         @FecIni=@FecIni,
         @FecFin=@FecFin,
         @idVencida=@IdVencida,
         @IdPerfil=@IdPerfil;
END TRY
BEGIN CATCH
    SELECT @ErrorNumero=ERROR_NUMBER(),
           @ErrorProcedimiento=ERROR_PROCEDURE(),
           @ErrorLinea=ERROR_LINE(),
           @ErrorMensaje=ERROR_MESSAGE();
END CATCH;

SET @Fin=SYSDATETIME();

SELECT N'MEDICION_B2' AS __Resultado,
       N'dbo.ObtenCobranzaConcentrada' AS Procedimiento,
       @IdEmpresa AS IdEmpresa,
       @IdVigencia AS IdVigenciaReferencia,
       @IdSolTipo AS IdSolTipo,
       @FecIni AS FecIni,
       @FecFin AS FecFin,
       @IdVencida AS IdVencida,
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

