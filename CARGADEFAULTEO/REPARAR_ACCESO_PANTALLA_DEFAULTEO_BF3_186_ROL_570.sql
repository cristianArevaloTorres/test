/*
  REPARA ACCESO A LA PANTALLA DE DEFAULTEO BF3
  Empresa: 186
  Rol:     570

  Ejecutar completo en la base utilizada por WSBeFlex.

  Este script es idempotente:
  - reutiliza el menu Defaulteo si ya existe;
  - si no existe, lo crea copiando la jerarquia de Carga Masiva;
  - guarda la ruta que AdministracionComponent necesita;
  - activa el permiso en ff_MenuRol2 para el rol 570;
  - copia la imagen de Carga Masiva;
  - desactiva asignaciones duplicadas de Defaulteo solo para el rol 570.

  La URL que debe abrir el navegador al terminar es:
      /pages/administracion/solicitudes/defaulteo
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @IdEmpresa INT = 186;
DECLARE @IdRol INT = 570;
DECLARE @RutaMenu VARCHAR(300) = 'administracion/solicitudes/defaulteo';
DECLARE @RutaFinal VARCHAR(350) = '/pages/administracion/solicitudes/defaulteo';
DECLARE @Ahora DATETIME = GETDATE();

DECLARE @IdMenuCarga INT;
DECLARE @IdMenuRolCarga INT;
DECLARE @IdMenuDefaulteo INT;
DECLARE @IdMenuRolDefaulteo INT;
DECLARE @IdMenuPadre INT;
DECLARE @OrdenCarga INT;
DECLARE @EsPadre BIT;
DECLARE @Target VARCHAR(20);
DECLARE @TieneIcono BIT;
DECLARE @IdTipoNegocio INT;
DECLARE @RutaBanner VARCHAR(100);
DECLARE @ImagenMenu VARCHAR(100);
DECLARE @UsuarioAuditoria INT = 0;

IF DB_NAME() IS NULL
    THROW 51800, 'No se pudo identificar la base actual.', 1;

IF OBJECT_ID('dbo.ff_Menu', 'U') IS NULL
   OR OBJECT_ID('dbo.ff_MenuRol2', 'U') IS NULL
   OR OBJECT_ID('dbo.ff_Rol', 'U') IS NULL
   OR OBJECT_ID('dbo.ff_Empresa', 'U') IS NULL
    THROW 51801, 'Faltan tablas del menu BF3 en la base actual.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.ff_Empresa
    WHERE EMIdEmpresa = @IdEmpresa
      AND EMIdEstatus = 1
)
    THROW 51802, 'La empresa 186 no existe o esta inactiva en esta base.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.ff_Rol R
    WHERE R.ROIdRol = @IdRol
      AND R.ROIdEstatus = 1
)
    THROW 51803, 'El rol 570 no existe o esta inactivo.', 1;

/* Carga Masiva es la referencia funcional que ya abre correctamente. */
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
    @ImagenMenu = MR.MRImagenMenu,
    @UsuarioAuditoria = COALESCE(MR.MRUsuarioAdd, 0)
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
          'administracion/titulares/cargamasivapoblaciones',
          '/administracion/titulares/cargamasivapoblaciones'
      )
      OR LOWER(LTRIM(RTRIM(M.MENombreMenu))) = N'carga masiva'
  )
ORDER BY M.MEIdMenu;

IF @IdMenuCarga IS NULL
    THROW 51804, 'Carga Masiva no esta asignada al rol 570; no se puede copiar su permiso.', 1;

DECLARE @Candidatos TABLE
(
    IdMenu INT NOT NULL PRIMARY KEY
);

INSERT @Candidatos (IdMenu)
SELECT M.MEIdMenu
FROM dbo.ff_Menu M
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
      OR LOWER(LTRIM(RTRIM(ISNULL(M.MENombreMenu, '')))) IN
      (
          N'defaulteo', N'defaulteo de cotizaciones',
          N'crear y actualizar solicitudes'
      )
  );

/* Prefiere el registro ya activo para el rol y en la jerarquia correcta. */
SELECT TOP (1) @IdMenuDefaulteo = C.IdMenu
FROM @Candidatos C
INNER JOIN dbo.ff_Menu M ON M.MEIdMenu = C.IdMenu
LEFT JOIN dbo.ff_MenuRol2 MR
    ON MR.MRIdMenu = M.MEIdMenu
   AND MR.MRIdRol = @IdRol
   AND ISNULL(MR.MRIdEstatus, 1) <> 2
ORDER BY
    CASE WHEN MR.MRIdMenuRol IS NOT NULL THEN 0 ELSE 1 END,
    CASE WHEN M.MEMenuPadre = @IdMenuPadre THEN 0 ELSE 1 END,
    CASE WHEN LOWER(LTRIM(RTRIM(ISNULL(M.MERutaLiga, '')))) = @RutaMenu THEN 0 ELSE 1 END,
    CASE WHEN M.MEIdEstatus = 1 THEN 0 ELSE 1 END,
    M.MEIdMenu;

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
            N'Defaulteo', @RutaMenu,
            'Defaulteo de empleados tipos 1, 2 y 3',
            ISNULL(@EsPadre, 0), ISNULL(@Target, 'centro'),
            ISNULL(@OrdenCarga, 0) + 1, ISNULL(@TieneIcono, 1),
            @IdMenuPadre, NULL, @IdTipoNegocio, 1,
            @UsuarioAuditoria, @Ahora, @UsuarioAuditoria, @Ahora,
            NULL, NULL
        );

        SET @IdMenuDefaulteo = CONVERT(INT, SCOPE_IDENTITY());
    END;

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

    /* Desactiva otros Defaulteos visibles para este rol, sin borrarlos. */
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
            @UsuarioAuditoria, @Ahora, NULL, NULL,
            @RutaBanner, @ImagenMenu
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
    END;

    /* Deja una sola relacion activa para el mismo menu y rol. */
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

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT
    DB_NAME() AS BaseDatos,
    @IdEmpresa AS IdEmpresa,
    @IdRol AS IdRol,
    D.MEIdMenu AS IdMenuDefaulteo,
    D.MENombreMenu,
    D.MERutaLiga AS RutaGuardada,
    @RutaFinal AS URLNavegador,
    D.MEMenuPadre,
    D.MEOrden,
    MR.MRIdMenuRol,
    MR.MRIdEstatus,
    MR.MRImagenMenu,
    CASE
        WHEN D.MERutaLiga = @RutaMenu
         AND D.MEMenuPadre = C.MEMenuPadre
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
    ON CMR.MRIdMenuRol = @IdMenuRolCarga
WHERE D.MEIdMenu = @IdMenuDefaulteo;

/* Indica que administradores de la empresa reciben realmente el rol 570. */
IF OBJECT_ID('dbo.ff_AdministradorEmpresa', 'U') IS NOT NULL
BEGIN
    SELECT
        'USUARIOS_CON_ROL_570' AS Bloque,
        AE.ADIdAdministrador,
        AE.AEIdEmpresa,
        AE.AEIdRol,
        AE.AEIdEstatus
    FROM dbo.ff_AdministradorEmpresa AE
    WHERE AE.AEIdEmpresa = @IdEmpresa
      AND AE.AEIdRol = @IdRol
      AND AE.AEIdEstatus = 1
    ORDER BY AE.ADIdAdministrador;

    SELECT
        'ROLES_ACTIVOS_EMPRESA_186' AS Bloque,
        AE.ADIdAdministrador,
        A.ADClaveAcceso,
        LTRIM(RTRIM(
            ISNULL(A.ADNombres, '') + ' ' +
            ISNULL(A.ADApellidoPaterno, '') + ' ' +
            ISNULL(A.ADApellidoMaterno, '')
        )) AS Administrador,
        AE.AEIdEmpresa,
        AE.AEIdRol,
        R.RODescripcionCorta AS Rol,
        AE.AEIdEstatus
    FROM dbo.ff_AdministradorEmpresa AE
    INNER JOIN dbo.ff_Administrador A
        ON A.ADIdAdministrador = AE.ADIdAdministrador
    LEFT JOIN dbo.ff_Rol R
        ON R.ROIdRol = AE.AEIdRol
    WHERE AE.AEIdEmpresa = @IdEmpresa
      AND AE.AEIdEstatus = 1
    ORDER BY A.ADClaveAcceso, AE.AEIdRol;
END;

PRINT 'LISTO: el ultimo resultado debe decir OK.';
PRINT 'Cierre sesion en BF3, vuelva a entrar y pruebe: ' + @RutaFinal;
PRINT 'Si conserva cache, elimine localStorage.menurol y localStorage.menus, luego recargue.';
PRINT 'Si la URL directa sigue en blanco o vuelve a home, falta desplegar el frontend que contiene la ruta defaulteo; SQL ya no es el bloqueo.';
GO
