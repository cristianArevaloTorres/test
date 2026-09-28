/*
  EXPORTACION BF3 / DELOITTE PARA REPRODUCIR EN LOCALDB

  SOLO LECTURA:
    - No contiene INSERT, UPDATE, DELETE, MERGE ni DDL.
    - No consulta empleados, contrasenas ni cadenas SOAP.
    - Ejecutar en FlexiForbesv2 del ambiente donde SI existen las plantillas
      507 y 12062 para Deloitte.

  ENTREGA:
    Guardar cada result set como CSV conservando el numero de bloque.
*/

SET NOCOUNT ON;
SET LOCK_TIMEOUT 15000;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @IdEmpresaDeloitte INT;
DECLARE @ClaveEmpresaDeloitte VARCHAR(100);
DECLARE @IdOperacion INT;
DECLARE @PlantillaBF2 INT;
DECLARE @PlantillaBF3 INT;

SET @IdEmpresaDeloitte = 186;
SET @ClaveEmpresaDeloitte = 'S001';
SET @IdOperacion = 2;
SET @PlantillaBF2 = 507;
SET @PlantillaBF3 = 12062;

/* 00. Confirmar servidor y base de origen. */
SELECT
    '00_CONTEXTO' AS bloque,
    CONVERT(NVARCHAR(128), SERVERPROPERTY('ServerName')) AS servidor,
    DB_NAME() AS baseDatos,
    GETDATE() AS fechaConsulta,
    CONVERT(NVARCHAR(128), SERVERPROPERTY('ProductVersion')) AS versionSql;

/* 01. Empresa Deloitte, sin usuarios ni credenciales. */
SELECT
    '01_EMPRESA_DELOITTE' AS bloque,
    E.EMIdEmpresa,
    E.EMIdEmpresaFlexiForbes,
    E.EMNombre,
    E.EMIdEstatus
FROM dbo.ff_Empresa E
WHERE E.EMIdEmpresa = @IdEmpresaDeloitte
   OR CONVERT(VARCHAR(100), E.EMIdEmpresaFlexiForbes) = @ClaveEmpresaDeloitte
ORDER BY E.EMIdEmpresa;

/* 02. Filas completas de configuracion para Deloitte y operacion 2. */
SELECT
    '02_CONFIGURACION_DELOITTE_OP2' AS bloque,
    CE.*
FROM dbo.ff_CargaMasivaOperacionEmpresa CE
WHERE CE.CEIdEmpresa = @IdEmpresaDeloitte
  AND CE.CEIdOperacion = @IdOperacion
ORDER BY CE.CEIdEstatus DESC, CE.CEIdOperacionEmpresa;

/* 03. Resultado real que consume CargaMasivaProcess. */
EXEC dbo.ff_CCMOperacionPropiedades
    @IdOperacion = @IdOperacion,
    @IdEmpresa = @IdEmpresaDeloitte;

/* 04. Filas completas de ambas plantillas. */
SELECT
    '04_PLANTILLAS_507_12062' AS bloque,
    P.*
FROM dbo.ff_Plantilla P
WHERE P.PLIdPlantilla IN (@PlantillaBF2, @PlantillaBF3)
ORDER BY P.PLIdPlantilla;

/* 05. Configuracion completa, activa e inactiva, de la plantilla BF3. */
SELECT
    '05_CONFIGURACION_PLANTILLA_12062' AS bloque,
    CP.*
FROM dbo.ff_ConfiguracionPlantilla CP
WHERE CP.PLIdPlantilla = @PlantillaBF3
ORDER BY CP.CPIdConfiguracionPlantilla;

/* 06. Campos completos referenciados por la plantilla BF3. */
SELECT
    '06_CAMPOS_PLANTILLA_12062' AS bloque,
    C.*
FROM dbo.ff_Campo C
WHERE EXISTS
(
    SELECT 1
    FROM dbo.ff_ConfiguracionPlantilla CP
    WHERE CP.PLIdPlantilla = @PlantillaBF3
      AND CP.CAIdCampo = C.CAIdCampo
)
ORDER BY C.CAIdCampo;

/* 07. Salida exacta utilizada por Plantilla/CargaMasivaParser. */
EXEC dbo.ff_CPlantillaCampos
    @IdPlantilla = @PlantillaBF3;

/* 08. Catalogo exacto utilizado para convertir el sexo BF3. */
EXEC dbo.ff_CMCSexo_BF3;

/* 09. Perfil que estamos utilizando en las cadenas de prueba. */
SELECT
    '09_PERFIL_PRUEBA' AS bloque,
    P.PEIdPerfil,
    P.PEIdEmpresa,
    P.PENombre,
    P.PEIdEstatus
FROM dbo.ff_Perfil P
WHERE P.PEIdPerfil = 678
   OR (P.PEIdEmpresa = @IdEmpresaDeloitte AND P.PEIdEstatus = 1)
ORDER BY
    CASE WHEN P.PEIdPerfil = 678 THEN 0 ELSE 1 END,
    P.PEIdPerfil;

/* 10. Firma de los SP involucrados. */
SELECT
    '10_PARAMETROS_SP' AS bloque,
    S.name AS esquema,
    O.name AS objeto,
    P.parameter_id,
    P.name AS parametro,
    TYPE_NAME(P.user_type_id) AS tipoDato,
    P.max_length,
    P.precision,
    P.scale,
    P.is_output
FROM sys.objects O
INNER JOIN sys.schemas S
    ON S.schema_id = O.schema_id
LEFT JOIN sys.parameters P
    ON P.object_id = O.object_id
WHERE S.name = 'dbo'
  AND O.name IN
  (
      'ff_CCMOperacionPropiedades',
      'ff_CPlantillaCampos',
      'ff_CMCSexo_BF3',
      'ff_XCMTitularesAltaCMM_BF3',
      'ff_XCMTitularesAlta_Base_BF3'
  )
ORDER BY O.name, P.parameter_id;

/* 11. Definiciones para comparar origen contra LocalDB. */
SELECT
    '11_DEFINICIONES_OBJETOS' AS bloque,
    S.name AS esquema,
    O.name AS objeto,
    O.type_desc,
    OBJECT_DEFINITION(O.object_id) AS definicion
FROM sys.objects O
INNER JOIN sys.schemas S
    ON S.schema_id = O.schema_id
WHERE S.name = 'dbo'
  AND O.name IN
  (
      'ff_CCMOperacionPropiedades',
      'ff_CPlantillaCampos',
      'ff_CMCSexo_BF3',
      'ff_XCMTitularesAltaCMM_BF3',
      'ff_XCMTitularesAlta_Base_BF3'
  )
ORDER BY O.name;

/*
  12. Estructura de las tablas para generar INSERT idempotente y compatible.
  Se incluyen identidades, columnas calculadas, NULL y valores por defecto.
*/
SELECT
    '12_ESTRUCTURA_TABLAS' AS bloque,
    S.name AS esquema,
    T.name AS tabla,
    C.column_id,
    C.name AS columna,
    TYPE_NAME(C.user_type_id) AS tipoDato,
    C.max_length,
    C.precision,
    C.scale,
    C.is_nullable,
    C.is_identity,
    C.is_computed,
    DC.definition AS valorDefault
FROM sys.tables T
INNER JOIN sys.schemas S
    ON S.schema_id = T.schema_id
INNER JOIN sys.columns C
    ON C.object_id = T.object_id
LEFT JOIN sys.default_constraints DC
    ON DC.parent_object_id = C.object_id
   AND DC.parent_column_id = C.column_id
WHERE S.name = 'dbo'
  AND T.name IN
  (
      'ff_Plantilla',
      'ff_ConfiguracionPlantilla',
      'ff_Campo',
      'ff_CargaMasivaOperacionEmpresa'
  )
ORDER BY T.name, C.column_id;

/* 13. Dictamen rapido: deben aparecer 23 campos activos para BF3. */
SELECT
    '13_DICTAMEN' AS bloque,
    @IdEmpresaDeloitte AS empresaDeloitte,
    @PlantillaBF3 AS plantillaBF3,
    (
        SELECT COUNT(*)
        FROM dbo.ff_CargaMasivaOperacionEmpresa CE
        WHERE CE.CEIdEmpresa = @IdEmpresaDeloitte
          AND CE.CEIdOperacion = @IdOperacion
          AND CE.CEIdPlantilla = @PlantillaBF3
          AND CE.CEIdEstatus = 1
    ) AS configuracionesBF3Activas,
    (
        SELECT COUNT(*)
        FROM dbo.ff_ConfiguracionPlantilla CP
        INNER JOIN dbo.ff_Campo C
            ON C.CAIdCampo = CP.CAIdCampo
        WHERE CP.PLIdPlantilla = @PlantillaBF3
          AND CP.CPIdEstatus = 1
          AND C.CAIdEstatus = 1
    ) AS camposBF3Activos;

