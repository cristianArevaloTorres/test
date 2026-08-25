USE [FlexiForbesv2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.bf_RepConf_Tabla',N'U') IS NULL
    THROW 50140,'No existe dbo.bf_RepConf_Tabla.',1;
IF OBJECT_ID(N'dbo.bf_RepConf_Columna',N'U') IS NULL
    THROW 50141,'No existe dbo.bf_RepConf_Columna.',1;

DECLARE @Hojas TABLE
(
    idEmpresa int NOT NULL,
    Empresa nvarchar(50) NOT NULL,
    grupo nvarchar(100) NOT NULL,
    grupoNormalizado nvarchar(100) NOT NULL,
    PRIMARY KEY(idEmpresa,grupoNormalizado)
);

INSERT @Hojas(idEmpresa,Empresa,grupo,grupoNormalizado)
VALUES (856, N'CORTEVA',N'GMM',N'GMM'),
       (856, N'CORTEVA',N'Vida',N'VIDA'),
       (856, N'CORTEVA',N'Opcionales',N'OPCIONALES'),
       (166, N'ATT',N'Opcionales',N'OPCIONALES'),
       (116, N'SSGT',N'OPC',N'OPCIONALES'),
       (117, N'SSGT',N'OPC',N'OPCIONALES'),
       (1038,N'BH',N'GMM',N'GMM'),
       (1038,N'BH',N'Vida',N'VIDA'),
       (1038,N'BH',N'OPC',N'OPCIONALES');

DECLARE @Campos TABLE
(
    campoOrigen nvarchar(200) NOT NULL PRIMARY KEY,
    SoloVida bit NOT NULL
);

INSERT @Campos(campoOrigen,SoloVida)
VALUES (N'Calle',0),(N'NumExt',0),(N'NumInt',0),(N'Colonia',0),
       (N'Del_Municipio',0),(N'EstadoFiscal',0),(N'CP',0),
       (N'PrimaNeta',1),(N'PrimeNeta',1),(N'Costo',1);

DECLARE @Configuracion TABLE
(
    idEmpresa int NOT NULL,
    Empresa nvarchar(50) NOT NULL,
    grupoNormalizado nvarchar(100) NOT NULL,
    grupoDestino nvarchar(100) NOT NULL,
    grupoFuente nvarchar(100) NOT NULL,
    PRIMARY KEY(idEmpresa,grupoNormalizado)
);

BEGIN TRY
    BEGIN TRANSACTION;

    IF EXISTS
    (
        SELECT 1
        FROM @Hojas AS H
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.bf_RepConf_Tabla AS T
            WHERE T.catReportesId=3
              AND T.idEmpresa=0
              AND CASE
                    WHEN UPPER(LTRIM(RTRIM(T.grupo))) IN
                         (N'OPC',N'OPCIONAL',N'OPCIONALES')
                        THEN N'OPCIONALES'
                    ELSE UPPER(LTRIM(RTRIM(T.grupo)))
                  END=H.grupoNormalizado
        )
    )
        THROW 50142,'Falta configuracion global en dbo.bf_RepConf_Tabla.',1;

    INSERT dbo.bf_RepConf_Tabla
    (
        idEmpresa,catReportesId,grupo,columnaGrupo,agruparPorColumna,
        indexTable,tituloTabla,espacioIzquierda,espacioDerecha,alineacion,
        colorFondo,colorLetra,activo,repConfTablaUsuarioAdd
    )
    SELECT H.idEmpresa,3,H.grupo,T.columnaGrupo,T.agruparPorColumna,
           T.indexTable,T.tituloTabla,T.espacioIzquierda,T.espacioDerecha,
           T.alineacion,T.colorFondo,T.colorLetra,ISNULL(T.activo,1),0
    FROM @Hojas AS H
    CROSS APPLY
    (
        SELECT TOP (1) G.*
        FROM dbo.bf_RepConf_Tabla AS G
        WHERE G.catReportesId=3
          AND G.idEmpresa=0
          AND CASE
                WHEN UPPER(LTRIM(RTRIM(G.grupo))) IN
                     (N'OPC',N'OPCIONAL',N'OPCIONALES')
                    THEN N'OPCIONALES'
                ELSE UPPER(LTRIM(RTRIM(G.grupo)))
              END=H.grupoNormalizado
        ORDER BY CASE WHEN UPPER(LTRIM(RTRIM(G.grupo)))=
                                UPPER(LTRIM(RTRIM(H.grupo)))
                      THEN 0 ELSE 1 END,
                 G.indexTable
    ) AS T
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.bf_RepConf_Tabla AS E
        WHERE E.catReportesId=3
          AND E.idEmpresa=H.idEmpresa
          AND CASE
                WHEN UPPER(LTRIM(RTRIM(E.grupo))) IN
                     (N'OPC',N'OPCIONAL',N'OPCIONALES')
                    THEN N'OPCIONALES'
                ELSE UPPER(LTRIM(RTRIM(E.grupo)))
              END=H.grupoNormalizado
    );

    INSERT @Configuracion
    (
        idEmpresa,Empresa,grupoNormalizado,grupoDestino,grupoFuente
    )
    SELECT H.idEmpresa,H.Empresa,H.grupoNormalizado,
           D.grupo,F.grupo
    FROM @Hojas AS H
    CROSS APPLY
    (
        SELECT TOP (1) T.grupo,T.activo,T.indexTable
        FROM dbo.bf_RepConf_Tabla AS T
        WHERE T.catReportesId=3
          AND T.idEmpresa=H.idEmpresa
          AND CASE
                WHEN UPPER(LTRIM(RTRIM(T.grupo))) IN
                     (N'OPC',N'OPCIONAL',N'OPCIONALES')
                    THEN N'OPCIONALES'
                ELSE UPPER(LTRIM(RTRIM(T.grupo)))
              END=H.grupoNormalizado
        ORDER BY CASE WHEN UPPER(LTRIM(RTRIM(T.grupo)))=
                                UPPER(LTRIM(RTRIM(H.grupo)))
                      THEN 0 ELSE 1 END,
                 CASE WHEN ISNULL(T.activo,1)=1 THEN 0 ELSE 1 END,
                 T.indexTable
    ) AS D
    CROSS APPLY
    (
        SELECT TOP (1) C.grupo
        FROM dbo.bf_RepConf_Columna AS C
        WHERE C.catReportesId=3
          AND C.idEmpresa=0
          AND CASE
                WHEN UPPER(LTRIM(RTRIM(C.grupo))) IN
                     (N'OPC',N'OPCIONAL',N'OPCIONALES')
                    THEN N'OPCIONALES'
                ELSE UPPER(LTRIM(RTRIM(C.grupo)))
              END=H.grupoNormalizado
        ORDER BY CASE WHEN UPPER(LTRIM(RTRIM(C.grupo)))=
                                UPPER(LTRIM(RTRIM(D.grupo)))
                      THEN 0 ELSE 1 END,
                 CASE WHEN UPPER(LTRIM(RTRIM(C.grupo)))=
                                UPPER(LTRIM(RTRIM(H.grupo)))
                      THEN 0 ELSE 1 END
    ) AS F;

    IF (SELECT COUNT(*) FROM @Configuracion)<>(SELECT COUNT(*) FROM @Hojas)
        THROW 50143,'No se pudo resolver la configuracion efectiva de todas las hojas.',1;

    INSERT dbo.bf_RepConf_Columna
    (
        idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,
        visible,ancho,formato,alinear,tipoDato,repConfColumnaUsuarioAdd
    )
    SELECT C.idEmpresa,3,C.grupoDestino,G.orden,G.campoOrigen,G.encabezado,
           G.visible,G.ancho,G.formato,G.alinear,G.tipoDato,0
    FROM @Configuracion AS C
    INNER JOIN dbo.bf_RepConf_Columna AS G
            ON G.idEmpresa=0
           AND G.catReportesId=3
           AND UPPER(LTRIM(RTRIM(G.grupo)))=
               UPPER(LTRIM(RTRIM(C.grupoFuente)))
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.bf_RepConf_Columna AS E
        WHERE E.idEmpresa=C.idEmpresa
          AND E.catReportesId=3
          AND UPPER(LTRIM(RTRIM(E.grupo)))=
              UPPER(LTRIM(RTRIM(C.grupoDestino)))
    );

    UPDATE D
       SET D.visible=0
    FROM dbo.bf_RepConf_Columna AS D
    INNER JOIN @Configuracion AS C
            ON C.idEmpresa=D.idEmpresa
           AND UPPER(LTRIM(RTRIM(C.grupoDestino)))=
               UPPER(LTRIM(RTRIM(D.grupo)))
    INNER JOIN @Campos AS F
            ON UPPER(LTRIM(RTRIM(F.campoOrigen)))=
               UPPER(LTRIM(RTRIM(D.campoOrigen)))
           AND (F.SoloVida=0 OR C.grupoNormalizado=N'VIDA')
    WHERE D.catReportesId=3
      AND ISNULL(D.visible,1)<>0;

    ;WITH Requeridas AS
    (
        SELECT C.idEmpresa,C.Empresa,C.grupoNormalizado,
               C.grupoDestino,C.grupoFuente,F.campoOrigen
        FROM @Configuracion AS C
        CROSS JOIN @Campos AS F
        WHERE F.SoloVida=0 OR C.grupoNormalizado=N'VIDA'
    ),
    Faltantes AS
    (
        SELECT R.idEmpresa,R.Empresa,R.grupoNormalizado,
               R.grupoDestino,R.grupoFuente,R.campoOrigen,
               M.MaxOrden,G.encabezado,G.ancho,G.formato,G.alinear,G.tipoDato,
               ROW_NUMBER() OVER
               (
                   PARTITION BY R.idEmpresa,R.grupoDestino
                   ORDER BY R.campoOrigen
               ) AS Posicion
        FROM Requeridas AS R
        OUTER APPLY
        (
            SELECT ISNULL(MAX(E.orden),0) AS MaxOrden
            FROM dbo.bf_RepConf_Columna AS E
            WHERE E.idEmpresa=R.idEmpresa
              AND E.catReportesId=3
              AND UPPER(LTRIM(RTRIM(E.grupo)))=
                  UPPER(LTRIM(RTRIM(R.grupoDestino)))
        ) AS M
        OUTER APPLY
        (
            SELECT TOP (1) E.encabezado,E.ancho,E.formato,E.alinear,E.tipoDato
            FROM dbo.bf_RepConf_Columna AS E
            WHERE E.idEmpresa=0
              AND E.catReportesId=3
              AND UPPER(LTRIM(RTRIM(E.grupo)))=
                  UPPER(LTRIM(RTRIM(R.grupoFuente)))
              AND UPPER(LTRIM(RTRIM(E.campoOrigen)))=
                  UPPER(LTRIM(RTRIM(R.campoOrigen)))
            ORDER BY E.orden
        ) AS G
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.bf_RepConf_Columna AS E
            WHERE E.idEmpresa=R.idEmpresa
              AND E.catReportesId=3
              AND UPPER(LTRIM(RTRIM(E.grupo)))=
                  UPPER(LTRIM(RTRIM(R.grupoDestino)))
              AND UPPER(LTRIM(RTRIM(E.campoOrigen)))=
                  UPPER(LTRIM(RTRIM(R.campoOrigen)))
        )
    )
    INSERT dbo.bf_RepConf_Columna
    (
        idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,
        visible,ancho,formato,alinear,tipoDato,repConfColumnaUsuarioAdd
    )
    SELECT idEmpresa,3,grupoDestino,MaxOrden+Posicion,campoOrigen,
           ISNULL(encabezado,campoOrigen),0,ancho,formato,alinear,tipoDato,0
    FROM Faltantes;

    IF EXISTS
    (
        SELECT 1
        FROM @Configuracion AS C
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.bf_RepConf_Columna AS E
            WHERE E.idEmpresa=C.idEmpresa
              AND E.catReportesId=3
              AND UPPER(LTRIM(RTRIM(E.grupo)))=
                  UPPER(LTRIM(RTRIM(C.grupoDestino)))
              AND ISNULL(E.visible,1)=1
        )
    )
        THROW 50144,'Una configuracion especifica quedo sin columnas visibles.',1;

    IF EXISTS
    (
        SELECT 1
        FROM @Configuracion AS C
        CROSS JOIN @Campos AS F
        WHERE (F.SoloVida=0 OR C.grupoNormalizado=N'VIDA')
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.bf_RepConf_Columna AS E
              WHERE E.idEmpresa=C.idEmpresa
                AND E.catReportesId=3
                AND UPPER(LTRIM(RTRIM(E.grupo)))=
                    UPPER(LTRIM(RTRIM(C.grupoDestino)))
                AND UPPER(LTRIM(RTRIM(E.campoOrigen)))=
                    UPPER(LTRIM(RTRIM(F.campoOrigen)))
                AND ISNULL(E.visible,1)=0
          )
    )
        THROW 50145,'No fue posible ocultar todas las columnas solicitadas.',1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT N'CONFIGURACION_FINAL' AS Resultado,
       C.idEmpresa,C.Empresa,C.grupoDestino AS grupo,
       SUM(CASE WHEN ISNULL(D.visible,1)=1 THEN 1 ELSE 0 END) AS Visibles,
       SUM(CASE WHEN ISNULL(D.visible,1)=0 THEN 1 ELSE 0 END) AS Ocultas
FROM @Configuracion AS C
INNER JOIN dbo.bf_RepConf_Columna AS D
        ON D.idEmpresa=C.idEmpresa
       AND D.catReportesId=3
       AND UPPER(LTRIM(RTRIM(D.grupo)))=
           UPPER(LTRIM(RTRIM(C.grupoDestino)))
GROUP BY C.idEmpresa,C.Empresa,C.grupoDestino
ORDER BY C.idEmpresa,C.grupoDestino;

SELECT N'COLUMNAS_OCULTAS' AS Resultado,
       C.idEmpresa,C.Empresa,C.grupoDestino AS grupo,
       D.orden,D.campoOrigen,D.encabezado,D.visible
FROM @Configuracion AS C
INNER JOIN dbo.bf_RepConf_Columna AS D
        ON D.idEmpresa=C.idEmpresa
       AND D.catReportesId=3
       AND UPPER(LTRIM(RTRIM(D.grupo)))=
           UPPER(LTRIM(RTRIM(C.grupoDestino)))
INNER JOIN @Campos AS F
        ON UPPER(LTRIM(RTRIM(F.campoOrigen)))=
           UPPER(LTRIM(RTRIM(D.campoOrigen)))
       AND (F.SoloVida=0 OR C.grupoNormalizado=N'VIDA')
ORDER BY C.idEmpresa,C.grupoDestino,D.orden;
GO
