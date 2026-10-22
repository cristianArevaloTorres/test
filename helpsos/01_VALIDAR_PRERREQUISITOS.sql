USE [FlexiForbesv2];
GO

SET NOCOUNT ON;
GO

/*
  Script de validación únicamente.
  No altera objetos ni datos.
*/

IF OBJECT_ID(N'dbo.bf_AltaConstanciaEmpleado', N'P') IS NULL
    THROW 51000, 'No existe dbo.bf_AltaConstanciaEmpleado.', 1;

IF OBJECT_ID(N'dbo.bf_ConstanciaEmpleado', N'U') IS NULL
    THROW 51000, 'No existe dbo.bf_ConstanciaEmpleado.', 1;

IF OBJECT_ID(N'dbo.ff_Empleado', N'U') IS NULL
    THROW 51000, 'No existe dbo.ff_Empleado.', 1;
GO

DECLARE @ParametrosEsperados TABLE
(
    Nombre sysname NOT NULL,
    Tipo sysname NOT NULL,
    Longitud smallint NOT NULL,
    EsSalida bit NOT NULL
);

INSERT INTO @ParametrosEsperados (Nombre, Tipo, Longitud, EsSalida)
VALUES
    (N'@IdEmpleado', N'int', 4, 0),
    (N'@IdAdministrador', N'int', 4, 0),
    (N'@LugarFechaEmision', N'varchar', 100, 0),
    (N'@FechaEmision', N'varchar', 10, 0),
    (N'@RFC', N'varchar', 20, 0),
    (N'@CURP', N'varchar', 30, 0),
    (N'@CodigoPostal', N'varchar', 10, 0),
    (N'@TipoVialidad', N'varchar', 100, 0),
    (N'@NombreVialidad', N'varchar', 200, 0),
    (N'@NoExterior', N'varchar', 10, 0),
    (N'@NoInterior', N'varchar', 10, 0),
    (N'@NombreColonia', N'varchar', 150, 0),
    (N'@NombreLocalidad', N'varchar', 150, 0),
    (N'@NombreEntidadFederativa', N'varchar', 150, 0),
    (N'@CorreoElectronico', N'varchar', 150, 0),
    (N'@Telefono', N'varchar', 20, 0),
    (N'@Regimen', N'varchar', -1, 0),
    (N'@NombreArchivo', N'varchar', 200, 1);

IF EXISTS
(
    SELECT Nombre, Tipo, Longitud, EsSalida
    FROM @ParametrosEsperados
    EXCEPT
    SELECT p.name, TYPE_NAME(p.user_type_id), p.max_length, p.is_output
    FROM sys.parameters AS p
    WHERE p.object_id = OBJECT_ID(N'dbo.bf_AltaConstanciaEmpleado')
)
    THROW 51000, 'La firma de dbo.bf_AltaConstanciaEmpleado no coincide con la esperada.', 1;

DECLARE @ColumnasConstancia TABLE (Nombre sysname NOT NULL);
INSERT INTO @ColumnasConstancia (Nombre)
VALUES
    (N'IdEmpleado'), (N'IdEmpresa'), (N'IdVigencia'),
    (N'LugarFechaEmision'), (N'FechaEmision'), (N'RFC'), (N'CURP'),
    (N'CodigoPostal'), (N'TipoVialidad'), (N'NombreVialidad'),
    (N'NoExterior'), (N'NoInterior'), (N'NombreColonia'),
    (N'NombreLocalidad'), (N'NombreEntidadFederativa'),
    (N'CorreoElectronico'), (N'Telefono'), (N'Regimen'), (N'RutaPDF');

IF EXISTS
(
    SELECT Nombre FROM @ColumnasConstancia
    EXCEPT
    SELECT c.name
    FROM sys.columns AS c
    WHERE c.object_id = OBJECT_ID(N'dbo.bf_ConstanciaEmpleado')
)
    THROW 51000, 'Faltan columnas requeridas en dbo.bf_ConstanciaEmpleado.', 1;

IF COL_LENGTH(N'dbo.ff_Empleado', N'EMrfc') IS NULL
    OR COL_LENGTH(N'dbo.ff_Empleado', N'EMcurp') IS NULL
    THROW 51000, 'ff_Empleado no contiene EMrfc y EMcurp.', 1;

SELECT
    N'OK' AS Resultado,
    N'La base cumple los prerrequisitos; no se requiere migración.' AS Mensaje;
GO
