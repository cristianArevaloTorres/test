/*
    ANALISIS DEL CATALOGO DE CODIGOS POSTALES

    IMPORTANTE:
    - Ejecutar en la base de datos del ambiente donde ocurrio el error.
    - Todas las consultas son exclusivamente de lectura.
    - No contiene INSERT, UPDATE, DELETE ni cambios de esquema.
    - Exportar cada resultado como CSV incluyendo encabezados y usando UTF-8.

    Caso investigado:
        Codigo postal: 55980
        Asentamiento:  San Jose
        Municipio:     Temascalapa
        Estado:        15

    Valores esperados segun la evidencia SEPOMEX:
        c_mnpio:          084
        id_asenta_cpcons: 8892
*/

/* ================================================================
   0. Confirmar servidor y base de datos
   Resultado sugerido: cp_ambiente.csv
   ================================================================ */
SELECT
    @@SERVERNAME AS Servidor,
    DB_NAME() AS BaseDatos;
GO

/* ================================================================
   1. Catalogo completo
   Resultado sugerido: cp_catalogo_completo.csv
   Este es el archivo principal para cargar en la LocalDB de analisis.
   ================================================================ */
SELECT
    Id,
    Codigo,
    Asentamiento,
    Municipio,
    Ciudad,
    CodigoPostalZona,
    IdEstadoCotizacion,
    IdCiudadCotizacion,
    IdEstado,
    IdMunicipioCotizacion
FROM dbo.CodigoPostal
ORDER BY Id;
GO

/* ================================================================
   2. Estructura de la tabla CodigoPostal
   Resultado sugerido: cp_estructura.csv
   ================================================================ */
SELECT
    c.ORDINAL_POSITION,
    c.COLUMN_NAME,
    c.DATA_TYPE,
    c.CHARACTER_MAXIMUM_LENGTH,
    c.NUMERIC_PRECISION,
    c.NUMERIC_SCALE,
    c.IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS AS c
WHERE c.TABLE_SCHEMA = 'dbo'
  AND c.TABLE_NAME = 'CodigoPostal'
ORDER BY c.ORDINAL_POSITION;
GO

/* ================================================================
   3. Buscar tablas que tengan columnas originales de SEPOMEX
   Resultado sugerido: cp_tablas_sepomex.csv
   ================================================================ */
SELECT
    s.name AS Esquema,
    t.name AS Tabla,
    c.name AS Columna,
    ty.name AS TipoDato,
    c.max_length AS Longitud
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
INNER JOIN sys.columns AS c
    ON c.object_id = t.object_id
INNER JOIN sys.types AS ty
    ON ty.user_type_id = c.user_type_id
WHERE c.name IN
(
    'd_codigo',
    'd_asenta',
    'd_tipo_asenta',
    'D_mnpio',
    'd_estado',
    'd_ciudad',
    'd_CP',
    'c_estado',
    'c_oficina',
    'c_CP',
    'c_tipo_asenta',
    'c_mnpio',
    'id_asenta_cpcons'
)
ORDER BY s.name, t.name, c.column_id;
GO

/* ================================================================
   4. Buscar procedimientos, vistas o funciones relacionados con la
      carga u homologacion del catalogo
   Resultado sugerido: cp_procesos_carga.csv
   ================================================================ */
SELECT
    s.name AS Esquema,
    o.name AS Objeto,
    o.type_desc AS TipoObjeto,
    m.definition AS Definicion
FROM sys.sql_modules AS m
INNER JOIN sys.objects AS o
    ON o.object_id = m.object_id
INNER JOIN sys.schemas AS s
    ON s.schema_id = o.schema_id
WHERE m.definition LIKE '%CodigoPostal%'
   OR m.definition LIKE '%IdCiudadCotizacion%'
   OR m.definition LIKE '%IdMunicipioCotizacion%'
   OR m.definition LIKE '%id_asenta_cpcons%'
   OR m.definition LIKE '%c_mnpio%'
ORDER BY s.name, o.name;
GO

/* ================================================================
   5. Municipios que tienen mas de una clave de municipio
   Resultado sugerido: cp_municipios_inconsistentes.csv
   Cada municipio deberia tener una sola clave c_mnpio por estado.
   ================================================================ */
SELECT
    IdEstadoCotizacion,
    Municipio,
    COUNT(*) AS TotalRegistros,
    COUNT(DISTINCT IdCiudadCotizacion) AS ClavesMunicipioDistintas,
    MIN(IdCiudadCotizacion) AS ClaveMinima,
    MAX(IdCiudadCotizacion) AS ClaveMaxima
FROM dbo.CodigoPostal
WHERE NULLIF(IdCiudadCotizacion, '') IS NOT NULL
GROUP BY
    IdEstadoCotizacion,
    Municipio
HAVING COUNT(DISTINCT IdCiudadCotizacion) > 1
ORDER BY
    IdEstadoCotizacion,
    Municipio;
GO

/* ================================================================
   6. Registros duplicados por la llave logica de direccion
   Resultado sugerido: cp_duplicados.csv
   ================================================================ */
SELECT
    Codigo,
    Asentamiento,
    Municipio,
    IdEstadoCotizacion,
    COUNT(*) AS Cantidad
FROM dbo.CodigoPostal
GROUP BY
    Codigo,
    Asentamiento,
    Municipio,
    IdEstadoCotizacion
HAVING COUNT(*) > 1
ORDER BY
    Cantidad DESC,
    Codigo,
    Asentamiento;
GO

/* ================================================================
   7. Caso especifico: todas las colonias del CP 55980
   Resultado sugerido: cp_55980.csv
   ================================================================ */
SELECT
    Id,
    Codigo,
    Asentamiento,
    Municipio,
    Ciudad,
    CodigoPostalZona,
    IdEstadoCotizacion,
    IdCiudadCotizacion AS ValorRegla7,
    IdMunicipioCotizacion AS ValorRegla8,
    IdEstado
FROM dbo.CodigoPostal
WHERE Codigo = '55980'
ORDER BY Asentamiento, Id;
GO

/* ================================================================
   8. Asentamientos San Jose del Estado de Mexico
   Resultado sugerido: cp_san_jose_estado_15.csv
   Ayuda a detectar cruces entre asentamientos con el mismo nombre.
   ================================================================ */
SELECT
    Id,
    Codigo,
    Asentamiento,
    Municipio,
    IdEstadoCotizacion,
    IdCiudadCotizacion,
    IdMunicipioCotizacion
FROM dbo.CodigoPostal
WHERE IdEstadoCotizacion = '15'
  AND Asentamiento LIKE N'San Jos%'
ORDER BY Asentamiento, Codigo, Id;
GO

/* ================================================================
   9. Localizar las claves involucradas en el caso
   Resultado sugerido: cp_claves_7806_8892.csv
   ================================================================ */
SELECT
    Id,
    Codigo,
    Asentamiento,
    Municipio,
    IdEstadoCotizacion,
    IdCiudadCotizacion,
    IdMunicipioCotizacion
FROM dbo.CodigoPostal
WHERE IdMunicipioCotizacion IN ('7806', '8892')
   OR (
        IdCiudadCotizacion = '099'
        AND IdMunicipioCotizacion = '7806'
   )
ORDER BY IdEstadoCotizacion, Codigo, Asentamiento;
GO

/* ================================================================
   10. Perfil general de calidad del catalogo
   Resultado sugerido: cp_resumen_calidad.csv
   ================================================================ */
SELECT
    COUNT(*) AS TotalRegistros,
    COUNT(DISTINCT Codigo) AS CodigosPostalesDistintos,
    COUNT(DISTINCT IdEstadoCotizacion) AS EstadosDistintos,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(Codigo)), '') IS NULL THEN 1 ELSE 0 END) AS SinCodigo,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(Asentamiento)), '') IS NULL THEN 1 ELSE 0 END) AS SinAsentamiento,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(Municipio)), '') IS NULL THEN 1 ELSE 0 END) AS SinMunicipio,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(IdEstadoCotizacion)), '') IS NULL THEN 1 ELSE 0 END) AS SinClaveEstado,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(IdCiudadCotizacion)), '') IS NULL THEN 1 ELSE 0 END) AS SinClaveMunicipio,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(IdMunicipioCotizacion)), '') IS NULL THEN 1 ELSE 0 END) AS SinClaveAsentamiento
FROM dbo.CodigoPostal;
GO

/*
    Correspondencia que se validara contra el archivo original SEPOMEX:

        Codigo                  <-> d_codigo
        Asentamiento            <-> d_asenta
        Municipio               <-> D_mnpio
        Ciudad                  <-> d_ciudad
        CodigoPostalZona        <-> d_CP
        IdEstadoCotizacion      <-> c_estado
        IdCiudadCotizacion      <-> c_mnpio
        IdMunicipioCotizacion   <-> id_asenta_cpcons
*/
