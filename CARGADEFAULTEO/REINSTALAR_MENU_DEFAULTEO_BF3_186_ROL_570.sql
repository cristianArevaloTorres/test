/*
  INSTALACION LIMPIA E IDEMPOTENTE DEL MENU BF3 DE DEFAULTEO

  Empresa : 186
  Rol     : 570
  Ruta BD : administracion/solicitudes/defaulteo
  URL BF3 : /pages/administracion/solicitudes/defaulteo

  No requiere conocer MEIdMenu ni MRIdMenuRol y se puede ejecutar varias veces.
  Si el menu ya existe, lo normaliza. Si no existe, lo crea copiando nivel,
  tipo de negocio e icono de Carga Masiva.

  No elimina fisicamente menus globales porque pueden estar relacionados con
  otros roles o con ff_MenuRol. Solo desactiva duplicados para el rol 570.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @IdEmpresa INT = 186;
DECLARE @IdRol INT = 570;
DECLARE @UsuarioAuditoria INT = 0;
DECLARE @Ahora DATETIME = GETDATE();
DECLARE @RutaMenu VARCHAR(300) = 'administracion/solicitudes/defaulteo';
DECLARE @RutaDirecta VARCHAR(350) = '/pages/administracion/solicitudes/defaulteo';

DECLARE @IdMenuCarga INT;
DECLARE @IdMenuRolCarga INT;
DECLARE @IdMenuPadre INT;
DECLARE @OrdenCarga INT;
DECLARE @EsPadre BIT;
DECLARE @Target VARCHAR(20);
DECLARE @TieneIcono BIT;
DECLARE @IdTipoNegocio INT;
DECLARE @RutaBanner VARCHAR(100);
DECLARE @ImagenMenu VARCHAR(100);
DECLARE @IdMenuDefaulteo INT;
DECLARE @IdMenuRolDefaulteo INT;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.ff_Empresa
    WHERE EMIdEmpresa = @IdEmpresa
      AND EMIdEstatus = 1
)
    THROW 51800, 'La empresa 186 no existe o esta inactiva.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.ff_Rol
    WHERE ROIdRol = @IdRol
      AND ROIdEstatus = 1
)
    THROW 51801, 'El rol 570 no existe o esta inactivo.', 1;

/* Obtiene la configuracion funcional de la tarjeta Carga Masiva. */
SELECT TOP (1)
    @IdMenuCarga = M.MEIdMenu,
    @IdMenuRolCarga = MR.MRIdMenuRol,
    @IdMenuPadre = M.MEMenuPadre,
    @OrdenCarga = M.MEOrden,
    @EsPadre = M.MEPadre,
    @Target = M.METarget,
    @TieneIcono = M.MEIcono,
    @IdTipoNegocio = M.MEIdTipoNegocio,
    @RutaBanner = MR.MRRutaBanner,
    @ImagenMenu = MR.MRImagenMenu
FROM dbo.ff_Menu M
INNER JOIN dbo.ff_MenuRol2 MR
    ON MR.MRIdMenu = M.MEIdMenu
   AND MR.MRIdRol = @IdRol
   AND ISNULL(MR.MRIdEstatus, 1) <> 2
WHERE M.MEIdEstatus = 1
  AND
  (
      LOWER(LTRIM(RTRIM(ISNULL(M.MERutaLiga, '')))) IN
      (
          '/cargamasivapoblaciones', 'cargamasivapoblaciones',
          '/administracion/titulares/cargamasivapoblaciones',
          'administracion/titulares/cargamasivapoblaciones'
      )
      OR LOWER(LTRIM(RTRIM(M.MENombreMenu))) = N'carga masiva'
  )
ORDER BY
    CASE WHEN LOWER(LTRIM(RTRIM(ISNULL(M.MERutaLiga, '')))) = '/cargamasivapoblaciones'
         THEN 0 ELSE 1 END,
    M.MEIdMenu;

IF @IdMenuCarga IS NULL
    THROW 51802, 'No se encontro Carga Masiva activa para el rol 570.', 1;

IF @IdMenuPadre IS NULL OR NOT EXISTS
(
    SELECT 1
    FROM dbo.ff_MenuRol2
    WHERE MRIdRol = @IdRol
      AND MRIdMenu = @IdMenuPadre
      AND ISNULL(MRIdEstatus, 1) <> 2
)
    THROW 51803, 'El menu padre de Carga Masiva no esta asignado al rol 570.', 1;

DECLARE @Candidatos TABLE
(
    IdMenu INT NOT NULL PRIMARY KEY,
    RelacionActivaRol INT NULL,
    MismaJerarquia BIT NOT NULL,
    RutaCorrecta BIT NOT NULL,
    MenuActivo BIT NOT NULL
);

INSERT @Candidatos
(
    IdMenu, RelacionActivaRol, MismaJerarquia, RutaCorrecta, MenuActivo
)
SELECT
    M.MEIdMenu,
    MAX(CASE WHEN MR.MRIdRol = @IdRol AND ISNULL(MR.MRIdEstatus, 1) <> 2
             THEN MR.MRIdMenuRol END),
    CONVERT(BIT, CASE WHEN M.MEMenuPadre = @IdMenuPadre THEN 1 ELSE 0 END),
    CONVERT(BIT, CASE WHEN LOWER(LTRIM(RTRIM(ISNULL(M.MERutaLiga, '')))) = @RutaMenu
                      THEN 1 ELSE 0 END),
    CONVERT(BIT, CASE WHEN M.MEIdEstatus = 1 THEN 1 ELSE 0 END)
FROM dbo.ff_Menu M
LEFT JOIN dbo.ff_MenuRol2 MR
    ON MR.MRIdMenu = M.MEIdMenu
WHERE LOWER(LTRIM(RTRIM(ISNULL(M.MERutaLiga, '')))) NOT LIKE '%casos-especiales%'
  AND
  (
      LOWER(LTRIM(RTRIM(ISNULL(M.MERutaLiga, '')))) IN
      (
          '/defaulteo', 'defaulteo',
          '/solicitudes/defaulteo', 'solicitudes/defaulteo',
          '/administracion/solicitudes/defaulteo',
          'administracion/solicitudes/defaulteo',
          '/pages/administracion/solicitudes/defaulteo',
          'pages/administracion/solicitudes/defaulteo'
      )
      OR LOWER(LTRIM(RTRIM(M.MENombreMenu))) IN
         (N'defaulteo', N'defaulteo de cotizaciones', N'crear y actualizar solicitudes')
  )
GROUP BY M.MEIdMenu, M.MEMenuPadre, M.MERutaLiga, M.MEIdEstatus;

SELECT TOP (1) @IdMenuDefaulteo = IdMenu
FROM @Candidatos
ORDER BY
    CASE WHEN RelacionActivaRol IS NOT NULL THEN 0 ELSE 1 END,
    CASE WHEN MismaJerarquia = 1 THEN 0 ELSE 1 END,
    CASE WHEN RutaCorrecta = 1 THEN 0 ELSE 1 END,
    CASE WHEN MenuActivo = 1 THEN 0 ELSE 1 END,
    IdMenu;

BEGIN TRY
    BEGIN TRANSACTION;

    IF @IdMenuDefaulteo IS NULL
    BEGIN
        INSERT dbo.ff_Menu
        (
            MENombreMenu, MERutaLiga, MEComentarios, MEPadre, METarget,
            MEOrden, MEIcono, MEMenuPadre, MEIdPagina, MEIdTipoNegocio,
            MEIdEstatus, MEUsuarioAdd, MEFechaAdd, MEUsuarioUMod,
            MEFechaUMod, MEUsuarioDel, MEFechaDel
        )
        VALUES
        (
            N'Defaulteo', @RutaMenu, 'Defaulteo de empleados tipos 1, 2 y 3',
            ISNULL(@EsPadre, 0), ISNULL(@Target, 'centro'),
            ISNULL(@OrdenCarga, 0) + 1, ISNULL(@TieneIcono, 1),
            @IdMenuPadre, NULL, @IdTipoNegocio, 1,
            @UsuarioAuditoria, @Ahora, @UsuarioAuditoria, @Ahora, NULL, NULL
        );

        SET @IdMenuDefaulteo = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE dbo.ff_Menu
        SET MENombreMenu = N'Defaulteo',
            MERutaLiga = @RutaMenu,
            MEComentarios = 'Defaulteo de empleados tipos 1, 2 y 3',
            MEPadre = ISNULL(@EsPadre, 0),
            METarget = ISNULL(@Target, 'centro'),
            MEOrden = ISNULL(@OrdenCarga, 0) + 1,
            MEIcono = ISNULL(@TieneIcono, 1),
            MEMenuPadre = @IdMenuPadre,
            MEIdTipoNegocio = @IdTipoNegocio,
            MEIdEstatus = 1,
            MEUsuarioUMod = @UsuarioAuditoria,
            MEFechaUMod = @Ahora,
            MEUsuarioDel = NULL,
            MEFechaDel = NULL
        WHERE MEIdMenu = @IdMenuDefaulteo;
    END;

    /* Desactiva para este rol las opciones duplicadas, sin borrarlas. */
    UPDATE MR
    SET MR.MRIdEstatus = 2,
        MR.MRUsuarioUMod = @UsuarioAuditoria,
        MR.MRFechaUMod = @Ahora,
        MR.MRUsuarioDel = @UsuarioAuditoria,
        MR.MRFechaDel = @Ahora
    FROM dbo.ff_MenuRol2 MR
    INNER JOIN @Candidatos C ON C.IdMenu = MR.MRIdMenu
    WHERE MR.MRIdRol = @IdRol
      AND MR.MRIdMenu <> @IdMenuDefaulteo
      AND ISNULL(MR.MRIdEstatus, 1) <> 2;

    SELECT TOP (1) @IdMenuRolDefaulteo = MR.MRIdMenuRol
    FROM dbo.ff_MenuRol2 MR
    WHERE MR.MRIdRol = @IdRol
      AND MR.MRIdMenu = @IdMenuDefaulteo
    ORDER BY
        CASE WHEN ISNULL(MR.MRIdEstatus, 1) <> 2 THEN 0 ELSE 1 END,
        MR.MRIdMenuRol;

    IF @IdMenuRolDefaulteo IS NULL
    BEGIN
        INSERT dbo.ff_MenuRol2
        (
            MRIdRol, MRIdMenu, MRIdEstatus, MRUsuarioAdd, MRFechaAdd,
            MRUsuarioUMod, MRFechaUMod, MRUsuarioDel, MRFechaDel,
            MRRutaBanner, MRImagenMenu
        )
        VALUES
        (
            @IdRol, @IdMenuDefaulteo, 1, @UsuarioAuditoria, @Ahora,
            @UsuarioAuditoria, @Ahora, NULL, NULL, @RutaBanner, @ImagenMenu
        );

        SET @IdMenuRolDefaulteo = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE dbo.ff_MenuRol2
        SET MRIdEstatus = 1,
            MRRutaBanner = @RutaBanner,
            MRImagenMenu = @ImagenMenu,
            MRUsuarioUMod = @UsuarioAuditoria,
            MRFechaUMod = @Ahora,
            MRUsuarioDel = NULL,
            MRFechaDel = NULL
        WHERE MRIdMenuRol = @IdMenuRolDefaulteo;

        UPDATE dbo.ff_MenuRol2
        SET MRIdEstatus = 2,
            MRUsuarioUMod = @UsuarioAuditoria,
            MRFechaUMod = @Ahora,
            MRUsuarioDel = @UsuarioAuditoria,
            MRFechaDel = @Ahora
        WHERE MRIdRol = @IdRol
          AND MRIdMenu = @IdMenuDefaulteo
          AND MRIdMenuRol <> @IdMenuRolDefaulteo
          AND ISNULL(MRIdEstatus, 1) <> 2;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT
    @IdEmpresa AS IdEmpresa,
    @IdRol AS IdRol,
    D.MEIdMenu AS IdMenuDefaulteo,
    D.MENombreMenu,
    D.MERutaLiga,
    @RutaDirecta AS URLFinal,
    D.MEMenuPadre,
    D.MEOrden,
    MR.MRIdMenuRol,
    MR.MRIdEstatus,
    MR.MRImagenMenu,
    C.MEIdMenu AS IdMenuCargaMasiva,
    C.MEOrden AS OrdenCargaMasiva,
    CASE
        WHEN D.MERutaLiga = @RutaMenu
         AND D.MEMenuPadre = C.MEMenuPadre
         AND D.MEOrden = C.MEOrden + 1
         AND D.MEIdEstatus = 1
         AND MR.MRIdRol = @IdRol
         AND ISNULL(MR.MRIdEstatus, 1) <> 2
         AND ISNULL(MR.MRImagenMenu, '') = ISNULL(CMR.MRImagenMenu, '')
        THEN 'OK'
        ELSE 'REVISAR'
    END AS Resultado
FROM dbo.ff_Menu D
INNER JOIN dbo.ff_MenuRol2 MR
    ON MR.MRIdMenu = D.MEIdMenu
   AND MR.MRIdMenuRol = @IdMenuRolDefaulteo
INNER JOIN dbo.ff_Menu C
    ON C.MEIdMenu = @IdMenuCarga
INNER JOIN dbo.ff_MenuRol2 CMR
    ON CMR.MRIdMenuRol = @IdMenuRolCarga;

PRINT 'LISTO: cierre sesion, elimine localStorage.menurol y vuelva a ingresar.';
GO
