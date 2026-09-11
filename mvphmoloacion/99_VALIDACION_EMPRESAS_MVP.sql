-- ============================================================================
-- CREA 010 - Validacion Paquete carga masiva (v2026-06-22) - DEV / QA
-- Reemplaza @IdEmpresa por el id de la empresa MVP recien creada por el Wizard.
-- ============================================================================
USE [FlexiForbesv2];
GO
DECLARE @IdEmpresa INT = 2947;   -- <<< poner id de la empresa de prueba

-- 1) Carga masiva: deben ser 5 ops con el mapeo FINAL confirmado
SELECT 'CARGA_MASIVA' AS check_, CEIdOperacion, CEIdPlantilla, CEStoredProc
FROM ff_CargaMasivaOperacionEmpresa
WHERE CEIdEmpresa = @IdEmpresa
ORDER BY CEIdOperacion;
-- Esperado:
--  1 | 12061 | ff_XCMDependientesAltaCMM
--  2 | 12062 | ff_XCMTitularesAltaCMM_BF3
--  3 |  154  | ff_XCMAseguradosBaja_Base
-- 13 | 12059 | ff_ActualizaNumEmpleadoTitular
-- 14 | 12060 | bf_ReactivacionEmpleadosTitular

-- 2) Que NO se hayan creado plantillas nuevas de masiva (las 12239/12240 del bug)
SELECT 'CLONES_MASIVA_NO_DEBEN_EXISTIR' AS check_, PLIdPlantilla, PLDescripcion
FROM ff_Plantilla
WHERE PLDescripcion LIKE '%masiva - MVP[_]' + CAST(@IdEmpresa AS VARCHAR);
-- Esperado: 0 filas

-- 3) Plantillas de pantalla MVP creadas (deben existir las 3)
SELECT 'PANTALLA_MVP' AS check_, PLIdPlantilla, PLDescripcion
FROM ff_Plantilla
WHERE PLDescripcion LIKE '%- MVP[_]' + CAST(@IdEmpresa AS VARCHAR)
ORDER BY PLIdPlantilla;
-- Esperado: Alta/Modifica/Consulta titulares - MVP_<id>

-- 4) Bitacora de la corrida
SELECT 'BITACORA' AS check_, BEAccion, BEExitoso, BECantidadElementos, BEDetalle, BEFechaCreacion
FROM bf_BitacoraEmpresa
WHERE BEIdEmpresa = @IdEmpresa
ORDER BY BEFechaCreacion DESC;
GO
