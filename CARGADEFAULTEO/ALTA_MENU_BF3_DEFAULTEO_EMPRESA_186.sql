/*
  Alta/actualizacion del menu Defaulteo en BF3 para la empresa 186.

  Resultado esperado:
    Carga Masiva  (/cargamasivapoblaciones)  orden N
    Defaulteo     (/defaulteo)                orden N + 1

  Defaulteo queda bajo el mismo padre y usa el mismo icono que Carga Masiva.
  La visibilidad de BF3 se administra por rol; para los insumos entregados de
  la empresa 186 el rol correspondiente es 570.

  El script es idempotente y no depende de las nuevas tablas de configuracion.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @IdEmpresa INT = 186;
DECLARE @IdRol INT = 570;
DECLARE @Usuario INT = 0;
DECLARE @Ahora DATETIME = GETDATE();

DECLARE @IdMenuCarga INT;
DECLARE @IdMenuDefaulteo INT;
DECLARE @IdMenuPadre INT;
DECLARE @OrdenCarga INT;
DECLARE @EsPadre BIT;
DECLARE @Target VARCHAR(20);
DECLARE @TieneIcono BIT;
DECLARE @IdTipoNegocio INT;
DECLARE @RutaBanner VARCHAR(200);
DECLARE @ImagenMenu VARCHAR(100);

IF NOT EXISTS
(
    SELECT 1 FROM dbo.ff_Empresa
    WHERE EMIdEmpresa=@IdEmpresa AND EMIdEstatus=1
)
    THROW 51600, 'No existe la empresa 186 activa.', 1;

SELECT TOP (1)
    @IdMenuCarga=M.MEIdMenu,
    @IdMenuPadre=M.MEMenuPadre,
    @OrdenCarga=M.MEOrden,
    @EsPadre=M.MEPadre,
    @Target=M.METarget,
    @TieneIcono=M.MEIcono,
    @IdTipoNegocio=M.MEIdTipoNegocio,
    @RutaBanner=MR.MRRutaBanner,
    @ImagenMenu=MR.MRImagenMenu
FROM dbo.ff_Menu M
INNER JOIN dbo.ff_MenuRol2 MR
    ON MR.MRIdMenu=M.MEIdMenu
   AND MR.MRIdRol=@IdRol
   AND MR.MRIdEstatus=1
WHERE M.MERutaLiga='/cargamasivapoblaciones'
  AND M.MEIdEstatus=1
ORDER BY M.MEIdMenu;

IF @IdMenuCarga IS NULL
    THROW 51601, 'El rol 570 no tiene activo el menu BF3 de Carga Masiva usado como referencia.', 1;

SELECT TOP (1) @IdMenuDefaulteo=MEIdMenu
FROM dbo.ff_Menu
WHERE MERutaLiga='/defaulteo'
ORDER BY CASE WHEN MEIdEstatus=1 THEN 0 ELSE 1 END,MEIdMenu;

BEGIN TRY
    BEGIN TRANSACTION;

    IF @IdMenuDefaulteo IS NULL
    BEGIN
        INSERT dbo.ff_Menu
        (
            MENombreMenu,MERutaLiga,MEComentarios,MEPadre,METarget,
            MEOrden,MEIcono,MEMenuPadre,MEIdPagina,MEIdTipoNegocio,
            MEIdEstatus,MEUsuarioAdd,MEFechaAdd,MEUsuarioUMod,
            MEFechaUMod,MEUsuarioDel,MEFechaDel
        )
        VALUES
        (
            N'Defaulteo','/defaulteo',
            'Defaulteo de empleados tipos 1, 2 y 3',
            ISNULL(@EsPadre,0),ISNULL(@Target,'centro'),
            ISNULL(@OrdenCarga,0)+1,ISNULL(@TieneIcono,1),@IdMenuPadre,
            NULL,@IdTipoNegocio,1,@Usuario,@Ahora,@Usuario,@Ahora,NULL,NULL
        );

        SET @IdMenuDefaulteo=CONVERT(INT,SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE dbo.ff_Menu
        SET MENombreMenu=N'Defaulteo',
            MERutaLiga='/defaulteo',
            MEComentarios='Defaulteo de empleados tipos 1, 2 y 3',
            MEPadre=ISNULL(@EsPadre,0),
            METarget=ISNULL(@Target,'centro'),
            MEOrden=ISNULL(@OrdenCarga,0)+1,
            MEIcono=ISNULL(@TieneIcono,1),
            MEMenuPadre=@IdMenuPadre,
            MEIdTipoNegocio=@IdTipoNegocio,
            MEIdEstatus=1,
            MEUsuarioUMod=@Usuario,
            MEFechaUMod=@Ahora,
            MEUsuarioDel=NULL,
            MEFechaDel=NULL
        WHERE MEIdMenu=@IdMenuDefaulteo;
    END;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.ff_MenuRol2
        WHERE MRIdRol=@IdRol AND MRIdMenu=@IdMenuDefaulteo
    )
    BEGIN
        INSERT dbo.ff_MenuRol2
        (
            MRIdRol,MRIdMenu,MRIdEstatus,MRUsuarioAdd,MRFechaAdd,
            MRUsuarioUMod,MRFechaUMod,MRUsuarioDel,MRFechaDel,
            MRRutaBanner,MRImagenMenu
        )
        VALUES
        (
            @IdRol,@IdMenuDefaulteo,1,@Usuario,@Ahora,@Usuario,@Ahora,
            NULL,NULL,@RutaBanner,@ImagenMenu
        );
    END
    ELSE
    BEGIN
        UPDATE dbo.ff_MenuRol2
        SET MRIdEstatus=1,
            MRRutaBanner=@RutaBanner,
            MRImagenMenu=@ImagenMenu,
            MRUsuarioUMod=@Usuario,
            MRFechaUMod=@Ahora,
            MRUsuarioDel=NULL,
            MRFechaDel=NULL
        WHERE MRIdRol=@IdRol AND MRIdMenu=@IdMenuDefaulteo;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

/* Comprobacion final. Debe devolver Resultado=OK. */
SELECT
    @IdEmpresa AS IdEmpresa,
    D.MEIdMenu,D.MENombreMenu,D.MERutaLiga,D.MEMenuPadre,D.MEOrden,
    MR.MRIdRol,MR.MRIdEstatus,MR.MRImagenMenu,
    C.MEIdMenu AS IdMenuCarga,C.MEOrden AS OrdenCarga,
    CASE
      WHEN D.MENombreMenu=N'Defaulteo'
       AND D.MEMenuPadre=C.MEMenuPadre
       AND D.MEOrden=C.MEOrden+1
       AND MR.MRIdEstatus=1
       AND ISNULL(MR.MRImagenMenu,'')=ISNULL(CMR.MRImagenMenu,'')
      THEN 'OK' ELSE 'REVISAR'
    END AS Resultado
FROM dbo.ff_Menu D
INNER JOIN dbo.ff_MenuRol2 MR
    ON MR.MRIdMenu=D.MEIdMenu AND MR.MRIdRol=@IdRol
INNER JOIN dbo.ff_Menu C
    ON C.MEIdMenu=@IdMenuCarga
INNER JOIN dbo.ff_MenuRol2 CMR
    ON CMR.MRIdMenu=C.MEIdMenu AND CMR.MRIdRol=@IdRol
WHERE D.MEIdMenu=@IdMenuDefaulteo;

