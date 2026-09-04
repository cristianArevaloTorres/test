/*
    HOMOLOGACION FUNCIONAL COBRANZA B3 -> B2

    Objetivo:
      dbo.ObtenCobranzaConcentrada_otro_V2_BF3 debe devolver exactamente
      los mismos resultsets que dbo.ObtenCobranzaConcentrada.

    Se conserva la firma B3 para no cambiar consumidores ni el cache.
    @idVIgencia permanece por compatibilidad; B2 determina internamente el
    universo correspondiente, igual que la ejecucion considerada correcta.

    Regla de perfil:
      - Un solo perfil B3 se traduce al entero aceptado por B2.
      - Cero o varios perfiles equivalen a NULL (todos), que es la llamada B2
        usada como linea base del reporte de empresa 917.
*/

USE [FlexiForbesv2];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'dbo.ObtenCobranzaConcentrada',N'P') IS NULL
    THROW 55100, 'No existe dbo.ObtenCobranzaConcentrada (B2).', 1;
GO

CREATE OR ALTER PROCEDURE dbo.ObtenCobranzaConcentrada_otro_V2_BF3
    @idEmpresa  int = 0,
    @idSolTipo  int = 0,
    @FecIni     varchar(16) = '',
    @FecFin     varchar(16) = '',
    @idVencida  int = 0,
    @IdPerfil   dbo.ListInt READONLY,
    @idVIgencia int = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @IdPerfilB2 int = NULL,
            @CantidadPerfiles int;

    SELECT @CantidadPerfiles = COUNT(*),
           @IdPerfilB2 = CASE WHEN COUNT(*) = 1
                              THEN MIN(IdTipoNotificacionCorreo)
                              ELSE NULL END
    FROM @IdPerfil;

    BEGIN TRY
        INSERT dbo.bf_RepConf_Debug(etapa,detalle)
        VALUES
        (
            'cobranza_bf3_ruta_sql',
            CONCAT('ruta=B2_HOMOLOGADA; empresa=',@idEmpresa,
                   '; vigencia=',@idVIgencia,
                   '; perfiles=',@CantidadPerfiles,
                   '; perfilB2=',COALESCE(CONVERT(varchar(20),@IdPerfilB2),'NULL'),
                   '; cache=',COALESCE(
                       TRY_CONVERT(varchar(10),
                           SESSION_CONTEXT(N'bf_CobranzaCacheCapturar')),'0'))
        );
    END TRY
    BEGIN CATCH
        /* El log nunca debe impedir la generacion del reporte. */
    END CATCH;

    EXEC dbo.ObtenCobranzaConcentrada
         @idEmpresa = @idEmpresa,
         @idSolTipo = @idSolTipo,
         @FecIni = @FecIni,
         @FecFin = @FecFin,
         @idVencida = @idVencida,
         @IdPerfil = @IdPerfilB2;
END;
GO

/*
   La ruta CACHE tambien debe respetar exactamente el contrato B2.
   El mecanismo cache anterior agregaba una hoja Informacion y, al delegar
   B3 en B2, dejaba escapar los ocho resultsets de la construccion antes de
   devolver los almacenados (17 resultsets en total). Para la homologacion
   funcional se convierte en una ruta de compatibilidad que usa el mismo
   punto de entrada B3 ya homologado y no agrega ningun resultset.
*/
CREATE OR ALTER PROCEDURE dbo.ReporteCobranzaConcentrada_BF3_Cache
    @idEmpresa  int = 0,
    @idSolTipo  int = 0,
    @FecIni     varchar(16) = '',
    @FecFin     varchar(16) = '',
    @idVencida  int = 0,
    @IdPerfil   dbo.ListInt READONLY,
    @idVIgencia int = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        INSERT dbo.bf_RepConf_Debug(etapa,detalle)
        VALUES
        (
            'cobranza_bf3_cache_ruta_sql',
            CONCAT('ruta=B2_HOMOLOGADA_SIN_CACHE; empresa=',@idEmpresa,
                   '; vigencia=',@idVIgencia)
        );
    END TRY
    BEGIN CATCH
        /* El log nunca debe impedir la generacion del reporte. */
    END CATCH;

    EXEC dbo.ObtenCobranzaConcentrada_otro_V2_BF3
         @idEmpresa = @idEmpresa,
         @idSolTipo = @idSolTipo,
         @FecIni = @FecIni,
         @FecFin = @FecFin,
         @idVencida = @idVencida,
         @IdPerfil = @IdPerfil,
         @idVIgencia = @idVIgencia;
END;
GO

IF OBJECT_DEFINITION(
       OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3',N'P'))
   NOT LIKE N'%ruta=B2_HOMOLOGADA%'
    THROW 55101, 'No se instalo la ruta B3 homologada con B2.', 1;
GO

IF OBJECT_DEFINITION(
       OBJECT_ID(N'dbo.ReporteCobranzaConcentrada_BF3_Cache',N'P'))
   NOT LIKE N'%ruta=B2_HOMOLOGADA_SIN_CACHE%'
    THROW 55102, 'No se instalo la ruta CACHE homologada con B2.', 1;
GO

SELECT N'INSTALACION_OK' AS Resultado,
       DB_NAME() AS BaseDatos,
       N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3' AS Procedimiento,
       N'dbo.ObtenCobranzaConcentrada' AS DelegaEn,
       N'DIRECTO_Y_CACHE' AS RutasHomologadas,
       SYSDATETIME() AS FechaInstalacion;
GO
