USE [FlexiForbesv2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

/*
Matriz autorizada por la comparacion B2/B3:
  - CORTEVA: GMM y Vida.
  - BH: GMM y Vida.
  - ZURICH SANTANDER: GMM y Vida.

ATT, SSGT y las hojas Opcionales de CORTEVA/BH quedan fuera. Este script
restaura sus direcciones si los scripts anteriores las dejaron en visible=0
y desactiva el filtro que ya pudo haberse inyectado en ff_SabanaOPC_v2.
*/

IF OBJECT_ID(N'dbo.bf_RepConf_Columna',N'U') IS NULL
    THROW 50300,'No existe dbo.bf_RepConf_Columna.',1;
IF OBJECT_ID(N'dbo.bf_RepConf_Tabla',N'U') IS NULL
    THROW 50301,'No existe dbo.bf_RepConf_Tabla.',1;
IF OBJECT_ID(N'dbo.ff_SabanaOPC_v2',N'P') IS NULL
    THROW 50302,'No existe dbo.ff_SabanaOPC_v2.',1;

DECLARE @Ocultar TABLE
(
    idEmpresa int NOT NULL,
    Empresa nvarchar(50) NOT NULL,
    grupoNormalizado nvarchar(20) NOT NULL,
    PRIMARY KEY(idEmpresa,grupoNormalizado)
);

INSERT @Ocultar(idEmpresa,Empresa,grupoNormalizado)
VALUES (856,N'CORTEVA',N'GMM'),
       (856,N'CORTEVA',N'VIDA'),
       (1038,N'BH',N'GMM'),
       (1038,N'BH',N'VIDA'),
       (1806,N'ZURICH SANTANDER',N'GMM'),
       (1806,N'ZURICH SANTANDER',N'VIDA'),
       (1807,N'ZURICH SANTANDER',N'GMM'),
       (1807,N'ZURICH SANTANDER',N'VIDA');

DECLARE @Restaurar TABLE
(
    idEmpresa int NOT NULL,
    Empresa nvarchar(50) NOT NULL,
    grupoNormalizado nvarchar(20) NOT NULL,
    grupoSugerido nvarchar(100) NOT NULL,
    PRIMARY KEY(idEmpresa,grupoNormalizado)
);

/* Combinaciones que los scripts anteriores incluyeron por error. */
INSERT @Restaurar(idEmpresa,Empresa,grupoNormalizado,grupoSugerido)
VALUES (166,N'ATT',N'OPCIONALES',N'Opcionales'),
       (116,N'SSGT',N'OPCIONALES',N'OPC'),
       (117,N'SSGT',N'OPCIONALES',N'OPC'),
       (856,N'CORTEVA',N'OPCIONALES',N'Opcionales'),
       (1038,N'BH',N'OPCIONALES',N'OPC');

DECLARE @Campos TABLE
(
    campoOrigen nvarchar(200) NOT NULL PRIMARY KEY,
    SoloVida bit NOT NULL
);

INSERT @Campos(campoOrigen,SoloVida)
VALUES (N'Calle',0),(N'NumExt',0),(N'NumInt',0),(N'Colonia',0),
       (N'Del_Municipio',0),(N'EstadoFiscal',0),(N'CP',0),
       (N'PrimaNeta',1),(N'PrimeNeta',1),(N'Costo',1);

DECLARE @RestaurarResuelto TABLE
(
    idEmpresa int NOT NULL,
    Empresa nvarchar(50) NOT NULL,
    grupoNormalizado nvarchar(20) NOT NULL,
    grupoDestino nvarchar(100) NOT NULL,
    PRIMARY KEY(idEmpresa,grupoNormalizado)
);

INSERT @RestaurarResuelto
    (idEmpresa,Empresa,grupoNormalizado,grupoDestino)
SELECT R.idEmpresa,R.Empresa,R.grupoNormalizado,
       COALESCE(T.grupo,C.grupo,R.grupoSugerido)
FROM @Restaurar AS R
OUTER APPLY
(
    SELECT TOP (1) X.grupo
    FROM dbo.bf_RepConf_Tabla AS X
    WHERE X.catReportesId=3
      AND X.idEmpresa=R.idEmpresa
      AND CASE WHEN UPPER(LTRIM(RTRIM(X.grupo))) IN
                    (N'OPC',N'OPCIONAL',N'OPCIONALES')
               THEN N'OPCIONALES'
               ELSE UPPER(LTRIM(RTRIM(X.grupo))) END=R.grupoNormalizado
    ORDER BY CASE WHEN ISNULL(X.activo,1)=1 THEN 0 ELSE 1 END,X.indexTable
) AS T
OUTER APPLY
(
    SELECT TOP (1) X.grupo
    FROM dbo.bf_RepConf_Columna AS X
    WHERE X.catReportesId=3
      AND X.idEmpresa=R.idEmpresa
      AND CASE WHEN UPPER(LTRIM(RTRIM(X.grupo))) IN
                    (N'OPC',N'OPCIONAL',N'OPCIONALES')
               THEN N'OPCIONALES'
               ELSE UPPER(LTRIM(RTRIM(X.grupo))) END=R.grupoNormalizado
    ORDER BY X.orden
) AS C;

BEGIN TRY
    BEGIN TRANSACTION;

    /* Ocultar unicamente la matriz autorizada. */
    UPDATE D
       SET D.visible=0
    FROM dbo.bf_RepConf_Columna AS D
    INNER JOIN @Ocultar AS O ON O.idEmpresa=D.idEmpresa
      AND CASE WHEN UPPER(LTRIM(RTRIM(D.grupo))) IN
                    (N'OPC',N'OPCIONAL',N'OPCIONALES')
               THEN N'OPCIONALES'
               ELSE UPPER(LTRIM(RTRIM(D.grupo))) END=O.grupoNormalizado
    INNER JOIN @Campos AS F
      ON UPPER(LTRIM(RTRIM(F.campoOrigen)))=
         UPPER(LTRIM(RTRIM(D.campoOrigen)))
     AND (F.SoloVida=0 OR O.grupoNormalizado=N'VIDA')
    WHERE D.catReportesId=3
      AND ISNULL(D.visible,1)<>0;

    /* Restaurar las filas existentes de ATT y de las demas combinaciones
       que no pertenecen a la matriz. */
    UPDATE D
       SET D.visible=1
    FROM dbo.bf_RepConf_Columna AS D
    INNER JOIN @RestaurarResuelto AS R
      ON R.idEmpresa=D.idEmpresa
     AND UPPER(LTRIM(RTRIM(R.grupoDestino)))=
         UPPER(LTRIM(RTRIM(D.grupo)))
    INNER JOIN @Campos AS F
      ON F.SoloVida=0
     AND UPPER(LTRIM(RTRIM(F.campoOrigen)))=
         UPPER(LTRIM(RTRIM(D.campoOrigen)))
    WHERE D.catReportesId=3
      AND ISNULL(D.visible,1)<>1;

    /* Si una direccion no existia en la configuracion especifica, crearla
       visible tomando formato de la configuracion global cuando exista. */
    ;WITH Requeridas AS
    (
        SELECT R.idEmpresa,R.Empresa,R.grupoNormalizado,R.grupoDestino,
               F.campoOrigen
        FROM @RestaurarResuelto AS R
        CROSS JOIN @Campos AS F
        WHERE F.SoloVida=0
    ),
    Faltantes AS
    (
        SELECT Q.idEmpresa,Q.Empresa,Q.grupoNormalizado,Q.grupoDestino,
               Q.campoOrigen,M.MaxOrden,
               P.encabezado,P.ancho,P.formato,P.alinear,P.tipoDato,
               ROW_NUMBER() OVER
               (PARTITION BY Q.idEmpresa,Q.grupoDestino
                ORDER BY Q.campoOrigen) AS Posicion
        FROM Requeridas AS Q
        OUTER APPLY
        (
            SELECT ISNULL(MAX(X.orden),0) AS MaxOrden
            FROM dbo.bf_RepConf_Columna AS X
            WHERE X.idEmpresa=Q.idEmpresa
              AND X.catReportesId=3
              AND UPPER(LTRIM(RTRIM(X.grupo)))=
                  UPPER(LTRIM(RTRIM(Q.grupoDestino)))
        ) AS M
        OUTER APPLY
        (
            SELECT TOP (1) X.encabezado,X.ancho,X.formato,X.alinear,X.tipoDato
            FROM dbo.bf_RepConf_Columna AS X
            WHERE X.catReportesId=3
              AND UPPER(LTRIM(RTRIM(X.campoOrigen)))=
                  UPPER(LTRIM(RTRIM(Q.campoOrigen)))
              AND CASE WHEN UPPER(LTRIM(RTRIM(X.grupo))) IN
                            (N'OPC',N'OPCIONAL',N'OPCIONALES')
                       THEN N'OPCIONALES'
                       ELSE UPPER(LTRIM(RTRIM(X.grupo))) END=Q.grupoNormalizado
            ORDER BY CASE WHEN X.idEmpresa=0 THEN 0 ELSE 1 END,X.orden
        ) AS P
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.bf_RepConf_Columna AS X
            WHERE X.idEmpresa=Q.idEmpresa
              AND X.catReportesId=3
              AND UPPER(LTRIM(RTRIM(X.grupo)))=
                  UPPER(LTRIM(RTRIM(Q.grupoDestino)))
              AND UPPER(LTRIM(RTRIM(X.campoOrigen)))=
                  UPPER(LTRIM(RTRIM(Q.campoOrigen)))
        )
    )
    INSERT dbo.bf_RepConf_Columna
    (
        idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,
        visible,ancho,formato,alinear,tipoDato,repConfColumnaUsuarioAdd
    )
    SELECT idEmpresa,3,grupoDestino,MaxOrden+Posicion,campoOrigen,
           ISNULL(encabezado,campoOrigen),1,ancho,formato,alinear,tipoDato,0
    FROM Faltantes;

    /* Un parche anterior filtraba direcciones para ATT/SSGT y para
       Opcionales de CORTEVA/BH antes de llegar al configurador de Excel. */
    DECLARE @Definicion nvarchar(max)=OBJECT_DEFINITION
            (OBJECT_ID(N'dbo.ff_SabanaOPC_v2')),
            @NuevaDefinicion nvarchar(max);

    IF @Definicion IS NULL
        THROW 50303,'No se pudo leer dbo.ff_SabanaOPC_v2.',1;

    SET @NuevaDefinicion=REPLACE
    (
        @Definicion,
        N'IF @idEmpresa IN (116,117,166,856,1038)',
        N'IF @idEmpresa IN (-2147483648)'
    );

    IF @NuevaDefinicion<>@Definicion
        EXEC sys.sp_executesql @NuevaDefinicion;

    SET @Definicion=OBJECT_DEFINITION(OBJECT_ID(N'dbo.ff_SabanaOPC_v2'));

    IF CHARINDEX(N'BF3_SOLO_SQL_OCULTA_COLUMNAS_B2',@Definicion)>0
       AND CHARINDEX(N'IF @idEmpresa IN (-2147483648)',@Definicion)=0
        THROW 50304,'El parche OPC instalado tiene una condicion no reconocida.',1;

    IF EXISTS
    (
        SELECT 1
        FROM @RestaurarResuelto AS R
        CROSS JOIN @Campos AS F
        WHERE R.idEmpresa=166
          AND F.SoloVida=0
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.bf_RepConf_Columna AS D
              WHERE D.idEmpresa=R.idEmpresa
                AND D.catReportesId=3
                AND UPPER(LTRIM(RTRIM(D.grupo)))=
                    UPPER(LTRIM(RTRIM(R.grupoDestino)))
                AND UPPER(LTRIM(RTRIM(D.campoOrigen)))=
                    UPPER(LTRIM(RTRIM(F.campoOrigen)))
                AND ISNULL(D.visible,1)=1
          )
    )
        THROW 50305,'ATT no quedo con todas las direcciones visibles.',1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT R.Empresa,R.idEmpresa,R.grupoDestino,C.campoOrigen,C.visible
FROM @RestaurarResuelto AS R
INNER JOIN dbo.bf_RepConf_Columna AS C
  ON C.idEmpresa=R.idEmpresa
 AND C.catReportesId=3
 AND UPPER(LTRIM(RTRIM(C.grupo)))=
     UPPER(LTRIM(RTRIM(R.grupoDestino)))
INNER JOIN @Campos AS F
  ON F.SoloVida=0
 AND UPPER(LTRIM(RTRIM(F.campoOrigen)))=
     UPPER(LTRIM(RTRIM(C.campoOrigen)))
ORDER BY R.Empresa,R.grupoDestino,C.orden;

SELECT O.Empresa,O.idEmpresa,O.grupoNormalizado,C.campoOrigen,C.visible
FROM @Ocultar AS O
INNER JOIN dbo.bf_RepConf_Columna AS C
  ON C.idEmpresa=O.idEmpresa
 AND C.catReportesId=3
 AND CASE WHEN UPPER(LTRIM(RTRIM(C.grupo))) IN
               (N'OPC',N'OPCIONAL',N'OPCIONALES')
          THEN N'OPCIONALES'
          ELSE UPPER(LTRIM(RTRIM(C.grupo))) END=O.grupoNormalizado
INNER JOIN @Campos AS F
  ON UPPER(LTRIM(RTRIM(F.campoOrigen)))=
     UPPER(LTRIM(RTRIM(C.campoOrigen)))
 AND (F.SoloVida=0 OR O.grupoNormalizado=N'VIDA')
ORDER BY O.Empresa,O.grupoNormalizado,C.orden;
GO
