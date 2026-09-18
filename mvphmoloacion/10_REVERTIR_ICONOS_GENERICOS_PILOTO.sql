/*
  REVERSION COMPLEMENTARIA DEL SCRIPT 07 - SOLO PILOTO

  Objetivo:
    - Quitar de las empresas hijas activas del corporativo piloto 495 únicamente
      las rutas genéricas que fueron colocadas por el script 07.
    - Dejar MRImagenMenu en NULL para que el menú se muestre sin esos PNG.

  Limitación importante:
    - El script 07 no persistió RutaAnterior; su bitácora sólo guarda la cantidad.
      Por eso esta reversión NO puede reconstruir los nombres anteriores.
    - Para no borrar iconos ajenos, sólo considera filas cuyo valor, usuario y
      fecha de modificación coinciden con la última ejecución exitosa del 07.

  SEGURIDAD:
    - Inicia en simulación.
    - Sólo opera sobre el corporativo 495.
    - No modifica roles, perfiles, menús, permisos, empresas ni archivos físicos.
*/
USE [FlexiForbesv2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Aplicar BIT = 0;              -- 0=simulación; 1=aplicar.
DECLARE @Confirmacion VARCHAR(80) = ''; -- Escribir: REVERTIR_ICONOS_GENERICOS_PILOTO
DECLARE @IdUsuario INT = NULL;          -- Administrador que registra la reversión.
DECLARE @IdCorporativoPiloto INT = 495;

IF OBJECT_ID('dbo.ff_Empresa','U') IS NULL
   OR OBJECT_ID('dbo.ff_Rol','U') IS NULL
   OR OBJECT_ID('dbo.ff_MenuRol2','U') IS NULL
   OR OBJECT_ID('dbo.bf_BitacoraEmpresa','U') IS NULL
    THROW 51000, 'Faltan objetos requeridos para revisar o revertir el script 07.', 1;

IF OBJECT_ID('tempdb..#ObjetivosPiloto') IS NOT NULL DROP TABLE #ObjetivosPiloto;
IF OBJECT_ID('tempdb..#UltimaEjecucion07') IS NOT NULL DROP TABLE #UltimaEjecucion07;
IF OBJECT_ID('tempdb..#IconosARevertir') IS NOT NULL DROP TABLE #IconosARevertir;

SELECT e.EMidEmpresa AS IdEmpresa,
       e.EMidCorporativo AS IdCorporativo,
       e.EMRazonSocial AS Empresa
INTO #ObjetivosPiloto
FROM dbo.ff_Empresa e
WHERE e.EMidCorporativo = @IdCorporativoPiloto
  AND e.EMidEmpresa <> e.EMidCorporativo
  AND e.EMidEstatus = 1;

IF NOT EXISTS (SELECT 1 FROM #ObjetivosPiloto)
    THROW 51000, 'No se encontraron empresas hijas activas para el corporativo piloto 495.', 1;

SELECT o.IdEmpresa,
       o.IdCorporativo,
       o.Empresa,
       b.BEIdUsuario AS UsuarioScript07,
       b.BEFechaCreacion AS FechaScript07,
       b.BECantidadElementos AS CantidadRegistrada07
INTO #UltimaEjecucion07
FROM #ObjetivosPiloto o
CROSS APPLY
(
    SELECT TOP (1)
           be.BEIdUsuario,
           be.BEFechaCreacion,
           be.BECantidadElementos
    FROM dbo.bf_BitacoraEmpresa be
    WHERE be.BEIdEmpresa = o.IdEmpresa
      AND be.BEAccion = 'REPARAR_ICONOS_GENERICOS_BF3'
      AND be.BEExitoso = 1
      AND be.BEDetalle LIKE '%alcance=PILOTO%'
    ORDER BY be.BEFechaCreacion DESC
) b;

/* La ruta debe coincidir exactamente con la fórmula usada por el script 07.
   Además, usuario y fecha deben corresponder a su última bitácora exitosa. */
SELECT u.IdEmpresa,
       u.IdCorporativo,
       u.Empresa,
       u.UsuarioScript07,
       u.FechaScript07,
       u.CantidadRegistrada07,
       r.ROIdRol,
       mr.MRidMenuRol,
       mr.MRidMenu,
       mr.MRImagenMenu AS RutaActual,
       mr.MRUsuarioUMod,
       mr.MRFechaUMod
INTO #IconosARevertir
FROM #UltimaEjecucion07 u
INNER JOIN dbo.ff_Rol r
    ON r.ROIdEmpresa = u.IdEmpresa
   AND r.ROIdEstatus = 1
INNER JOIN dbo.ff_MenuRol2 mr
    ON mr.MRidRol = r.ROIdRol
   AND mr.MRidEstatus = 1
WHERE mr.MRImagenMenu =
      '../../StilosDefault/img/shared/sidebar/'
      + RIGHT('0' + CONVERT(VARCHAR(2), ((ABS(CONVERT(BIGINT,mr.MRidMenu)) + 6) % 7) + 1), 2)
      + '.png'
  AND mr.MRUsuarioUMod = u.UsuarioScript07
  AND mr.MRFechaUMod >= DATEADD(MINUTE, -5, u.FechaScript07)
  AND mr.MRFechaUMod <= DATEADD(SECOND, 5, u.FechaScript07);

SELECT '01_EMPRESAS_PILOTO' AS Bloque,
       o.IdCorporativo,
       o.IdEmpresa,
       o.Empresa,
       u.UsuarioScript07,
       u.FechaScript07,
       u.CantidadRegistrada07,
       COUNT(i.MRidMenuRol) AS IconosIdentificadosParaRevertir,
       CASE
           WHEN u.IdEmpresa IS NULL THEN 'SIN_BITACORA_DEL_07_PILOTO'
           WHEN COUNT(i.MRidMenuRol) = 0 THEN 'SIN_RUTAS_ATRIBUIBLES_AL_07'
           WHEN COUNT(i.MRidMenuRol) = ISNULL(u.CantidadRegistrada07,0) THEN 'COINCIDENCIA_COMPLETA'
           ELSE 'COINCIDENCIA_PARCIAL_REVISAR'
       END AS Diagnostico
FROM #ObjetivosPiloto o
LEFT JOIN #UltimaEjecucion07 u ON u.IdEmpresa = o.IdEmpresa
LEFT JOIN #IconosARevertir i ON i.IdEmpresa = o.IdEmpresa
GROUP BY o.IdCorporativo,o.IdEmpresa,o.Empresa,
         u.IdEmpresa,u.UsuarioScript07,u.FechaScript07,u.CantidadRegistrada07
ORDER BY o.IdEmpresa;

SELECT '02_DETALLE_PREVIO' AS Bloque,
       IdCorporativo,IdEmpresa,Empresa,ROIdRol,MRidMenuRol,MRidMenu,
       RutaActual,MRUsuarioUMod,MRFechaUMod,
       CAST(NULL AS VARCHAR(100)) AS RutaDespues
FROM #IconosARevertir
ORDER BY IdEmpresa,ROIdRol,MRidMenu;

IF @Aplicar = 0
BEGIN
    PRINT 'SIMULACION: no se modifico informacion. Revise los bloques 01 y 02.';
    RETURN;
END;

IF @Confirmacion <> 'REVERTIR_ICONOS_GENERICOS_PILOTO'
    THROW 51000, 'La frase de confirmacion no coincide.', 1;

IF @IdUsuario IS NULL OR @IdUsuario <= 0
    THROW 51000, 'Debe capturar @IdUsuario.', 1;

IF NOT EXISTS (
    SELECT 1
    FROM dbo.ff_administrador
    WHERE ADIdAdministrador = @IdUsuario
      AND ADIdEstatus = 1
)
    THROW 51000, '@IdUsuario no corresponde a un administrador activo.', 1;

IF EXISTS (
    SELECT 1
    FROM #ObjetivosPiloto o
    LEFT JOIN #UltimaEjecucion07 u ON u.IdEmpresa = o.IdEmpresa
    WHERE u.IdEmpresa IS NULL
)
    THROW 51000, 'No existe bitacora exitosa del script 07 con alcance PILOTO para todos los objetivos.', 1;

IF EXISTS (
    SELECT 1
    FROM #UltimaEjecucion07 u
    LEFT JOIN #IconosARevertir i ON i.IdEmpresa = u.IdEmpresa
    GROUP BY u.IdEmpresa,u.CantidadRegistrada07
    HAVING COUNT(i.MRidMenuRol) <> ISNULL(u.CantidadRegistrada07,0)
)
    THROW 51000, 'La cantidad identificada no coincide con la bitacora del 07. No se aplico una reversion parcial.', 1;

IF NOT EXISTS (SELECT 1 FROM #IconosARevertir)
BEGIN
    PRINT 'SIN CAMBIOS: no quedan rutas genéricas atribuibles al script 07 en el piloto.';
    RETURN;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE mr
       SET mr.MRImagenMenu = NULL,
           mr.MRUsuarioUMod = @IdUsuario,
           mr.MRFechaUMod = GETDATE()
    FROM dbo.ff_MenuRol2 mr
    INNER JOIN #IconosARevertir i
        ON i.MRidMenuRol = mr.MRidMenuRol
       AND i.RutaActual = mr.MRImagenMenu;

    DECLARE @IconosRevertidos INT = @@ROWCOUNT;

    INSERT INTO dbo.bf_BitacoraEmpresa (
        BEIdEmpresa,BEIdUsuario,BEAccion,BEDetalle,BEElementoAfectado,
        BECantidadElementos,BEExitoso,BEFechaCreacion
    )
    SELECT i.IdEmpresa,@IdUsuario,'REVERTIR_ICONOS_GENERICOS_BF3',
           'Se limpiaron únicamente rutas atribuibles al script 07; alcance=PILOTO.',
           'ff_MenuRol2',COUNT(*),1,GETDATE()
    FROM #IconosARevertir i
    GROUP BY i.IdEmpresa;

    COMMIT TRANSACTION;

    SELECT '03_RESULTADO' AS Bloque,
           @IconosRevertidos AS IconosRevertidos,
           'OK' AS Resultado;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
