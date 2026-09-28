/*
  CONFIGURACION IDEMPOTENTE DE DELOITTE PARA BF3

  ALCANCE UNICO:
    Empresa    : 186 (Deloitte)
    Operacion  : 2
    Plantilla  : 12062
    SP          : dbo.ff_XCMTitularesAltaCMM_BF3

  SEGURIDAD:
    - Por defecto simula el cambio y ejecuta ROLLBACK.
    - No crea ni modifica la plantilla 12062.
    - Se detiene si la plantilla no tiene exactamente 23 campos activos.
    - Se detiene si no existe la configuracion BF2 historica esperada.
    - Se detiene si existe una configuracion BF3 diferente o inactiva que
      requiera revision manual.
    - No ejecutar antes de desplegar la DLL que selecciona BF2/BF3 por el
      numero de posiciones.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET LOCK_TIMEOUT 15000;

DECLARE @Aplicar BIT;
DECLARE @ConfirmoDllConSelector BIT;
DECLARE @IdEmpresa INT;
DECLARE @IdOperacion INT;
DECLARE @PlantillaBF2 INT;
DECLARE @PlantillaBF3 INT;
DECLARE @SpBF2 VARCHAR(80);
DECLARE @SpBF3 VARCHAR(80);
DECLARE @UsuarioAuditoria INT;

/*
  Mantener ambas variables en 0 para una simulacion con ROLLBACK.
  Cambiar ambas a 1 solamente durante la ventana controlada de despliegue.
*/
SET @Aplicar = 0;
SET @ConfirmoDllConSelector = 0;

SET @IdEmpresa = 186;
SET @IdOperacion = 2;
SET @PlantillaBF2 = 507;
SET @PlantillaBF3 = 12062;
SET @SpBF2 = 'ff_XCMTitularesAltaCMDeloitte';
SET @SpBF3 = 'ff_XCMTitularesAltaCMM_BF3';

IF DB_NAME() <> 'FlexiForbesv2'
BEGIN
    RAISERROR('Base incorrecta. Debe ejecutarse en FlexiForbesv2.', 16, 1);
    RETURN;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.ff_Empresa
    WHERE EMIdEmpresa = @IdEmpresa
      AND EMIdEstatus = 1
)
BEGIN
    RAISERROR('No existe Deloitte 186 activa.', 16, 1);
    RETURN;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.ff_CargaMasivaOperacion
    WHERE COIdOperacion = @IdOperacion
      AND COIdEstatus = 1
)
BEGIN
    RAISERROR('No existe la operacion 2 activa.', 16, 1);
    RETURN;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.ff_Plantilla
    WHERE PLIdPlantilla = @PlantillaBF3
      AND PLIdEstatus = 1
)
BEGIN
    RAISERROR('No existe la plantilla BF3 12062 activa. No se realizo ningun cambio.', 16, 1);
    RETURN;
END;

IF
(
    SELECT COUNT(*)
    FROM dbo.ff_ConfiguracionPlantilla CP
    INNER JOIN dbo.ff_Campo C ON C.CAIdCampo = CP.CAIdCampo
    WHERE CP.PLIdPlantilla = @PlantillaBF3
      AND CP.CPIdEstatus = 1
      AND C.CAIdEstatus = 1
) <> 23
BEGIN
    RAISERROR('La plantilla BF3 12062 no tiene exactamente 23 campos activos.', 16, 1);
    RETURN;
END;

IF OBJECT_ID('dbo.ff_XCMTitularesAltaCMM_BF3', 'P') IS NULL
BEGIN
    RAISERROR('No existe dbo.ff_XCMTitularesAltaCMM_BF3.', 16, 1);
    RETURN;
END;

IF OBJECT_ID('dbo.ff_CMCSexo_BF3', 'P') IS NULL
BEGIN
    RAISERROR('No existe dbo.ff_CMCSexo_BF3.', 16, 1);
    RETURN;
END;

IF
(
    SELECT COUNT(*)
    FROM dbo.ff_CargaMasivaOperacionEmpresa CE
    WHERE CE.CEIdEmpresa = @IdEmpresa
      AND CE.CEIdOperacion = @IdOperacion
      AND CE.CEIdPlantilla = @PlantillaBF2
      AND LTRIM(RTRIM(CE.CEStoredProc)) = @SpBF2
      AND CE.CEIdEstatus = 1
) <> 1
BEGIN
    RAISERROR('La configuracion BF2 historica de Deloitte no es unica o no existe.', 16, 1);
    RETURN;
END;

IF EXISTS
(
    SELECT 1
    FROM dbo.ff_CargaMasivaOperacionEmpresa CE
    WHERE CE.CEIdEmpresa = @IdEmpresa
      AND CE.CEIdOperacion = @IdOperacion
      AND CE.CEIdPlantilla = @PlantillaBF3
      AND LTRIM(RTRIM(CE.CEStoredProc)) = @SpBF3
      AND CE.CEIdEstatus = 1
)
BEGIN
    SELECT
        'YA_CONFIGURADO' AS resultado,
        CE.CEIdOperacionEmpresa,
        CE.CEIdEmpresa,
        CE.CEIdOperacion,
        CE.CEIdPlantilla,
        LTRIM(RTRIM(CE.CEStoredProc)) AS storedProcedure,
        CE.CEIdEstatus
    FROM dbo.ff_CargaMasivaOperacionEmpresa CE
    WHERE CE.CEIdEmpresa = @IdEmpresa
      AND CE.CEIdOperacion = @IdOperacion
      AND CE.CEIdPlantilla = @PlantillaBF3
      AND LTRIM(RTRIM(CE.CEStoredProc)) = @SpBF3
      AND CE.CEIdEstatus = 1;

    RETURN;
END;

/* Cualquier antecedente BF3 se revisa manualmente para no duplicarlo. */
IF EXISTS
(
    SELECT 1
    FROM dbo.ff_CargaMasivaOperacionEmpresa CE
    WHERE CE.CEIdEmpresa = @IdEmpresa
      AND CE.CEIdOperacion = @IdOperacion
      AND
      (
          CE.CEIdPlantilla = @PlantillaBF3
          OR LTRIM(RTRIM(CE.CEStoredProc)) = @SpBF3
      )
)
BEGIN
    SELECT
        'REQUIERE_REVISION_MANUAL' AS resultado,
        CE.CEIdOperacionEmpresa,
        CE.CEIdEmpresa,
        CE.CEIdOperacion,
        CE.CEIdPlantilla,
        LTRIM(RTRIM(CE.CEStoredProc)) AS storedProcedure,
        CE.CEIdEstatus,
        CE.CEFechaAdd,
        CE.CEFechaUMod
    FROM dbo.ff_CargaMasivaOperacionEmpresa CE
    WHERE CE.CEIdEmpresa = @IdEmpresa
      AND CE.CEIdOperacion = @IdOperacion
      AND
      (
          CE.CEIdPlantilla = @PlantillaBF3
          OR LTRIM(RTRIM(CE.CEStoredProc)) = @SpBF3
      );

    RAISERROR('Existe un antecedente BF3. No se realizo ningun cambio.', 16, 1);
    RETURN;
END;

SELECT TOP (1)
    @UsuarioAuditoria = ISNULL(CE.CEUsuarioUMod, CE.CEUsuarioAdd)
FROM dbo.ff_CargaMasivaOperacionEmpresa CE
WHERE CE.CEIdEmpresa = @IdEmpresa
  AND CE.CEIdOperacion = @IdOperacion
  AND CE.CEIdPlantilla = @PlantillaBF2
  AND LTRIM(RTRIM(CE.CEStoredProc)) = @SpBF2
  AND CE.CEIdEstatus = 1
ORDER BY CE.CEIdOperacionEmpresa;

IF @UsuarioAuditoria IS NULL
BEGIN
    RAISERROR('No fue posible determinar el usuario de auditoria.', 16, 1);
    RETURN;
END;

BEGIN TRANSACTION;

INSERT INTO dbo.ff_CargaMasivaOperacionEmpresa
(
    CEIdOperacion,
    CEIdEmpresa,
    CEIdPlantilla,
    CEStoredProc,
    CEStoredProcAtributos,
    CEIdEstatus,
    CEUsuarioAdd,
    CEFechaAdd,
    CEUsuarioUMod,
    CEFechaUMod,
    CEUsuarioDel,
    CEFechaDel
)
VALUES
(
    @IdOperacion,
    @IdEmpresa,
    @PlantillaBF3,
    @SpBF3,
    3,
    1,
    @UsuarioAuditoria,
    GETDATE(),
    @UsuarioAuditoria,
    GETDATE(),
    NULL,
    NULL
);

SELECT
    CASE
        WHEN @Aplicar = 1 AND @ConfirmoDllConSelector = 1
            THEN 'CONFIGURACION_LISTA_PARA_COMMIT'
        ELSE 'SIMULACION_LISTA_PARA_ROLLBACK'
    END AS resultado,
    CE.CEIdOperacionEmpresa,
    CE.CEIdEmpresa,
    CE.CEIdOperacion,
    CE.CEIdPlantilla,
    LTRIM(RTRIM(CE.CEStoredProc)) AS storedProcedure,
    CE.CEStoredProcAtributos,
    CE.CEIdEstatus
FROM dbo.ff_CargaMasivaOperacionEmpresa CE
WHERE CE.CEIdEmpresa = @IdEmpresa
  AND CE.CEIdOperacion = @IdOperacion
ORDER BY CE.CEIdOperacionEmpresa;

IF @Aplicar = 1 AND @ConfirmoDllConSelector = 1
BEGIN
    COMMIT TRANSACTION;
    SELECT 'COMMIT_REALIZADO' AS resultado;
END
ELSE
BEGIN
    ROLLBACK TRANSACTION;
    SELECT 'ROLLBACK_REALIZADO_SIN_CAMBIOS' AS resultado;
END;

