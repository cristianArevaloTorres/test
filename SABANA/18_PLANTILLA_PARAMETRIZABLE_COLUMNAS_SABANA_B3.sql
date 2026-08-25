Mens. 156, Nivel 15, Estado 1, Línea 72
Incorrect syntax near the keyword 'IF'.

Hora de finalización: 2026-08-25T13:15:42.4134776-06:00


    

USE [FlexiForbesv2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

/*
    PLANTILLA PARAMETRIZABLE PARA MOSTRAR U OCULTAR COLUMNAS DE SABANA B3

    1. Agregar empresas/grupos en @Empresas.
    2. Agregar los campoOrigen exactos en @Campos.
    3. Dejar @AplicarCambios=0 para revisar la vista previa.
    4. Cambiar @AplicarCambios=1 para aplicar.

    
*/

DECLARE @AplicarCambios bit=0;  -- 0=solo revisar; 1=aplicar UPDATE/INSERT
DECLARE @VisibleDestino bit=1;  -- 0=ocultar; 1=mostrar

IF OBJECT_ID(N'dbo.bf_RepConf_Columna',N'U') IS NULL
    THROW 50700,'No existe dbo.bf_RepConf_Columna.',1;
IF OBJECT_ID(N'dbo.bf_RepConf_Tabla',N'U') IS NULL
    THROW 50701,'No existe dbo.bf_RepConf_Tabla.',1;

DECLARE @Empresas TABLE
(
    idEmpresa int NOT NULL,
    Empresa nvarchar(100) NOT NULL,
    grupoSugerido nvarchar(100) NOT NULL,
    idEmpresaFuente int NOT NULL,
    visibleDestino bit NOT NULL,
    PRIMARY KEY(idEmpresa,grupoSugerido)
);

/*
   EJEMPLO SSGT:
     - 116 es la empresa/corporativo.
     - 117 hereda de 116.
     - El grupo real encontrado en la configuracion es OPC.
     - Ambas filas usan el parametro @VisibleDestino declarado arriba.

   Para otra empresa, agregar otra fila con su ID, grupo e ID fuente.
   Usar idEmpresaFuente=0 cuando deba copiar la configuracion global.
*/
INSERT @Empresas
    (idEmpresa,Empresa,grupoSugerido,idEmpresaFuente,visibleDestino)
VALUES
    (116,N'SSGT',N'OPC',0,@VisibleDestino),
    (117,N'SSGT',N'OPC',116,@VisibleDestino);

DECLARE @Campos TABLE
(
    campoOrigen nvarchar(256) NOT NULL PRIMARY KEY
);

/*
   CAMPOS PARAMETRIZABLES:
   Dejar solamente los que se quieran mostrar/ocultar.
   El texto debe coincidir con bf_RepConf_Columna.campoOrigen.
*/
INSERT @Campos(campoOrigen)
VALUES
      -- (N'Calle'),
       (N'NumExt'),
       (N'NumInt'),
    --   (N'Colonia'),
    --   (N'Del_Municipio'),
    --   (N'EstadoFiscal'),
    --   (N'CP');

/* Confirmar que los IDs existan antes de continuar. */
IF OBJECT_ID(N'dbo.ff_Empresa',N'U') IS NOT NULL
   AND EXISTS
   (
       SELECT 1
       FROM @Empresas AS P
       WHERE NOT EXISTS
       (
           SELECT 1
           FROM dbo.ff_Empresa AS E
           WHERE E.EMidEmpresa=P.idEmpresa
       )
   )
    THROW 50702,'Uno de los IDs indicados no existe en dbo.ff_Empresa.',1;

DECLARE @Resuelto TABLE
(
    idEmpresa int NOT NULL,
    Empresa nvarchar(100) NOT NULL,
    grupoNormalizado nvarchar(100) NOT NULL,
    grupoDestino nvarchar(100) NOT NULL,
    idEmpresaFuente int NOT NULL,
    visibleDestino bit NOT NULL,
    PRIMARY KEY(idEmpresa,grupoNormalizado)
);

/*
   Normalizar OPC/OPCIONAL/OPCIONALES y conservar el nombre real del grupo
   que ya existe para cada empresa.
*/
INSERT @Resuelto
    (idEmpresa,Empresa,grupoNormalizado,grupoDestino,idEmpresaFuente,
     visibleDestino)
SELECT P.idEmpresa,P.Empresa,N.grupoNormalizado,
       COALESCE(T.grupo,C.grupo,P.grupoSugerido),
       P.idEmpresaFuente,P.visibleDestino
FROM @Empresas AS P
CROSS APPLY
(
    SELECT CASE WHEN UPPER(LTRIM(RTRIM(P.grupoSugerido))) IN
                          (N'OPC',N'OPCIONAL',N'OPCIONALES')
                     THEN N'OPCIONALES'
                     ELSE UPPER(LTRIM(RTRIM(P.grupoSugerido))) END
           AS grupoNormalizado
) AS N
OUTER APPLY
(
    SELECT TOP (1) X.grupo
    FROM dbo.bf_RepConf_Tabla AS X
    WHERE X.idEmpresa=P.idEmpresa AND X.catReportesId=3
      AND CASE WHEN UPPER(LTRIM(RTRIM(X.grupo))) IN
                         (N'OPC',N'OPCIONAL',N'OPCIONALES')
                    THEN N'OPCIONALES'
                    ELSE UPPER(LTRIM(RTRIM(X.grupo))) END=N.grupoNormalizado
    ORDER BY CASE WHEN ISNULL(X.activo,1)=1 THEN 0 ELSE 1 END,X.indexTable
) AS T
OUTER APPLY
(
    SELECT TOP (1) X.grupo
    FROM dbo.bf_RepConf_Columna AS X
    WHERE X.idEmpresa=P.idEmpresa AND X.catReportesId=3
      AND CASE WHEN UPPER(LTRIM(RTRIM(X.grupo))) IN
                         (N'OPC',N'OPCIONAL',N'OPCIONALES')
                    THEN N'OPCIONALES'
                    ELSE UPPER(LTRIM(RTRIM(X.grupo))) END=N.grupoNormalizado
    ORDER BY X.orden
) AS C;

/* Vista previa: estado actual y operacion que se realizaria. */
SELECT R.Empresa,R.idEmpresa,R.grupoDestino,F.campoOrigen,
       C.visible AS visibleActual,R.visibleDestino,
       CASE WHEN C.campoOrigen IS NULL THEN N'INSERTAR'
            WHEN C.visible<>R.visibleDestino THEN N'ACTUALIZAR'
            ELSE N'SIN CAMBIO' END AS Accion
FROM @Resuelto AS R
CROSS JOIN @Campos AS F
OUTER APPLY
(
    SELECT TOP (1) X.campoOrigen,X.visible
    FROM dbo.bf_RepConf_Columna AS X
    WHERE X.idEmpresa=R.idEmpresa AND X.catReportesId=3
      AND CASE WHEN UPPER(LTRIM(RTRIM(X.grupo))) IN
                         (N'OPC',N'OPCIONAL',N'OPCIONALES')
                    THEN N'OPCIONALES'
                    ELSE UPPER(LTRIM(RTRIM(X.grupo))) END=R.grupoNormalizado
      AND UPPER(LTRIM(RTRIM(X.campoOrigen)))=
          UPPER(LTRIM(RTRIM(F.campoOrigen)))
    ORDER BY X.orden
) AS C
ORDER BY R.Empresa,R.idEmpresa,R.grupoDestino,F.campoOrigen;

IF @AplicarCambios=0
BEGIN
    SELECT N'VISTA PREVIA: no se modifico ningun dato. Cambiar '
           +N'@AplicarCambios a 1 para aplicar.' AS Resultado;
    RETURN;
END;

/*
   Validar que exista una fuente completa cuando la empresa aun no tenga
   configuracion especifica. Así no se crea una lista parcial de columnas.
*/
IF EXISTS
(
    SELECT 1
    FROM @Resuelto AS R
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.bf_RepConf_Columna AS C
        WHERE C.idEmpresa=R.idEmpresa AND C.catReportesId=3
          AND CASE WHEN UPPER(LTRIM(RTRIM(C.grupo))) IN
                             (N'OPC',N'OPCIONAL',N'OPCIONALES')
                        THEN N'OPCIONALES'
                        ELSE UPPER(LTRIM(RTRIM(C.grupo))) END=
              R.grupoNormalizado
    )
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.bf_RepConf_Columna AS C
          WHERE C.idEmpresa IN (R.idEmpresaFuente,0)
            AND C.catReportesId=3
            AND CASE WHEN UPPER(LTRIM(RTRIM(C.grupo))) IN
                               (N'OPC',N'OPCIONAL',N'OPCIONALES')
                          THEN N'OPCIONALES'
                          ELSE UPPER(LTRIM(RTRIM(C.grupo))) END=
                R.grupoNormalizado
      )
)
    THROW 50703,'No existe configuracion fuente para una empresa/grupo.',1;

BEGIN TRY
    BEGIN TRANSACTION;

    /* Copiar lista completa solo si la empresa no tiene ninguna columna. */
    ;WITH SinConfiguracion AS
    (
        SELECT R.*
        FROM @Resuelto AS R
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.bf_RepConf_Columna AS C
            WHERE C.idEmpresa=R.idEmpresa AND C.catReportesId=3
              AND CASE WHEN UPPER(LTRIM(RTRIM(C.grupo))) IN
                                 (N'OPC',N'OPCIONAL',N'OPCIONALES')
                        THEN N'OPCIONALES'
                        ELSE UPPER(LTRIM(RTRIM(C.grupo))) END=
                  R.grupoNormalizado
        )
    ),
    Fuente AS
    (
        SELECT R.*,F.idFuente,F.grupoFuente
        FROM SinConfiguracion AS R
        CROSS APPLY
        (
            SELECT TOP (1) C.idEmpresa AS idFuente,C.grupo AS grupoFuente
            FROM dbo.bf_RepConf_Columna AS C
            WHERE C.idEmpresa IN (R.idEmpresaFuente,0)
              AND C.catReportesId=3
              AND CASE WHEN UPPER(LTRIM(RTRIM(C.grupo))) IN
                                 (N'OPC',N'OPCIONAL',N'OPCIONALES')
                        THEN N'OPCIONALES'
                        ELSE UPPER(LTRIM(RTRIM(C.grupo))) END=
                  R.grupoNormalizado
            ORDER BY CASE WHEN C.idEmpresa=R.idEmpresaFuente THEN 0 ELSE 1 END,
                     C.orden
        ) AS F
    ),
    Copia AS
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
        FROM Fuente AS R
        INNER JOIN dbo.bf_RepConf_Columna AS C
          ON C.idEmpresa=R.idFuente AND C.catReportesId=3
         AND C.grupo=R.grupoFuente
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
    FROM Copia
    WHERE Duplicado=1;

    /* Insertar solamente campos solicitados que sigan faltando. */
    ;WITH Faltantes AS
    (
        SELECT R.idEmpresa,R.grupoDestino,F.campoOrigen,
               M.MaxOrden,P.encabezado,P.ancho,P.formato,P.alinear,P.tipoDato,
               ROW_NUMBER() OVER
               (PARTITION BY R.idEmpresa,R.grupoDestino
                ORDER BY F.campoOrigen) AS Posicion,
               R.visibleDestino
        FROM @Resuelto AS R
        CROSS JOIN @Campos AS F
        CROSS APPLY
        (
            SELECT ISNULL(MAX(C.orden),0) AS MaxOrden
            FROM dbo.bf_RepConf_Columna AS C
            WHERE C.idEmpresa=R.idEmpresa AND C.catReportesId=3
              AND CASE WHEN UPPER(LTRIM(RTRIM(C.grupo))) IN
                                 (N'OPC',N'OPCIONAL',N'OPCIONALES')
                        THEN N'OPCIONALES'
                        ELSE UPPER(LTRIM(RTRIM(C.grupo))) END=
                  R.grupoNormalizado
        ) AS M
        OUTER APPLY
        (
            SELECT TOP (1)
                   C.encabezado,C.ancho,C.formato,C.alinear,C.tipoDato
            FROM dbo.bf_RepConf_Columna AS C
            WHERE C.idEmpresa IN (R.idEmpresa,R.idEmpresaFuente,0)
              AND C.catReportesId=3
              AND CASE WHEN UPPER(LTRIM(RTRIM(C.grupo))) IN
                                 (N'OPC',N'OPCIONAL',N'OPCIONALES')
                        THEN N'OPCIONALES'
                        ELSE UPPER(LTRIM(RTRIM(C.grupo))) END=
                  R.grupoNormalizado
              AND UPPER(LTRIM(RTRIM(C.campoOrigen)))=
                  UPPER(LTRIM(RTRIM(F.campoOrigen)))
            ORDER BY CASE WHEN C.idEmpresa=R.idEmpresa THEN 0
                          WHEN C.idEmpresa=R.idEmpresaFuente THEN 1
                          ELSE 2 END,C.orden
        ) AS P
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.bf_RepConf_Columna AS C
            WHERE C.idEmpresa=R.idEmpresa AND C.catReportesId=3
              AND CASE WHEN UPPER(LTRIM(RTRIM(C.grupo))) IN
                                 (N'OPC',N'OPCIONAL',N'OPCIONALES')
                        THEN N'OPCIONALES'
                        ELSE UPPER(LTRIM(RTRIM(C.grupo))) END=
                  R.grupoNormalizado
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
           ISNULL(encabezado,campoOrigen),visibleDestino,
           ancho,formato,alinear,tipoDato,
           0,GETDATE(),NULL,NULL,NULL,NULL
    FROM Faltantes;

    /* Aplicar visibleDestino a los campos seleccionados. */
    UPDATE C
       SET C.visible=R.visibleDestino,
           C.repConfColumnaUsuarioMod=0,
           C.repConfColumnaFechaMod=GETDATE()
    FROM dbo.bf_RepConf_Columna AS C
    INNER JOIN @Resuelto AS R
      ON R.idEmpresa=C.idEmpresa
     AND CASE WHEN UPPER(LTRIM(RTRIM(C.grupo))) IN
                        (N'OPC',N'OPCIONAL',N'OPCIONALES')
               THEN N'OPCIONALES'
               ELSE UPPER(LTRIM(RTRIM(C.grupo))) END=R.grupoNormalizado
    INNER JOIN @Campos AS F
      ON UPPER(LTRIM(RTRIM(C.campoOrigen)))=
         UPPER(LTRIM(RTRIM(F.campoOrigen)))
    WHERE C.catReportesId=3
      AND ISNULL(C.visible,1)<>R.visibleDestino;

    /* Verificar antes de confirmar. */
    IF EXISTS
    (
        SELECT 1
        FROM @Resuelto AS R
        CROSS JOIN @Campos AS F
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM dbo.bf_RepConf_Columna AS C
            WHERE C.idEmpresa=R.idEmpresa AND C.catReportesId=3
              AND CASE WHEN UPPER(LTRIM(RTRIM(C.grupo))) IN
                                 (N'OPC',N'OPCIONAL',N'OPCIONALES')
                        THEN N'OPCIONALES'
                        ELSE UPPER(LTRIM(RTRIM(C.grupo))) END=
                  R.grupoNormalizado
              AND UPPER(LTRIM(RTRIM(C.campoOrigen)))=
                  UPPER(LTRIM(RTRIM(F.campoOrigen)))
              AND C.visible=R.visibleDestino
        )
    )
        THROW 50704,'La configuracion no quedo completa; se revertira.',1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT R.Empresa,R.idEmpresa,R.grupoDestino,F.campoOrigen,
       C.visible,N'APLICADO' AS Resultado
FROM @Resuelto AS R
CROSS JOIN @Campos AS F
INNER JOIN dbo.bf_RepConf_Columna AS C
  ON C.idEmpresa=R.idEmpresa AND C.catReportesId=3
 AND CASE WHEN UPPER(LTRIM(RTRIM(C.grupo))) IN
                    (N'OPC',N'OPCIONAL',N'OPCIONALES')
           THEN N'OPCIONALES'
           ELSE UPPER(LTRIM(RTRIM(C.grupo))) END=R.grupoNormalizado
 AND UPPER(LTRIM(RTRIM(C.campoOrigen)))=
     UPPER(LTRIM(RTRIM(F.campoOrigen)))
ORDER BY R.Empresa,R.idEmpresa,R.grupoDestino,F.campoOrigen;
GO
