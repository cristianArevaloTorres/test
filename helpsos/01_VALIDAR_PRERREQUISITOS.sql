USE [FlexiForbesv2];
GO

SET NOCOUNT ON;

/* Valida que las dos plantillas esten activas. */
IF
(
    SELECT COUNT(DISTINCT CEIdPlantilla)
    FROM dbo.ff_CargaMasivaOperacionEmpresa
    WHERE CEIdEmpresa = 186
      AND CEIdOperacion = 2
      AND CEIdPlantilla IN (507, 12062)
      AND CEIdEstatus = 1
) < 2
BEGIN
    UPDATE dbo.ff_CargaMasivaOperacionEmpresa
    SET CEIdEstatus = 1
    WHERE CEIdEmpresa = 186
      AND CEIdOperacion = 2
      AND CEIdPlantilla IN (507, 12062);
END;

SELECT
    CEIdPlantilla,
    CEIdEstatus
FROM dbo.ff_CargaMasivaOperacionEmpresa
WHERE CEIdEmpresa = 186
  AND CEIdOperacion = 2
  AND CEIdPlantilla IN (507, 12062)
ORDER BY CEIdPlantilla;
