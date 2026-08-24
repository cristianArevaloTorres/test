/*
  Verifica y, opcionalmente, habilita la pantalla BF3 de Defaulteo.

  Este script corresponde al menu consumido por Angular y servido por Java:
      Angular menus.service.ts -> POST /beflex/menu/rol/2
      Java WSFfMenu -> JDBCFfMenusRol.consultarMenusPorRol2
      SQL -> dbo.ff_MenuRol2 INNER JOIN dbo.ff_Menu

  No usa dbo.ff_MenuRol, que pertenece al contrato anterior/legado.

  Ruta Angular:
      /pages/administracion/solicitudes/defaulteo

  Modelo de seguridad real:
      ff_AdministradorEmpresa (usuario + empresa -> rol)
        -> ff_MenuRol2 (rol -> menus visibles)
        -> ff_Menu (menu padre Solicitudes + opcion Defaulteo)

  USO:
  1. Complete @IdEmpresa y @IdAdministrador o @ClaveAccesoAdmin.
  2. Ejecute con @Aplicar = 0. Revise los bloques RESULTADO_*.
  3. Si el administrador tiene mas de un rol activo para la empresa, copie el
     rol correcto a @IdRol.
  4. Si RESULTADO_MENU_CANDIDATO devuelve mas de una opcion, copie el menu
     correcto a @IdMenuDefaulteo.
  5. Cambie @Aplicar = 1 y vuelva a ejecutar.

  Si ff_Menu esta vacia o no existe el padre Solicitudes, capture
  @IdTipoNegocio y use tambien @CrearMenuPadreSiNoExiste = 1. El padre, la
  opcion hija y las asignaciones se confirman en una sola transaccion.

  El script no inventa empresa, administrador ni rol. Si el catalogo del menu
  no existe, solo lo crea cuando @CrearMenuSiNoExiste = 1 y puede identificar
  de forma univoca el menu padre "Administracion de Solicitudes".
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET NOCOUNT ON;
SET XACT_ABORT ON;

/* ======================= PARAMETROS EDITABLES ======================= */
DECLARE @IdEmpresa              INT         = 186;   -- Empresa de esta prueba.
DECLARE @IdAdministrador        INT         = NULL;  -- Recomendado.
DECLARE @ClaveAccesoAdmin       VARCHAR(20) = NULL;  -- Alternativa a @IdAdministrador.
DECLARE @IdRol                  INT         = NULL;  -- Opcional si el usuario tiene un solo rol en la empresa.
DECLARE @IdMenuDefaulteo        INT         = NULL;  -- Opcional; usar si hay menus candidatos duplicados.
DECLARE @IdMenuPadreSolicitudes INT         = NULL;  -- Opcional; usar si hay padres candidatos duplicados.
DECLARE @IdUsuarioAuditoria     INT         = NULL;  -- Si queda NULL se usa @IdAdministrador.
DECLARE @IdTipoNegocio          INT         = NULL;  -- Obligatorio solo si se debe crear el menu padre.

DECLARE @Aplicar                BIT         = 0;     -- 0 = solo verificar; 1 = habilitar.
DECLARE @CrearMenuSiNoExiste    BIT         = 0;     -- Mantener 0 si el catalogo se administra por otro despliegue.
DECLARE @CrearMenuPadreSiNoExiste BIT       = 0;     -- Usar 1 solo para una BD sin el padre Solicitudes.
/* =================================================================== */

DECLARE @RutaDirecta VARCHAR(300) = '/pages/administracion/solicitudes/defaulteo';
/* AdministracionComponent antepone "pages/" antes de navegar. */
DECLARE @RutaMenu    VARCHAR(300) = 'administracion/solicitudes/defaulteo';
DECLARE @NombreMenu  NVARCHAR(500) = N'Crear y actualizar solicitudes';

PRINT 'CONFIGURACION: la visibilidad es por ROL. El usuario obtiene ese rol por empresa en ff_AdministradorEmpresa.';
PRINT 'RUTA_DIRECTA=' + @RutaDirecta;

SELECT *
FROM (VALUES
    (1, 'DIRECTA_BF3_JAVA', 'ff_Menu',                 'Catalogo que Java devuelve a Angular.'),
    (2, 'DIRECTA_BF3_JAVA', 'ff_MenuRol2',             'Relacion que el DAO Java filtra por idRol.'),
    (3, 'SOPORTE_ROL',      'ff_Rol',                  'Valida el rol recibido por el endpoint Java.'),
    (4, 'SOPORTE_ROL',      'ff_AdministradorEmpresa', 'Permite descubrir el rol del administrador para la empresa 186.'),
    (5, 'SOPORTE_ROL',      'ff_Administrador',        'Permite localizar al administrador por ID o clave.'),
    (6, 'VALIDACION',       'ff_Empresa',              'Valida que la empresa 186 exista y este activa.'),
    (7, 'NO_UTILIZADA_BF3', 'ff_MenuRol',              'Tabla legada; este script no la consulta ni la modifica.')
) T(orden, grupo, tabla, uso)
ORDER BY orden;

SELECT
    'RESULTADO_AMBIENTE' AS bloque,
    (SELECT COUNT(*) FROM dbo.ff_Empresa WHERE EMIdEstatus = 1) AS empresasActivas,
    (SELECT COUNT(*) FROM dbo.ff_Administrador WHERE ADIdEstatus = 1) AS administradoresActivos,
    (SELECT COUNT(*) FROM dbo.ff_Rol WHERE ROIdEstatus = 1) AS rolesActivos,
    (SELECT COUNT(*) FROM dbo.ff_Menu WHERE MEIdEstatus = 1) AS menusActivos,
    (SELECT COUNT(*) FROM dbo.ff_MenuRol2 WHERE ISNULL(MRidEstatus, 1) <> 2) AS asignacionesMenuActivas;

IF @IdEmpresa IS NULL OR @IdEmpresa <= 0
BEGIN
    SELECT TOP (100)
        'EMPRESAS_DISPONIBLES' AS bloque,
        EMidEmpresa AS idEmpresa,
        EMNombre AS empresa,
        EMClaveAcceso AS claveEmpresa,
        EMIdEstatus AS estatus
    FROM dbo.ff_Empresa
    WHERE EMIdEstatus = 1
    ORDER BY EMNombre;

    PRINT 'DETENIDO: capture @IdEmpresa. No se realizo ningun cambio.';
    RETURN;
END;

IF NOT EXISTS (
    SELECT 1 FROM dbo.ff_Empresa
    WHERE EMidEmpresa = @IdEmpresa AND EMIdEstatus = 1)
    THROW 50401, 'La empresa indicada no existe o esta inactiva.', 1;

IF @IdAdministrador IS NULL AND NULLIF(LTRIM(RTRIM(@ClaveAccesoAdmin)), '') IS NOT NULL
BEGIN
    IF (SELECT COUNT(*) FROM dbo.ff_Administrador
        WHERE ADClaveAcceso = LTRIM(RTRIM(@ClaveAccesoAdmin)) AND ADIdEstatus = 1) <> 1
        THROW 50402, 'La clave no identifica exactamente a un administrador activo.', 1;

    SELECT @IdAdministrador = ADIdAdministrador
    FROM dbo.ff_Administrador
    WHERE ADClaveAcceso = LTRIM(RTRIM(@ClaveAccesoAdmin)) AND ADIdEstatus = 1;
END;

IF @IdAdministrador IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM dbo.ff_Administrador
    WHERE ADIdAdministrador = @IdAdministrador AND ADIdEstatus = 1)
    THROW 50403, 'El administrador indicado no existe o esta inactivo.', 1;

DECLARE @RolesObjetivo TABLE
(
    idRol INT NOT NULL PRIMARY KEY,
    origen VARCHAR(30) NOT NULL
);

IF @IdRol IS NOT NULL
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM dbo.ff_Rol r
        WHERE r.ROIdRol = @IdRol
          AND r.ROIdEstatus = 1
          AND (
                r.ROIdEmpresa = @IdEmpresa
                OR EXISTS (
                    SELECT 1
                    FROM dbo.ff_AdministradorEmpresa ae
                    WHERE ae.AEIdEmpresa = @IdEmpresa
                      AND ae.AEIdRol = @IdRol
                      AND ae.AEIdEstatus = 1
                )
              ))
        THROW 50404, 'El rol no esta activo o no corresponde a la empresa.', 1;

    INSERT @RolesObjetivo (idRol, origen) VALUES (@IdRol, 'PARAMETRO');
END
ELSE IF @IdAdministrador IS NOT NULL
BEGIN
    INSERT @RolesObjetivo (idRol, origen)
    SELECT DISTINCT ae.AEIdRol, 'ADMIN_EMPRESA'
    FROM dbo.ff_AdministradorEmpresa ae
    INNER JOIN dbo.ff_Rol r
        ON r.ROIdRol = ae.AEIdRol
       AND r.ROIdEstatus = 1
    WHERE ae.ADIdAdministrador = @IdAdministrador
      AND ae.AEIdEmpresa = @IdEmpresa
      AND ae.AEIdEstatus = 1
      AND ae.AEIdRol IS NOT NULL;
END;

SELECT
    'RESULTADO_USUARIO_ROL' AS bloque,
    a.ADIdAdministrador AS idAdministrador,
    a.ADClaveAcceso AS claveAcceso,
    LTRIM(RTRIM(ISNULL(a.ADNombres, '') + ' ' + ISNULL(a.ADApellidoPaterno, '')
        + ' ' + ISNULL(a.ADApellidoMaterno, ''))) AS administrador,
    ae.AEIdEmpresa AS idEmpresa,
    e.EMNombre AS empresa,
    ae.AEIdRol AS idRol,
    r.RODescripcionCorta AS rol,
    ae.AEidTipoNegocio AS idTipoNegocio,
    ae.AEIdEstatus AS estatusAsignacion
FROM dbo.ff_AdministradorEmpresa ae
INNER JOIN dbo.ff_Administrador a ON a.ADIdAdministrador = ae.ADIdAdministrador
INNER JOIN dbo.ff_Empresa e ON e.EMidEmpresa = ae.AEIdEmpresa
LEFT JOIN dbo.ff_Rol r ON r.ROIdRol = ae.AEIdRol
WHERE ae.AEIdEmpresa = @IdEmpresa
  AND (@IdAdministrador IS NULL OR ae.ADIdAdministrador = @IdAdministrador)
ORDER BY a.ADClaveAcceso, ae.AEIdRol;

IF NOT EXISTS (SELECT 1 FROM @RolesObjetivo)
BEGIN
    SELECT
        'ROLES_DISPONIBLES_EMPRESA' AS bloque,
        r.ROIdRol AS idRol,
        r.RODescripcionCorta AS rol,
        r.ROAdministrador AS esAdministrador,
        r.ROIdEstatus AS estatus
    FROM dbo.ff_Rol r
    WHERE r.ROIdEmpresa = @IdEmpresa
    ORDER BY r.RODescripcionCorta;

    PRINT 'DETENIDO: no se resolvio un rol. Capture @IdAdministrador/@ClaveAccesoAdmin o @IdRol.';
    RETURN;
END;

IF (SELECT COUNT(*) FROM @RolesObjetivo) > 1 AND @IdRol IS NULL
BEGIN
    SELECT 'ROLES_AMBIGUOS' AS bloque, idRol, origen FROM @RolesObjetivo ORDER BY idRol;
    PRINT 'DETENIDO: el usuario tiene mas de un rol activo para la empresa. Capture @IdRol.';
    RETURN;
END;

DECLARE @RolObjetivo INT = (SELECT TOP (1) idRol FROM @RolesObjetivo);

/* Busca las formas historicas y B3 conocidas de la liga. */
DECLARE @MenusCandidatos TABLE
(
    idMenu INT NOT NULL PRIMARY KEY
);

INSERT @MenusCandidatos (idMenu)
SELECT m.MEidMenu
FROM dbo.ff_Menu m
WHERE m.MEIdEstatus = 1
  AND (
        LOWER(LTRIM(RTRIM(ISNULL(m.MERutaLiga, '')))) IN (
            '/defaulteo', 'defaulteo',
            '/solicitudes/defaulteo', 'solicitudes/defaulteo',
            '/administracion/solicitudes/defaulteo', 'administracion/solicitudes/defaulteo',
            '/pages/administracion/solicitudes/defaulteo', 'pages/administracion/solicitudes/defaulteo'
        )
        OR LOWER(LTRIM(RTRIM(m.MENombreMenu))) IN (
            N'crear y actualizar solicitudes', N'defaulteo', N'defaulteo de cotizaciones'
        )
      )
  AND LOWER(LTRIM(RTRIM(ISNULL(m.MERutaLiga, '')))) NOT LIKE '%casos-especiales%';

SELECT
    'RESULTADO_MENU_CANDIDATO' AS bloque,
    m.MEidMenu AS idMenu,
    m.MENombreMenu AS menu,
    m.MERutaLiga AS rutaGuardada,
    @RutaDirecta AS rutaAngular,
    m.MEPadre AS esPadre,
    m.MEMenuPadre AS idMenuPadre,
    m.MEidTipoNegocio AS idTipoNegocio,
    m.MEIdEstatus AS estatus
FROM @MenusCandidatos c
INNER JOIN dbo.ff_Menu m ON m.MEidMenu = c.idMenu
ORDER BY m.MEidMenu;

SELECT
    'RESULTADO_MENU_PADRE_CANDIDATO' AS bloque,
    m.MEidMenu AS idMenu,
    m.MENombreMenu AS menu,
    m.MERutaLiga AS ruta,
    m.MEPadre AS esPadre,
    m.MEMenuPadre AS idMenuPadre,
    m.MEidTipoNegocio AS idTipoNegocio,
    m.MEIdEstatus AS estatus
FROM dbo.ff_Menu m
WHERE m.MEIdEstatus = 1
  AND m.MEPadre = 1
  AND (
        LOWER(LTRIM(RTRIM(ISNULL(m.MERutaLiga, '')))) IN (
            '/administracion/solicitudes', 'administracion/solicitudes',
            '/solicitudes', 'solicitudes'
        )
        OR LOWER(LTRIM(RTRIM(m.MENombreMenu))) IN (
            N'administracion de solicitudes', N'administración de solicitudes', N'solicitudes'
        )
      )
ORDER BY m.MEidMenu;

IF @IdMenuDefaulteo IS NOT NULL
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM dbo.ff_Menu
        WHERE MEidMenu = @IdMenuDefaulteo AND MEIdEstatus = 1)
        THROW 50405, 'El menu de Defaulteo indicado no existe o esta inactivo.', 1;
END
ELSE IF (SELECT COUNT(*) FROM @MenusCandidatos) = 1
    SELECT @IdMenuDefaulteo = idMenu FROM @MenusCandidatos;

IF @IdMenuDefaulteo IS NULL AND @CrearMenuSiNoExiste = 1 AND @Aplicar = 1
BEGIN
    DECLARE @PadresCandidatos TABLE (idMenu INT NOT NULL PRIMARY KEY);

    INSERT @PadresCandidatos (idMenu)
    SELECT m.MEidMenu
    FROM dbo.ff_Menu m
    WHERE m.MEIdEstatus = 1
      AND m.MEPadre = 1
      AND (
            LOWER(LTRIM(RTRIM(ISNULL(m.MERutaLiga, '')))) IN (
                '/administracion/solicitudes', 'administracion/solicitudes',
                '/solicitudes', 'solicitudes'
            )
            OR LOWER(LTRIM(RTRIM(m.MENombreMenu))) IN (
                N'administracion de solicitudes', N'administración de solicitudes', N'solicitudes'
            )
          );

    IF @IdMenuPadreSolicitudes IS NULL AND (SELECT COUNT(*) FROM @PadresCandidatos) = 1
        SELECT @IdMenuPadreSolicitudes = idMenu FROM @PadresCandidatos;

    IF @IdMenuPadreSolicitudes IS NULL
       AND NOT EXISTS (SELECT 1 FROM @PadresCandidatos)
       AND @CrearMenuPadreSiNoExiste = 1
    BEGIN
        IF @IdTipoNegocio IS NULL
           AND (SELECT COUNT(DISTINCT ae.AEidTipoNegocio)
                FROM dbo.ff_AdministradorEmpresa ae
                WHERE ae.AEIdEmpresa = @IdEmpresa
                  AND ae.AEIdRol = @RolObjetivo
                  AND ae.AEIdEstatus = 1
                  AND ae.AEidTipoNegocio IS NOT NULL) = 1
            SELECT @IdTipoNegocio = MAX(ae.AEidTipoNegocio)
            FROM dbo.ff_AdministradorEmpresa ae
            WHERE ae.AEIdEmpresa = @IdEmpresa
              AND ae.AEIdRol = @RolObjetivo
              AND ae.AEIdEstatus = 1;

        IF @IdTipoNegocio IS NULL
            THROW 50409, 'Capture @IdTipoNegocio para crear el menu padre Solicitudes.', 1;

        SET @IdUsuarioAuditoria = COALESCE(@IdUsuarioAuditoria, @IdAdministrador, 0);

        IF @@TRANCOUNT = 0
            BEGIN TRANSACTION;

        INSERT dbo.ff_Menu
            (MENombreMenu, MERutaLiga, MEComentarios, MEPadre, METarget, MEOrden,
             MEIcono, MEMenuPadre, MEIdPagina, MEidTipoNegocio, MEIdEstatus,
             MEUsuarioAdd, MEFechaAdd)
        VALUES
            (N'Administración de Solicitudes', '/solicitudes',
             'Menu padre para la administracion de solicitudes.', 1, NULL,
             ISNULL((SELECT MAX(m.MEOrden) FROM dbo.ff_Menu m WHERE m.MEPadre = 1), 0) + 1,
             1, NULL, NULL, @IdTipoNegocio, 1, @IdUsuarioAuditoria, GETDATE());

        SET @IdMenuPadreSolicitudes = CONVERT(INT, SCOPE_IDENTITY());
        INSERT @PadresCandidatos (idMenu) VALUES (@IdMenuPadreSolicitudes);
        PRINT 'Se creo el menu padre Solicitudes con id '
            + CONVERT(VARCHAR(20), @IdMenuPadreSolicitudes) + '.';
    END;

    IF @IdMenuPadreSolicitudes IS NULL
    BEGIN
        SELECT
            'RESULTADO_PADRES_CANDIDATOS' AS bloque,
            m.MEidMenu AS idMenu,
            m.MENombreMenu AS menu,
            m.MERutaLiga AS ruta,
            m.MEMenuPadre AS idMenuPadre,
            m.MEidTipoNegocio AS idTipoNegocio
        FROM @PadresCandidatos p
        INNER JOIN dbo.ff_Menu m ON m.MEidMenu = p.idMenu;
        THROW 50406, 'No se identifico un unico menu padre Solicitudes. Capture @IdMenuPadreSolicitudes.', 1;
    END;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.ff_Menu
        WHERE MEidMenu = @IdMenuPadreSolicitudes AND MEIdEstatus = 1 AND MEPadre = 1)
        THROW 50407, 'El menu padre de Solicitudes no existe, esta inactivo o no es padre.', 1;

    SET @IdUsuarioAuditoria = COALESCE(@IdUsuarioAuditoria, @IdAdministrador, 0);

    /* La creacion y las asignaciones se confirman juntas al final. */
    IF @@TRANCOUNT = 0
        BEGIN TRANSACTION;

    INSERT dbo.ff_Menu
        (MENombreMenu, MERutaLiga, MEComentarios, MEPadre, METarget, MEOrden,
         MEIcono, MEMenuPadre, MEIdPagina, MEidTipoNegocio, MEIdEstatus,
         MEUsuarioAdd, MEFechaAdd)
    SELECT
        @NombreMenu, @RutaMenu, 'Pantalla B3 de Defaulteo basico, avanzado e historico.',
        0, NULL,
        ISNULL((SELECT MAX(h.MEOrden) FROM dbo.ff_Menu h
                WHERE h.MEMenuPadre = @IdMenuPadreSolicitudes), 0) + 1,
        1, @IdMenuPadreSolicitudes, NULL, p.MEidTipoNegocio, 1,
        @IdUsuarioAuditoria, GETDATE()
    FROM dbo.ff_Menu p
    WHERE p.MEidMenu = @IdMenuPadreSolicitudes;

    SET @IdMenuDefaulteo = CONVERT(INT, SCOPE_IDENTITY());
    PRINT 'Se creo la opcion ff_Menu de Defaulteo con id ' + CONVERT(VARCHAR(20), @IdMenuDefaulteo) + '.';
END;

IF @IdMenuDefaulteo IS NULL
BEGIN
    PRINT 'DETENIDO: no existe un menu de Defaulteo univoco. Revise RESULTADO_MENU_CANDIDATO.';
    PRINT 'Si no existe, use @CrearMenuSiNoExiste=1; si hay varios, capture @IdMenuDefaulteo.';
    RETURN;
END;

SELECT @IdMenuPadreSolicitudes = COALESCE(@IdMenuPadreSolicitudes, MEMenuPadre)
FROM dbo.ff_Menu
WHERE MEidMenu = @IdMenuDefaulteo;

IF @IdMenuPadreSolicitudes IS NULL OR NOT EXISTS (
    SELECT 1 FROM dbo.ff_Menu
    WHERE MEidMenu = @IdMenuPadreSolicitudes AND MEIdEstatus = 1)
    THROW 50408, 'La opcion Defaulteo no tiene un menu padre activo.', 1;

/* Resultado antes de aplicar. Ambos menus deben estar asignados al rol. */
SELECT
    'RESULTADO_VISIBILIDAD' AS bloque,
    @IdEmpresa AS idEmpresa,
    @IdAdministrador AS idAdministrador,
    @RolObjetivo AS idRol,
    r.RODescripcionCorta AS rol,
    @IdMenuPadreSolicitudes AS idMenuSolicitudes,
    p.MENombreMenu AS menuSolicitudes,
    CONVERT(BIT, CASE WHEN EXISTS (
        SELECT 1 FROM dbo.ff_MenuRol2 mr
        WHERE mr.MRidRol = @RolObjetivo
          AND mr.MRidMenu = @IdMenuPadreSolicitudes
          AND ISNULL(mr.MRidEstatus, 1) <> 2) THEN 1 ELSE 0 END) AS padreAsignado,
    @IdMenuDefaulteo AS idMenuDefaulteo,
    h.MENombreMenu AS menuDefaulteo,
    h.MERutaLiga AS rutaMenu,
    CONVERT(BIT, CASE WHEN EXISTS (
        SELECT 1 FROM dbo.ff_MenuRol2 mr
        WHERE mr.MRidRol = @RolObjetivo
          AND mr.MRidMenu = @IdMenuDefaulteo
          AND ISNULL(mr.MRidEstatus, 1) <> 2) THEN 1 ELSE 0 END) AS defaulteoAsignado,
    @RutaDirecta AS rutaDirecta
FROM dbo.ff_Rol r
INNER JOIN dbo.ff_Menu p ON p.MEidMenu = @IdMenuPadreSolicitudes
INNER JOIN dbo.ff_Menu h ON h.MEidMenu = @IdMenuDefaulteo
WHERE r.ROIdRol = @RolObjetivo;

IF @Aplicar = 0
BEGIN
    PRINT 'MODO DIAGNOSTICO: no se realizo ningun cambio. Para habilitar use @Aplicar=1.';
    RETURN;
END;

SET @IdUsuarioAuditoria = COALESCE(@IdUsuarioAuditoria, @IdAdministrador, 0);

IF @@TRANCOUNT = 0
    BEGIN TRANSACTION;

/* Normaliza la liga al contrato real de AdministracionComponent, que agrega
   el prefijo pages/ antes de llamar al Router de Angular. */
UPDATE dbo.ff_Menu
SET MERutaLiga = @RutaMenu,
    MEUsuarioUMod = @IdUsuarioAuditoria,
    MEFechaUMod = GETDATE()
WHERE MEidMenu = @IdMenuDefaulteo;

DECLARE @MenusAsignar TABLE (idMenu INT NOT NULL PRIMARY KEY);
INSERT @MenusAsignar (idMenu)
VALUES (@IdMenuPadreSolicitudes), (@IdMenuDefaulteo);

DECLARE @MenuActual INT;
DECLARE menus_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT idMenu FROM @MenusAsignar;

OPEN menus_cursor;
FETCH NEXT FROM menus_cursor INTO @MenuActual;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM dbo.ff_MenuRol2
        WHERE MRidRol = @RolObjetivo
          AND MRidMenu = @MenuActual
          AND ISNULL(MRidEstatus, 1) <> 2)
    BEGIN
        DECLARE @IdAsignacion INT = NULL;
        SELECT TOP (1) @IdAsignacion = MRidMenuRol
        FROM dbo.ff_MenuRol2
        WHERE MRidRol = @RolObjetivo AND MRidMenu = @MenuActual
        ORDER BY MRidMenuRol;

        IF @IdAsignacion IS NOT NULL
            UPDATE dbo.ff_MenuRol2
               SET MRidEstatus = 1,
                   MRUsuarioUMod = @IdUsuarioAuditoria,
                   MRFechaUMod = GETDATE(),
                   MRUsuarioDel = NULL,
                   MRFechaDel = NULL
             WHERE MRidMenuRol = @IdAsignacion;
        ELSE
            INSERT dbo.ff_MenuRol2
                (MRidRol, MRidMenu, MRidEstatus, MRUsuarioAdd, MRFechaAdd,
                 MRRutaBanner, MRImagenMenu)
            SELECT
                @RolObjetivo, @MenuActual, 1, @IdUsuarioAuditoria, GETDATE(),
                referencia.MRRutaBanner, referencia.MRImagenMenu
            FROM (SELECT 1 AS n) x
            OUTER APPLY (
                SELECT TOP (1) mr.MRRutaBanner, mr.MRImagenMenu
                FROM dbo.ff_MenuRol2 mr
                WHERE mr.MRidMenu = @MenuActual
                ORDER BY CASE WHEN ISNULL(mr.MRidEstatus, 1) <> 2 THEN 0 ELSE 1 END,
                         mr.MRidMenuRol
            ) referencia;
    END;

    FETCH NEXT FROM menus_cursor INTO @MenuActual;
END;
CLOSE menus_cursor;
DEALLOCATE menus_cursor;

COMMIT TRANSACTION;

SELECT
    'RESULTADO_FINAL' AS bloque,
    mr.MRidRol AS idRol,
    r.RODescripcionCorta AS rol,
    mr.MRidMenu AS idMenu,
    m.MENombreMenu AS menu,
    m.MERutaLiga AS ruta,
    mr.MRidEstatus AS estatus,
    mr.MRImagenMenu AS imagen,
    CASE WHEN mr.MRidMenu = @IdMenuDefaulteo THEN @RutaDirecta ELSE NULL END AS rutaDirecta
FROM dbo.ff_MenuRol2 mr
INNER JOIN dbo.ff_Rol r ON r.ROIdRol = mr.MRidRol
INNER JOIN dbo.ff_Menu m ON m.MEidMenu = mr.MRidMenu
WHERE mr.MRidRol = @RolObjetivo
  AND mr.MRidMenu IN (@IdMenuPadreSolicitudes, @IdMenuDefaulteo)
  AND ISNULL(mr.MRidEstatus, 1) <> 2
ORDER BY m.MEPadre DESC, m.MEOrden, m.MEidMenu;

PRINT 'LISTO: cierre sesion y vuelva a ingresar para renovar identity/menurol del localStorage.';
PRINT 'Tambien puede validar directamente la ruta ' + @RutaDirecta + '.';
GO
