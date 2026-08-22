/*
   ASIGNAR REPORTE DE COBRANZA AL MENU B3 DE ZURICH SANTANDER

   - Empresa: 1807
   - B3 consume ff_MenuRol2 mediante /menu/rol/2.
   - Incluye automaticamente los menus padre requeridos.
   - Inicia en vista previa: no cambia datos hasta usar @Aplicar=1.

   Primero ejecute con @IdRolObjetivo=NULL y @Aplicar=0. Copie el IdRol del
   usuario correcto, coloquelo en @IdRolObjetivo, revise la vista previa y solo
   entonces cambie @Aplicar a 1.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @IdEmpresa int=1807,
        @IdRolObjetivo int=NULL,  -- completar con el rol mostrado en la primera consulta
        @Aplicar bit=0,           -- 0 = vista previa; 1 = asignar menu
        @UsuarioAuditoria int=1,
        @IdMenuCobranza int;

IF OBJECT_ID(N'dbo.ff_Menu',N'U') IS NULL
   OR OBJECT_ID(N'dbo.ff_MenuRol2',N'U') IS NULL
   OR OBJECT_ID(N'dbo.ff_Rol',N'U') IS NULL
    THROW 52950,'Faltan tablas de menu B3.',1;

/* Usuarios y roles disponibles: no muestra contrasenas ni claves de acceso. */
SELECT A.ADIdAdministrador,A.ADNombres,A.ADApellidoPaterno,A.ADApellidoMaterno,
       A.ADCorreoElectronico,AE.AEIdRol,R.RODescripcionCorta,R.RODescripcionLarga,
       R.ROAdministrador,AE.AEIdEstatus AS EstatusAsignacion,R.ROIdEstatus AS EstatusRol
FROM dbo.ff_AdministradorEmpresa AS AE WITH(NOLOCK)
INNER JOIN dbo.ff_Administrador AS A WITH(NOLOCK)
        ON A.ADIdAdministrador=AE.ADIdAdministrador
INNER JOIN dbo.ff_Rol AS R WITH(NOLOCK)
        ON R.ROIdRol=AE.AEIdRol
WHERE AE.AEIdEmpresa=@IdEmpresa
  AND AE.AEIdEstatus=1
  AND A.ADIdEstatus=1
  AND R.ROIdEstatus=1
ORDER BY A.ADNombres,A.ADApellidoPaterno,AE.AEIdRol;

IF @IdRolObjetivo IS NULL
BEGIN
    SELECT N'SOLO_CONSULTA' AS Resultado,
           N'Copie el AEIdRol del usuario, asignelo a @IdRolObjetivo y vuelva a ejecutar con @Aplicar=0.' AS SiguientePaso;
    RETURN;
END;

IF NOT EXISTS
(
    SELECT 1 FROM dbo.ff_Rol
    WHERE ROIdRol=@IdRolObjetivo AND ROIdEmpresa=@IdEmpresa AND ROIdEstatus=1
)
    THROW 52951,'El rol indicado no pertenece a la empresa 1807 o esta inactivo.',1;

/* Prioriza la ruta real de B3; el nombre se usa solamente como respaldo. */
SELECT TOP(1) @IdMenuCobranza=M.MEIdMenu
FROM dbo.ff_Menu AS M WITH(NOLOCK)
WHERE M.MEIdEstatus=1
  AND
  (
      LOWER(REPLACE(ISNULL(M.MERutaLiga,''),'\','/')) LIKE '%reportes/cobranza%'
      OR LOWER(LTRIM(RTRIM(ISNULL(M.MENombreMenu,'')))) IN
         ('reporte de cobranza','reporte cobranza','cobranza')
  )
ORDER BY CASE WHEN LOWER(REPLACE(ISNULL(M.MERutaLiga,''),'\','/'))
                        LIKE '%reportes/cobranza%' THEN 0 ELSE 1 END,
         M.MEIdMenu;

IF @IdMenuCobranza IS NULL
    THROW 52952,'No se encontro el menu activo de Reporte de Cobranza en ff_Menu.',1;

DECLARE @MenusRequeridos TABLE
(
    IdMenu int NOT NULL PRIMARY KEY,
    Nivel int NOT NULL
);

;WITH Arbol AS
(
    SELECT M.MEIdMenu,M.MEMenuPadre,0 AS Nivel
    FROM dbo.ff_Menu AS M
    WHERE M.MEIdMenu=@IdMenuCobranza AND M.MEIdEstatus=1

    UNION ALL

    SELECT P.MEIdMenu,P.MEMenuPadre,H.Nivel+1
    FROM dbo.ff_Menu AS P
    INNER JOIN Arbol AS H ON P.MEIdMenu=H.MEMenuPadre
    WHERE P.MEIdEstatus=1 AND H.Nivel<20
)
INSERT @MenusRequeridos(IdMenu,Nivel)
SELECT MEIdMenu,MIN(Nivel)
FROM Arbol
GROUP BY MEIdMenu
OPTION(MAXRECURSION 20);

IF NOT EXISTS(SELECT 1 FROM @MenusRequeridos)
    THROW 52953,'No se pudo construir la jerarquia del menu de Cobranza.',1;

DECLARE @VistaPrevia TABLE
(
    Nivel int NOT NULL,
    IdMenu int NOT NULL,
    NombreMenu varchar(500) NULL,
    RutaLiga varchar(1000) NULL,
    Accion varchar(20) NOT NULL,
    RutaBanner varchar(500) NULL,
    ImagenMenu varchar(500) NULL
);

INSERT @VistaPrevia(Nivel,IdMenu,NombreMenu,RutaLiga,Accion,RutaBanner,ImagenMenu)
SELECT RQ.Nivel,M.MEIdMenu,M.MENombreMenu,M.MERutaLiga,
       CASE WHEN D.Activos>0 THEN 'YA_ASIGNADO'
            WHEN D.Existentes>0 THEN 'REACTIVAR'
            ELSE 'INSERTAR' END,
       S.MRRutaBanner,S.MRImagenMenu
FROM @MenusRequeridos AS RQ
INNER JOIN dbo.ff_Menu AS M ON M.MEIdMenu=RQ.IdMenu
OUTER APPLY
(
    SELECT COUNT(*) AS Existentes,
           SUM(CASE WHEN X.MRidEstatus=1 THEN 1 ELSE 0 END) AS Activos
    FROM dbo.ff_MenuRol2 AS X
    WHERE X.MRidRol=@IdRolObjetivo AND X.MRidMenu=RQ.IdMenu
) AS D
OUTER APPLY
(
    SELECT TOP(1) X.MRRutaBanner,X.MRImagenMenu
    FROM dbo.ff_MenuRol2 AS X
    INNER JOIN dbo.ff_Rol AS SR ON SR.ROIdRol=X.MRidRol
    WHERE X.MRidMenu=RQ.IdMenu AND X.MRidEstatus=1 AND SR.ROIdEstatus=1
    ORDER BY CASE WHEN SR.ROIdEmpresa=@IdEmpresa THEN 0 ELSE 1 END,
             CASE WHEN SR.ROAdministrador=1 THEN 0 ELSE 1 END,
             X.MRidMenuRol DESC
) AS S;

SELECT @IdEmpresa AS IdEmpresa,@IdRolObjetivo AS IdRolObjetivo,
       @IdMenuCobranza AS IdMenuCobranza,@Aplicar AS Aplicar;

SELECT Nivel,IdMenu,NombreMenu,RutaLiga,Accion,RutaBanner,ImagenMenu
FROM @VistaPrevia
ORDER BY Nivel DESC,IdMenu;

IF @Aplicar=0
BEGIN
    SELECT N'VISTA_PREVIA' AS Resultado,
           N'No se modificaron datos. Si el usuario/rol y menus son correctos, cambie @Aplicar a 1.' AS Detalle;
    RETURN;
END;

BEGIN TRY
    BEGIN TRANSACTION;

    /* Reactiva la relacion mas reciente cuando el menu ya existia. */
    ;WITH D AS
    (
        SELECT MR.MRidMenuRol,
               ROW_NUMBER() OVER(PARTITION BY MR.MRidMenu ORDER BY MR.MRidMenuRol DESC) AS RN
        FROM dbo.ff_MenuRol2 AS MR WITH(UPDLOCK,HOLDLOCK)
        INNER JOIN @MenusRequeridos AS RQ ON RQ.IdMenu=MR.MRidMenu
        WHERE MR.MRidRol=@IdRolObjetivo
    )
    UPDATE MR
       SET MR.MRidEstatus=1,
           MR.MRUsuarioUMod=@UsuarioAuditoria,
           MR.MRFechaUMod=GETDATE(),
           MR.MRRutaBanner=COALESCE(NULLIF(MR.MRRutaBanner,''),V.RutaBanner),
           MR.MRImagenMenu=COALESCE(NULLIF(MR.MRImagenMenu,''),V.ImagenMenu)
    FROM dbo.ff_MenuRol2 AS MR
    INNER JOIN D ON D.MRidMenuRol=MR.MRidMenuRol AND D.RN=1
    INNER JOIN @VistaPrevia AS V ON V.IdMenu=MR.MRidMenu;

    INSERT dbo.ff_MenuRol2
    (MRidRol,MRidMenu,MRidEstatus,MRUsuarioAdd,MRFechaAdd,MRRutaBanner,MRImagenMenu)
    SELECT @IdRolObjetivo,V.IdMenu,1,@UsuarioAuditoria,GETDATE(),
           V.RutaBanner,V.ImagenMenu
    FROM @VistaPrevia AS V
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.ff_MenuRol2 AS X WITH(UPDLOCK,HOLDLOCK)
        WHERE X.MRidRol=@IdRolObjetivo AND X.MRidMenu=V.IdMenu
    );

    IF EXISTS
    (
        SELECT 1
        FROM @MenusRequeridos AS RQ
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.ff_MenuRol2 AS X
            WHERE X.MRidRol=@IdRolObjetivo
              AND X.MRidMenu=RQ.IdMenu AND X.MRidEstatus=1
        )
    )
        THROW 52954,'No quedaron activos todos los menus requeridos.',1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT M.MEIdMenu,M.MENombreMenu,M.MERutaLiga,M.MEMenuPadre,
       MR.MRidRol,MR.MRidEstatus,MR.MRRutaBanner,MR.MRImagenMenu
FROM dbo.ff_MenuRol2 AS MR
INNER JOIN dbo.ff_Menu AS M ON M.MEIdMenu=MR.MRidMenu
INNER JOIN @MenusRequeridos AS RQ ON RQ.IdMenu=M.MEIdMenu
WHERE MR.MRidRol=@IdRolObjetivo AND MR.MRidEstatus=1
ORDER BY RQ.Nivel DESC,M.MEIdMenu;

SELECT N'APLICADO' AS Resultado,
       N'Cierre sesion y vuelva a entrar para renovar menurol en localStorage.' AS SiguientePaso;

