/*
    SELECTS DE INSUMOS DEL MENU BF3 (JAVA) - EMPRESA 186

    Flujo real usado por BF3:
      ff_AdministradorEmpresa -> ff_Rol -> ff_MenuRol2 -> ff_Menu

    Java ejecuta la equivalencia de:
      SELECT ...
      FROM dbo.ff_MenuRol2 mr
      INNER JOIN dbo.ff_Menu m ON m.MEidMenu = mr.MRidMenu
      WHERE mr.MRidEstatus <> 2 AND mr.MRidRol = @IdRol
      ORDER BY m.MEOrden;

    Este archivo es de solo lectura sobre tablas permanentes. Las tablas
    temporales se usan únicamente para acotar el resultado a la empresa 186.

    Para exportar un solo administrador, capture @IdAdministrador.
    Con NULL se exportan todos los roles/asignaciones activos de la empresa.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @IdEmpresa INT = 186;
DECLARE @IdAdministrador INT = NULL;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.ff_Empresa E
    WHERE E.EMidEmpresa = @IdEmpresa
)
    THROW 51200, 'La empresa 186 no existe en la base origen.', 1;

DROP TABLE IF EXISTS #RolesBF3;
DROP TABLE IF EXISTS #MenusBF3;

CREATE TABLE #RolesBF3
(
    ROIdRol INT NOT NULL PRIMARY KEY
);

/* Roles realmente asignados a administradores de la empresa. */
INSERT #RolesBF3 (ROIdRol)
SELECT DISTINCT AE.AEIdRol
FROM dbo.ff_AdministradorEmpresa AE
INNER JOIN dbo.ff_Rol R
    ON R.ROIdRol = AE.AEIdRol
WHERE AE.AEIdEmpresa = @IdEmpresa
  AND AE.AEIdEstatus = 1
  AND R.ROIdEstatus = 1
  AND AE.AEIdRol IS NOT NULL
  AND (@IdAdministrador IS NULL OR AE.ADIdAdministrador = @IdAdministrador);

CREATE TABLE #MenusBF3
(
    MEidMenu INT NOT NULL PRIMARY KEY
);

/* Menús asignados por ff_MenuRol2. */
INSERT #MenusBF3 (MEidMenu)
SELECT DISTINCT MR.MRidMenu
FROM dbo.ff_MenuRol2 MR
INNER JOIN #RolesBF3 R ON R.ROIdRol = MR.MRidRol
WHERE ISNULL(MR.MRidEstatus, 1) <> 2;

/* Agrega padres que no estuvieran asignados directamente al rol. */
WHILE 1 = 1
BEGIN
    INSERT #MenusBF3 (MEidMenu)
    SELECT DISTINCT M.MEMenuPadre
    FROM dbo.ff_Menu M
    INNER JOIN #MenusBF3 X ON X.MEidMenu = M.MEidMenu
    WHERE M.MEMenuPadre IS NOT NULL
      AND M.MEMenuPadre > 0
      AND NOT EXISTS
      (
          SELECT 1
          FROM #MenusBF3 Y
          WHERE Y.MEidMenu = M.MEMenuPadre
      );

    IF @@ROWCOUNT = 0 BREAK;
END;

/* 00. Control del paquete. */
SELECT
    '00_MANIFIESTO_MENU_BF3' AS __Tabla,
    @IdEmpresa AS IdEmpresa,
    @IdAdministrador AS IdAdministrador,
    (SELECT COUNT(*) FROM dbo.ff_AdministradorEmpresa AE
     WHERE AE.AEIdEmpresa = @IdEmpresa
       AND AE.AEIdEstatus = 1
       AND (@IdAdministrador IS NULL OR AE.ADIdAdministrador = @IdAdministrador)) AS AsignacionesAdministradorEmpresa,
    (SELECT COUNT(*) FROM #RolesBF3) AS RolesBF3,
    (SELECT COUNT(*) FROM dbo.ff_MenuRol2 MR
     INNER JOIN #RolesBF3 R ON R.ROIdRol = MR.MRidRol
     WHERE ISNULL(MR.MRidEstatus, 1) <> 2) AS AsignacionesMenuRol2,
    (SELECT COUNT(*) FROM #MenusBF3) AS MenusIncluidos;

/* 01. Asignación administrador/empresa/rol. */
SELECT 'dbo.ff_AdministradorEmpresa' AS __Tabla, AE.*
FROM dbo.ff_AdministradorEmpresa AE
WHERE AE.AEIdEmpresa = @IdEmpresa
  AND AE.AEIdEstatus = 1
  AND (@IdAdministrador IS NULL OR AE.ADIdAdministrador = @IdAdministrador)
ORDER BY AE.ADIdAdministrador, AE.AEIdRol, AE.AEIdr;

/* 02. Roles requeridos por BF3. */
SELECT 'dbo.ff_Rol' AS __Tabla, R.*
FROM dbo.ff_Rol R
INNER JOIN #RolesBF3 X ON X.ROIdRol = R.ROIdRol
ORDER BY R.ROIdRol;

/* 03. Catálogo de menús asignados y sus padres. */
SELECT 'dbo.ff_Menu' AS __Tabla, M.*
FROM dbo.ff_Menu M
INNER JOIN #MenusBF3 X ON X.MEidMenu = M.MEidMenu
ORDER BY
    CASE WHEN M.MEPadre = 1 THEN 0 ELSE 1 END,
    M.MEMenuPadre,
    M.MEOrden,
    M.MEidMenu;

/* 04. Relaciones rol/menú consumidas directamente por Java. */
SELECT 'dbo.ff_MenuRol2' AS __Tabla, MR.*
FROM dbo.ff_MenuRol2 MR
INNER JOIN #RolesBF3 R ON R.ROIdRol = MR.MRidRol
WHERE ISNULL(MR.MRidEstatus, 1) <> 2
ORDER BY MR.MRidRol, MR.MRidMenuRol;

/* 05. Administradores identificables, sin exportar contraseñas. */
SELECT
    'REFERENCIA_ADMINISTRADOR_SIN_CREDENCIALES' AS __Tabla,
    A.ADIdAdministrador,
    A.ADClaveAcceso,
    LTRIM(RTRIM(ISNULL(A.ADNombres, '') + ' '
        + ISNULL(A.ADApellidoPaterno, '') + ' '
        + ISNULL(A.ADApellidoMaterno, ''))) AS Administrador,
    A.ADIdEstatus,
    AE.AEIdEmpresa,
    AE.AEIdRol,
    AE.AEidTipoNegocio
FROM dbo.ff_AdministradorEmpresa AE
INNER JOIN dbo.ff_Administrador A
    ON A.ADIdAdministrador = AE.ADIdAdministrador
WHERE AE.AEIdEmpresa = @IdEmpresa
  AND AE.AEIdEstatus = 1
  AND (@IdAdministrador IS NULL OR AE.ADIdAdministrador = @IdAdministrador)
ORDER BY A.ADClaveAcceso, AE.AEIdRol;

/* 06. Resultado exacto que recibirá el endpoint Java por cada rol. */
SELECT
    'VALIDACION_ENDPOINT_JAVA' AS __Tabla,
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
INNER JOIN #RolesBF3 R
    ON R.ROIdRol = MR.MRidRol
WHERE ISNULL(MR.MRidEstatus, 1) <> 2
ORDER BY MR.MRidRol, M.MEOrden;

/* 07. Confirmación específica del acceso a Defaulteo BF3. */
SELECT
    'VALIDACION_DEFAULTEO_BF3' AS __Tabla,
    MR.MRidRol,
    MR.MRidMenu,
    M.MENombreMenu,
    M.MERutaLiga,
    M.MEMenuPadre,
    M.MEIdEstatus,
    MR.MRidEstatus
FROM dbo.ff_MenuRol2 MR
INNER JOIN dbo.ff_Menu M
    ON M.MEidMenu = MR.MRidMenu
INNER JOIN #RolesBF3 R
    ON R.ROIdRol = MR.MRidRol
WHERE ISNULL(MR.MRidEstatus, 1) <> 2
  AND
  (
      LOWER(ISNULL(M.MERutaLiga, '')) LIKE '%defaulteo%'
      OR LOWER(ISNULL(M.MENombreMenu, '')) LIKE '%defaulteo%'
      OR LOWER(ISNULL(M.MENombreMenu, '')) LIKE '%solicitud%'
  )
ORDER BY MR.MRidRol, M.MEOrden;

SELECT
    '99_FIN_MENU_BF3' AS __Tabla,
    @IdEmpresa AS IdEmpresa,
    (SELECT COUNT(*) FROM #RolesBF3) AS RolesExportados,
    (SELECT COUNT(*) FROM #MenusBF3) AS MenusExportados;
