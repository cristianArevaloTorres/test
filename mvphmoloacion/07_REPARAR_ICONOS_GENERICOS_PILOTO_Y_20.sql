/*
  REPARACION COMPLEMENTARIA DE ICONOS GENERICOS BF3

  Uso:
    - Para empresas que ya fueron homologadas por 01/03 y conservan iconos rotos.
    - No vuelve a ejecutar bf_ProcesoMVP ni modifica perfiles, plantillas, planes,
      carga masiva, empleados o solicitudes.
    - Reemplaza exclusivamente ff_MenuRol2.MRImagenMenu de roles activos.

  Los siete PNG compartidos viven en:
    /Stilos/StilosDefault/img/shared/sidebar/01.png ... 07.png

  BF3 antepone /Stilos/Menus/{idEmpresa}/ al valor de MRImagenMenu. Por ello se
  almacena ../../StilosDefault/... y el navegador resuelve la URL compartida.

  DESACTIVADO POR DEFECTO. Primero ejecutar como simulacion.
*/
USE [FlexiForbesv2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID('tempdb..#ObjetivosIconos') IS NOT NULL DROP TABLE #ObjetivosIconos;
IF OBJECT_ID('tempdb..#CambiosIconos') IS NOT NULL DROP TABLE #CambiosIconos;
IF OBJECT_ID('tempdb..#ResultadoIconos') IS NOT NULL DROP TABLE #ResultadoIconos;

DECLARE @Aplicar BIT=0;                    -- 0=simulacion; 1=aplicar.
DECLARE @Confirmacion VARCHAR(60)='';       -- Escribir: REPARAR_ICONOS_GENERICOS_MVP_B3
DECLARE @IdUsuario INT=NULL;                -- Obligatorio solamente con @Aplicar=1.
DECLARE @Alcance VARCHAR(10)='TODOS';       -- PILOTO o TODOS.
DECLARE @SobrescribirIconosExistentes BIT=1;-- 1 reemplaza tambien rutas no vacias que hoy estan rotas.
DECLARE @UrlBaseRecursos VARCHAR(250)='https://belocktonha.com/';

IF UPPER(@Alcance) NOT IN ('PILOTO','TODOS')
    THROW 51000, '@Alcance debe ser PILOTO o TODOS.', 1;

DECLARE @Corporativos TABLE (
    IdCorporativo INT PRIMARY KEY,
    Grupo VARCHAR(30) NOT NULL
);

INSERT INTO @Corporativos (IdCorporativo,Grupo) VALUES
(495,'HAPAG'),(531,'GN102'),(658,'GCABLE'),(698,'TORRENT'),
(718,'UNICCO'),(721,'CCPM'),(723,'SCHNEIDER'),(725,'IMCP'),
(727,'BIOMETC'),(752,'GEPC'),(756,'LOEFFLERC'),(758,'AMCHAM'),
(760,'IMEFC'),(762,'PRV'),(790,'MELTSANC'),(797,'CLYPC'),
(799,'VITOLC'),(806,'SGWIC'),(812,'DE LA VEGA'),(814,'CONSTRUMACC');

CREATE TABLE #ObjetivosIconos (
    IdEmpresa INT PRIMARY KEY,
    IdCorporativo INT NOT NULL,
    Grupo VARCHAR(30) NOT NULL,
    Empresa VARCHAR(200) NULL
);

INSERT INTO #ObjetivosIconos (IdEmpresa,IdCorporativo,Grupo,Empresa)
SELECT e.EMidEmpresa,c.IdCorporativo,c.Grupo,e.EMRazonSocial
FROM @Corporativos c
INNER JOIN dbo.ff_Empresa e
    ON e.EMidCorporativo=c.IdCorporativo
WHERE e.EMidEmpresa<>e.EMidCorporativo
  AND e.EMidEstatus=1
  AND (UPPER(@Alcance)='TODOS' OR c.IdCorporativo=495);

IF NOT EXISTS (SELECT 1 FROM #ObjetivosIconos)
    THROW 51000, 'No se encontraron empresas hijas activas para el alcance solicitado.', 1;

IF OBJECT_ID('dbo.ff_MenuRol2','U') IS NULL
   OR OBJECT_ID('dbo.ff_Rol','U') IS NULL
   OR OBJECT_ID('dbo.bf_BitacoraEmpresa','U') IS NULL
    THROW 51000, 'Faltan ff_MenuRol2, ff_Rol o bf_BitacoraEmpresa.', 1;

SELECT o.IdEmpresa,o.IdCorporativo,o.Grupo,o.Empresa,
       r.ROIdRol,mr.MRidMenuRol,mr.MRidMenu,
       mr.MRImagenMenu AS RutaAnterior,
       CONVERT(VARCHAR(100),
           '../../StilosDefault/img/shared/sidebar/'
           + RIGHT('0'+CONVERT(VARCHAR(2),((ABS(CONVERT(BIGINT,mr.MRidMenu))+6)%7)+1),2)
           + '.png') AS RutaNueva
INTO #CambiosIconos
FROM #ObjetivosIconos o
INNER JOIN dbo.ff_Rol r
    ON r.ROIdEmpresa=o.IdEmpresa AND r.ROIdEstatus=1
INNER JOIN dbo.ff_MenuRol2 mr
    ON mr.MRidRol=r.ROIdRol AND mr.MRidEstatus=1
WHERE (@SobrescribirIconosExistentes=1
       OR NULLIF(LTRIM(RTRIM(mr.MRImagenMenu)),'') IS NULL)
  AND ISNULL(LTRIM(RTRIM(mr.MRImagenMenu)),'')<>
      '../../StilosDefault/img/shared/sidebar/'
      + RIGHT('0'+CONVERT(VARCHAR(2),((ABS(CONVERT(BIGINT,mr.MRidMenu))+6)%7)+1),2)
      + '.png';

IF EXISTS (
    SELECT 1 FROM #CambiosIconos
    WHERE DATALENGTH(RutaNueva)>COL_LENGTH('dbo.ff_MenuRol2','MRImagenMenu')
)
    THROW 51000, 'Una ruta generica excede la longitud de ff_MenuRol2.MRImagenMenu.', 1;

SELECT '01_OBJETIVOS' Bloque,*
FROM #ObjetivosIconos
ORDER BY IdCorporativo,IdEmpresa;

SELECT '02_RESUMEN_SIMULACION' Bloque,
       @Aplicar Aplicar,@Alcance Alcance,
       @SobrescribirIconosExistentes SobrescribirIconosExistentes,
       (SELECT COUNT(*) FROM #ObjetivosIconos) Empresas,
       (SELECT COUNT(*) FROM #CambiosIconos) IconosPorActualizar;

SELECT '03_CAMBIOS_POR_EMPRESA' Bloque,
       o.IdCorporativo,o.IdEmpresa,o.Grupo,o.Empresa,
       COUNT(c.MRidMenuRol) IconosPorActualizar
FROM #ObjetivosIconos o
LEFT JOIN #CambiosIconos c ON c.IdEmpresa=o.IdEmpresa
GROUP BY o.IdCorporativo,o.IdEmpresa,o.Grupo,o.Empresa
ORDER BY o.IdCorporativo,o.IdEmpresa;

SELECT TOP (300) '04_DETALLE_PREVIO' Bloque,
       IdCorporativo,IdEmpresa,Grupo,ROIdRol,MRidMenuRol,MRidMenu,
       RutaAnterior,RutaNueva,
       @UrlBaseRecursos+'Stilos/StilosDefault/img/shared/sidebar/'
       + RIGHT('0'+CONVERT(VARCHAR(2),((ABS(CONVERT(BIGINT,MRidMenu))+6)%7)+1),2)
       + '.png' UrlCompartidaEsperada
FROM #CambiosIconos
ORDER BY IdCorporativo,IdEmpresa,ROIdRol,MRidMenu;

IF @Aplicar=0
BEGIN
    PRINT 'SIMULACION: no se modifico informacion. Revise los bloques 01 a 04.';
    RETURN;
END;

IF @Confirmacion<>'REPARAR_ICONOS_GENERICOS_MVP_B3'
    THROW 51000, 'La frase de confirmacion no coincide.', 1;

IF @IdUsuario IS NULL OR @IdUsuario<=0
    THROW 51000, 'Debe capturar @IdUsuario.', 1;

IF NOT EXISTS (
    SELECT 1 FROM dbo.ff_administrador
    WHERE ADIdAdministrador=@IdUsuario AND ADIdEstatus=1
)
    THROW 51000, '@IdUsuario no corresponde a un administrador activo.', 1;

CREATE TABLE #ResultadoIconos (
    IdEmpresa INT NOT NULL,
    IdCorporativo INT NOT NULL,
    Resultado VARCHAR(10) NOT NULL,
    IconosActualizados INT NOT NULL,
    Mensaje VARCHAR(1000) NULL
);

DECLARE @IdEmpresa INT,@IdCorporativo INT,@Actualizados INT,@Error VARCHAR(1000);
DECLARE curIconos CURSOR LOCAL FAST_FORWARD FOR
SELECT IdEmpresa,IdCorporativo
FROM #ObjetivosIconos
ORDER BY IdCorporativo,IdEmpresa;

OPEN curIconos;
FETCH NEXT FROM curIconos INTO @IdEmpresa,@IdCorporativo;
WHILE @@FETCH_STATUS=0
BEGIN
    SET @Actualizados=0;
    SET @Error=NULL;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE mr
           SET mr.MRImagenMenu=c.RutaNueva,
               mr.MRUsuarioUMod=@IdUsuario,
               mr.MRFechaUMod=GETDATE()
        FROM dbo.ff_MenuRol2 mr
        INNER JOIN #CambiosIconos c ON c.MRidMenuRol=mr.MRidMenuRol
        WHERE c.IdEmpresa=@IdEmpresa;

        SET @Actualizados=@@ROWCOUNT;

        INSERT INTO dbo.bf_BitacoraEmpresa (
            BEIdEmpresa,BEIdUsuario,BEAccion,BEDetalle,BEElementoAfectado,
            BECantidadElementos,BEExitoso,BEFechaCreacion
        )
        VALUES (
            @IdEmpresa,@IdUsuario,'REPARAR_ICONOS_GENERICOS_BF3',
            'Ruta compartida StilosDefault; alcance='+@Alcance,
            'ff_MenuRol2',@Actualizados,1,GETDATE()
        );

        COMMIT TRANSACTION;

        INSERT INTO #ResultadoIconos
        VALUES (@IdEmpresa,@IdCorporativo,'OK',@Actualizados,NULL);
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        SET @Error=LEFT(ERROR_MESSAGE(),1000);

        INSERT INTO #ResultadoIconos
        VALUES (@IdEmpresa,@IdCorporativo,'ERROR',0,@Error);

        BEGIN TRY
            INSERT INTO dbo.bf_BitacoraEmpresa (
                BEIdEmpresa,BEIdUsuario,BEAccion,BEDetalle,BEElementoAfectado,
                BECantidadElementos,BEExitoso,BEMensajeError,BEFechaCreacion
            )
            VALUES (
                @IdEmpresa,@IdUsuario,'REPARAR_ICONOS_GENERICOS_BF3',
                'Fallo la reparacion de iconos compartidos.',
                'ff_MenuRol2',0,0,@Error,GETDATE()
            );
        END TRY
        BEGIN CATCH
            /* Conservar el error original aunque la bitacora tampoco este disponible. */
        END CATCH;
    END CATCH;

    FETCH NEXT FROM curIconos INTO @IdEmpresa,@IdCorporativo;
END;

CLOSE curIconos;
DEALLOCATE curIconos;

SELECT '05_RESULTADO' Bloque,*
FROM #ResultadoIconos
ORDER BY IdCorporativo,IdEmpresa;

SELECT '06_RESUMEN_FINAL' Bloque,
       COUNT(*) EmpresasProcesadas,
       SUM(CASE WHEN Resultado='OK' THEN 1 ELSE 0 END) EmpresasCorrectas,
       SUM(CASE WHEN Resultado='ERROR' THEN 1 ELSE 0 END) EmpresasConError,
       SUM(IconosActualizados) IconosActualizados
FROM #ResultadoIconos;

IF EXISTS (SELECT 1 FROM #ResultadoIconos WHERE Resultado='ERROR')
    THROW 51000, 'La reparacion termino con al menos una empresa en ERROR. Revise 05_RESULTADO.', 1;
GO
