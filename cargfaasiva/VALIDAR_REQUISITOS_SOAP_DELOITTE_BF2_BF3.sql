/*
  VALIDACION DE REQUISITOS SOAP DELOITTE BF2 / BF3

  SOLO LECTURA:
    - No modifica datos ni objetos persistentes.
    - No consulta empleados, usuarios, contrasenas ni cadenas SOAP.
    - Compatible con versiones antiguas de SQL Server.

  Resultado esperado para habilitar ambos formatos:
    - Una configuracion activa Deloitte/operacion 2/plantilla 507/SP BF2.
    - Una configuracion activa Deloitte/operacion 2/plantilla 12062/SP BF3.
    - 32 campos activos en plantilla 507.
    - 23 campos activos en plantilla 12062.
*/

SET NOCOUNT ON;
SET LOCK_TIMEOUT 15000;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @IdEmpresa INT;
DECLARE @IdOperacion INT;
DECLARE @PlantillaBF2 INT;
DECLARE @PlantillaBF3 INT;
DECLARE @SpBF2 VARCHAR(80);
DECLARE @SpBF3 VARCHAR(80);

SET @IdEmpresa = 186;
SET @IdOperacion = 2;
SET @PlantillaBF2 = 507;
SET @PlantillaBF3 = 12062;
SET @SpBF2 = 'ff_XCMTitularesAltaCMDeloitte';
SET @SpBF3 = 'ff_XCMTitularesAltaCMM_BF3';

SELECT
    '00_CONTEXTO' AS bloque,
    CONVERT(NVARCHAR(128), SERVERPROPERTY('ServerName')) AS servidor,
    DB_NAME() AS baseDatos,
    GETDATE() AS fechaValidacion;

/* 01. Resultado resumido por requisito. */
SELECT
    '01_REQUISITOS' AS bloque,
    R.orden,
    R.requisito,
    R.valorActual,
    R.valorEsperado,
    CASE WHEN R.valorActual = R.valorEsperado THEN 'OK' ELSE 'FALTA_O_DIFIERE' END AS resultado
FROM
(
    SELECT 1 AS orden, 'Empresa Deloitte 186 activa' AS requisito,
           CONVERT(VARCHAR(20), COUNT(*)) AS valorActual,
           '1' AS valorEsperado
    FROM dbo.ff_Empresa
    WHERE EMIdEmpresa = @IdEmpresa
      AND EMIdEstatus = 1

    UNION ALL

    SELECT 2, 'Operacion 2 activa', CONVERT(VARCHAR(20), COUNT(*)), '1'
    FROM dbo.ff_CargaMasivaOperacion
    WHERE COIdOperacion = @IdOperacion
      AND COIdEstatus = 1

    UNION ALL

    SELECT 3, 'Plantilla BF2 507 activa', CONVERT(VARCHAR(20), COUNT(*)), '1'
    FROM dbo.ff_Plantilla
    WHERE PLIdPlantilla = @PlantillaBF2
      AND PLIdEstatus = 1

    UNION ALL

    SELECT 4, 'Campos activos plantilla BF2 507', CONVERT(VARCHAR(20), COUNT(*)), '32'
    FROM dbo.ff_ConfiguracionPlantilla CP
    INNER JOIN dbo.ff_Campo C ON C.CAIdCampo = CP.CAIdCampo
    WHERE CP.PLIdPlantilla = @PlantillaBF2
      AND CP.CPIdEstatus = 1
      AND C.CAIdEstatus = 1

    UNION ALL

    SELECT 5, 'Plantilla BF3 12062 activa', CONVERT(VARCHAR(20), COUNT(*)), '1'
    FROM dbo.ff_Plantilla
    WHERE PLIdPlantilla = @PlantillaBF3
      AND PLIdEstatus = 1

    UNION ALL

    SELECT 6, 'Campos activos plantilla BF3 12062', CONVERT(VARCHAR(20), COUNT(*)), '23'
    FROM dbo.ff_ConfiguracionPlantilla CP
    INNER JOIN dbo.ff_Campo C ON C.CAIdCampo = CP.CAIdCampo
    WHERE CP.PLIdPlantilla = @PlantillaBF3
      AND CP.CPIdEstatus = 1
      AND C.CAIdEstatus = 1

    UNION ALL

    SELECT 7, 'Configuracion activa Deloitte BF2 exacta', CONVERT(VARCHAR(20), COUNT(*)), '1'
    FROM dbo.ff_CargaMasivaOperacionEmpresa CE
    WHERE CE.CEIdEmpresa = @IdEmpresa
      AND CE.CEIdOperacion = @IdOperacion
      AND CE.CEIdPlantilla = @PlantillaBF2
      AND LTRIM(RTRIM(CE.CEStoredProc)) = @SpBF2
      AND CE.CEIdEstatus = 1

    UNION ALL

    SELECT 8, 'Configuracion activa Deloitte BF3 exacta', CONVERT(VARCHAR(20), COUNT(*)), '1'
    FROM dbo.ff_CargaMasivaOperacionEmpresa CE
    WHERE CE.CEIdEmpresa = @IdEmpresa
      AND CE.CEIdOperacion = @IdOperacion
      AND CE.CEIdPlantilla = @PlantillaBF3
      AND LTRIM(RTRIM(CE.CEStoredProc)) = @SpBF3
      AND CE.CEIdEstatus = 1

    UNION ALL

    SELECT 9, 'Total configuraciones activas Deloitte operacion 2', CONVERT(VARCHAR(20), COUNT(*)), '2'
    FROM dbo.ff_CargaMasivaOperacionEmpresa CE
    WHERE CE.CEIdEmpresa = @IdEmpresa
      AND CE.CEIdOperacion = @IdOperacion
      AND CE.CEIdEstatus = 1

    UNION ALL

    SELECT 10, 'SP BF2 existente',
           CASE WHEN OBJECT_ID('dbo.' + @SpBF2, 'P') IS NULL THEN '0' ELSE '1' END,
           '1'

    UNION ALL

    SELECT 11, 'SP BF3 existente',
           CASE WHEN OBJECT_ID('dbo.' + @SpBF3, 'P') IS NULL THEN '0' ELSE '1' END,
           '1'

    UNION ALL

    SELECT 12, 'SP catalogo sexo BF3 existente',
           CASE WHEN OBJECT_ID('dbo.ff_CMCSexo_BF3', 'P') IS NULL THEN '0' ELSE '1' END,
           '1'

    UNION ALL

    SELECT 13, 'Perfil 678 activo y perteneciente a Deloitte', CONVERT(VARCHAR(20), COUNT(*)), '1'
    FROM dbo.ff_Perfil P
    WHERE P.PEIdPerfil = 678
      AND P.PEIdEmpresa = @IdEmpresa
      AND P.PEIdEstatus = 1
) R
ORDER BY R.orden;

/* 02. Configuraciones exactas que el servicio puede resolver actualmente. */
SELECT
    '02_CONFIGURACIONES_ACTUALES' AS bloque,
    CE.CEIdOperacionEmpresa,
    CE.CEIdEmpresa,
    CE.CEIdOperacion,
    CE.CEIdPlantilla,
    LTRIM(RTRIM(CE.CEStoredProc)) AS storedProcedure,
    CE.CEStoredProcAtributos,
    CE.CEIdEstatus,
    CE.CEFechaAdd,
    CE.CEFechaUMod
FROM dbo.ff_CargaMasivaOperacionEmpresa CE
WHERE CE.CEIdEmpresa = @IdEmpresa
  AND CE.CEIdOperacion = @IdOperacion
ORDER BY CE.CEIdEstatus DESC, CE.CEIdOperacionEmpresa;

/* 03. Lo que realmente devuelve el resolver utilizado por CargaMasivaProcess. */
EXEC dbo.ff_CCMOperacionPropiedades
    @IdOperacion = @IdOperacion,
    @IdEmpresa = @IdEmpresa;

/* 04. Orden y validaciones exactas de los 23 campos BF3, si existen. */
SELECT
    '04_CAMPOS_BF3' AS bloque,
    ROW_NUMBER() OVER (ORDER BY CP.CPIdConfiguracionPlantilla) AS posicion,
    CP.CPIdConfiguracionPlantilla,
    CP.CAIdCampo,
    LTRIM(RTRIM(C.CANombreCampo)) AS campo,
    C.CATipoDato,
    C.CALongitud,
    C.CATipoValor,
    C.CACaracteresValidos,
    CP.CPRangoValores,
    CP.CPRequerido,
    CP.CPEncriptado
FROM dbo.ff_ConfiguracionPlantilla CP
INNER JOIN dbo.ff_Campo C
    ON C.CAIdCampo = CP.CAIdCampo
WHERE CP.PLIdPlantilla = @PlantillaBF3
  AND CP.CPIdEstatus = 1
  AND C.CAIdEstatus = 1
ORDER BY CP.CPIdConfiguracionPlantilla;

/* 05. Catalogo permitido para la posicion 3. */
IF OBJECT_ID('dbo.ff_CMCSexo_BF3', 'P') IS NOT NULL
BEGIN
    EXEC dbo.ff_CMCSexo_BF3;
END;

/* 06. Dictamen final. */
SELECT
    '06_DICTAMEN_FINAL' AS bloque,
    CASE
        WHEN NOT EXISTS
        (
            SELECT 1 FROM dbo.ff_Plantilla
            WHERE PLIdPlantilla = @PlantillaBF3 AND PLIdEstatus = 1
        ) THEN 'FALTA_PLANTILLA_12062'
        WHEN
        (
            SELECT COUNT(*)
            FROM dbo.ff_ConfiguracionPlantilla CP
            INNER JOIN dbo.ff_Campo C ON C.CAIdCampo = CP.CAIdCampo
            WHERE CP.PLIdPlantilla = @PlantillaBF3
              AND CP.CPIdEstatus = 1
              AND C.CAIdEstatus = 1
        ) <> 23 THEN 'PLANTILLA_12062_NO_TIENE_23_CAMPOS_ACTIVOS'
        WHEN OBJECT_ID('dbo.ff_XCMTitularesAltaCMM_BF3', 'P') IS NULL
            THEN 'FALTA_SP_BF3'
        WHEN NOT EXISTS
        (
            SELECT 1
            FROM dbo.ff_CargaMasivaOperacionEmpresa CE
            WHERE CE.CEIdEmpresa = @IdEmpresa
              AND CE.CEIdOperacion = @IdOperacion
              AND CE.CEIdPlantilla = @PlantillaBF3
              AND LTRIM(RTRIM(CE.CEStoredProc)) = @SpBF3
              AND CE.CEIdEstatus = 1
        ) THEN 'FALTA_CONFIGURACION_ACTIVA_DELOITTE_BF3'
        WHEN
        (
            SELECT COUNT(*)
            FROM dbo.ff_CargaMasivaOperacionEmpresa CE
            WHERE CE.CEIdEmpresa = @IdEmpresa
              AND CE.CEIdOperacion = @IdOperacion
              AND CE.CEIdPlantilla = @PlantillaBF3
              AND LTRIM(RTRIM(CE.CEStoredProc)) = @SpBF3
              AND CE.CEIdEstatus = 1
        ) > 1 THEN 'CONFIGURACION_DELOITTE_BF3_DUPLICADA'
        ELSE 'LISTO_PARA_BF2_Y_BF3'
    END AS dictamen;

