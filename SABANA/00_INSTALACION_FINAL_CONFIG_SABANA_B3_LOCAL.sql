USE [FlexiForbesv2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

/*
INSTALACION FINAL LOCAL - CONFIGURACION SABANA B3

1. Reemplaza completamente bf_RepConf_Tabla con doc12.csv.
2. Reemplaza completamente bf_RepConf_Columna con doc11.csv.
3. Aplica exclusivamente la matriz B3 vs B2 confirmada:
     GMM  -> ocultar Calle, NumExt, NumInt, Colonia,
             Del_Municipio, EstadoFiscal y CP.
     VIDA -> ocultar las siete anteriores, PrimaNeta/PrimeNeta y Costo.
   Empresas cubiertas:
     CORTEVA/PHI:       856 y 332.
     BH:                1038 y 1039.
     ZURICH SANTANDER:  1806 y 1807.

ATT 166, SSGT 116/117 y todas las hojas Opcionales quedan fuera.
*/

IF OBJECT_ID(N'dbo.bf_RepConf_Tabla',N'U') IS NULL
    THROW 50500,'No existe dbo.bf_RepConf_Tabla.',1;
IF OBJECT_ID(N'dbo.bf_RepConf_Columna',N'U') IS NULL
    THROW 50501,'No existe dbo.bf_RepConf_Columna.',1;

/* Respaldo recuperable del estado anterior a la primera ejecucion. */
IF OBJECT_ID(N'dbo.bf_RepConf_Tabla_BAK_20260825_ANTES_FINAL',N'U') IS NULL
    SELECT * INTO dbo.bf_RepConf_Tabla_BAK_20260825_ANTES_FINAL
    FROM dbo.bf_RepConf_Tabla;

IF OBJECT_ID(N'dbo.bf_RepConf_Columna_BAK_20260825_ANTES_FINAL',N'U') IS NULL
    SELECT * INTO dbo.bf_RepConf_Columna_BAK_20260825_ANTES_FINAL
    FROM dbo.bf_RepConf_Columna;

CREATE TABLE #CargaTabla
(
    c1 nvarchar(max),c2 nvarchar(max),c3 nvarchar(max),c4 nvarchar(max),
    c5 nvarchar(max),c6 nvarchar(max),c7 nvarchar(max),c8 nvarchar(max),
    c9 nvarchar(max),c10 nvarchar(max),c11 nvarchar(max),c12 nvarchar(max),
    c13 nvarchar(max),c14 nvarchar(max),c15 nvarchar(max),c16 nvarchar(max),
    c17 nvarchar(max),c18 nvarchar(max),c19 nvarchar(max)
);

CREATE TABLE #CargaColumna
(
    c1 nvarchar(max),c2 nvarchar(max),c3 nvarchar(max),c4 nvarchar(max),
    c5 nvarchar(max),c6 nvarchar(max),c7 nvarchar(max),c8 nvarchar(max),
    c9 nvarchar(max),c10 nvarchar(max),c11 nvarchar(max),c12 nvarchar(max),
    c13 nvarchar(max),c14 nvarchar(max),c15 nvarchar(max),c16 nvarchar(max),
    c17 nvarchar(max)
);

BULK INSERT #CargaTabla
FROM 'C:\Users\sanel\Downloads\doc12.csv'
WITH
(
    FORMAT='CSV',FIELDQUOTE='"',CODEPAGE='65001',
    ROWTERMINATOR='0x0a',TABLOCK
);

BULK INSERT #CargaColumna
FROM 'C:\Users\sanel\Downloads\doc11.csv'
WITH
(
    FORMAT='CSV',FIELDQUOTE='"',CODEPAGE='65001',
    ROWTERMINATOR='0x0a',TABLOCK
);

IF (SELECT COUNT(*) FROM #CargaTabla)<>319
    THROW 50502,'doc12.csv no contiene las 319 filas esperadas.',1;
IF (SELECT COUNT(*) FROM #CargaColumna)<>11267
    THROW 50503,'doc11.csv no contiene las 11267 filas esperadas.',1;

IF EXISTS
(
    SELECT 1
    FROM #CargaTabla
    WHERE TRY_CONVERT(int,c1) IS NULL
       OR TRY_CONVERT(int,c2) IS NULL
       OR NULLIF(LTRIM(RTRIM(c3)),N'') IS NULL
       OR TRY_CONVERT(bit,c5) IS NULL
       OR TRY_CONVERT(bit,c13) IS NULL
       OR TRY_CONVERT(int,c14) IS NULL
       OR TRY_CONVERT(datetime,c15,121) IS NULL
)
    THROW 50504,'doc12.csv contiene datos obligatorios invalidos.',1;

IF EXISTS
(
    SELECT 1
    FROM #CargaColumna
    WHERE TRY_CONVERT(int,c1) IS NULL
       OR TRY_CONVERT(int,c2) IS NULL
       OR NULLIF(LTRIM(RTRIM(c3)),N'') IS NULL
       OR TRY_CONVERT(int,c4) IS NULL
       OR NULLIF(LTRIM(RTRIM(c6)),N'') IS NULL
       OR TRY_CONVERT(bit,c7) IS NULL
       OR TRY_CONVERT(int,c12) IS NULL
       OR TRY_CONVERT(datetime,c13,121) IS NULL
)
    THROW 50505,'doc11.csv contiene datos obligatorios invalidos.',1;

IF EXISTS
(
    SELECT 1
    FROM #CargaTabla
    GROUP BY TRY_CONVERT(int,c1),TRY_CONVERT(int,c2),UPPER(LTRIM(RTRIM(c3)))
    HAVING COUNT(*)>1
)
    THROW 50506,'doc12.csv contiene claves duplicadas.',1;

IF EXISTS
(
    SELECT 1
    FROM #CargaColumna
    GROUP BY TRY_CONVERT(int,c1),TRY_CONVERT(int,c2),
             UPPER(LTRIM(RTRIM(c3))),TRY_CONVERT(int,c4)
    HAVING COUNT(*)>1
)
    THROW 50507,'doc11.csv contiene ordenes duplicados.',1;

IF EXISTS
(
    SELECT 1
    FROM #CargaColumna
    GROUP BY TRY_CONVERT(int,c1),TRY_CONVERT(int,c2),
             UPPER(LTRIM(RTRIM(c3))),UPPER(LTRIM(RTRIM(c5)))
    HAVING COUNT(*)>1
)
    THROW 50508,'doc11.csv contiene campos duplicados.',1;

DECLARE @Target TABLE
(
    idEmpresa int NOT NULL,
    Empresa nvarchar(60) NOT NULL,
    grupoNormalizado nvarchar(20) NOT NULL,
    grupoSugerido nvarchar(100) NOT NULL,
    idEmpresaFuente int NOT NULL,
    QuitarPrimaCosto bit NOT NULL,
    PRIMARY KEY(idEmpresa,grupoNormalizado)
);

INSERT @Target
    (idEmpresa,Empresa,grupoNormalizado,grupoSugerido,
     idEmpresaFuente,QuitarPrimaCosto)
VALUES
    (332,N'CORTEVA/PHI',N'GMM',N'GMM',856,0),
    (332,N'CORTEVA/PHI',N'VIDA',N'Vida',856,1),
    (856,N'CORTEVA',N'GMM',N'GMM',0,0),
    (856,N'CORTEVA',N'VIDA',N'Vida',0,1),
    (1038,N'BH',N'GMM',N'GMM',0,0),
    (1038,N'BH',N'VIDA',N'Vida',0,1),
    (1039,N'BH PRODUCTS',N'GMM',N'GMM',1038,0),
    (1039,N'BH PRODUCTS',N'VIDA',N'Vida',1038,1),
    (1806,N'ZURICH SANTANDER',N'GMM',N'GMM',0,0),
    (1806,N'ZURICH SANTANDER',N'VIDA',N'Vida',0,1),
    (1807,N'ZURICH SANTANDER',N'GMM',N'GMM',0,0),
    (1807,N'ZURICH SANTANDER',N'VIDA',N'Vida',0,1);

DECLARE @Campos TABLE
(
    campoOrigen nvarchar(256) NOT NULL PRIMARY KEY,
    SoloVida bit NOT NULL
);

INSERT @Campos(campoOrigen,SoloVida)
VALUES (N'Calle',0),(N'NumExt',0),(N'NumInt',0),(N'Colonia',0),
       (N'Del_Municipio',0),(N'EstadoFiscal',0),(N'CP',0),
       (N'PrimaNeta',1),(N'PrimeNeta',1),(N'Costo',1);

DECLARE @Mostrar TABLE
(
    idEmpresa int NOT NULL,
    grupoNormalizado nvarchar(20) NOT NULL,
    PRIMARY KEY(idEmpresa,grupoNormalizado)
);

/* Combinaciones fuera de la matriz que fueron afectadas por pruebas previas. */
INSERT @Mostrar(idEmpresa,grupoNormalizado)
VALUES (116,N'OPCIONALES'),(117,N'OPCIONALES'),
       (166,N'GMM'),(166,N'VIDA'),(166,N'OPCIONALES'),
       (332,N'OPCIONALES'),(856,N'OPCIONALES'),
       (1038,N'OPCIONALES'),(1039,N'OPCIONALES');

DECLARE @TargetResuelto TABLE
(
    idEmpresa int NOT NULL,
    Empresa nvarchar(60) NOT NULL,
    grupoNormalizado nvarchar(20) NOT NULL,
    grupoDestino nvarchar(100) NOT NULL,
    idEmpresaFuente int NOT NULL,
    QuitarPrimaCosto bit NOT NULL,
    PRIMARY KEY(idEmpresa,grupoNormalizado)
);

BEGIN TRY
    BEGIN TRANSACTION;

    DELETE FROM dbo.bf_RepConf_Columna;
    DELETE FROM dbo.bf_RepConf_Tabla;

    INSERT dbo.bf_RepConf_Tabla
    (
        idEmpresa,catReportesId,grupo,columnaGrupo,agruparPorColumna,
        indexTable,tituloTabla,espacioIzquierda,espacioDerecha,alineacion,
        colorFondo,colorLetra,activo,repConfTablaUsuarioAdd,
        repConfTablaFechaAdd,repConfTablaUsuarioMod,repConfTablaFechaMod,
        repConfTablaUsuarioDel,repConfTablaFechaDel
    )
    SELECT TRY_CONVERT(int,c1),TRY_CONVERT(int,c2),c3,
           CASE WHEN UPPER(LTRIM(RTRIM(c4)))=N'NULL' THEN NULL ELSE c4 END,
           TRY_CONVERT(bit,c5),
           TRY_CONVERT(int,NULLIF(c6,N'NULL')),
           CASE WHEN UPPER(LTRIM(RTRIM(c7)))=N'NULL' THEN NULL ELSE c7 END,
           TRY_CONVERT(int,NULLIF(c8,N'NULL')),
           TRY_CONVERT(int,NULLIF(c9,N'NULL')),
           CASE WHEN UPPER(LTRIM(RTRIM(c10)))=N'NULL' THEN NULL ELSE c10 END,
           CASE WHEN UPPER(LTRIM(RTRIM(c11)))=N'NULL' THEN NULL ELSE c11 END,
           CASE WHEN UPPER(LTRIM(RTRIM(c12)))=N'NULL' THEN NULL ELSE c12 END,
           TRY_CONVERT(bit,c13),TRY_CONVERT(int,c14),
           TRY_CONVERT(datetime,c15,121),
           TRY_CONVERT(int,NULLIF(c16,N'NULL')),
           TRY_CONVERT(datetime,NULLIF(c17,N'NULL'),121),
           TRY_CONVERT(int,NULLIF(c18,N'NULL')),
           TRY_CONVERT(datetime,NULLIF(REPLACE(c19,CHAR(13),N''),N'NULL'),121)
    FROM #CargaTabla;

    INSERT dbo.bf_RepConf_Columna
    (
        idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,
        ancho,formato,alinear,tipoDato,repConfColumnaUsuarioAdd,
        repConfColumnaFechaAdd,repConfColumnaUsuarioMod,
        repConfColumnaFechaMod,repConfColumnaUsuarioDel,
        repConfColumnaFechaDel
    )
    SELECT TRY_CONVERT(int,c1),TRY_CONVERT(int,c2),c3,TRY_CONVERT(int,c4),
            COALESCE(c5,N''),c6,TRY_CONVERT(bit,c7),
           TRY_CONVERT(int,NULLIF(c8,N'NULL')),
           CASE WHEN UPPER(LTRIM(RTRIM(c9)))=N'NULL' THEN NULL ELSE c9 END,
           CASE WHEN UPPER(LTRIM(RTRIM(c10)))=N'NULL' THEN NULL ELSE c10 END,
           TRY_CONVERT(int,NULLIF(c11,N'NULL')),TRY_CONVERT(int,c12),
           TRY_CONVERT(datetime,c13,121),
           TRY_CONVERT(int,NULLIF(c14,N'NULL')),
           TRY_CONVERT(datetime,NULLIF(c15,N'NULL'),121),
           TRY_CONVERT(int,NULLIF(c16,N'NULL')),
           TRY_CONVERT(datetime,NULLIF(REPLACE(c17,CHAR(13),N''),N'NULL'),121)
    FROM #CargaColumna;

    IF (SELECT COUNT(*) FROM dbo.bf_RepConf_Tabla)<>319
        THROW 50509,'No se cargaron las 319 filas de bf_RepConf_Tabla.',1;
    IF (SELECT COUNT(*) FROM dbo.bf_RepConf_Columna)<>11267
        THROW 50510,'No se cargaron las 11267 filas de bf_RepConf_Columna.',1;

    /* Crear tablas especificas faltantes para los IDs efectivos B3. */
    INSERT dbo.bf_RepConf_Tabla
    (
        idEmpresa,catReportesId,grupo,columnaGrupo,agruparPorColumna,
        indexTable,tituloTabla,espacioIzquierda,espacioDerecha,alineacion,
        colorFondo,colorLetra,activo,repConfTablaUsuarioAdd,
        repConfTablaFechaAdd,repConfTablaUsuarioMod,repConfTablaFechaMod,
        repConfTablaUsuarioDel,repConfTablaFechaDel
    )
    SELECT T.idEmpresa,3,T.grupoSugerido,S.columnaGrupo,S.agruparPorColumna,
           S.indexTable,S.tituloTabla,S.espacioIzquierda,S.espacioDerecha,
           S.alineacion,S.colorFondo,S.colorLetra,ISNULL(S.activo,1),0,
           GETDATE(),NULL,NULL,NULL,NULL
    FROM @Target AS T
    CROSS APPLY
    (
        SELECT TOP (1) X.*
        FROM dbo.bf_RepConf_Tabla AS X
        WHERE X.catReportesId=3
          AND X.idEmpresa IN(T.idEmpresaFuente,0)
          AND UPPER(LTRIM(RTRIM(X.grupo)))=T.grupoNormalizado
        ORDER BY CASE WHEN X.idEmpresa=T.idEmpresaFuente THEN 0 ELSE 1 END,
                 CASE WHEN ISNULL(X.activo,1)=1 THEN 0 ELSE 1 END,X.indexTable
    ) AS S
    WHERE NOT EXISTS
    (
        SELECT 1 FROM dbo.bf_RepConf_Tabla AS E
        WHERE E.idEmpresa=T.idEmpresa AND E.catReportesId=3
          AND UPPER(LTRIM(RTRIM(E.grupo)))=T.grupoNormalizado
    );

    INSERT @TargetResuelto
        (idEmpresa,Empresa,grupoNormalizado,grupoDestino,
         idEmpresaFuente,QuitarPrimaCosto)
    SELECT T.idEmpresa,T.Empresa,T.grupoNormalizado,D.grupo,
           T.idEmpresaFuente,T.QuitarPrimaCosto
    FROM @Target AS T
    CROSS APPLY
    (
        SELECT TOP (1) X.grupo
        FROM dbo.bf_RepConf_Tabla AS X
        WHERE X.idEmpresa=T.idEmpresa AND X.catReportesId=3
          AND UPPER(LTRIM(RTRIM(X.grupo)))=T.grupoNormalizado
        ORDER BY CASE WHEN ISNULL(X.activo,1)=1 THEN 0 ELSE 1 END,X.indexTable
    ) AS D;

    IF (SELECT COUNT(*) FROM @TargetResuelto)<>(SELECT COUNT(*) FROM @Target)
        THROW 50511,'No se resolvieron todas las tablas de la matriz.',1;

    /* Cuando no existe ninguna columna especifica, clonar la lista completa
       desde la empresa perfil o desde idEmpresa=0. */
    ;WITH SinColumnas AS
    (
        SELECT R.*
        FROM @TargetResuelto AS R
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.bf_RepConf_Columna AS C
            WHERE C.idEmpresa=R.idEmpresa AND C.catReportesId=3
              AND UPPER(LTRIM(RTRIM(C.grupo)))=R.grupoNormalizado
        )
    ),
    FuenteElegida AS
    (
        SELECT R.*,F.idEmpresa AS idFuente,F.grupo AS grupoFuente
        FROM SinColumnas AS R
        CROSS APPLY
        (
            SELECT TOP (1) C.idEmpresa,C.grupo
            FROM dbo.bf_RepConf_Columna AS C
            WHERE C.catReportesId=3
              AND C.idEmpresa IN(R.idEmpresaFuente,0)
              AND UPPER(LTRIM(RTRIM(C.grupo)))=R.grupoNormalizado
            GROUP BY C.idEmpresa,C.grupo
            ORDER BY CASE WHEN C.idEmpresa=R.idEmpresaFuente THEN 0 ELSE 1 END
        ) AS F
    ),
    FuenteDeduplicada AS
    (
        SELECT R.idEmpresa AS idEmpresaDestino,R.grupoDestino,
               C.orden,C.campoOrigen,C.encabezado,C.visible,C.ancho,
               C.formato,C.alinear,C.tipoDato,
               ROW_NUMBER() OVER
               (
                   PARTITION BY R.idEmpresa,R.grupoDestino,
                                UPPER(LTRIM(RTRIM(C.campoOrigen)))
                   ORDER BY C.orden
               ) AS Duplicado
        FROM FuenteElegida AS R
        INNER JOIN dbo.bf_RepConf_Columna AS C
          ON C.idEmpresa=R.idFuente AND C.catReportesId=3
         AND UPPER(LTRIM(RTRIM(C.grupo)))=
             UPPER(LTRIM(RTRIM(R.grupoFuente)))
    )
    INSERT dbo.bf_RepConf_Columna
    (
        idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,
        ancho,formato,alinear,tipoDato,repConfColumnaUsuarioAdd,
        repConfColumnaFechaAdd,repConfColumnaUsuarioMod,
        repConfColumnaFechaMod,repConfColumnaUsuarioDel,
        repConfColumnaFechaDel
    )
    SELECT idEmpresaDestino,3,grupoDestino,
           ROW_NUMBER() OVER(PARTITION BY idEmpresaDestino,grupoDestino
                             ORDER BY orden,campoOrigen),
           campoOrigen,encabezado,visible,ancho,formato,alinear,tipoDato,
           0,GETDATE(),NULL,NULL,NULL,NULL
    FROM FuenteDeduplicada
    WHERE Duplicado=1;

    /* Agregar como oculto cualquier campo de la matriz que falte. */
    ;WITH Faltantes AS
    (
        SELECT R.idEmpresa,R.Empresa,R.grupoNormalizado,R.grupoDestino,
               F.campoOrigen,M.MaxOrden,P.encabezado,P.ancho,P.formato,
               P.alinear,P.tipoDato,
               ROW_NUMBER() OVER
               (PARTITION BY R.idEmpresa,R.grupoDestino
                ORDER BY F.campoOrigen) AS Posicion
        FROM @TargetResuelto AS R
        CROSS JOIN @Campos AS F
        CROSS APPLY
        (
            SELECT ISNULL(MAX(C.orden),0) AS MaxOrden
            FROM dbo.bf_RepConf_Columna AS C
            WHERE C.idEmpresa=R.idEmpresa AND C.catReportesId=3
              AND UPPER(LTRIM(RTRIM(C.grupo)))=R.grupoNormalizado
        ) AS M
        OUTER APPLY
        (
            SELECT TOP (1) C.encabezado,C.ancho,C.formato,C.alinear,C.tipoDato
            FROM dbo.bf_RepConf_Columna AS C
            WHERE C.catReportesId=3
              AND UPPER(LTRIM(RTRIM(C.grupo)))=R.grupoNormalizado
              AND UPPER(LTRIM(RTRIM(C.campoOrigen)))=
                  UPPER(LTRIM(RTRIM(F.campoOrigen)))
            ORDER BY CASE WHEN C.idEmpresa=R.idEmpresa THEN 0
                          WHEN C.idEmpresa=R.idEmpresaFuente THEN 1
                          WHEN C.idEmpresa=0 THEN 2 ELSE 3 END,C.orden
        ) AS P
        WHERE (F.SoloVida=0 OR R.QuitarPrimaCosto=1)
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.bf_RepConf_Columna AS C
              WHERE C.idEmpresa=R.idEmpresa AND C.catReportesId=3
                AND UPPER(LTRIM(RTRIM(C.grupo)))=R.grupoNormalizado
                AND UPPER(LTRIM(RTRIM(C.campoOrigen)))=
                    UPPER(LTRIM(RTRIM(F.campoOrigen)))
          )
    )
    INSERT dbo.bf_RepConf_Columna
    (
        idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,
        ancho,formato,alinear,tipoDato,repConfColumnaUsuarioAdd,
        repConfColumnaFechaAdd,repConfColumnaUsuarioMod,
        repConfColumnaFechaMod,repConfColumnaUsuarioDel,
        repConfColumnaFechaDel
    )
    SELECT idEmpresa,3,grupoDestino,MaxOrden+Posicion,campoOrigen,
           ISNULL(encabezado,campoOrigen),0,ancho,formato,alinear,tipoDato,
           0,GETDATE(),NULL,NULL,NULL,NULL
    FROM Faltantes;

    UPDATE C
       SET C.visible=0,
           C.repConfColumnaUsuarioMod=0,
           C.repConfColumnaFechaMod=GETDATE()
    FROM dbo.bf_RepConf_Columna AS C
    INNER JOIN @TargetResuelto AS R
      ON R.idEmpresa=C.idEmpresa
     AND UPPER(LTRIM(RTRIM(C.grupo)))=R.grupoNormalizado
    INNER JOIN @Campos AS F
      ON UPPER(LTRIM(RTRIM(F.campoOrigen)))=
         UPPER(LTRIM(RTRIM(C.campoOrigen)))
     AND (F.SoloVida=0 OR R.QuitarPrimaCosto=1)
    WHERE C.catReportesId=3 AND ISNULL(C.visible,1)<>0;

    /* Restaurar direcciones de combinaciones expresamente fuera de matriz. */
    ;WITH MostrarResuelto AS
    (
        SELECT M.idEmpresa,M.grupoNormalizado,T.grupo AS grupoDestino
        FROM @Mostrar AS M
        CROSS APPLY
        (
            SELECT TOP (1) X.grupo
            FROM dbo.bf_RepConf_Tabla AS X
            WHERE X.idEmpresa=M.idEmpresa AND X.catReportesId=3
              AND CASE WHEN UPPER(LTRIM(RTRIM(X.grupo))) IN
                            (N'OPC',N'OPCIONAL',N'OPCIONALES')
                       THEN N'OPCIONALES'
                       ELSE UPPER(LTRIM(RTRIM(X.grupo))) END=M.grupoNormalizado
            ORDER BY CASE WHEN ISNULL(X.activo,1)=1 THEN 0 ELSE 1 END,X.indexTable
        ) AS T
    ),
    FaltantesMostrar AS
    (
        SELECT R.idEmpresa,R.grupoNormalizado,R.grupoDestino,F.campoOrigen,
               M.MaxOrden,P.encabezado,P.ancho,P.formato,P.alinear,P.tipoDato,
               ROW_NUMBER() OVER
               (PARTITION BY R.idEmpresa,R.grupoDestino
                ORDER BY F.campoOrigen) AS Posicion
        FROM MostrarResuelto AS R
        CROSS JOIN @Campos AS F
        CROSS APPLY
        (
            SELECT ISNULL(MAX(C.orden),0) AS MaxOrden
            FROM dbo.bf_RepConf_Columna AS C
            WHERE C.idEmpresa=R.idEmpresa AND C.catReportesId=3
              AND UPPER(LTRIM(RTRIM(C.grupo)))=
                  UPPER(LTRIM(RTRIM(R.grupoDestino)))
        ) AS M
        OUTER APPLY
        (
            SELECT TOP (1) C.encabezado,C.ancho,C.formato,C.alinear,C.tipoDato
            FROM dbo.bf_RepConf_Columna AS C
            WHERE C.catReportesId=3
              AND UPPER(LTRIM(RTRIM(C.campoOrigen)))=
                  UPPER(LTRIM(RTRIM(F.campoOrigen)))
              AND CASE WHEN UPPER(LTRIM(RTRIM(C.grupo))) IN
                            (N'OPC',N'OPCIONAL',N'OPCIONALES')
                       THEN N'OPCIONALES'
                       ELSE UPPER(LTRIM(RTRIM(C.grupo))) END=R.grupoNormalizado
            ORDER BY CASE WHEN C.idEmpresa=0 THEN 0 ELSE 1 END,C.orden
        ) AS P
        WHERE F.SoloVida=0
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.bf_RepConf_Columna AS C
              WHERE C.idEmpresa=R.idEmpresa AND C.catReportesId=3
                AND UPPER(LTRIM(RTRIM(C.grupo)))=
                    UPPER(LTRIM(RTRIM(R.grupoDestino)))
                AND UPPER(LTRIM(RTRIM(C.campoOrigen)))=
                    UPPER(LTRIM(RTRIM(F.campoOrigen)))
          )
    )
    INSERT dbo.bf_RepConf_Columna
    (
        idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,
        ancho,formato,alinear,tipoDato,repConfColumnaUsuarioAdd,
        repConfColumnaFechaAdd,repConfColumnaUsuarioMod,
        repConfColumnaFechaMod,repConfColumnaUsuarioDel,
        repConfColumnaFechaDel
    )
    SELECT idEmpresa,3,grupoDestino,MaxOrden+Posicion,campoOrigen,
           ISNULL(encabezado,campoOrigen),1,ancho,formato,alinear,tipoDato,
           0,GETDATE(),NULL,NULL,NULL,NULL
    FROM FaltantesMostrar;

    UPDATE C
       SET C.visible=1,
           C.repConfColumnaUsuarioMod=0,
           C.repConfColumnaFechaMod=GETDATE()
    FROM dbo.bf_RepConf_Columna AS C
    INNER JOIN @Mostrar AS M ON M.idEmpresa=C.idEmpresa
      AND CASE WHEN UPPER(LTRIM(RTRIM(C.grupo))) IN
                    (N'OPC',N'OPCIONAL',N'OPCIONALES')
               THEN N'OPCIONALES'
               ELSE UPPER(LTRIM(RTRIM(C.grupo))) END=M.grupoNormalizado
    INNER JOIN @Campos AS F
      ON F.SoloVida=0
     AND UPPER(LTRIM(RTRIM(F.campoOrigen)))=
         UPPER(LTRIM(RTRIM(C.campoOrigen)))
    WHERE C.catReportesId=3 AND ISNULL(C.visible,1)<>1;

    IF EXISTS
    (
        SELECT 1
        FROM @TargetResuelto AS R
        CROSS JOIN @Campos AS F
        WHERE (F.SoloVida=0 OR R.QuitarPrimaCosto=1)
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.bf_RepConf_Columna AS C
              WHERE C.idEmpresa=R.idEmpresa AND C.catReportesId=3
                AND UPPER(LTRIM(RTRIM(C.grupo)))=R.grupoNormalizado
                AND UPPER(LTRIM(RTRIM(C.campoOrigen)))=
                    UPPER(LTRIM(RTRIM(F.campoOrigen)))
                AND C.visible=0
          )
    )
        THROW 50512,'La matriz final no quedo completamente oculta.',1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.bf_RepConf_Columna AS C
        INNER JOIN @Mostrar AS M ON M.idEmpresa=C.idEmpresa
          AND CASE WHEN UPPER(LTRIM(RTRIM(C.grupo))) IN
                        (N'OPC',N'OPCIONAL',N'OPCIONALES')
                   THEN N'OPCIONALES'
                   ELSE UPPER(LTRIM(RTRIM(C.grupo))) END=M.grupoNormalizado
        INNER JOIN @Campos AS F
          ON F.SoloVida=0
         AND UPPER(LTRIM(RTRIM(F.campoOrigen)))=
             UPPER(LTRIM(RTRIM(C.campoOrigen)))
        WHERE C.catReportesId=3 AND C.visible<>1
    )
        THROW 50513,'Una combinacion fuera de la matriz quedo oculta.',1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT N'CONTEOS_FINALES' AS Resultado,
       (SELECT COUNT(*) FROM dbo.bf_RepConf_Tabla) AS FilasTabla,
       (SELECT COUNT(*) FROM dbo.bf_RepConf_Columna) AS FilasColumna;

SELECT R.Empresa,R.idEmpresa,R.grupoNormalizado,
       C.campoOrigen,C.visible
FROM @TargetResuelto AS R
INNER JOIN dbo.bf_RepConf_Columna AS C
  ON C.idEmpresa=R.idEmpresa AND C.catReportesId=3
 AND UPPER(LTRIM(RTRIM(C.grupo)))=R.grupoNormalizado
INNER JOIN @Campos AS F
  ON UPPER(LTRIM(RTRIM(F.campoOrigen)))=
     UPPER(LTRIM(RTRIM(C.campoOrigen)))
 AND (F.SoloVida=0 OR R.QuitarPrimaCosto=1)
ORDER BY R.Empresa,R.idEmpresa,R.grupoNormalizado,C.campoOrigen;
GO
