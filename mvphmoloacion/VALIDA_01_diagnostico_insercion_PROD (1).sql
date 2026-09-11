/* ============================================================================
   CREA010 - Empresa MVP :: DIAGNOSTICO "no esta insertando en PROD" (READ-ONLY)
   ----------------------------------------------------------------------------
   Objetivo: identificar POR QUE la cascada bf_ProcesoMVP no inserto la config
   de una empresa MVP recien creada. NO crea, altera ni borra NADA (solo SELECT).
   Seguro en PRODUCCION.

   COMO USAR:
     1) Conectar VPN / abrir sesion en el server PROD (lockmx-dbn).
     2) Ajustar @IdCorp abajo (en tu caso 2940).
     3) Ejecutar TODO. Leer los grids de arriba hacia abajo; el primero que
        salga en rojo (>>> ...) es la causa raiz.

   HIPOTESIS PRINCIPAL (la mas comun en PROD):
     bf_ProcesoMVP copia desde la empresa MODELO 2494 (DRAGER hija) y corp
     MODELO 2493. Esos ids son de DEV/QA. Si NO existen en PROD, cada SP de
     copia hace RAISERROR('...modelo no existe') + THROW -> la cascada aborta
     y no inserta la config del hijo. El corporativo queda solo con los pocos
     parametros que ff_AddEmpresa mete ANTES de llamar al MVP.
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @IdCorp  INT = 2940;         -- <<< corporativo creado en PROD
DECLARE @Modelo  INT = 2494;         -- empresa modelo (hija) que usa bf_ProcesoMVP por default
DECLARE @ModCorp INT = 2493;         -- corp modelo por default

PRINT '=================================================================';
PRINT ' DIAGNOSTICO MVP PROD  ->  Corp = ' + CAST(@IdCorp AS varchar(20))
      + '   Modelo hija = ' + CAST(@Modelo AS varchar(20))
      + '   Modelo corp = ' + CAST(@ModCorp AS varchar(20));
PRINT '=================================================================';

/* ---------------------------------------------------------------------
   [1] CAUSA RAIZ #1: la empresa MODELO debe existir en PROD.
       Si alguna sale FALTA, la cascada truena y no inserta nada del hijo.
   --------------------------------------------------------------------- */
SELECT '[1]_MODELO_EXISTE' AS seccion,
       m.id_modelo,
       m.rol,
       CASE WHEN e.EMidEmpresa IS NULL THEN '>>> FALTA EN PROD (causa del fallo)'
            WHEN e.EMidEstatus <> 1     THEN '>>> EXISTE PERO INACTIVA'
            ELSE 'OK' END AS estado,
       e.EMRazonSocial, e.EMNombre, e.EMidEstatus, e.EMidCorporativo
FROM (VALUES (@Modelo,'empresa modelo (hija)'), (@ModCorp,'corp modelo')) m(id_modelo, rol)
LEFT JOIN ff_Empresa e ON e.EMidEmpresa = m.id_modelo;

/* ---------------------------------------------------------------------
   [2] Objetos CREA010 desplegados en PROD (deben estar los 19).
   --------------------------------------------------------------------- */
DECLARE @obj TABLE (nombre sysname);
INSERT INTO @obj VALUES
 ('bf_BitacoraEmpresa'),('sp_CopiarRolesEmpresa'),('sp_CopiarPerfilesEmpresa'),
 ('sp_CopiarMenusEmpresa'),('sp_CopiarImagenesEmpresa'),('sp_CopiarColoresEmpresa'),
 ('sp_CopiarDocumentosEmpresa'),('sp_CopiarPlanesEmpresa'),('sp_CopiarParametrosEmpresa'),
 ('sp_CopiarAccesoBeflex'),('sp_CopiarBeflexInicio2'),('sp_CopiarConfiguracionEmpresa'),
 ('sp_CopiarMenusV2_MVP'),('sp_CopiarParametroMismoSexo_MVP'),('sp_CopiarPlantillasMVP'),
 ('sp_CopiarCargaMasiva_MVP'),('sp_CopiarReporteInterfabricaMVP'),('sp_CrearEmpresaMVP'),
 ('bf_ProcesoMVP');

SELECT '[2]_OBJETOS' AS seccion, o.nombre,
       CASE WHEN s.object_id IS NULL THEN '>>> FALTA' ELSE 'OK (' + CONVERT(varchar,s.modify_date,120) + ')' END AS estado
FROM @obj o
LEFT JOIN sys.objects s ON s.name = o.nombre AND s.is_ms_shipped = 0
ORDER BY o.nombre;

SELECT '[2]_OBJETOS_RESUMEN' AS seccion,
       (SELECT COUNT(*) FROM @obj) AS esperados,
       (SELECT COUNT(*) FROM @obj o JOIN sys.objects s ON s.name=o.nombre AND s.is_ms_shipped=0) AS presentes;

/* ---------------------------------------------------------------------
   [3] BITACORA de la corrida: aqui queda el ERROR exacto si la cascada
       aborto (BEExitoso = 0 trae ERROR_MESSAGE en BEMensajeError).
       ---> ESTE ES EL GRID MAS IMPORTANTE. <---
   --------------------------------------------------------------------- */
IF OBJECT_ID('dbo.bf_BitacoraEmpresa') IS NULL
    SELECT '[3]_BITACORA' AS seccion, '>>> La tabla bf_BitacoraEmpresa NO existe en PROD (objeto no desplegado)' AS nota;
ELSE
    SELECT '[3]_BITACORA' AS seccion, b.BEId, b.BEIdEmpresa, b.BEAccion, b.BEExitoso,
           b.BEElementoAfectado, b.BECantidadElementos, b.BEMensajeError, b.BEDetalle, b.BEFechaCreacion
    FROM bf_BitacoraEmpresa b
    WHERE b.BEIdEmpresa = @IdCorp
       OR b.BEIdEmpresa IN (SELECT EMidEmpresa FROM ff_Empresa WHERE EMidCorporativo = @IdCorp)
    ORDER BY b.BEFechaCreacion DESC, b.BEId DESC;

/* ---------------------------------------------------------------------
   [4] Corporativo + empresas hijas creadas bajo el corp.
       Si solo aparece el corp (sin hija) el Wizard no creo la empresa MVP.
   --------------------------------------------------------------------- */
SELECT '[4]_EMPRESAS' AS seccion, EMidEmpresa, EMidCorporativo, EMidPadre, EMNivel,
       EMRazonSocial, EMNombre, EMidEstatus,
       CASE WHEN EMidEmpresa = EMidCorporativo THEN 'CORP' ELSE 'EMP HIJA' END AS tipo
FROM ff_Empresa
WHERE EMidEmpresa = @IdCorp OR EMidCorporativo = @IdCorp
ORDER BY EMNivel, EMidEmpresa;

/* ---------------------------------------------------------------------
   [5] Config insertada POR EMPRESA (corp + hijas): si la cascada corrio,
       la empresa hija debe traer perfiles/roles/menus/carga masiva > 0.
       Todo en 0 en la hija = la cascada no inserto (ver [1] y [3]).
   --------------------------------------------------------------------- */
SELECT '[5]_CONFIG_POR_EMPRESA' AS seccion,
       e.EMidEmpresa,
       CASE WHEN e.EMidEmpresa = @IdCorp THEN 'CORP' ELSE 'EMP HIJA' END AS tipo,
       (SELECT COUNT(*) FROM bf_EmpresaMVP m WHERE m.IdEmpresa = e.EMidEmpresa)                                  AS marca_mvp,
       (SELECT COUNT(*) FROM ff_Perfil    p WHERE p.PEIdEmpresa = e.EMidEmpresa AND p.PEIdEstatus = 1)           AS perfiles,
       (SELECT COUNT(*) FROM ff_Rol       r WHERE r.ROIdEmpresa = e.EMidEmpresa AND r.ROIdEstatus = 1)           AS roles,
       (SELECT COUNT(*) FROM ff_MenuRol2 mr JOIN ff_Rol r2 ON r2.ROIdRol = mr.MRidRol
              WHERE r2.ROIdEmpresa = e.EMidEmpresa AND mr.MRidEstatus = 1)                                       AS menu_asig,
       (SELECT COUNT(*) FROM ff_Parametro pa WHERE pa.paIdEmpresa = e.EMidEmpresa AND pa.paidEstatus = 1)        AS parametros,
       (SELECT COUNT(*) FROM ff_CargaMasivaOperacionEmpresa c WHERE c.CEIdEmpresa = e.EMidEmpresa)               AS carga_masiva,
       (SELECT COUNT(*) FROM ff_Plantilla pl WHERE pl.PLDescripcion LIKE '%- MVP[_]'+CAST(e.EMidEmpresa AS varchar(20))+'%') AS plantillas_pantalla
FROM ff_Empresa e
WHERE e.EMidEmpresa = @IdCorp OR e.EMidCorporativo = @IdCorp
ORDER BY CASE WHEN e.EMidEmpresa = @IdCorp THEN 0 ELSE 1 END, e.EMidEmpresa;

/* ---------------------------------------------------------------------
   [6] Detalle de parametros del corporativo (lo que mostraste en tu grid)
   --------------------------------------------------------------------- */
SELECT '[6]_PARAMETROS_CORP' AS seccion, paId, paIdEmpresa, paClase, paValor, paDescripcion, paidEstatus
FROM ff_Parametro
WHERE paIdEmpresa = @IdCorp AND paidEstatus = 1
ORDER BY paId;

PRINT '=== FIN. Orden de lectura: [1] modelo -> [3] bitacora (error real) -> [5] config del hijo. ===';
GO
