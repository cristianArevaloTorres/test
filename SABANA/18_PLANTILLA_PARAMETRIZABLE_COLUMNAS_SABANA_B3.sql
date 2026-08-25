USE [FlexiForbesv2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

/* PARAMETRO PRINCIPAL: 0=ocultar los campos; 1=mostrarlos. */
DECLARE @VisibleDestino bit=0;

/*
  AJUSTE INCREMENTAL FINAL - SABANA B3

  Este script NO reemplaza tablas completas, NO usa BULK INSERT y NO elimina
  configuraciones. Solo realiza UPDATE y los INSERT indispensables cuando una
  empresa no tiene configuracion especifica o le falta uno de los campos.

  Matriz solicitada:
    - CORTEVA GMM: ocultar Calle, NumExt, NumInt, Colonia,
      Del_Municipio, EstadoFiscal y CP.
    - CORTEVA VIDA: lo anterior mas PrimaNeta/PrimeNeta y Costo.
    - BH GMM/VIDA: misma regla.
    - ZURICH SANTANDER GMM/VIDA: misma regla.

  IDs efectivos confirmados con datos y logs:
    CORTEVA: 332 y 856
    BH: 1038 y 1039
    ZURICH SANTANDER: 1806 y 1807

  ATT, SSGT y Opcionales quedan con las direcciones visibles.
*/

IF OBJECT_ID(N'dbo.bf_RepConf_Columna',N'U') IS NULL
    THROW 50600,'No existe dbo.bf_RepConf_Columna.',1;
IF OBJECT_ID(N'dbo.bf_RepConf_Tabla',N'U') IS NULL
    THROW 50601,'No existe dbo.bf_RepConf_Tabla.',1;

DECLARE @Target TABLE
(
    idEmpresa int NOT NULL,
    Empresa nvarchar(60) NOT NULL,
    grupoNormalizado nvarchar(20) NOT NULL,
    idEmpresaFuente int NOT NULL,
    QuitarPrimaCosto bit NOT NULL,
    PRIMARY KEY(idEmpresa,grupoNormalizado)
);

INSERT @Target
    (idEmpresa,Empresa,grupoNormalizado,idEmpresaFuente,QuitarPrimaCosto)
VALUES
    (332,N'CORTEVA/PHI',N'GMM',856,0),
    (332,N'CORTEVA/PHI',N'VIDA',856,1),
    (856,N'CORTEVA',N'GMM',0,0),
    (856,N'CORTEVA',N'VIDA',0,1),
    (1038,N'BH',N'GMM',0,0),
    (1038,N'BH',N'VIDA',0,1),
    (1039,N'BH PRODUCTS',N'GMM',1038,0),
    (1039,N'BH PRODUCTS',N'VIDA',1038,1),
    (1806,N'ZURICH SANTANDER',N'GMM',0,0),
    (1806,N'ZURICH SANTANDER',N'VIDA',0,1),
    (1807,N'ZURICH SANTANDER',N'GMM',0,0),
    (1807,N'ZURICH SANTANDER',N'VIDA',0,1);

DECLARE @Campos TABLE
(
    campoOrigen nvarchar(200) NOT NULL PRIMARY KEY,
    SoloVida bit NOT NULL
);

INSERT @Campos(campoOrigen,SoloVida)
VALUES (N'Calle',0),(N'NumExt',0),(N'NumInt',0),(N'Colonia',0),
       (N'Del_Municipio',0),(N'EstadoFiscal',0),(N'CP',0),
       /* Se contemplan ambas grafias encontradas en los procedimientos. */
       (N'PrimaNeta',1),(N'PrimeNeta',1),(N'Costo',1);

/* Validar que los IDs realmente existan antes de modificar configuracion. */
IF OBJECT_ID(N'dbo.ff_Empresa',N'U') IS NOT NULL
   AND EXISTS
   (
       SELECT 1
       FROM (SELECT DISTINCT idEmpresa FROM @Target) AS T
       WHERE NOT EXISTS
       (
           SELECT 1
           FROM dbo.ff_Empresa AS E
           WHERE E.EMidEmpresa=T.idEmpresa
       )
   )
    THROW 50602,'Falta uno de los IDs de empresa esperados; no se aplico el ajuste.',1;

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

/* Respetar exactamente la escritura del grupo que ya usa cada empresa. */
INSERT @TargetResuelto
    (idEmpresa,Empresa,grupoNormalizado,grupoDestino,idEmpresaFuente,
     QuitarPrimaCosto)
SELECT T.idEmpresa,T.Empresa,T.grupoNormalizado,
       COALESCE(RT.grupo,RC.grupo,
                CASE WHEN T.grupoNormalizado=N'VIDA' THEN N'Vida'
                     ELSE N'GMM' END),
       T.idEmpresaFuente,T.QuitarPrimaCosto
FROM @Target AS T
OUTER APPLY
(
    SELECT TOP (1) X.grupo
    FROM dbo.bf_RepConf_Tabla AS X
    WHERE X.catReportesId=3 AND X.idEmpresa=T.idEmpresa
      AND UPPER(LTRIM(RTRIM(X.grupo)))=T.grupoNormalizado
    ORDER BY CASE WHEN ISNULL(X.activo,1)=1 THEN 0 ELSE 1 END,X.indexTable
) AS RT
OUTER APPLY
(
    SELECT TOP (1) X.grupo
    FROM dbo.bf_RepConf_Columna AS X
    WHERE X.catReportesId=3 AND X.idEmpresa=T.idEmpresa
      AND UPPER(LTRIM(RTRIM(X.grupo)))=T.grupoNormalizado
    ORDER BY X.orden
) AS RC;

/*
  Si no hay ninguna columna especifica para un ID/grupo, insertar una copia
  completa desde su empresa fuente o desde la configuracion global. Esto evita
  crear una configuracion parcial que pudiera dejar la hoja casi vacia.
*/
IF EXISTS
(
    SELECT 1
    FROM @TargetResuelto AS R
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.bf_RepConf_Columna AS C
        WHERE C.idEmpresa=R.idEmpresa AND C.catReportesId=3
          AND UPPER(LTRIM(RTRIM(C.grupo)))=R.grupoNormalizado
    )
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.bf_RepConf_Columna AS C
          WHERE C.idEmpresa IN (R.idEmpresaFuente,0)
            AND C.catReportesId=3
            AND UPPER(LTRIM(RTRIM(C.grupo)))=R.grupoNormalizado
      )
)
    THROW 50603,'No existe configuracion fuente para uno de los grupos.',1;

BEGIN TRY
    BEGIN TRANSACTION;

    ;WITH SinConfiguracion AS
    (
        SELECT R.*
        FROM @TargetResuelto AS R
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.bf_RepConf_Columna AS C
            WHERE C.idEmpresa=R.idEmpresa AND C.catReportesId=3
              AND UPPER(LTRIM(RTRIM(C.grupo)))=R.grupoNormalizado
        )
    ),
    FuenteElegida AS
    (
        SELECT R.*,
               F.idFuente,F.grupoFuente
        FROM SinConfiguracion AS R
        CROSS APPLY
        (
            SELECT TOP (1) C.idEmpresa AS idFuente,C.grupo AS grupoFuente
            FROM dbo.bf_RepConf_Columna AS C
            WHERE C.catReportesId=3
              AND C.idEmpresa IN (R.idEmpresaFuente,0)
              AND UPPER(LTRIM(RTRIM(C.grupo)))=R.grupoNormalizado
            ORDER BY CASE WHEN C.idEmpresa=R.idEmpresaFuente THEN 0 ELSE 1 END,
                     C.orden
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
           ROW_NUMBER() OVER
           (PARTITION BY idEmpresaDestino,grupoDestino
            ORDER BY orden,campoOrigen),
           campoOrigen,encabezado,visible,ancho,formato,alinear,tipoDato,
           0,GETDATE(),NULL,NULL,NULL,NULL
    FROM FuenteDeduplicada
    WHERE Duplicado=1;

    /* Insertar con @VisibleDestino los campos solicitados que aun no existan. */
    ;WITH Faltantes AS
    (
        SELECT R.idEmpresa,R.grupoNormalizado,R.grupoDestino,
               F.campoOrigen,M.MaxOrden,
               P.encabezado,P.ancho,P.formato,P.alinear,P.tipoDato,
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
            SELECT TOP (1)
                   C.encabezado,C.ancho,C.formato,C.alinear,C.tipoDato
            FROM dbo.bf_RepConf_Columna AS C
            WHERE C.catReportesId=3
              AND C.idEmpresa IN (R.idEmpresa,R.idEmpresaFuente,0)
              AND UPPER(LTRIM(RTRIM(C.grupo)))=R.grupoNormalizado
              AND UPPER(LTRIM(RTRIM(C.campoOrigen)))=
                  UPPER(LTRIM(RTRIM(F.campoOrigen)))
            ORDER BY CASE WHEN C.idEmpresa=R.idEmpresa THEN 0
                          WHEN C.idEmpresa=R.idEmpresaFuente THEN 1
                          ELSE 2 END,C.orden
        ) AS P
        WHERE (F.SoloVida=0 OR R.QuitarPrimaCosto=1)
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.bf_RepConf_Columna AS C
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
           ISNULL(encabezado,campoOrigen),@VisibleDestino,
           ancho,formato,alinear,tipoDato,
           0,GETDATE(),NULL,NULL,NULL,NULL
    FROM Faltantes;

    /* Aplicar la matriz exacta. */
    UPDATE C
       SET C.visible=@VisibleDestino,
           C.repConfColumnaUsuarioMod=0,
           C.repConfColumnaFechaMod=GETDATE()
    FROM dbo.bf_RepConf_Columna AS C
    INNER JOIN @TargetResuelto AS R
      ON R.idEmpresa=C.idEmpresa
     AND UPPER(LTRIM(RTRIM(C.grupo)))=R.grupoNormalizado
    INNER JOIN @Campos AS F
      ON UPPER(LTRIM(RTRIM(C.campoOrigen)))=
         UPPER(LTRIM(RTRIM(F.campoOrigen)))
     AND (F.SoloVida=0 OR R.QuitarPrimaCosto=1)
    WHERE C.catReportesId=3
      AND ISNULL(C.visible,1)<>@VisibleDestino;

    /*
      Corregir solamente posibles residuos de scripts anteriores:
      ATT, SSGT y Opcionales no pertenecen a la matriz de ocultamiento.
      No se crean configuraciones nuevas para estas combinaciones.
    */
    UPDATE C
       SET C.visible=1,
           C.repConfColumnaUsuarioMod=0,
           C.repConfColumnaFechaMod=GETDATE()
    FROM dbo.bf_RepConf_Columna AS C
    INNER JOIN
    (
        SELECT 116 AS idEmpresa,N'OPC' AS grupoNormalizado UNION ALL
        SELECT 117,N'OPC' UNION ALL
        SELECT 166,N'GMM' UNION ALL
        SELECT 166,N'VIDA' UNION ALL
        SELECT 166,N'OPCIONALES' UNION ALL
        SELECT 332,N'OPCIONALES' UNION ALL
        SELECT 856,N'OPCIONALES' UNION ALL
        SELECT 1038,N'OPCIONALES' UNION ALL
        SELECT 1039,N'OPCIONALES'
    ) AS V
      ON V.idEmpresa=C.idEmpresa
     AND CASE WHEN UPPER(LTRIM(RTRIM(C.grupo))) IN
                   (N'OPC',N'OPCIONAL',N'OPCIONALES')
              THEN N'OPCIONALES'
              ELSE UPPER(LTRIM(RTRIM(C.grupo))) END=
         CASE WHEN V.grupoNormalizado=N'OPC' THEN N'OPCIONALES'
              ELSE V.grupoNormalizado END
    INNER JOIN @Campos AS F
      ON F.SoloVida=0
     AND UPPER(LTRIM(RTRIM(C.campoOrigen)))=
         UPPER(LTRIM(RTRIM(F.campoOrigen)))
    WHERE C.catReportesId=3
      AND ISNULL(C.visible,1)<>1;

    /* Si algo no queda con la visibilidad solicitada, revertir todo el lote. */
    IF EXISTS
    (
        SELECT 1
        FROM @TargetResuelto AS R
        CROSS JOIN @Campos AS F
        WHERE (F.SoloVida=0 OR R.QuitarPrimaCosto=1)
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.bf_RepConf_Columna AS C
              WHERE C.idEmpresa=R.idEmpresa AND C.catReportesId=3
                AND UPPER(LTRIM(RTRIM(C.grupo)))=R.grupoNormalizado
                AND UPPER(LTRIM(RTRIM(C.campoOrigen)))=
                    UPPER(LTRIM(RTRIM(F.campoOrigen)))
                AND C.visible=@VisibleDestino
          )
    )
        THROW 50604,'La matriz no quedo completa; se revertira el lote.',1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

/* Resultado final: visible debe coincidir con @VisibleDestino. */
SELECT R.Empresa,R.idEmpresa,R.grupoNormalizado,
       C.campoOrigen,C.visible,@VisibleDestino AS visibleSolicitado
FROM @TargetResuelto AS R
INNER JOIN dbo.bf_RepConf_Columna AS C
  ON C.idEmpresa=R.idEmpresa AND C.catReportesId=3
 AND UPPER(LTRIM(RTRIM(C.grupo)))=R.grupoNormalizado
INNER JOIN @Campos AS F
  ON UPPER(LTRIM(RTRIM(C.campoOrigen)))=
     UPPER(LTRIM(RTRIM(F.campoOrigen)))
 AND (F.SoloVida=0 OR R.QuitarPrimaCosto=1)
ORDER BY R.Empresa,R.idEmpresa,R.grupoNormalizado,C.orden;
GO
