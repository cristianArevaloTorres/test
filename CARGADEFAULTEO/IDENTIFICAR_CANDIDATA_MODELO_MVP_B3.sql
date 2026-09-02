/*
===============================================================================
 IDENTIFICAR POSIBLES EMPRESAS MODELO MVP B3
===============================================================================

 Solo lectura sobre la base funcional. No inserta, actualiza ni elimina datos.

 Evidencia fuerte de flujo B3:
   - CREACION_EMPRESA_MVP / CREACION_EMPRESA_MVP_FIN en bf_BitacoraEmpresa.
   - COPIAR_MENUS, COPIAR_ROLES, COPIAR_IMAGENES, COPIAR_COLORES,
     COPIAR_DOCUMENTOS, COPIAR_PERFILES, COPIAR_PLANES y COPIAR_PARAMETROS.

 Advertencia:
   bf_EmpresaMVP por si sola no demuestra B3; puede contener empresas legacy B2.
   Una empresa con componentes tampoco es automaticamente una plantilla. El
   resultado sirve para localizar candidatas que deben aprobarse funcionalmente.

 Para ver el detalle de una candidata, asigne su ID a @IdEmpresaRevisar.
===============================================================================
*/

SET NOCOUNT ON;

DECLARE @IdEmpresaRevisar INT = NULL;

IF OBJECT_ID('dbo.ff_Empresa','U') IS NULL
 OR OBJECT_ID('dbo.bf_EmpresaMVP','U') IS NULL
 OR OBJECT_ID('dbo.bf_BitacoraEmpresa','U') IS NULL
 OR OBJECT_ID('dbo.ff_Rol','U') IS NULL
 OR OBJECT_ID('dbo.ff_Perfil','U') IS NULL
 OR OBJECT_ID('dbo.ff_MenuRol','U') IS NULL
 OR OBJECT_ID('dbo.ff_MenuRol2','U') IS NULL
 OR OBJECT_ID('dbo.ff_EmpresaImagen','U') IS NULL
 OR OBJECT_ID('dbo.ff_ImagenEmpresaMenu','U') IS NULL
 OR OBJECT_ID('dbo.ff_Parametro','U') IS NULL
 OR OBJECT_ID('dbo.ff_Documentos','U') IS NULL
 OR OBJECT_ID('dbo.ff_DocumentoPlanB3','U') IS NULL
    THROW 51000, 'Faltan objetos necesarios para identificar candidatas MVP B3.', 1;

DROP TABLE IF EXISTS #IdsCandidatos;
DROP TABLE IF EXISTS #InventarioMVP;

CREATE TABLE #IdsCandidatos
(
    IdEmpresa INT NOT NULL PRIMARY KEY
);

/* 1. Empresas marcadas como MVP, incluso si la marca pudiera ser legacy. */
INSERT INTO #IdsCandidatos(IdEmpresa)
SELECT DISTINCT m.IdEmpresa
FROM dbo.bf_EmpresaMVP m
JOIN dbo.ff_Empresa e ON e.EMidEmpresa=m.IdEmpresa AND e.EMidEstatus=1
WHERE m.IdEstatus=1;

/* 2. Empresas con alguna traza específica del flujo MVP B3. */
INSERT INTO #IdsCandidatos(IdEmpresa)
SELECT DISTINCT b.BEIdEmpresa
FROM dbo.bf_BitacoraEmpresa b
JOIN dbo.ff_Empresa e ON e.EMidEmpresa=b.BEIdEmpresa AND e.EMidEstatus=1
WHERE
(
    b.BEAccion LIKE '%MVP%'
    OR b.BEAccion IN
    (
      'COPIAR_MENUS','COPIAR_ROLES','COPIAR_IMAGENES','COPIAR_COLORES',
      'COPIAR_DOCUMENTOS','COPIAR_PERFILES','COPIAR_PLANES','COPIAR_PARAMETROS'
    )
)
AND NOT EXISTS
(
    SELECT 1 FROM #IdsCandidatos x WHERE x.IdEmpresa=b.BEIdEmpresa
);

/*
 3. Empresas sin traza pero con núcleo técnico B3. Se parte de MenuRol2 para
 reducir el universo antes de consultar perfiles y parámetros.
*/
INSERT INTO #IdsCandidatos(IdEmpresa)
SELECT DISTINCT r.ROIdEmpresa
FROM dbo.ff_Rol r
JOIN dbo.ff_MenuRol2 mr ON mr.MRidRol=r.ROIdRol AND mr.MRidEstatus=1
JOIN dbo.ff_Empresa e ON e.EMidEmpresa=r.ROIdEmpresa AND e.EMidEstatus=1
WHERE r.ROIdEstatus=1
  AND EXISTS
  (
      SELECT 1 FROM dbo.ff_Perfil p
      WHERE p.PEIdEmpresa=r.ROIdEmpresa AND p.PEIdEstatus=1
  )
  AND EXISTS
  (
      SELECT 1 FROM dbo.ff_Parametro pa
      WHERE pa.paIdEmpresa=r.ROIdEmpresa AND pa.paidEstatus=1
  )
  AND NOT EXISTS
  (
      SELECT 1 FROM #IdsCandidatos x WHERE x.IdEmpresa=r.ROIdEmpresa
  );

;WITH TrazaB3 AS
(
    SELECT
        b.BEIdEmpresa AS IdEmpresa,
        CreacionB3Exitosa=MAX(CASE
          WHEN b.BEAccion IN ('CREACION_EMPRESA_MVP','CREACION_EMPRESA_MVP_FIN','CREAR_EMPRESA_MVP')
           AND b.BEExitoso=1 THEN 1 ELSE 0 END),
        PasosB3Exitosos=COUNT(DISTINCT CASE
          WHEN b.BEAccion IN
          (
            'COPIAR_MENUS','COPIAR_ROLES','COPIAR_IMAGENES','COPIAR_COLORES',
            'COPIAR_DOCUMENTOS','COPIAR_PERFILES','COPIAR_PLANES','COPIAR_PARAMETROS'
          ) AND b.BEExitoso=1 THEN b.BEAccion END),
        UltimaTrazaB3=MAX(CASE
          WHEN b.BEAccion LIKE '%MVP%' OR b.BEAccion LIKE 'COPIAR_%'
          THEN b.BEFechaCreacion END)
    FROM dbo.bf_BitacoraEmpresa b
    JOIN #IdsCandidatos c ON c.IdEmpresa=b.BEIdEmpresa
    GROUP BY b.BEIdEmpresa
)
SELECT
    e.EMidEmpresa AS IdEmpresa,
    e.EMNombre AS Empresa,
    e.EMidCorporativo AS IdCorporativo,
    TipoRegistro=CASE WHEN e.EMidEmpresa=e.EMidCorporativo
                      THEN 'CORPORATIVO' ELSE 'EMPRESA' END,
    MarcadaMVP=CONVERT(BIT,CASE WHEN EXISTS
    (
        SELECT 1 FROM dbo.bf_EmpresaMVP m
        WHERE m.IdEmpresa=e.EMidEmpresa AND m.IdEstatus=1
    ) THEN 1 ELSE 0 END),
    CreacionB3Exitosa=CONVERT(BIT,ISNULL(t.CreacionB3Exitosa,0)),
    PasosB3Exitosos=ISNULL(t.PasosB3Exitosos,0),
    t.UltimaTrazaB3,
    Roles=(SELECT COUNT(*) FROM dbo.ff_Rol r
           WHERE r.ROIdEmpresa=e.EMidEmpresa AND r.ROIdEstatus=1),
    Perfiles=(SELECT COUNT(*) FROM dbo.ff_Perfil p
              WHERE p.PEIdEmpresa=e.EMidEmpresa AND p.PEIdEstatus=1),
    MenusV1=(SELECT COUNT(*) FROM dbo.ff_MenuRol mr
             JOIN dbo.ff_Rol r ON r.ROIdRol=mr.MRidRol
             WHERE r.ROIdEmpresa=e.EMidEmpresa AND r.ROIdEstatus=1 AND mr.MRidEstatus=1),
    MenusV2=(SELECT COUNT(*) FROM dbo.ff_MenuRol2 mr
             JOIN dbo.ff_Rol r ON r.ROIdRol=mr.MRidRol
             WHERE r.ROIdEmpresa=e.EMidEmpresa AND r.ROIdEstatus=1 AND mr.MRidEstatus=1),
    Imagenes=(SELECT COUNT(*) FROM dbo.ff_EmpresaImagen i WHERE i.EIIdEmpresa=e.EMidEmpresa)
             +(SELECT COUNT(*) FROM dbo.ff_ImagenEmpresaMenu i WHERE i.IEMIdEmpresa=e.EMidEmpresa AND i.IEMEstatus=1),
    Documentos=(SELECT COUNT(*) FROM dbo.ff_Documentos d
                WHERE d.DOIdEmpresa=e.EMidEmpresa AND d.DOUsuarioDel IS NULL),
    PlanesB3=(SELECT COUNT(*) FROM dbo.ff_DocumentoPlanB3 p
              WHERE p.DPIdEmpresa=e.EMidEmpresa AND p.DPEstatus=1),
    Parametros=(SELECT COUNT(*) FROM dbo.ff_Parametro p
                WHERE p.paIdEmpresa=e.EMidEmpresa AND p.paidEstatus=1)
INTO #InventarioMVP
FROM #IdsCandidatos c
JOIN dbo.ff_Empresa e ON e.EMidEmpresa=c.IdEmpresa AND e.EMidEstatus=1
LEFT JOIN TrazaB3 t ON t.IdEmpresa=e.EMidEmpresa
;

/*
 RESULTADO 1: clasificación de candidatas.

 B3_FLUJO_COMPLETO_COMPROBABLE es la evidencia mas fuerte, pero aun requiere
 revisar que no haya sido personalizada despues de su creación.
*/
SELECT
    Clasificacion=CASE
      WHEN CreacionB3Exitosa=1 AND PasosB3Exitosos=8
       AND Roles>0 AND Perfiles>0 AND MenusV2>0 AND Parametros>0
        THEN 'B3_FLUJO_COMPLETO_COMPROBABLE'
      WHEN CreacionB3Exitosa=1 AND PasosB3Exitosos BETWEEN 1 AND 7
        THEN 'B3_FLUJO_PARCIAL_REVISAR'
      WHEN MarcadaMVP=1 AND CreacionB3Exitosa=0
        THEN 'MVP_MARCADA_SIN_TRAZA_B3_POSIBLE_LEGACY'
      WHEN Roles>0 AND Perfiles>0 AND MenusV2>0 AND Parametros>0
        THEN 'CONFIGURADA_SIN_EVIDENCIA_DE_FLUJO_MVP'
      ELSE 'NO_CANDIDATA' END,
    PuntajeEvidencia=
        CASE WHEN CreacionB3Exitosa=1 THEN 40 ELSE 0 END
      + PasosB3Exitosos*5
      + CASE WHEN MarcadaMVP=1 THEN 10 ELSE 0 END
      + CASE WHEN Roles>0 THEN 2 ELSE 0 END
      + CASE WHEN Perfiles>0 THEN 2 ELSE 0 END
      + CASE WHEN MenusV2>0 THEN 2 ELSE 0 END
      + CASE WHEN Parametros>0 THEN 2 ELSE 0 END
      + CASE WHEN Imagenes>0 THEN 1 ELSE 0 END
      + CASE WHEN Documentos>0 THEN 1 ELSE 0 END
      + CASE WHEN PlanesB3>0 THEN 1 ELSE 0 END,
    *
FROM #InventarioMVP
WHERE MarcadaMVP=1
   OR CreacionB3Exitosa=1
   OR PasosB3Exitosos>0
   OR (Roles>0 AND Perfiles>0 AND MenusV2>0 AND Parametros>0)
ORDER BY
    PuntajeEvidencia DESC,
    UltimaTrazaB3 DESC,
    IdEmpresa;

/* RESULTADO 2: resumen; permite saber si existe evidencia B3 real. */
SELECT
    TotalEmpresasActivas=(SELECT COUNT(*) FROM dbo.ff_Empresa WHERE EMidEstatus=1),
    TotalCandidatasInventariadas=COUNT(*),
    ConMarcaMVP=SUM(CASE WHEN MarcadaMVP=1 THEN 1 ELSE 0 END),
    ConCreacionB3Comprobable=SUM(CASE WHEN CreacionB3Exitosa=1 THEN 1 ELSE 0 END),
    ConOchoPasosB3=SUM(CASE WHEN PasosB3Exitosos=8 THEN 1 ELSE 0 END),
    ConNucleoConfigurado=SUM(CASE
      WHEN Roles>0 AND Perfiles>0 AND MenusV2>0 AND Parametros>0
      THEN 1 ELSE 0 END)
FROM #InventarioMVP;

/*
 RESULTADO 3: huellas repetidas por conteos.
 Varias empresas con la misma huella pueden provenir de una misma plantilla,
 pero los conteos iguales no prueban que los registros sean idénticos.
*/
SELECT
    EmpresasConMismaHuella=COUNT(*),
    Roles,Perfiles,MenusV1,MenusV2,Imagenes,Documentos,PlanesB3,Parametros,
    IdMenor=MIN(IdEmpresa),
    IdMayor=MAX(IdEmpresa)
FROM #InventarioMVP
WHERE Roles>0 AND Perfiles>0 AND MenusV2>0 AND Parametros>0
GROUP BY Roles,Perfiles,MenusV1,MenusV2,Imagenes,Documentos,PlanesB3,Parametros
HAVING COUNT(*)>1
ORDER BY EmpresasConMismaHuella DESC,Roles,Perfiles,MenusV2;

/* RESULTADO 4: bitácora exacta de creación/copia para la empresa seleccionada. */
SELECT
    BEIdEmpresa,BEAccion,BEElementoAfectado,BECantidadElementos,
    BEExitoso,BEFechaCreacion,BEDetalle,BEMensajeError
FROM dbo.bf_BitacoraEmpresa
WHERE BEIdEmpresa=@IdEmpresaRevisar
  AND
  (
      BEAccion LIKE '%MVP%'
      OR BEAccion IN
      (
        'COPIAR_MENUS','COPIAR_ROLES','COPIAR_IMAGENES','COPIAR_COLORES',
        'COPIAR_DOCUMENTOS','COPIAR_PERFILES','COPIAR_PLANES','COPIAR_PARAMETROS'
      )
  )
ORDER BY BEFechaCreacion,BEId;

/* RESULTADO 5: detalle no sensible de la candidata seleccionada. */
SELECT *
FROM #InventarioMVP
WHERE IdEmpresa=@IdEmpresaRevisar;

SELECT ROIdRol,RODescripcionCorta,RODescripcionLarga,RODefault,ROAdministrador
FROM dbo.ff_Rol
WHERE ROIdEmpresa=@IdEmpresaRevisar AND ROIdEstatus=1
ORDER BY RODescripcionCorta,ROIdRol;

SELECT PEIdPerfil,PENombre,PEDescripcion,PEAdministrador,PEIdRolDefault
FROM dbo.ff_Perfil
WHERE PEIdEmpresa=@IdEmpresaRevisar AND PEIdEstatus=1
ORDER BY PENombre,PEIdPerfil;

SELECT r.RODescripcionCorta,mr.MRidMenu
FROM dbo.ff_MenuRol2 mr
JOIN dbo.ff_Rol r ON r.ROIdRol=mr.MRidRol
WHERE r.ROIdEmpresa=@IdEmpresaRevisar
  AND r.ROIdEstatus=1 AND mr.MRidEstatus=1
ORDER BY r.RODescripcionCorta,mr.MRidMenu;

/* No muestra paValor para evitar exponer secretos o datos sensibles. */
SELECT paId,paClase,paDescripcion,
       ValorConfigurado=CASE WHEN NULLIF(LTRIM(RTRIM(paValor)),'') IS NULL THEN 0 ELSE 1 END,
       LongitudValor=LEN(paValor)
FROM dbo.ff_Parametro
WHERE paIdEmpresa=@IdEmpresaRevisar AND paidEstatus=1
ORDER BY paId,paClase;

PRINT 'Diagnostico terminado. No se modificaron datos.';
