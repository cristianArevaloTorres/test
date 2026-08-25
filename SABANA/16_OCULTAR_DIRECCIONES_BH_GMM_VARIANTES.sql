USE [FlexiForbesv2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

/*
La ejecucion diagnosticada de BH carga:
  idEmpresaParam = 332
  grupo           = GMM
  columnaGrupo    = NombrePestana

GMM Basico y GMM Exceso no son grupos de configuracion independientes: son
valores de NombrePestana. Al registrar estas siete columnas como no visibles
en el grupo GMM, el API las reconoce como configuradas y no las vuelve a
anexar como columnas dinamicas.
*/

IF OBJECT_ID(N'dbo.bf_RepConf_Tabla',N'U') IS NULL
    THROW 50400,'No existe dbo.bf_RepConf_Tabla.',1;
IF OBJECT_ID(N'dbo.bf_RepConf_Columna',N'U') IS NULL
    THROW 50401,'No existe dbo.bf_RepConf_Columna.',1;

DECLARE @IdEmpresa int=332,
        @Grupo nvarchar(100);

SELECT TOP (1) @Grupo=T.grupo
FROM dbo.bf_RepConf_Tabla AS T
WHERE T.idEmpresa=@IdEmpresa
  AND T.catReportesId=3
  AND UPPER(LTRIM(RTRIM(T.grupo)))=N'GMM'
ORDER BY CASE WHEN ISNULL(T.activo,1)=1 THEN 0 ELSE 1 END,T.indexTable;

IF @Grupo IS NULL
    THROW 50402,'No existe configuracion GMM del reporte 3 para idEmpresa 332.',1;

DECLARE @Campos TABLE
(
    campoOrigen nvarchar(200) NOT NULL PRIMARY KEY
);

INSERT @Campos(campoOrigen)
VALUES (N'Calle'),(N'NumExt'),(N'NumInt'),(N'Colonia'),
       (N'Del_Municipio'),(N'EstadoFiscal'),(N'CP');

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE C
       SET C.visible=0
    FROM dbo.bf_RepConf_Columna AS C
    INNER JOIN @Campos AS F
      ON UPPER(LTRIM(RTRIM(F.campoOrigen)))=
         UPPER(LTRIM(RTRIM(C.campoOrigen)))
    WHERE C.idEmpresa=@IdEmpresa
      AND C.catReportesId=3
      AND UPPER(LTRIM(RTRIM(C.grupo)))=UPPER(LTRIM(RTRIM(@Grupo)))
      AND ISNULL(C.visible,1)<>0;

    /* Insertar como ocultas las direcciones que no estaban en las 34
       columnas efectivas de BH. Se toma el formato de otra
       configuracion GMM cuando exista. */
    ;WITH Faltantes AS
    (
        SELECT F.campoOrigen,M.MaxOrden,
               P.encabezado,P.ancho,P.formato,P.alinear,P.tipoDato,
               ROW_NUMBER() OVER (ORDER BY F.campoOrigen) AS Posicion
        FROM @Campos AS F
        CROSS APPLY
        (
            SELECT ISNULL(MAX(C.orden),0) AS MaxOrden
            FROM dbo.bf_RepConf_Columna AS C
            WHERE C.idEmpresa=@IdEmpresa
              AND C.catReportesId=3
              AND UPPER(LTRIM(RTRIM(C.grupo)))=
                  UPPER(LTRIM(RTRIM(@Grupo)))
        ) AS M
        OUTER APPLY
        (
            SELECT TOP (1)
                   C.encabezado,C.ancho,C.formato,C.alinear,C.tipoDato
            FROM dbo.bf_RepConf_Columna AS C
            WHERE C.catReportesId=3
              AND UPPER(LTRIM(RTRIM(C.grupo)))=N'GMM'
              AND UPPER(LTRIM(RTRIM(C.campoOrigen)))=
                  UPPER(LTRIM(RTRIM(F.campoOrigen)))
            ORDER BY CASE WHEN C.idEmpresa=0 THEN 0 ELSE 1 END,C.orden
        ) AS P
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.bf_RepConf_Columna AS C
            WHERE C.idEmpresa=@IdEmpresa
              AND C.catReportesId=3
              AND UPPER(LTRIM(RTRIM(C.grupo)))=
                  UPPER(LTRIM(RTRIM(@Grupo)))
              AND UPPER(LTRIM(RTRIM(C.campoOrigen)))=
                  UPPER(LTRIM(RTRIM(F.campoOrigen)))
        )
    )
    INSERT dbo.bf_RepConf_Columna
    (
        idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,
        visible,ancho,formato,alinear,tipoDato,repConfColumnaUsuarioAdd
    )
    SELECT @IdEmpresa,3,@Grupo,MaxOrden+Posicion,campoOrigen,
           ISNULL(encabezado,campoOrigen),0,
           ancho,formato,alinear,tipoDato,0
    FROM Faltantes;

    IF EXISTS
    (
        SELECT 1
        FROM @Campos AS F
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.bf_RepConf_Columna AS C
            WHERE C.idEmpresa=@IdEmpresa
              AND C.catReportesId=3
              AND UPPER(LTRIM(RTRIM(C.grupo)))=
                  UPPER(LTRIM(RTRIM(@Grupo)))
              AND UPPER(LTRIM(RTRIM(C.campoOrigen)))=
                  UPPER(LTRIM(RTRIM(F.campoOrigen)))
              AND ISNULL(C.visible,1)=0
        )
    )
        THROW 50403,'No quedaron ocultas las siete direcciones de BH GMM.',1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT C.idEmpresa,C.grupo,C.campoOrigen,C.encabezado,C.visible,C.orden
FROM dbo.bf_RepConf_Columna AS C
INNER JOIN @Campos AS F
  ON UPPER(LTRIM(RTRIM(F.campoOrigen)))=
     UPPER(LTRIM(RTRIM(C.campoOrigen)))
WHERE C.idEmpresa=@IdEmpresa
  AND C.catReportesId=3
  AND UPPER(LTRIM(RTRIM(C.grupo)))=UPPER(LTRIM(RTRIM(@Grupo)))
ORDER BY C.orden;
GO
