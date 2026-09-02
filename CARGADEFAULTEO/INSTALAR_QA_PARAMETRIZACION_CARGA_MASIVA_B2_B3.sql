/*
  CORRECCION QA - PARAMETRIZACION DE CARGA MASIVA B2/B3

  Instala exclusivamente los cuatro objetos que el diagnostico reporto como
  faltantes. Es idempotente: puede ejecutarse varias veces.

  No modifica objetos ni datos de Defaulteo.
  No requiere insertar una configuracion inicial por empresa: si no existe una
  fila, el flujo devuelve Pantalla=B3 y Automatico=B2 como valores por defecto.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.bf_ConfiguracionFlujoCargaMasiva', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.bf_ConfiguracionFlujoCargaMasiva
    (
        CFIdEmpresa          INT      NOT NULL,
        CFFlujoPantalla      CHAR(2)  NOT NULL,
        CFFlujoAutomatico    CHAR(2)  NOT NULL,
        CFIdEstatus          INT      NOT NULL
            CONSTRAINT DF_bf_CargaFlujo_Estatus DEFAULT (1),
        CFUsuarioAdd         INT      NOT NULL,
        CFFechaAdd           DATETIME NOT NULL
            CONSTRAINT DF_bf_CargaFlujo_FechaAdd DEFAULT (GETDATE()),
        CFUsuarioUMod        INT      NULL,
        CFFechaUMod          DATETIME NULL,

        CONSTRAINT PK_bf_ConfiguracionFlujoCargaMasiva
            PRIMARY KEY (CFIdEmpresa),
        CONSTRAINT CK_bf_CargaFlujo_Pantalla
            CHECK (CFFlujoPantalla IN ('B2', 'B3')),
        CONSTRAINT CK_bf_CargaFlujo_Automatico
            CHECK (CFFlujoAutomatico IN ('B2', 'B3')),
        CONSTRAINT CK_bf_CargaFlujo_Estatus
            CHECK (CFIdEstatus IN (1, 2))
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.bf_CargaMasivaFlujo_Obtener
    @IdEmpresa INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        @IdEmpresa AS idEmpresa,
        COALESCE(c.CFFlujoPantalla, 'B3') AS flujoPantalla,
        COALESCE(c.CFFlujoAutomatico, 'B2') AS flujoAutomatico,
        CONVERT(BIT, CASE WHEN c.CFIdEmpresa IS NULL THEN 0 ELSE 1 END) AS configurado,
        c.CFUsuarioAdd AS usuarioAdd,
        c.CFFechaAdd AS fechaAdd,
        c.CFUsuarioUMod AS usuarioUMod,
        c.CFFechaUMod AS fechaUmod
    FROM (SELECT 1 AS n) x
    LEFT JOIN dbo.bf_ConfiguracionFlujoCargaMasiva c
        ON c.CFIdEmpresa = @IdEmpresa
       AND c.CFIdEstatus = 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.bf_CargaMasivaFlujo_Guardar
    @IdEmpresa       INT,
    @FlujoPantalla   CHAR(2),
    @FlujoAutomatico CHAR(2),
    @IdUsuario       INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @FlujoPantalla = UPPER(LTRIM(RTRIM(@FlujoPantalla)));
    SET @FlujoAutomatico = UPPER(LTRIM(RTRIM(@FlujoAutomatico)));

    IF @IdEmpresa <= 0
       OR NOT EXISTS
          (SELECT 1
           FROM dbo.ff_Empresa
           WHERE EMIdEmpresa = @IdEmpresa
             AND EMIdEstatus = 1)
        THROW 50001, 'La empresa indicada no existe o esta inactiva.', 1;

    IF @IdUsuario <= 0
        THROW 50002, 'El usuario es obligatorio.', 1;

    IF @FlujoPantalla NOT IN ('B2', 'B3')
       OR @FlujoAutomatico NOT IN ('B2', 'B3')
        THROW 50003, 'Los flujos permitidos son B2 y B3.', 1;

    BEGIN TRANSACTION;

    UPDATE dbo.bf_ConfiguracionFlujoCargaMasiva WITH (UPDLOCK, SERIALIZABLE)
       SET CFFlujoPantalla = @FlujoPantalla,
           CFFlujoAutomatico = @FlujoAutomatico,
           CFIdEstatus = 1,
           CFUsuarioUMod = @IdUsuario,
           CFFechaUMod = GETDATE()
     WHERE CFIdEmpresa = @IdEmpresa;

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT dbo.bf_ConfiguracionFlujoCargaMasiva
            (CFIdEmpresa, CFFlujoPantalla, CFFlujoAutomatico, CFIdEstatus,
             CFUsuarioAdd, CFFechaAdd)
        VALUES
            (@IdEmpresa, @FlujoPantalla, @FlujoAutomatico, 1,
             @IdUsuario, GETDATE());
    END;

    COMMIT TRANSACTION;

    EXEC dbo.bf_CargaMasivaFlujo_Obtener @IdEmpresa = @IdEmpresa;
END;
GO

CREATE OR ALTER PROCEDURE dbo.bf_CargaMasivaFlujo_Resolver
    @IdEmpresa INT,
    @Canal     VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @Canal = UPPER(LTRIM(RTRIM(@Canal)));

    IF @Canal NOT IN ('PANTALLA', 'AUTOMATICO')
        THROW 50004, 'El canal debe ser PANTALLA o AUTOMATICO.', 1;

    SELECT
        @IdEmpresa AS idEmpresa,
        @Canal AS canal,
        CASE
            WHEN c.CFIdEmpresa IS NULL AND @Canal = 'AUTOMATICO' THEN 'B2'
            WHEN c.CFIdEmpresa IS NULL THEN NULL
            WHEN @Canal = 'PANTALLA' THEN c.CFFlujoPantalla
            ELSE c.CFFlujoAutomatico
        END AS flujo,
        CONVERT(BIT, CASE WHEN c.CFIdEmpresa IS NULL THEN 0 ELSE 1 END) AS configurado
    FROM (SELECT 1 AS n) x
    LEFT JOIN dbo.bf_ConfiguracionFlujoCargaMasiva c
        ON c.CFIdEmpresa = @IdEmpresa
       AND c.CFIdEstatus = 1;
END;
GO

SELECT
    DB_NAME() AS BaseDatos,
    x.Objeto,
    CASE WHEN OBJECT_ID(x.Objeto, x.Tipo) IS NULL THEN 'FALTA' ELSE 'OK' END AS Resultado
FROM (VALUES
    (N'dbo.bf_ConfiguracionFlujoCargaMasiva', N'U'),
    (N'dbo.bf_CargaMasivaFlujo_Obtener', N'P'),
    (N'dbo.bf_CargaMasivaFlujo_Guardar', N'P'),
    (N'dbo.bf_CargaMasivaFlujo_Resolver', N'P')
) x(Objeto, Tipo)
ORDER BY x.Objeto;
GO
