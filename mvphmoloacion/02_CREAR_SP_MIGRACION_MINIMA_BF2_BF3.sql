/*
  CREA/ACTUALIZA EL SP DE MIGRACION MINIMA BF2 -> BF3

  ALCANCE:
    - NO crea empresas.
    - NO inserta, actualiza ni elimina ff_Rol.
    - NO inserta, actualiza ni elimina ff_Perfil.
    - Habilita acceso BF3 para empresa y corporativo.
    - Sincroniza ff_MenuRol2 desde el rol modelo 7365 al rol administrador existente.
    - Corrige asignaciones administrativas activas que apunten a perfiles o roles
      de otra empresa, inactivos o no administrativos; reutiliza exclusivamente
      el perfil y rol administrador ya existentes en la empresa destino.
    - Sincroniza los nombres de icono en todos los roles administrativos locales
      que realmente esten asignados a administradores activos de la empresa.
    - Crea/reutiliza UNICAMENTE Interfabrica desde la plantilla 689.
    - No recibe IdUsuario: resuelve un administrador activo real para auditoria.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*
  Patron compatible con SQL Server anteriores a CREATE OR ALTER.
  La primera ejecucion crea un contenedor vacio y todas las ejecuciones,
  incluida la primera, aplican despues exactamente la misma definicion.
*/
IF OBJECT_ID('dbo.bf_MigrarEmpresaBF2aBF3_Minimo', 'P') IS NULL
    EXEC(N'CREATE PROCEDURE dbo.bf_MigrarEmpresaBF2aBF3_Minimo AS BEGIN SET NOCOUNT ON; END;');
GO

ALTER PROCEDURE dbo.bf_MigrarEmpresaBF2aBF3_Minimo
    @IdEmpresa INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RolModeloBF3 INT = 7365;
    DECLARE @PlantillaInterfabricaOrigen INT = 689;
    DECLARE @IdCorporativo INT;
    DECLARE @IdPerfilAdministrador INT;
    DECLARE @IdRolAdministrador INT;
    DECLARE @IdUsuarioTecnico INT;
    DECLARE @IdPlantillaInterfabrica INT;
    DECLARE @DescripcionInterfabrica NVARCHAR(100);
    DECLARE @EstadoPlantilla VARCHAR(20) = 'REUTILIZADA';
    DECLARE @RolesAntes INT, @RolesDespues INT;
    DECLARE @PerfilesAntes INT, @PerfilesDespues INT;
    DECLARE @HashRolesAntes INT, @HashRolesDespues INT;
    DECLARE @HashPerfilesAntes INT, @HashPerfilesDespues INT;
    DECLARE @MenusInsertados INT = 0, @MenusActualizados INT = 0;
    DECLARE @IconosRolesAsignadosActualizados INT = 0;
    DECLARE @AsignacionesAdministradorCorregidas INT = 0;
    DECLARE @AccesosInsertados INT = 0, @AccesosActualizados INT = 0;
    DECLARE @AsignacionesPlantillaInsertadas INT = 0;
    DECLARE @MarcadoresMvpInsertados INT = 0;

    DECLARE @PlantillasCreadas TABLE
    (
        IdPlantilla INT NOT NULL PRIMARY KEY,
        Descripcion NVARCHAR(100) NOT NULL
    );

    SELECT @IdCorporativo = E.EMidCorporativo
    FROM dbo.ff_Empresa E
    WHERE E.EMidEmpresa = @IdEmpresa
      AND E.EMidEstatus = 1;

    IF @IdCorporativo IS NULL
        THROW 51000, 'La empresa destino no existe o esta inactiva.', 1;

    /* Usar el rol realmente relacionado con el perfil administrador existente. */
    SELECT TOP (1)
        @IdPerfilAdministrador = P.PEIdPerfil,
        @IdRolAdministrador = P.PEIdRolDefault
    FROM dbo.ff_Perfil P
    INNER JOIN dbo.ff_Rol R
        ON R.ROIdRol = P.PEIdRolDefault
       AND R.ROIdEmpresa = @IdEmpresa
       AND R.ROIdEstatus = 1
    WHERE P.PEIdEmpresa = @IdEmpresa
      AND P.PEAdministrador = 1
      AND P.PEIdEstatus = 1
    ORDER BY P.PEIdPerfil;

    IF @IdPerfilAdministrador IS NULL OR @IdRolAdministrador IS NULL
        THROW 51000, 'La empresa no tiene un perfil administrador activo con rol activo propio. No se crearon roles ni perfiles.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ff_Rol
        WHERE ROIdRol = @RolModeloBF3
          AND ROIdEstatus = 1
    )
        THROW 51000, 'No existe el rol modelo BF3 7365 activo.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ff_Plantilla
        WHERE PLIdPlantilla = @PlantillaInterfabricaOrigen
          AND PLIdEstatus = 1
    )
        THROW 51000, 'No existe la plantilla Interfabrica origen 689 activa.', 1;

    /* No se recibe IdUsuario. Se usa un administrador real asociado al destino. */
    SELECT TOP (1)
        @IdUsuarioTecnico = AE.ADIdAdministrador
    FROM dbo.ff_AdministradorEmpresa AE
    INNER JOIN dbo.ff_administrador A
        ON A.ADIdAdministrador = AE.ADIdAdministrador
       AND A.ADIdEstatus = 1
    WHERE AE.AEIdEmpresa IN (@IdEmpresa, @IdCorporativo)
      AND AE.AEIdEstatus = 1
    ORDER BY CASE WHEN AE.AEIdEmpresa = @IdEmpresa THEN 0 ELSE 1 END,
             AE.ADIdAdministrador;

    IF @IdUsuarioTecnico IS NULL
        THROW 51000, 'No existe un administrador activo para registrar la auditoria. No se utilizara NULL ni usuario 0.', 1;

    SET @DescripcionInterfabrica =
        N'Interfabrica_MVP_' + CONVERT(NVARCHAR(10), @IdCorporativo);

    IF (SELECT COUNT(*) FROM dbo.ff_Plantilla WHERE PLDescripcion = @DescripcionInterfabrica) > 1
        THROW 51000, 'Existe mas de una plantilla Interfabrica para el corporativo. Se requiere depuracion manual.', 1;

    SELECT @IdPlantillaInterfabrica = PLIdPlantilla
    FROM dbo.ff_Plantilla
    WHERE PLDescripcion = @DescripcionInterfabrica;

    /*
      Reejecucion segura: no basta con encontrar una bitacora anterior.
      Solo se omite el proceso cuando el estado funcional completo sigue
      presente. Si algo se perdio o cambio, el SP entra a repararlo.
    */
    IF @IdPlantillaInterfabrica IS NOT NULL
       AND EXISTS
       (
           SELECT 1 FROM dbo.ff_Plantilla
           WHERE PLIdPlantilla = @IdPlantillaInterfabrica
             AND PLIdEstatus = 1
       )
       AND EXISTS
       (
           SELECT 1 FROM dbo.ff_accesoBeflex
           WHERE idempresa = @IdEmpresa AND acceso = 1
       )
       AND EXISTS
       (
           SELECT 1 FROM dbo.ff_accesoBeflex
           WHERE idempresa = @IdCorporativo AND acceso = 1
       )
       AND EXISTS
       (
           SELECT 1 FROM dbo.ff_PlantillaPerfil
           WHERE PPPlantilla = @IdPlantillaInterfabrica
             AND PPIdPerfil = @IdPerfilAdministrador
             AND PPIdEmpresa = @IdEmpresa
             AND PPIdEstatus = 1
       )
       AND EXISTS
       (
           SELECT 1 FROM dbo.bf_ConfiguracionEdicionEmpresaEmpleado
           WHERE CEIdEmpresa = @IdCorporativo
             AND CEIdPlantilla = @IdPlantillaInterfabrica
             AND CEIdEstatus = 1
       )
       AND EXISTS
       (
           SELECT 1 FROM dbo.bf_EmpresaMVP
           WHERE IdEmpresa = @IdEmpresa
             AND ISNULL(IdEstatus, 1) = 1
       )
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.ff_MenuRol2 S
           WHERE S.MRidRol = @RolModeloBF3
             AND S.MRidEstatus = 1
             AND NOT EXISTS
             (
                 SELECT 1
                 FROM dbo.ff_MenuRol2 D
                 WHERE D.MRidRol = @IdRolAdministrador
                   AND D.MRidMenu = S.MRidMenu
                   AND D.MRidEstatus = 1
                   AND ISNULL(D.MRRutaBanner, '') = ISNULL(S.MRRutaBanner, '')
                   AND ISNULL(D.MRImagenMenu, '') = ISNULL(S.MRImagenMenu, '')
             )
       )
       /* Ningun administrador activo puede quedar ligado a otra empresa. */
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.ff_AdministradorEmpresa AE
           LEFT JOIN dbo.ff_Perfil PA
               ON PA.PEIdPerfil = AE.AEIdPerfil
              AND PA.PEIdEmpresa = @IdEmpresa
              AND PA.PEAdministrador = 1
              AND PA.PEIdEstatus = 1
           LEFT JOIN dbo.ff_Rol RA
               ON RA.ROIdRol = AE.AEIdRol
              AND RA.ROIdEmpresa = @IdEmpresa
              AND RA.ROAdministrador = 1
              AND RA.ROIdEstatus = 1
           WHERE AE.AEIdEmpresa = @IdEmpresa
             AND AE.AEIdEstatus = 1
             AND (PA.PEIdPerfil IS NULL OR RA.ROIdRol IS NULL)
       )
       /* Las filas que consume el API (estatus distinto de 2) deben usar
          el mismo archivo de icono que el rol modelo BF3. */
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.ff_AdministradorEmpresa AE
           INNER JOIN dbo.ff_Perfil PA
               ON PA.PEIdPerfil = AE.AEIdPerfil
              AND PA.PEIdEmpresa = @IdEmpresa
              AND PA.PEAdministrador = 1
              AND PA.PEIdEstatus = 1
           INNER JOIN dbo.ff_Rol RA
               ON RA.ROIdRol = AE.AEIdRol
              AND RA.ROIdEmpresa = @IdEmpresa
              AND RA.ROAdministrador = 1
              AND RA.ROIdEstatus = 1
           INNER JOIN dbo.ff_MenuRol2 D
               ON D.MRidRol = AE.AEIdRol
              AND D.MRidEstatus <> 2
           INNER JOIN dbo.ff_MenuRol2 S
               ON S.MRidRol = @RolModeloBF3
              AND S.MRidMenu = D.MRidMenu
              AND S.MRidEstatus = 1
           WHERE AE.AEIdEmpresa = @IdEmpresa
             AND AE.AEIdEstatus = 1
             AND ISNULL(LTRIM(RTRIM(D.MRImagenMenu)), '')
                 <> ISNULL(LTRIM(RTRIM(S.MRImagenMenu)), '')
       )
    BEGIN
        SELECT
            'YA_MIGRADA_SIN_CAMBIOS' AS Resultado,
            @IdEmpresa AS IdEmpresa,
            @IdCorporativo AS IdCorporativo,
            @IdPerfilAdministrador AS PerfilAdministradorExistente,
            @IdRolAdministrador AS RolAdministradorExistente,
            @IdPlantillaInterfabrica AS IdPlantillaInterfabrica,
            0 AS RolesCreados,
            0 AS PerfilesCreados,
            0 AS AsignacionesAdministradorCorregidas,
            0 AS IconosRolesAsignadosActualizados,
            0 AS CambiosRealizados;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        /* Bloquea el conjunto para comprobar que el SP no modifica roles/perfiles. */
        SELECT @RolesAntes = COUNT(*)
        FROM dbo.ff_Rol WITH (UPDLOCK, HOLDLOCK)
        WHERE ROIdEmpresa = @IdEmpresa;

        SELECT @HashRolesAntes = CHECKSUM_AGG(BINARY_CHECKSUM(*))
        FROM dbo.ff_Rol
        WHERE ROIdEmpresa = @IdEmpresa;

        SELECT @PerfilesAntes = COUNT(*)
        FROM dbo.ff_Perfil WITH (UPDLOCK, HOLDLOCK)
        WHERE PEIdEmpresa = @IdEmpresa;

        SELECT @HashPerfilesAntes = CHECKSUM_AGG(BINARY_CHECKSUM(*))
        FROM dbo.ff_Perfil
        WHERE PEIdEmpresa = @IdEmpresa;

        /*
          Corrige unicamente asignaciones invalidas. No crea ni modifica roles
          o perfiles. Ejemplo CENTINELA: el administrador 25 estaba ligado al
          perfil 324 / rol 268 de otra empresa, aunque CENTINELA ya tenia el
          perfil 18806 / rol 8097.
        */
        UPDATE AE
           SET AE.AEIdPerfil = @IdPerfilAdministrador,
               AE.AEIdRol = @IdRolAdministrador,
               AE.AEUsuarioUMod = @IdUsuarioTecnico,
               AE.AEFechaUMod = GETDATE()
        FROM dbo.ff_AdministradorEmpresa AE
        LEFT JOIN dbo.ff_Perfil PA
            ON PA.PEIdPerfil = AE.AEIdPerfil
           AND PA.PEIdEmpresa = @IdEmpresa
           AND PA.PEAdministrador = 1
           AND PA.PEIdEstatus = 1
        LEFT JOIN dbo.ff_Rol RA
            ON RA.ROIdRol = AE.AEIdRol
           AND RA.ROIdEmpresa = @IdEmpresa
           AND RA.ROAdministrador = 1
           AND RA.ROIdEstatus = 1
        WHERE AE.AEIdEmpresa = @IdEmpresa
          AND AE.AEIdEstatus = 1
          AND (PA.PEIdPerfil IS NULL OR RA.ROIdRol IS NULL);
        SET @AsignacionesAdministradorCorregidas = @@ROWCOUNT;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ff_AdministradorEmpresa AE
            LEFT JOIN dbo.ff_Perfil PA
                ON PA.PEIdPerfil = AE.AEIdPerfil
               AND PA.PEIdEmpresa = @IdEmpresa
               AND PA.PEAdministrador = 1
               AND PA.PEIdEstatus = 1
            LEFT JOIN dbo.ff_Rol RA
                ON RA.ROIdRol = AE.AEIdRol
               AND RA.ROIdEmpresa = @IdEmpresa
               AND RA.ROAdministrador = 1
               AND RA.ROIdEstatus = 1
            WHERE AE.AEIdEmpresa = @IdEmpresa
              AND AE.AEIdEstatus = 1
              AND (PA.PEIdPerfil IS NULL OR RA.ROIdRol IS NULL)
        )
            THROW 51000, 'No fue posible corregir todas las asignaciones administrativas invalidas.', 1;

        /* Acceso BF3 para empresa y corporativo. */
        UPDATE dbo.ff_accesoBeflex
           SET acceso = 1
        WHERE idempresa IN (@IdEmpresa, @IdCorporativo)
          AND ISNULL(acceso, 0) <> 1;
        SET @AccesosActualizados = @@ROWCOUNT;

        INSERT INTO dbo.ff_accesoBeflex (acceso, idempresa)
        SELECT 1, V.Id
        FROM (SELECT @IdEmpresa AS Id UNION SELECT @IdCorporativo) V
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.ff_accesoBeflex A
            WHERE A.idempresa = V.Id
        );
        SET @AccesosInsertados = @@ROWCOUNT;

        /* Actualiza menus existentes para evitar conservar rutas/estatus obsoletos. */
        UPDATE D
           SET D.MRidEstatus = S.MRidEstatus,
               D.MRRutaBanner = S.MRRutaBanner,
               D.MRImagenMenu = S.MRImagenMenu,
               D.MRUsuarioUMod = @IdUsuarioTecnico,
               D.MRFechaUMod = GETDATE()
        FROM dbo.ff_MenuRol2 D
        INNER JOIN dbo.ff_MenuRol2 S
            ON S.MRidRol = @RolModeloBF3
           AND S.MRidMenu = D.MRidMenu
           AND S.MRidEstatus = 1
        WHERE D.MRidRol = @IdRolAdministrador
          AND
          (
              ISNULL(D.MRidEstatus, -1) <> ISNULL(S.MRidEstatus, -1)
           OR ISNULL(D.MRRutaBanner, '') <> ISNULL(S.MRRutaBanner, '')
           OR ISNULL(D.MRImagenMenu, '') <> ISNULL(S.MRImagenMenu, '')
          );
        SET @MenusActualizados = @@ROWCOUNT;

        INSERT INTO dbo.ff_MenuRol2
        (
            MRidRol, MRidMenu, MRidEstatus,
            MRUsuarioAdd, MRFechaAdd, MRUsuarioUMod, MRFechaUMod,
            MRRutaBanner, MRImagenMenu
        )
        SELECT
            @IdRolAdministrador, S.MRidMenu, S.MRidEstatus,
            @IdUsuarioTecnico, GETDATE(), @IdUsuarioTecnico, GETDATE(),
            S.MRRutaBanner, S.MRImagenMenu
        FROM dbo.ff_MenuRol2 S
        WHERE S.MRidRol = @RolModeloBF3
          AND S.MRidEstatus = 1
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.ff_MenuRol2 D
              WHERE D.MRidRol = @IdRolAdministrador
                AND D.MRidMenu = S.MRidMenu
          );
        SET @MenusInsertados = @@ROWCOUNT;

        /*
          Un perfil administrador valido puede usar otro rol administrativo
          local. Para esos roles se corrige solamente el nombre del icono en
          menus ya existentes; no se agregan permisos, roles ni perfiles.
          Se actualizan todas las filas que el API consume (estatus <> 2), con
          lo cual tampoco queda una fila duplicada capaz de devolver el icono
          anterior de manera no determinista.
        */
        ;WITH RolesAdministradorAsignados AS
        (
            SELECT DISTINCT AE.AEIdRol AS IdRol
            FROM dbo.ff_AdministradorEmpresa AE
            INNER JOIN dbo.ff_Perfil PA
                ON PA.PEIdPerfil = AE.AEIdPerfil
               AND PA.PEIdEmpresa = @IdEmpresa
               AND PA.PEAdministrador = 1
               AND PA.PEIdEstatus = 1
            INNER JOIN dbo.ff_Rol RA
                ON RA.ROIdRol = AE.AEIdRol
               AND RA.ROIdEmpresa = @IdEmpresa
               AND RA.ROAdministrador = 1
               AND RA.ROIdEstatus = 1
            WHERE AE.AEIdEmpresa = @IdEmpresa
              AND AE.AEIdEstatus = 1
        )
        UPDATE D
           SET D.MRImagenMenu = S.MRImagenMenu,
               D.MRUsuarioUMod = @IdUsuarioTecnico,
               D.MRFechaUMod = GETDATE()
        FROM dbo.ff_MenuRol2 D
        INNER JOIN RolesAdministradorAsignados RAA
            ON RAA.IdRol = D.MRidRol
        INNER JOIN dbo.ff_MenuRol2 S
            ON S.MRidRol = @RolModeloBF3
           AND S.MRidMenu = D.MRidMenu
           AND S.MRidEstatus = 1
        WHERE D.MRidEstatus <> 2
          AND ISNULL(LTRIM(RTRIM(D.MRImagenMenu)), '')
              <> ISNULL(LTRIM(RTRIM(S.MRImagenMenu)), '');
        SET @IconosRolesAsignadosActualizados = @@ROWCOUNT;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.ff_AdministradorEmpresa AE
            INNER JOIN dbo.ff_Perfil PA
                ON PA.PEIdPerfil = AE.AEIdPerfil
               AND PA.PEIdEmpresa = @IdEmpresa
               AND PA.PEAdministrador = 1
               AND PA.PEIdEstatus = 1
            INNER JOIN dbo.ff_Rol RA
                ON RA.ROIdRol = AE.AEIdRol
               AND RA.ROIdEmpresa = @IdEmpresa
               AND RA.ROAdministrador = 1
               AND RA.ROIdEstatus = 1
            INNER JOIN dbo.ff_MenuRol2 D
                ON D.MRidRol = AE.AEIdRol
               AND D.MRidEstatus <> 2
            INNER JOIN dbo.ff_MenuRol2 S
                ON S.MRidRol = @RolModeloBF3
               AND S.MRidMenu = D.MRidMenu
               AND S.MRidEstatus = 1
            WHERE AE.AEIdEmpresa = @IdEmpresa
              AND AE.AEIdEstatus = 1
              AND ISNULL(LTRIM(RTRIM(D.MRImagenMenu)), '')
                  <> ISNULL(LTRIM(RTRIM(S.MRImagenMenu)), '')
        )
            THROW 51000, 'Validacion fallida: un rol administrativo asignado conserva iconos distintos al modelo BF3.', 1;

        SELECT @IdPlantillaInterfabrica = PLIdPlantilla
        FROM dbo.ff_Plantilla WITH (UPDLOCK, HOLDLOCK)
        WHERE PLDescripcion = @DescripcionInterfabrica;

        IF @IdPlantillaInterfabrica IS NULL
        BEGIN
            INSERT INTO dbo.ff_Plantilla
            (
                PLDescripcion, PLPagina, PLTabla, PLIdPlantillaPadre,
                PLIdEstatus, PLFechaEstatus, PLConsulta,
                PLUsuarioAdd, PLFechaAdd, PLUsuarioUMod, PLFechaUMod
            )
            OUTPUT inserted.PLIdPlantilla, inserted.PLDescripcion
                INTO @PlantillasCreadas (IdPlantilla, Descripcion)
            SELECT
                @DescripcionInterfabrica, PLPagina, PLTabla,
                @PlantillaInterfabricaOrigen, PLIdEstatus, GETDATE(), PLConsulta,
                @IdUsuarioTecnico, GETDATE(), @IdUsuarioTecnico, GETDATE()
            FROM dbo.ff_Plantilla
            WHERE PLIdPlantilla = @PlantillaInterfabricaOrigen;

            SET @IdPlantillaInterfabrica = SCOPE_IDENTITY();
            SET @EstadoPlantilla = 'CREADA';

            INSERT INTO dbo.ff_ConfiguracionPlantilla
            (
                PLIdPlantilla, CAIdCampo, REIdRegla, CPIdTitular,
                CPHabilitado, CPVisible, CPEtiqueta, CPRequerido,
                CPRangoValores, CPOrden, CPEncriptado, CPIdEstatus,
                CPFechaEstatus, CPUsuarioAdd, CPFechaAdd,
                CPUsuarioUMod, CPFechaUMod, CPConfirmacion
            )
            SELECT
                @IdPlantillaInterfabrica, CAIdCampo, REIdRegla, CPIdTitular,
                CPHabilitado, CPVisible, CPEtiqueta, CPRequerido,
                CPRangoValores, CPOrden, CPEncriptado, CPIdEstatus,
                GETDATE(), @IdUsuarioTecnico, GETDATE(),
                @IdUsuarioTecnico, GETDATE(), CPConfirmacion
            FROM dbo.ff_ConfiguracionPlantilla
            WHERE PLIdPlantilla = @PlantillaInterfabricaOrigen;
        END
        ELSE IF EXISTS
        (
            SELECT 1
            FROM dbo.ff_Plantilla
            WHERE PLIdPlantilla = @IdPlantillaInterfabrica
              AND PLIdEstatus <> 1
        )
        BEGIN
            UPDATE dbo.ff_Plantilla
               SET PLIdEstatus = 1,
                   PLFechaEstatus = GETDATE(),
                   PLUsuarioUMod = @IdUsuarioTecnico,
                   PLFechaUMod = GETDATE()
            WHERE PLIdPlantilla = @IdPlantillaInterfabrica;
            SET @EstadoPlantilla = 'REACTIVADA';
        END

        /* Asignar solo Interfabrica. No elimina las plantillas BF2 existentes. */
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.ff_PlantillaPerfil
            WHERE PPPlantilla = @IdPlantillaInterfabrica
              AND PPIdPerfil = @IdPerfilAdministrador
              AND PPIdEmpresa = @IdEmpresa
              AND PPIdEstatus = 1
        )
        BEGIN
            INSERT INTO dbo.ff_PlantillaPerfil
            (
                PPPlantilla, PPIdPerfil, PPIdEmpresa, PPIdEstatus,
                PPUsuarioAdd, PPFechaAdd, PPUsuarioUMod, PPFechaUMod
            )
            VALUES
            (
                @IdPlantillaInterfabrica, @IdPerfilAdministrador, @IdEmpresa, 1,
                @IdUsuarioTecnico, GETDATE(), @IdUsuarioTecnico, GETDATE()
            );
            SET @AsignacionesPlantillaInsertadas = 1;
        END

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.bf_ConfiguracionEdicionEmpresaEmpleado
            WHERE CEIdEmpresa = @IdCorporativo
              AND CEIdPlantilla = @IdPlantillaInterfabrica
              AND CEIdEstatus = 1
        )
        BEGIN
            INSERT INTO dbo.bf_ConfiguracionEdicionEmpresaEmpleado
            (
                CEIdEmpresa, CEIdPlantilla, CEIdEstatus,
                CEUsuarioAdd, CEFechaAdd, CEUsuarioUMod, CEFechaUMod
            )
            SELECT TOP (1)
                @IdCorporativo, @IdPlantillaInterfabrica, 1,
                @IdUsuarioTecnico, GETDATE(), @IdUsuarioTecnico, GETDATE()
            FROM dbo.bf_ConfiguracionEdicionEmpresaEmpleado
            WHERE CEIdConfiguracion = 8;
        END

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.bf_ConfiguracionEdicionEmpresaEmpleado
            WHERE CEIdEmpresa = @IdCorporativo
              AND CEIdPlantilla = @IdPlantillaInterfabrica
              AND CEIdEstatus = 1
        )
            THROW 51000, 'No fue posible configurar Interfabrica para el corporativo. Falta la configuracion origen 8 o no se inserto el registro.', 1;

        /* Impide que el Wizard aplique despues la cascada completa. */
        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.bf_EmpresaMVP
            WHERE IdEmpresa = @IdEmpresa
              AND ISNULL(IdEstatus, 1) = 1
        )
        BEGIN
            INSERT INTO dbo.bf_EmpresaMVP
                (IdEmpresa, IdEstatus, IdUsuarioAdd, FechaAdd)
            VALUES
                (@IdEmpresa, 1, @IdUsuarioTecnico, GETDATE());
            SET @MarcadoresMvpInsertados = 1;
        END

        SELECT @RolesDespues = COUNT(*)
        FROM dbo.ff_Rol
        WHERE ROIdEmpresa = @IdEmpresa;

        SELECT @HashRolesDespues = CHECKSUM_AGG(BINARY_CHECKSUM(*))
        FROM dbo.ff_Rol
        WHERE ROIdEmpresa = @IdEmpresa;

        SELECT @PerfilesDespues = COUNT(*)
        FROM dbo.ff_Perfil
        WHERE PEIdEmpresa = @IdEmpresa;

        SELECT @HashPerfilesDespues = CHECKSUM_AGG(BINARY_CHECKSUM(*))
        FROM dbo.ff_Perfil
        WHERE PEIdEmpresa = @IdEmpresa;

        IF @RolesAntes <> @RolesDespues
            THROW 51000, 'Validacion fallida: se detecto un cambio en la cantidad de roles.', 1;

        IF @PerfilesAntes <> @PerfilesDespues
            THROW 51000, 'Validacion fallida: se detecto un cambio en la cantidad de perfiles.', 1;

        IF ISNULL(@HashRolesAntes,0) <> ISNULL(@HashRolesDespues,0)
            THROW 51000, 'Validacion fallida: se detecto una modificacion en roles.', 1;

        IF ISNULL(@HashPerfilesAntes,0) <> ISNULL(@HashPerfilesDespues,0)
            THROW 51000, 'Validacion fallida: se detecto una modificacion en perfiles.', 1;

        IF (SELECT COUNT(*) FROM @PlantillasCreadas) > 1
            THROW 51000, 'Validacion fallida: se creo mas de una plantilla.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM @PlantillasCreadas
            WHERE IdPlantilla <> @IdPlantillaInterfabrica
               OR Descripcion <> @DescripcionInterfabrica
        )
            THROW 51000, 'Validacion fallida: se creo una plantilla no autorizada.', 1;

        INSERT INTO dbo.bf_BitacoraEmpresa
        (
            BEIdEmpresa, BEIdUsuario, BEAccion, BEDetalle,
            BEElementoAfectado, BECantidadElementos, BEExitoso, BEFechaCreacion
        )
        VALUES
        (
            @IdEmpresa, @IdUsuarioTecnico, 'MIGRAR_BF2_BF3_MINIMO',
            'Sin crear roles/perfiles. Menus insertados=' + CONVERT(VARCHAR(12), @MenusInsertados)
             + ', actualizados=' + CONVERT(VARCHAR(12), @MenusActualizados)
             + ', asignaciones admin corregidas=' + CONVERT(VARCHAR(12), @AsignacionesAdministradorCorregidas)
             + ', iconos de roles asignados corregidos=' + CONVERT(VARCHAR(12), @IconosRolesAsignadosActualizados)
             + ', Interfabrica=' + @EstadoPlantilla + '.',
            'acceso+adminEmpresa+menuRol2+Interfabrica',
            @MenusInsertados + @MenusActualizados
             + @IconosRolesAsignadosActualizados
             + @AsignacionesAdministradorCorregidas
             + @AsignacionesPlantillaInsertadas,
            1, GETDATE()
        );

        COMMIT TRANSACTION;

        SELECT
            'MIGRACION_CORRECTA' AS Resultado,
            @IdEmpresa AS IdEmpresa,
            @IdCorporativo AS IdCorporativo,
            @IdUsuarioTecnico AS IdUsuarioAuditoria,
            @IdPerfilAdministrador AS PerfilAdministradorExistente,
            @IdRolAdministrador AS RolAdministradorExistente,
            @RolesAntes AS RolesAntes,
            @RolesDespues AS RolesDespues,
            @RolesDespues - @RolesAntes AS RolesCreados,
            CASE WHEN ISNULL(@HashRolesAntes,0)=ISNULL(@HashRolesDespues,0) THEN 0 ELSE 1 END AS RolesModificados,
            @PerfilesAntes AS PerfilesAntes,
            @PerfilesDespues AS PerfilesDespues,
            @PerfilesDespues - @PerfilesAntes AS PerfilesCreados,
            CASE WHEN ISNULL(@HashPerfilesAntes,0)=ISNULL(@HashPerfilesDespues,0) THEN 0 ELSE 1 END AS PerfilesModificados,
            @MenusInsertados AS MenusBF3Insertados,
            @MenusActualizados AS MenusBF3Actualizados,
            @AsignacionesAdministradorCorregidas AS AsignacionesAdministradorCorregidas,
            @IconosRolesAsignadosActualizados AS IconosRolesAsignadosActualizados,
            @EstadoPlantilla AS EstadoInterfabrica,
            @IdPlantillaInterfabrica AS IdPlantillaInterfabrica,
            (SELECT COUNT(*) FROM @PlantillasCreadas) AS PlantillasCreadas,
            0 AS OtrasPlantillasCreadas,
            @AccesosInsertados AS AccesosBF3Insertados,
            @AccesosActualizados AS AccesosBF3Actualizados,
            @MarcadoresMvpInsertados AS MarcadoresMvpInsertados;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        BEGIN TRY
            INSERT INTO dbo.bf_BitacoraEmpresa
            (
                BEIdEmpresa, BEIdUsuario, BEAccion, BEDetalle,
                BEElementoAfectado, BEExitoso, BEMensajeError, BEFechaCreacion
            )
            VALUES
            (
                @IdEmpresa, @IdUsuarioTecnico, 'MIGRAR_BF2_BF3_MINIMO',
                'Error en migracion minima BF2 a BF3.',
                'migracion_minima', 0, ERROR_MESSAGE(), GETDATE()
            );
        END TRY
        BEGIN CATCH
        END CATCH;

        THROW;
    END CATCH;
END;
GO
