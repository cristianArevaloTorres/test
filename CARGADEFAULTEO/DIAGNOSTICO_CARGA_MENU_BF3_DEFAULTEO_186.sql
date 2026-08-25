
Bloque	ADIdAdministrador	ADClaveAcceso	Administrador	AEIdEmpresa	AEIdRol	AEIdEstatus	Rol	Resultado
05_USUARIO_EMPRESA_ROL	NULL	NULL		NULL	NULL	NULL	NULL	FALTA: ASIGNACION EN ff_AdministradorEmpresa

  Bloque	IdEmpresa	IdRol	IdMenuCargaMasiva	IdMenuDefaulteo	ResultadoMenuBD	ResultadoSeguridad	URLDirecta	SiguienteRevision
07_RESUMEN	186	570	583	566	OK_MENU_BD	OK_USUARIO_EMPRESA_ROL	/pages/administracion/solicitudes/defaulteo	Si ResultadoMenuBD es OK y la URL directa regresa a /pages/home, el frontend ejecutado no contiene la ruta nueva o conserva un build/cache anterior.

  Bloque	IdMenuCargaMasiva	MenuCargaMasiva	RutaCargaMasiva	PadreCargaMasiva	OrdenCargaMasiva	IdRelacionCargaMasiva	ImagenCargaMasiva	IdMenuDefaulteo	MenuDefaulteo	RutaDefaulteo	URLFinalCalculada	PadreDefaulteo	OrdenDefaulteo	IdRelacionDefaulteo	ImagenDefaulteo	ValidacionMenu	ValidacionRol	ValidacionRuta	ValidacionNivel	ValidacionOrden	ValidacionIcono
02_COMPARACION_CARGA_VS_DEFAULTEO	583	Carga Masiva	/cargamasivapoblaciones	580	10	31916	Boton_CARGA MASIVA.png	566	Defaulteo	administracion/solicitudes/defaulteo	/pages/administracion/solicitudes/defaulteo	580	11	31919	Boton_CARGA MASIVA.png	OK	OK	OK	OK	OK	OK
  






/*
  DIAGNOSTICO DE CARGA DEL MENU BF3 - DEFAULTEO, EMPRESA 186

  SOLO LECTURA: este script no inserta, actualiza ni elimina registros.

  Reproduce el SELECT que ejecuta Java en:
    JDBCFfMenusRol.consultarMenusPorRol2(int idRol)

  Angular llama:
    POST /beflex/menu/rol/2
    body: { "idRol": 570 }

  La tarjeta navega agregando "pages/" a MERutaLiga. Por eso Defaulteo debe
  guardar: administracion/solicitudes/defaulteo
  y la URL final es: /pages/administracion/solicitudes/defaulteo
*/
SET NOCOUNT ON;

/* ===================== UNICOS DATOS EDITABLES ===================== */
DECLARE @IdEmpresa INT = 186;
DECLARE @IdRol INT = 570;
DECLARE @IdAdministrador INT = NULL;       -- Opcional: ID del usuario que inicia sesion.
DECLARE @ClaveAdministrador VARCHAR(50) = NULL; -- Opcional: clave/login del usuario.
/* ================================================================= */

DECLARE @RutaDefaulteo VARCHAR(300) = 'administracion/solicitudes/defaulteo';
DECLARE @IdMenuCarga INT;
DECLARE @IdMenuDefaulteo INT;
DECLARE @IdMenuPadre INT;

/* 1. Este es el SELECT REAL utilizado por el backend Java de BF3. */
SELECT
    '01_SELECT_REAL_JAVA' AS Bloque,
    MR.MRidRol,
    MR.MRidMenu,
    M.MEPadre,
    M.MEMenuPadre,
    M.MENombreMenu,
    M.MERutaLiga,
    M.MEOrden,
    MR.MRRutaBanner,
    MR.MRImagenMenu
FROM dbo.ff_MenuRol2 MR
INNER JOIN dbo.ff_Menu M
    ON M.MEidMenu = MR.MRidMenu
WHERE MR.MRidEstatus <> 2
  AND MR.MRidRol = @IdRol
ORDER BY M.MEOrden;

/* 2. Referencia funcional: Carga Masiva visible para el rol 570. */
SELECT TOP (1)
    @IdMenuCarga = M.MEIdMenu,
    @IdMenuPadre = M.MEMenuPadre
FROM dbo.ff_Menu M
INNER JOIN dbo.ff_MenuRol2 MR
    ON MR.MRidMenu = M.MEIdMenu
   AND MR.MRidRol = @IdRol
   AND ISNULL(MR.MRidEstatus, 1) <> 2
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
    CASE WHEN LOWER(LTRIM(RTRIM(ISNULL(M.MERutaLiga, '')))) = '/cargamasivapoblaciones'
         THEN 0 ELSE 1 END,
    M.MEIdMenu;

/* 3. Localiza el Defaulteo que el backend debería devolver. */
SELECT TOP (1)
    @IdMenuDefaulteo = M.MEIdMenu
FROM dbo.ff_Menu M
LEFT JOIN dbo.ff_MenuRol2 MR
    ON MR.MRidMenu = M.MEIdMenu
   AND MR.MRidRol = @IdRol
   AND ISNULL(MR.MRidEstatus, 1) <> 2
WHERE LOWER(LTRIM(RTRIM(ISNULL(M.MERutaLiga, '')))) NOT LIKE '%casos-especiales%'
  AND
  (
      LOWER(LTRIM(RTRIM(ISNULL(M.MERutaLiga, '')))) IN
      (
          '/defaulteo', 'defaulteo',
          '/solicitudes/defaulteo', 'solicitudes/defaulteo',
          '/administracion/solicitudes/defaulteo', 'administracion/solicitudes/defaulteo',
          '/pages/administracion/solicitudes/defaulteo',
          'pages/administracion/solicitudes/defaulteo'
      )
      OR LOWER(LTRIM(RTRIM(M.MENombreMenu))) IN
         (N'defaulteo', N'defaulteo de cotizaciones', N'crear y actualizar solicitudes')
  )
ORDER BY
    CASE WHEN MR.MRidMenuRol IS NOT NULL THEN 0 ELSE 1 END,
    CASE WHEN M.MEMenuPadre = @IdMenuPadre THEN 0 ELSE 1 END,
    CASE WHEN LOWER(LTRIM(RTRIM(ISNULL(M.MERutaLiga, '')))) = @RutaDefaulteo
         THEN 0 ELSE 1 END,
    CASE WHEN M.MEIdEstatus = 1 THEN 0 ELSE 1 END,
    M.MEIdMenu;

/* 4. Comparación directa Carga Masiva contra Defaulteo. */
SELECT
    '02_COMPARACION_CARGA_VS_DEFAULTEO' AS Bloque,
    C.MEIdMenu AS IdMenuCargaMasiva,
    C.MENombreMenu AS MenuCargaMasiva,
    C.MERutaLiga AS RutaCargaMasiva,
    C.MEMenuPadre AS PadreCargaMasiva,
    C.MEOrden AS OrdenCargaMasiva,
    CMR.MRIdMenuRol AS IdRelacionCargaMasiva,
    CMR.MRImagenMenu AS ImagenCargaMasiva,
    D.MEIdMenu AS IdMenuDefaulteo,
    D.MENombreMenu AS MenuDefaulteo,
    D.MERutaLiga AS RutaDefaulteo,
    '/pages/' + LTRIM(RTRIM(ISNULL(D.MERutaLiga, ''))) AS URLFinalCalculada,
    D.MEMenuPadre AS PadreDefaulteo,
    D.MEOrden AS OrdenDefaulteo,
    DMR.MRIdMenuRol AS IdRelacionDefaulteo,
    DMR.MRImagenMenu AS ImagenDefaulteo,
    CASE WHEN D.MEIdEstatus = 1 THEN 'OK' ELSE 'FALTA: MENU INACTIVO' END AS ValidacionMenu,
    CASE WHEN DMR.MRidMenuRol IS NOT NULL THEN 'OK' ELSE 'FALTA: RELACION ff_MenuRol2' END AS ValidacionRol,
    CASE WHEN D.MERutaLiga = @RutaDefaulteo THEN 'OK' ELSE 'FALTA: RUTA INCORRECTA' END AS ValidacionRuta,
    CASE WHEN D.MEMenuPadre = C.MEMenuPadre THEN 'OK' ELSE 'FALTA: PADRE DISTINTO' END AS ValidacionNivel,
    CASE WHEN D.MEOrden = C.MEOrden + 1 THEN 'OK' ELSE 'REVISAR: ORDEN DISTINTO' END AS ValidacionOrden,
    CASE WHEN ISNULL(DMR.MRImagenMenu, '') = ISNULL(CMR.MRImagenMenu, '')
         THEN 'OK' ELSE 'REVISAR: ICONO DISTINTO' END AS ValidacionIcono
FROM dbo.ff_Menu C
LEFT JOIN dbo.ff_MenuRol2 CMR
    ON CMR.MRidMenu = C.MEIdMenu
   AND CMR.MRidRol = @IdRol
   AND ISNULL(CMR.MRidEstatus, 1) <> 2
FULL JOIN dbo.ff_Menu D
    ON D.MEIdMenu = @IdMenuDefaulteo
LEFT JOIN dbo.ff_MenuRol2 DMR
    ON DMR.MRidMenu = D.MEIdMenu
   AND DMR.MRidRol = @IdRol
   AND ISNULL(DMR.MRidEstatus, 1) <> 2
WHERE C.MEIdMenu = @IdMenuCarga
   OR (@IdMenuCarga IS NULL AND D.MEIdMenu = @IdMenuDefaulteo);

/* 5. El padre también debe estar activo y asignado al rol. */
SELECT
    '03_MENU_PADRE' AS Bloque,
    P.MEIdMenu AS IdMenuPadre,
    P.MENombreMenu AS MenuPadre,
    P.MERutaLiga AS RutaPadre,
    P.MEIdEstatus AS EstatusMenu,
    PMR.MRIdMenuRol,
    PMR.MRidRol,
    PMR.MRidEstatus AS EstatusRelacion,
    CASE
        WHEN P.MEIdMenu IS NULL THEN 'FALTA: MENU PADRE'
        WHEN P.MEIdEstatus <> 1 THEN 'FALTA: PADRE INACTIVO'
        WHEN PMR.MRIdMenuRol IS NULL THEN 'FALTA: PADRE NO ASIGNADO AL ROL'
        ELSE 'OK'
    END AS Resultado
FROM (SELECT @IdMenuPadre AS IdMenuPadre) X
LEFT JOIN dbo.ff_Menu P
    ON P.MEIdMenu = X.IdMenuPadre
LEFT JOIN dbo.ff_MenuRol2 PMR
    ON PMR.MRidMenu = P.MEIdMenu
   AND PMR.MRidRol = @IdRol
   AND ISNULL(PMR.MRidEstatus, 1) <> 2;

/* 6. Los duplicados activos pueden producir tarjetas repetidas o ambiguas. */
SELECT
    '04_DUPLICADOS_DEFAULTEO' AS Bloque,
    M.MEIdMenu,
    M.MENombreMenu,
    M.MERutaLiga,
    M.MEMenuPadre,
    M.MEOrden,
    MR.MRIdMenuRol,
    MR.MRidEstatus
FROM dbo.ff_MenuRol2 MR
INNER JOIN dbo.ff_Menu M
    ON M.MEIdMenu = MR.MRidMenu
WHERE MR.MRidRol = @IdRol
  AND ISNULL(MR.MRidEstatus, 1) <> 2
  AND LOWER(LTRIM(RTRIM(ISNULL(M.MERutaLiga, '')))) NOT LIKE '%casos-especiales%'
  AND
  (
      LOWER(LTRIM(RTRIM(ISNULL(M.MERutaLiga, '')))) LIKE '%defaulteo%'
      OR LOWER(LTRIM(RTRIM(M.MENombreMenu))) IN
         (N'defaulteo', N'defaulteo de cotizaciones', N'crear y actualizar solicitudes')
  )
ORDER BY M.MEIdMenu, MR.MRIdMenuRol;

/* 7. Seguridad de inicio de sesión: usuario + empresa debe resolver el rol 570. */
IF @IdAdministrador IS NULL
   AND NULLIF(LTRIM(RTRIM(@ClaveAdministrador)), '') IS NOT NULL
BEGIN
    SELECT TOP (1) @IdAdministrador = A.ADIdAdministrador
    FROM dbo.ff_Administrador A
    WHERE A.ADClaveAcceso = LTRIM(RTRIM(@ClaveAdministrador))
      AND A.ADIdEstatus = 1
    ORDER BY A.ADIdAdministrador;
END;

SELECT
    '05_USUARIO_EMPRESA_ROL' AS Bloque,
    A.ADIdAdministrador,
    A.ADClaveAcceso,
    LTRIM(RTRIM(ISNULL(A.ADNombres, '') + ' ' +
                ISNULL(A.ADApellidoPaterno, '') + ' ' +
                ISNULL(A.ADApellidoMaterno, ''))) AS Administrador,
    AE.AEIdEmpresa,
    AE.AEIdRol,
    AE.AEIdEstatus,
    R.RODescripcionCorta AS Rol,
    CASE
        WHEN AE.ADIdAdministrador IS NULL THEN 'FALTA: ASIGNACION EN ff_AdministradorEmpresa'
        WHEN AE.AEIdRol <> @IdRol THEN 'REVISAR: EL USUARIO TIENE OTRO ROL'
        WHEN AE.AEIdEstatus <> 1 THEN 'FALTA: ASIGNACION INACTIVA'
        ELSE 'OK'
    END AS Resultado
FROM (SELECT @IdAdministrador AS IdAdministrador) X
LEFT JOIN dbo.ff_Administrador A
    ON A.ADIdAdministrador = X.IdAdministrador
LEFT JOIN dbo.ff_AdministradorEmpresa AE
    ON AE.ADIdAdministrador = A.ADIdAdministrador
   AND AE.AEIdEmpresa = @IdEmpresa
LEFT JOIN dbo.ff_Rol R
    ON R.ROIdRol = AE.AEIdRol;

/* Si no se capturó usuario, muestra todas las asignaciones disponibles. */
IF @IdAdministrador IS NULL
BEGIN
    SELECT
        '06_ASIGNACIONES_DISPONIBLES_EMPRESA' AS Bloque,
        AE.ADIdAdministrador,
        A.ADClaveAcceso,
        LTRIM(RTRIM(ISNULL(A.ADNombres, '') + ' ' +
                    ISNULL(A.ADApellidoPaterno, '') + ' ' +
                    ISNULL(A.ADApellidoMaterno, ''))) AS Administrador,
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
    ORDER BY AE.AEIdEstatus, A.ADClaveAcceso, AE.AEIdRol;
END;

/* 8. Resumen: permite distinguir un problema de BD de un frontend sin ruta. */
SELECT
    '07_RESUMEN' AS Bloque,
    @IdEmpresa AS IdEmpresa,
    @IdRol AS IdRol,
    @IdMenuCarga AS IdMenuCargaMasiva,
    @IdMenuDefaulteo AS IdMenuDefaulteo,
    CASE
        WHEN @IdMenuCarga IS NULL THEN 'REVISAR: NO SE ENCONTRO CARGA MASIVA PARA EL ROL'
        WHEN @IdMenuDefaulteo IS NULL THEN 'REVISAR: NO SE ENCONTRO DEFAULTEO'
        WHEN NOT EXISTS
        (
            SELECT 1
            FROM dbo.ff_Menu M
            INNER JOIN dbo.ff_MenuRol2 MR
                ON MR.MRidMenu = M.MEIdMenu
               AND MR.MRidRol = @IdRol
               AND ISNULL(MR.MRidEstatus, 1) <> 2
            WHERE M.MEIdMenu = @IdMenuDefaulteo
              AND M.MEIdEstatus = 1
              AND M.MERutaLiga = @RutaDefaulteo
        ) THEN 'REVISAR: DEFAULTEO NO CUMPLE EL SELECT DE JAVA'
        WHEN NOT EXISTS
        (
            SELECT 1
            FROM dbo.ff_MenuRol2 MR
            WHERE MR.MRidRol = @IdRol
              AND MR.MRidMenu = @IdMenuPadre
              AND ISNULL(MR.MRidEstatus, 1) <> 2
        ) THEN 'REVISAR: MENU PADRE NO ASIGNADO AL ROL'
        ELSE 'OK_MENU_BD'
    END AS ResultadoMenuBD,
    CASE
        WHEN EXISTS
        (
            SELECT 1
            FROM dbo.ff_AdministradorEmpresa AE
            WHERE AE.AEIdEmpresa = @IdEmpresa
              AND AE.AEIdRol = @IdRol
              AND AE.AEIdEstatus = 1
              AND (@IdAdministrador IS NULL OR AE.ADIdAdministrador = @IdAdministrador)
        ) THEN 'OK_USUARIO_EMPRESA_ROL'
        ELSE 'REVISAR: NO HAY USUARIO ACTIVO DE LA EMPRESA CON ROL 570'
    END AS ResultadoSeguridad,
    '/pages/administracion/solicitudes/defaulteo' AS URLDirecta,
    CASE
        WHEN @IdMenuDefaulteo IS NOT NULL THEN
            'Si ResultadoMenuBD es OK y la URL directa regresa a /pages/home, el frontend ejecutado no contiene la ruta nueva o conserva un build/cache anterior.'
        ELSE
            'Corrija primero los bloques de BD marcados como REVISAR/FALTA.'
    END AS SiguienteRevision;
GO
