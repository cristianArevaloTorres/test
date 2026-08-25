USE [FlexiForbesv2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

/*
La ejecucion diagnosticada de BH carga:
  idEmpresaParam = 1039
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

DECLARE @IdEmpresa int=1039,
        @GrupoGlobal nvarchar(100),
        @Grupo nvarchar(100);

SELECT TOP (1) @GrupoGlobal=T.grupo
FROM dbo.bf_RepConf_Tabla AS T
WHERE T.idEmpresa=0
  AND T.catReportesId=3
  AND UPPER(LTRIM(RTRIM(T.grupo)))=N'GMM'
ORDER BY CASE WHEN ISNULL(T.activo,1)=1 THEN 0 ELSE 1 END,T.indexTable;

IF @GrupoGlobal IS NULL
    THROW 50402,'No existe configuracion global GMM del reporte 3.',1;

DECLARE @Campos TABLE
(
    campoOrigen nvarchar(200) NOT NULL PRIMARY KEY
);

INSERT @Campos(campoOrigen)
VALUES (N'Calle'),(N'NumExt'),(N'NumInt'),(N'Colonia'),
       (N'Del_Municipio'),(N'EstadoFiscal'),(N'CP');

BEGIN TRY
    BEGIN TRANSACTION;

    /* BH 1039 estaba usando idEmpresaConfig=0. Crear primero una tabla
       especifica completa evita que, al agregar columnas ocultas, el API
       descarte las otras columnas provenientes de la configuracion global. */
    INSERT dbo.bf_RepConf_Tabla
    (
        idEmpresa,catReportesId,grupo,columnaGrupo,agruparPorColumna,
        indexTable,tituloTabla,espacioIzquierda,espacioDerecha,alineacion,
        colorFondo,colorLetra,activo,repConfTablaUsuarioAdd
    )
    SELECT TOP (1)
           @IdEmpresa,3,N'GMM',T.columnaGrupo,T.agruparPorColumna,
           T.indexTable,T.tituloTabla,T.espacioIzquierda,T.espacioDerecha,
           T.alineacion,T.colorFondo,T.colorLetra,ISNULL(T.activo,1),0
    FROM dbo.bf_RepConf_Tabla AS T
    WHERE T.idEmpresa=0
      AND T.catReportesId=3
      AND UPPER(LTRIM(RTRIM(T.grupo)))=N'GMM'
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.bf_RepConf_Tabla AS E
          WHERE E.idEmpresa=@IdEmpresa
            AND E.catReportesId=3
            AND UPPER(LTRIM(RTRIM(E.grupo)))=N'GMM'
      )
    ORDER BY CASE WHEN ISNULL(T.activo,1)=1 THEN 0 ELSE 1 END,T.indexTable;

    SELECT TOP (1) @Grupo=T.grupo
    FROM dbo.bf_RepConf_Tabla AS T
    WHERE T.idEmpresa=@IdEmpresa
      AND T.catReportesId=3
      AND UPPER(LTRIM(RTRIM(T.grupo)))=N'GMM'
    ORDER BY CASE WHEN ISNULL(T.activo,1)=1 THEN 0 ELSE 1 END,T.indexTable;

    IF @Grupo IS NULL
        THROW 50404,'No se pudo crear/resolver GMM para BH idEmpresa 1039.',1;

    /* Clonar todos los campos globales faltantes. bf_RepConf_Columna usa
       configuracion especifica o global, no una mezcla; por eso se requiere
       copiar la lista completa antes de personalizar las direcciones. */
    ;WITH Fuente AS
    (
        SELECT C.*,
               ROW_NUMBER() OVER
               (
                   PARTITION BY UPPER(LTRIM(RTRIM(C.campoOrigen)))
                   ORDER BY C.orden
               ) AS Duplicado
        FROM dbo.bf_RepConf_Columna AS C
        WHERE C.idEmpresa=0
          AND C.catReportesId=3
          AND UPPER(LTRIM(RTRIM(C.grupo)))=
              UPPER(LTRIM(RTRIM(@GrupoGlobal)))
    ),
    FaltantesGlobales AS
    (
        SELECT G.orden,G.campoOrigen,G.encabezado,G.visible,G.ancho,
               G.formato,G.alinear,G.tipoDato,M.MaxOrden,
               ROW_NUMBER() OVER
                   (ORDER BY G.orden,G.campoOrigen) AS Posicion
        FROM Fuente AS G
        CROSS APPLY
        (
            SELECT ISNULL(MAX(E.orden),0) AS MaxOrden
            FROM dbo.bf_RepConf_Columna AS E
            WHERE E.idEmpresa=@IdEmpresa
              AND E.catReportesId=3
              AND UPPER(LTRIM(RTRIM(E.grupo)))=
                  UPPER(LTRIM(RTRIM(@Grupo)))
        ) AS M
        WHERE G.Duplicado=1
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.bf_RepConf_Columna AS E
              WHERE E.idEmpresa=@IdEmpresa
                AND E.catReportesId=3
                AND UPPER(LTRIM(RTRIM(E.grupo)))=
                    UPPER(LTRIM(RTRIM(@Grupo)))
                AND UPPER(LTRIM(RTRIM(E.campoOrigen)))=
                    UPPER(LTRIM(RTRIM(G.campoOrigen)))
          )
    )
    INSERT dbo.bf_RepConf_Columna
    (
        idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,
        visible,ancho,formato,alinear,tipoDato,repConfColumnaUsuarioAdd
    )
    SELECT @IdEmpresa,3,@Grupo,MaxOrden+Posicion,campoOrigen,encabezado,
           visible,ancho,formato,alinear,tipoDato,0
    FROM FaltantesGlobales;

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

    /* Insertar como ocultas las direcciones que no estuvieran en la
       configuracion especifica de BH. Se toma el formato de otra
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

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.bf_RepConf_Columna AS C
        WHERE C.idEmpresa=@IdEmpresa
          AND C.catReportesId=3
          AND UPPER(LTRIM(RTRIM(C.grupo)))=UPPER(LTRIM(RTRIM(@Grupo)))
          AND ISNULL(C.visible,1)=1
    )
        THROW 50405,'BH GMM quedo sin columnas visibles; se revierte el cambio.',1;

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
