/*
    Configura el orden de campos de la plantilla 12062.

    IMPORTANTE:
    - Ejecutar primero en QA.
    - Cambiar @Usuario por el identificador del usuario que aplica el cambio.
    - El script desactiva en la plantilla 12062 los campos que no aparecen
      en @ConfiguracionDeseada.
    - No modifica las definiciones globales de ff_Campo; las valida y aborta
      si no coinciden con la configuracion solicitada.
    - ff_CPlantillaCampos actualmente ordena por CPIdConfiguracionPlantilla.
      El script lo ajusta para ordenar por CPOrden solamente en la plantilla
      12062 y conserva el comportamiento anterior para las demas plantillas.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @IdPlantilla INT = 12062;
DECLARE @Usuario INT = 5; -- TODO: sustituir por el usuario que aplica el cambio.

DECLARE @ConfiguracionDeseada TABLE
(
    IdCampo        INT          NOT NULL PRIMARY KEY,
    CANombreCampo  VARCHAR(100) NOT NULL,
    CPEtiqueta     VARCHAR(50)  NOT NULL,
    CPOrden        INT          NOT NULL UNIQUE,
    CALongitud     VARCHAR(100) NOT NULL,
    CATipoDato     CHAR(1)      NOT NULL,
    CPRequerido    CHAR(1)      NOT NULL
);

INSERT INTO @ConfiguracionDeseada
(
    IdCampo,
    CANombreCampo,
    CPEtiqueta,
    CPOrden,
    CALongitud,
    CATipoDato,
    CPRequerido
)
VALUES
    ( 82, 'EMIdEmpresa',                'Empresa',                   1, '10',  'E', '1'),
    ( 88, 'EMNumeroEmpleado',           'Numero de Empleado',        2, '20',  'T', '1'),
    ( 89, 'EMCertificado',              'Certificado',               3, '20',  'T', '1'),
    ( 90, 'EMApellidoPaterno',          'Apellido Paterno',          4, '30',  'T', '1'),
    ( 91, 'EMApellidoMaterno',          'Apellido Materno',          5, '30',  'T', '0'),
    ( 92, 'EMNombre1',                  'Primer Nombre',             6, '70',  'T', '1'),
    ( 93, 'EMNombre2',                  'Segundo Nombre',            7, '30',  'T', '0'),
    ( 83, 'EMIdPerfil',                 'Perfil',                    8, '10',  'E', '1'),
    ( 84, 'EMIdSexo',                   'Sexo',                      9, '10',  'E', '1'),
    ( 94, 'EMFechaNacimiento',          'Fecha de Nacimiento',      10, '23',  'D', '1'),
    ( 95, 'EMFechaIngresoEmpresa',      'Fecha de Ingreso',         11, '23',  'D', '1'),
    (183, 'EMFechaAlta',                'Fecha de Alta',            12, '23',  'D', '1'),
    (171, 'EMFechaAntiguedadGMM',       'FechaAntiguedadGMM',       13, '23',  'D', '0'),
    ( 99, 'EMOficina',                  'Oficina',                  14, '10',  'E', '0'),
    (101, 'EMcurp',                     'CURP',                     15, '50',  'T', '0'),
    (100, 'EMrfc',                      'RFC',                      16, '20',  'T', '0'),
    (107, 'EMSalarioBase',              'Salario Base',             17, '19',  'M', '1'),
    (121, 'EMBeneficioMaximoM',         'Beneficio Maximo Mensual', 25, '19',  'M', '0'),
    (131, 'EMidCentroCostos',           'Centro de Costos',         26, '10',  'E', '0'),
    ( 98, 'EMArea',                     'Area',                     27, '10',  'E', '0'),
    ( 97, 'EMPuesto',                   'Puesto',                   28, '100', 'T', '0'),
    (125, 'EMCorreoElectronico',        'Correo electronico',       29, '500', 'T', '0');

/* Mostrar diferencias de catalogo antes de modificar datos. */
SELECT
    d.IdCampo,
    d.CANombreCampo AS NombreEsperado,
    RTRIM(c.CANombreCampo) AS NombreActual,
    d.CALongitud AS LongitudEsperada,
    LTRIM(RTRIM(c.CALongitud)) AS LongitudActual,
    d.CATipoDato AS TipoEsperado,
    c.CATipoDato AS TipoActual
FROM @ConfiguracionDeseada d
LEFT JOIN dbo.ff_Campo c
    ON c.CAIdCampo = d.IdCampo
WHERE c.CAIdCampo IS NULL
   OR RTRIM(c.CANombreCampo) <> d.CANombreCampo
   OR LTRIM(RTRIM(c.CALongitud)) <> d.CALongitud
   OR c.CATipoDato <> d.CATipoDato;

IF EXISTS
(
    SELECT 1
    FROM @ConfiguracionDeseada d
    LEFT JOIN dbo.ff_Campo c
        ON c.CAIdCampo = d.IdCampo
    WHERE c.CAIdCampo IS NULL
       OR RTRIM(c.CANombreCampo) <> d.CANombreCampo
       OR LTRIM(RTRIM(c.CALongitud)) <> d.CALongitud
       OR c.CATipoDato <> d.CATipoDato
)
BEGIN
    THROW 50001,
          'Los IdCampo, nombres, longitudes o tipos no coinciden con ff_Campo. No se aplicaron cambios.',
          1;
END;

/* Todos los campos solicitados deben existir ya en la plantilla. */
SELECT
    d.IdCampo,
    d.CANombreCampo AS CampoFaltante
FROM @ConfiguracionDeseada d
LEFT JOIN dbo.ff_ConfiguracionPlantilla cp
    ON cp.PLIdPlantilla = @IdPlantilla
   AND cp.CAIdCampo = d.IdCampo
WHERE cp.CPIdConfiguracionPlantilla IS NULL;

IF EXISTS
(
    SELECT 1
    FROM @ConfiguracionDeseada d
    LEFT JOIN dbo.ff_ConfiguracionPlantilla cp
        ON cp.PLIdPlantilla = @IdPlantilla
       AND cp.CAIdCampo = d.IdCampo
    WHERE cp.CPIdConfiguracionPlantilla IS NULL
)
BEGIN
    THROW 50002,
          'Hay campos solicitados que no existen en la plantilla 12062. No se aplicaron cambios.',
          1;
END;

/* Confirmar que el catalogo de sexo conserva los valores requeridos. */
CREATE TABLE #SexoBF3
(
    Clave VARCHAR(100),
    Valor INT
);

INSERT INTO #SexoBF3 (Clave, Valor)
EXEC dbo.ff_CMCSexo_BF3;

IF NOT EXISTS (SELECT 1 FROM #SexoBF3 WHERE UPPER(Clave) = 'MASCULINO')
   OR NOT EXISTS (SELECT 1 FROM #SexoBF3 WHERE UPPER(Clave) = 'FEMENINO')
BEGIN
    THROW 50003,
          'ff_CMCSexo_BF3 no contiene MASCULINO y FEMENINO. No se aplicaron cambios.',
          1;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    /* Respaldos persistentes previos al cambio. */
    IF OBJECT_ID(N'dbo.BAK_ff_ConfiguracionPlantilla_12062_20261027', N'U') IS NOT NULL
    BEGIN
        THROW 50004,
              'Ya existe el respaldo BAK_ff_ConfiguracionPlantilla_12062_20261027. Revise antes de continuar.',
              1;
    END;

    SELECT
        SYSDATETIME() AS FechaRespaldo,
        cp.*
    INTO dbo.BAK_ff_ConfiguracionPlantilla_12062_20261027
    FROM dbo.ff_ConfiguracionPlantilla cp
    WHERE cp.PLIdPlantilla = @IdPlantilla;

    IF OBJECT_ID(N'dbo.BAK_ff_CPlantillaCampos_20261027', N'U') IS NOT NULL
    BEGIN
        THROW 50005,
              'Ya existe el respaldo BAK_ff_CPlantillaCampos_20261027. Revise antes de continuar.',
              1;
    END;

    SELECT
        SYSDATETIME() AS FechaRespaldo,
        OBJECT_DEFINITION(OBJECT_ID(N'dbo.ff_CPlantillaCampos')) AS Definicion
    INTO dbo.BAK_ff_CPlantillaCampos_20261027;

    /* Activar y configurar los campos solicitados. */
    UPDATE cp
       SET cp.CPEtiqueta    = d.CPEtiqueta,
           cp.CPOrden       = d.CPOrden,
           cp.CPRequerido   = d.CPRequerido,
           cp.CPHabilitado  = 1,
           cp.CPVisible     = 1,
           cp.CPRangoValores = CASE
                                   WHEN d.CANombreCampo = 'EMIdSexo'
                                       THEN 'ff_CMCSexo_BF3:'
                                   ELSE cp.CPRangoValores
                               END,
           cp.CPIdEstatus   = 1,
           cp.CPFechaEstatus = GETDATE(),
           cp.CPUsuarioUMod = @Usuario,
           cp.CPFechaUMod   = GETDATE(),
           cp.CPUsuarioDel  = NULL,
           cp.CPFechaDel    = NULL
    FROM dbo.ff_ConfiguracionPlantilla cp
    INNER JOIN @ConfiguracionDeseada d
        ON d.IdCampo = cp.CAIdCampo
    WHERE cp.PLIdPlantilla = @IdPlantilla;

    /* Desactivar los campos que no forman parte del nuevo layout. */
    UPDATE cp
       SET cp.CPIdEstatus   = 2,
           cp.CPFechaEstatus = GETDATE(),
           cp.CPUsuarioUMod = @Usuario,
           cp.CPFechaUMod   = GETDATE(),
           cp.CPUsuarioDel  = @Usuario,
           cp.CPFechaDel    = GETDATE()
    FROM dbo.ff_ConfiguracionPlantilla cp
    WHERE cp.PLIdPlantilla = @IdPlantilla
      AND NOT EXISTS
          (
              SELECT 1
              FROM @ConfiguracionDeseada d
              WHERE d.IdCampo = cp.CAIdCampo
          );

    /*
       El servicio consume ff_CPlantillaCampos y actualmente este SP ignora
       CPOrden. Se cambia el orden solo para la plantilla 12062.
    */
    EXEC sys.sp_executesql N'
ALTER PROCEDURE dbo.ff_CPlantillaCampos
(
    @IdPlantilla INT
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        cp.CPIdConfiguracionPlantilla,
        CANombreCampo = RTRIM(c.CANombreCampo),
        c.CADescripcionCampo,
        c.CATabla,
        c.CATipoDato,
        c.CALongitud,
        c.CATipoValor,
        c.CACaracteresValidos,
        cp.CPRangoValores,
        cp.CPRequerido,
        cp.CPEncriptado
    FROM dbo.ff_ConfiguracionPlantilla cp
    INNER JOIN dbo.ff_Campo c
        ON cp.CAIdCampo = c.CAIdCampo
    WHERE cp.PLIdPlantilla = @IdPlantilla
      AND cp.CPIdEstatus = 1
      AND c.CAIdEstatus = 1
    ORDER BY
        CASE
            WHEN @IdPlantilla = 12062
                THEN ISNULL(cp.CPOrden, cp.CPIdConfiguracionPlantilla)
            ELSE cp.CPIdConfiguracionPlantilla
        END,
        cp.CPIdConfiguracionPlantilla;
END;';

    /* Validaciones previas al COMMIT. */
    IF (SELECT COUNT(*)
        FROM dbo.ff_ConfiguracionPlantilla cp
        INNER JOIN dbo.ff_Campo c ON c.CAIdCampo = cp.CAIdCampo
        WHERE cp.PLIdPlantilla = @IdPlantilla
          AND cp.CPIdEstatus = 1
          AND c.CAIdEstatus = 1) <> 22
    BEGIN
        THROW 50006,
              'La plantilla no quedo con los 22 campos activos esperados.',
              1;
    END;

    IF EXISTS
    (
        SELECT cp.CPOrden
        FROM dbo.ff_ConfiguracionPlantilla cp
        WHERE cp.PLIdPlantilla = @IdPlantilla
          AND cp.CPIdEstatus = 1
        GROUP BY cp.CPOrden
        HAVING COUNT(*) > 1
    )
    BEGIN
        THROW 50007,
              'La plantilla contiene valores CPOrden duplicados.',
              1;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;

/* ================================================================
   RESULTADOS DE VERIFICACION
   ================================================================ */

SELECT
    cp.CAIdCampo AS IdCampo,
    RTRIM(c.CANombreCampo) AS CANombreCampo,
    RTRIM(cp.CPEtiqueta) AS CPEtiqueta,
    cp.CPOrden,
    LTRIM(RTRIM(c.CALongitud)) AS CALongitud,
    c.CATipoDato,
    cp.CPRequerido,
    cp.CPRangoValores,
    cp.CPIdEstatus
FROM dbo.ff_ConfiguracionPlantilla cp
INNER JOIN dbo.ff_Campo c
    ON c.CAIdCampo = cp.CAIdCampo
WHERE cp.PLIdPlantilla = @IdPlantilla
  AND cp.CPIdEstatus = 1
ORDER BY cp.CPOrden;

/* Este es exactamente el orden que recibira el servicio. */
EXEC dbo.ff_CPlantillaCampos @IdPlantilla = 12062;

/* Debe devolver MASCULINO y FEMENINO. */
EXEC dbo.ff_CMCSexo_BF3;

