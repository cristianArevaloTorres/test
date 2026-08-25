USE [FlexiForbesv2];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.bf_RepConf_Columna',N'U') IS NULL
    THROW 50120,'No existe dbo.bf_RepConf_Columna.',1;

DECLARE @Hojas TABLE
(
    idEmpresa int NOT NULL,
    Empresa nvarchar(50) NOT NULL,
    grupo nvarchar(100) NOT NULL,
    PRIMARY KEY(idEmpresa,grupo)
);

INSERT @Hojas(idEmpresa,Empresa,grupo)
VALUES (856, N'CORTEVA',N'GMM'),
       (856, N'CORTEVA',N'Vida'),
       (856, N'CORTEVA',N'Opcionales'),
       (166, N'ATT',N'Opcionales'),
       (116, N'SSGT',N'OPC'),
       (117, N'SSGT',N'OPC'),
       (1038,N'BH',N'GMM'),
       (1038,N'BH',N'Vida'),
       (1038,N'BH',N'OPC');

DECLARE @Actualizadas TABLE
(
    idEmpresa int NOT NULL,
    Empresa nvarchar(50) NOT NULL,
    grupo nvarchar(100) NOT NULL,
    campoOrigen nvarchar(200) NOT NULL
);

BEGIN TRY
    BEGIN TRANSACTION;

    UPDATE C
       SET C.visible=0
    OUTPUT inserted.idEmpresa,H.Empresa,inserted.grupo,inserted.campoOrigen
      INTO @Actualizadas(idEmpresa,Empresa,grupo,campoOrigen)
    FROM dbo.bf_RepConf_Columna AS C
    INNER JOIN @Hojas AS H
            ON H.idEmpresa=C.idEmpresa
           AND UPPER(LTRIM(RTRIM(H.grupo)))=
               UPPER(LTRIM(RTRIM(C.grupo)))
    WHERE C.catReportesId=3
      AND ISNULL(C.visible,1)<>0
      AND
      (
          UPPER(LTRIM(RTRIM(C.campoOrigen))) IN
          (
              N'CALLE',N'NUMEXT',N'NUMINT',N'COLONIA',
              N'DEL_MUNICIPIO',N'ESTADOFISCAL',N'CP'
          )
          OR
          (
              UPPER(LTRIM(RTRIM(H.grupo)))=N'VIDA'
              AND UPPER(LTRIM(RTRIM(C.campoOrigen))) IN
                  (N'PRIMANETA',N'PRIMENETA',N'COSTO')
          )
      );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT COUNT(*) AS ColumnasActualizadas
FROM @Actualizadas;

SELECT idEmpresa,Empresa,grupo,campoOrigen,CAST(0 AS bit) AS visible
FROM @Actualizadas
ORDER BY idEmpresa,grupo,campoOrigen;

SELECT H.idEmpresa,H.Empresa,H.grupo,
       C.campoOrigen,C.encabezado,C.visible
FROM @Hojas AS H
INNER JOIN dbo.bf_RepConf_Columna AS C
        ON C.idEmpresa=H.idEmpresa
       AND C.catReportesId=3
       AND UPPER(LTRIM(RTRIM(C.grupo)))=
           UPPER(LTRIM(RTRIM(H.grupo)))
WHERE
      UPPER(LTRIM(RTRIM(C.campoOrigen))) IN
      (
          N'CALLE',N'NUMEXT',N'NUMINT',N'COLONIA',
          N'DEL_MUNICIPIO',N'ESTADOFISCAL',N'CP'
      )
   OR
      (
          UPPER(LTRIM(RTRIM(H.grupo)))=N'VIDA'
          AND UPPER(LTRIM(RTRIM(C.campoOrigen))) IN
              (N'PRIMANETA',N'PRIMENETA',N'COSTO')
      )
ORDER BY H.idEmpresa,H.grupo,C.campoOrigen;
GO
