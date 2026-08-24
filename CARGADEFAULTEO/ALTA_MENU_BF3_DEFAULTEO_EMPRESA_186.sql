/*
  CONFIGURACION DIRECTA DEL MENU BF3 DE DEFAULTEO - EMPRESA 186

  Se puede ejecutar completo mas de una vez.

  - El rol BF3 queda fijo en 570.
  - Busca y reutiliza el Defaulteo creado por ejecuciones anteriores.
  - Si no existe, lo crea copiando la configuracion funcional de Carga Masiva.
  - Lo coloca al mismo nivel que Carga Masiva y copia su icono.
  - Corrige la liga para que AdministracionComponent navegue a:
      /pages/administracion/solicitudes/defaulteo
  - Desactiva para el rol 570 asignaciones duplicadas de Defaulteo.

  IMPORTANTE:
  MEIdMenu y MRIdMenuRol son columnas IDENTITY. No se usa MAX + 1 para sus
  identificadores; SQL Server genera el ID y se recupera con SCOPE_IDENTITY().
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @IdEmpresa INT = 186;
DECLARE @IdRol INT = 570;
DECLARE @UsuarioAuditoria INT = 0;
DECLARE @Ahora DATETIME = GETDATE();

/* La tarjeta agrega pages/ desde AdministracionComponent. */
DECLARE @RutaMenu VARCHAR(300) = 'administracion/solicitudes/defaulteo';
DECLARE @RutaDirecta VARCHAR(350) = '/pages/administracion/solicitudes/defaulteo';

DECLARE @IdMenuCarga INT;
DECLARE @IdMenuDefaulteo INT;
DECLARE @IdMenuRolCarga INT;
DECLARE @IdMenuRolDefaulteo INT;
DECLARE @IdMenuPadre INT;
DECLARE @OrdenCarga INT;
DECLARE @EsPadre BIT;
DECLARE @Target VARCHAR(20);
DECLARE @TieneIcono BIT;
DECLARE @IdTipoNegocio INT;
DECLARE @RutaBanner VARCHAR(100);
DECLARE @ImagenMenu VARCHAR(100);

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.ff_Empresa
    WHERE EMIdEmpresa = @IdEmpresa
      AND EMIdEstatus = 1
)
    THROW 51600, 'La empresa 186 no existe o esta inactiva.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.ff_Rol R
    WHERE R.ROIdRol = @IdRol
      AND R.ROIdEstatus = 1
      AND
      (
          R.ROIdEmpresa = @IdEmpresa
          OR EXISTS
          (
              SELECT 1
              FROM dbo.ff_AdministradorEmpresa AE
              WHERE AE.AEIdEmpresa = @IdEmpresa
                AND AE.AEIdRol = @IdRol
                AND AE.AEIdEstatus = 1
          )
      )
)
    THROW 51601, 'El rol 570 no esta activo o no corresponde a la empresa 186.', 1;

/* Carga Masiva es la referencia real de nivel, orden, tipo de negocio e icono. */
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
          'administracion/titulares/cargamasivapoblaciones',
          '/administracion/titulares/cargamasivapoblaciones'
      )
      OR LOWER(LTRIM(RTRIM(M.MENombreMenu))) = N'carga masiva'
  )
ORDER BY
    CASE WHEN LOWER(LTRIM(RTRIM(ISNULL(M.MERutaLiga, '')))) = '/cargamasivapoblaciones' THEN 0 ELSE 1 END,
    M.MEIdMenu;

IF @IdMenuCarga IS NULL
    THROW 51602, 'No se encontro la Carga Masiva activa para el rol 570; no es posible copiar su configuracion.', 1;

/*
  Incluye las rutas/nombres utilizados por los scripts anteriores. Casos
  especiales se excluye porque es una pantalla independiente.
*/
DECLARE @MenusDefaulteo TABLE
(
    IdMenu INT NOT NULL PRIMARY KEY,
    IdMenuRolActivo INT NULL,
    MismaJerarquia BIT NOT NULL,
    RutaCorrecta BIT NOT NULL,
    MenuActivo BIT NOT NULL
);

INSERT @MenusDefaulteo
(
    IdMenu, IdMenuRolActivo, MismaJerarquia, RutaCorrecta, MenuActivo
)
SELECT
    M.MEIdMenu,
    MAX(CASE WHEN MR.MRIdRol = @IdRol AND ISNULL(MR.MRIdEstatus, 1) <> 2
             THEN MR.MRIdMenuRol END),
    CONVERT(BIT, CASE WHEN M.MEMenuPadre = @IdMenuPadre THEN 1 ELSE 0 END),
    CONVERT(BIT, CASE WHEN LOWER(LTRIM(RTRIM(ISNULL(M.MERutaLiga, '')))) = @RutaMenu THEN 1 ELSE 0 END),
    CONVERT(BIT, CASE WHEN M.MEIdEstatus = 1 THEN 1 ELSE 0 END)
FROM dbo.ff_Menu M
LEFT JOIN dbo.ff_MenuRol2 MR
    ON MR.MRIdMenu = M.MEIdMenu
WHERE
    LOWER(LTRIM(RTRIM(ISNULL(M.MERutaLiga, '')))) NOT LIKE '%casos-especiales%'
    AND
    (
        LOWER(LTRIM(RTRIM(ISNULL(M.MERutaLiga, '')))) IN
        (
            '/defaulteo', 'defaulteo',
            '/solicitudes/defaulteo', 'solicitudes/defaulteo',
            '/administracion/solicitudes/defaulteo', 'administracion/solicitudes/defaulteo',
            '/pages/administracion/solicitudes/defaulteo', 'pages/administracion/solicitudes/defaulteo'
        )
        OR LOWER(LTRIM(RTRIM(M.MENombreMenu))) IN
        (
            N'defaulteo', N'defaulteo de cotizaciones', N'crear y actualizar solicitudes'
        )
    )
GROUP BY
    M.MEIdMenu, M.MEMenuPadre, M.MERutaLiga, M.MEIdEstatus;

/*
  Si los scripts anteriores ya crearon el menu, se prioriza el que ya esta
  asignado al rol, en la misma jerarquia y con la ruta correcta.
*/
SELECT TOP (1) @IdMenuDefaulteo = IdMenu
FROM @MenusDefaulteo
ORDER BY
    CASE WHEN IdMenuRolActivo IS NOT NULL THEN 0 ELSE 1 END,
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
            N'Defaulteo', @RutaMenu,
            'Defaulteo de empleados tipos 1, 2 y 3',
            ISNULL(@EsPadre, 0), ISNULL(@Target, 'centro'),
            ISNULL(@OrdenCarga, 0) + 1, ISNULL(@TieneIcono, 1),
            @IdMenuPadre, NULL, @IdTipoNegocio, 1,
            @UsuarioAuditoria, @Ahora, @UsuarioAuditoria, @Ahora, NULL, NULL
        );

        SET @IdMenuDefaulteo = CONVERT(INT, SCOPE_IDENTITY());
        PRINT 'Se creo automaticamente el menu Defaulteo con ID '
            + CONVERT(VARCHAR(20), @IdMenuDefaulteo) + '.';
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

        PRINT 'Se reutilizo y corrigio el menu Defaulteo con ID '
            + CONVERT(VARCHAR(20), @IdMenuDefaulteo) + '.';
    END;

    /*
      Si hubo dos ejecuciones previas que dejaron mas de un Defaulteo, para
      el rol 570 se conserva visible solamente el registro seleccionado.
      No se eliminan menus ni se afectan otros roles.
    */
    UPDATE MR
    SET MR.MRIdEstatus = 2,
        MR.MRUsuarioDel = @UsuarioAuditoria,
        MR.MRFechaDel = @Ahora,
        MR.MRUsuarioUMod = @UsuarioAuditoria,
        MR.MRFechaUMod = @Ahora
    FROM dbo.ff_MenuRol2 MR
    INNER JOIN @MenusDefaulteo C
        ON C.IdMenu = MR.MRIdMenu
    WHERE MR.MRIdRol = @IdRol
      AND MR.MRIdMenu <> @IdMenuDefaulteo
      AND ISNULL(MR.MRIdEstatus, 1) <> 2;

    /* Reutiliza una asignacion anterior si existe; no genera duplicados. */
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

        /* En caso de duplicados de la misma relacion, deja una sola activa. */
        UPDATE dbo.ff_MenuRol2
        SET MRIdEstatus = 2,
            MRUsuarioDel = @UsuarioAuditoria,
            MRFechaDel = @Ahora,
            MRUsuarioUMod = @UsuarioAuditoria,
            MRFechaUMod = @Ahora
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

/* El ultimo bloque debe devolver Resultado = OK. */
SELECT
    @IdEmpresa AS IdEmpresa,
    D.MEIdMenu AS IdMenuDefaulteo,
    D.MENombreMenu,
    D.MERutaLiga,
    @RutaDirecta AS URLFinal,
    D.MEMenuPadre,
    D.MEOrden,
    MR.MRIdMenuRol,
    MR.MRIdRol,
    MR.MRIdEstatus,
    MR.MRImagenMenu,
    C.MEIdMenu AS IdMenuCargaMasiva,
    C.MEOrden AS OrdenCargaMasiva,
    CMR.MRImagenMenu AS ImagenCargaMasiva,
    CASE
        WHEN D.MERutaLiga = @RutaMenu
         AND D.MEMenuPadre = C.MEMenuPadre
         AND D.MEOrden = C.MEOrden + 1
         AND MR.MRIdRol = @IdRol
         AND ISNULL(MR.MRIdEstatus, 1) <> 2
         AND ISNULL(MR.MRImagenMenu, '') = ISNULL(CMR.MRImagenMenu, '')
         AND NOT EXISTS
         (
             SELECT 1
             FROM dbo.ff_MenuRol2 MR2
             INNER JOIN dbo.ff_Menu M2 ON M2.MEIdMenu = MR2.MRIdMenu
             WHERE MR2.MRIdRol = @IdRol
               AND ISNULL(MR2.MRIdEstatus, 1) <> 2
               AND MR2.MRIdMenu <> D.MEIdMenu
               AND LOWER(LTRIM(RTRIM(ISNULL(M2.MERutaLiga, '')))) IN
               (
                   '/defaulteo', 'defaulteo',
                   '/solicitudes/defaulteo', 'solicitudes/defaulteo',
                   '/administracion/solicitudes/defaulteo', 'administracion/solicitudes/defaulteo',
                   '/pages/administracion/solicitudes/defaulteo', 'pages/administracion/solicitudes/defaulteo'
               )
         )
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

PRINT 'LISTO: cierre sesion y vuelva a ingresar a BF3.';
PRINT 'Si el navegador conserva el menu anterior, elimine localStorage.menurol y recargue.';
GO
