/*
   CORRECCION DEL FILTRO DE LECTURA DEL CACHE B3

   La seleccion de perfiles se resuelve con la fila concentrada del empleado.
   Una vez seleccionado el empleado deben incluirse todas sus solicitudes en
   Desglosada. El filtro anterior volvia a comparar NumSolicitud y descartaba
   movimientos historicos validos del mismo empleado.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @Def nvarchar(max),@Upper nvarchar(max),@Inicio int,@Fin int,@Proc int,
        @Bloque nvarchar(max);

IF OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache',N'P') IS NULL
    THROW 53800,'No existe el lector de cache B3.',1;

IF OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache_PRE_FILTRO_20260822',N'P') IS NULL
BEGIN
    SET @Def=OBJECT_DEFINITION(OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache'));
    SET @Def=REPLACE(@Def,N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache',
                          N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache_PRE_FILTRO_20260822');
    EXEC sys.sp_executesql @Def;
END;

SET @Def=OBJECT_DEFINITION(OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache'));
IF @Def NOT LIKE N'%BF3_CACHE_EMPLEADO_COMPLETO_V2%'
   AND @Def NOT LIKE N'%BF3_CACHE_TITULAR_DEPENDIENTES_V3%'
BEGIN
    SET @Upper=UPPER(@Def);
    SET @Inicio=CHARINDEX(N'AND EXISTS',@Upper,
                 CHARINDEX(N'FROM DBO.BF_COBRANZACACHE_DESGLOSADAV2',@Upper));
    SET @Fin=CHARINDEX(N';',@Def,@Inicio);
    IF @Inicio=0 OR @Fin=0
        THROW 53801,'No se encontro el filtro Desglosada del cache B3.',1;

    SET @Bloque=N'AND EXISTS
          (/* BF3_CACHE_EMPLEADO_COMPLETO_V2 */
           SELECT 1
           FROM #EmpleadosUniverso AS E
           WHERE E.CveEmpl=D.idemp
             AND E.NumEmpleado COLLATE DATABASE_DEFAULT=
                 D.NUMEMPLEADO COLLATE DATABASE_DEFAULT)';
    SET @Def=STUFF(@Def,@Inicio,@Fin-@Inicio,@Bloque);
    SET @Upper=UPPER(@Def);
    SET @Proc=CHARINDEX(N'PROCEDURE',@Upper);
    SET @Def=N'CREATE OR ALTER '+SUBSTRING(@Def,@Proc,LEN(@Def));
    EXEC sys.sp_executesql @Def;
END;

/* V3: Desglosada contiene titular y dependientes. El idemp del dependiente
   no existe en Concentrada; la llave comun es empresa + numero de empleado. */
SET @Def=OBJECT_DEFINITION(OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache'));
IF @Def NOT LIKE N'%BF3_CACHE_FILTRO_EMPRESA_NUM_V3%'
BEGIN
    SET @Upper=UPPER(@Def);
    SET @Inicio=CHARINDEX(N'CREATE TABLE #EMPLEADOSUNIVERSO',@Upper);
    SET @Fin=CHARINDEX(N';',@Def,@Inicio);
    IF @Inicio=0 OR @Fin=0
        THROW 53803,'No se encontro #EmpleadosUniverso en lector cache B3.',1;

    SET @Bloque=N'/* BF3_CACHE_TITULAR_DEPENDIENTES_V3 */
    CREATE TABLE #EmpleadosUniverso
    (
        Empresa int NOT NULL,
        CveEmpl int NULL,
        NumSolicitud varchar(8) COLLATE DATABASE_DEFAULT NULL,
        NumEmpleado varchar(20) COLLATE DATABASE_DEFAULT NULL
    );';
    SET @Def=STUFF(@Def,@Inicio,@Fin-@Inicio+1,@Bloque);

    SET @Def=REPLACE(@Def,
        N'INSERT #EmpleadosUniverso(CveEmpl,NumSolicitud,NumEmpleado)',
        N'INSERT #EmpleadosUniverso(Empresa,CveEmpl,NumSolicitud,NumEmpleado)');
    SET @Def=REPLACE(@Def,
        N'SELECT DISTINCT C.CveEmpl,C.NumSolicitud,C.NumEMpleado',
        N'SELECT DISTINCT C.empresa,C.CveEmpl,C.NumSolicitud,C.NumEMpleado');

    SET @Upper=UPPER(@Def);
    SET @Inicio=CHARINDEX(N'AND EXISTS',@Upper,
                 CHARINDEX(N'FROM DBO.BF_COBRANZACACHE_DESGLOSADAV2',@Upper));
    SET @Fin=CHARINDEX(N';',@Def,@Inicio);
    IF @Inicio=0 OR @Fin=0
        THROW 53804,'No se encontro filtro empleado/dependientes B3.',1;

    SET @Bloque=N'AND EXISTS
          (/* BF3_CACHE_FILTRO_EMPRESA_NUM_V3 */
           SELECT 1
           FROM #EmpleadosUniverso AS E
           WHERE E.Empresa=D.EMPRESA
             AND E.NumEmpleado COLLATE DATABASE_DEFAULT=
                 D.NUMEMPLEADO COLLATE DATABASE_DEFAULT)';
    SET @Def=STUFF(@Def,@Inicio,@Fin-@Inicio,@Bloque);

    SET @Upper=UPPER(@Def);
    SET @Proc=CHARINDEX(N'PROCEDURE',@Upper);
    SET @Def=N'CREATE OR ALTER '+SUBSTRING(@Def,@Proc,LEN(@Def));
    EXEC sys.sp_executesql @Def;
END;

/* V4: el flujo directo recibe la descripcion char(100) en varchar(50).
   Igualar el tipo evita espacios de relleno distintos en el contrato cache. */
SET @Def=OBJECT_DEFINITION(OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache'));
IF @Def NOT LIKE N'%BF3_CACHE_SUBTOTAL_VARCHAR50_V4%'
BEGIN
    SET @Def=REPLACE(@Def,
        N'DECLARE @IdSubtotal int,@DescripcionSubtotal varchar(100)',
        N'/* BF3_CACHE_SUBTOTAL_VARCHAR50_V4 */
    DECLARE @IdSubtotal int,@DescripcionSubtotal varchar(50)');
    IF @Def NOT LIKE N'%BF3_CACHE_SUBTOTAL_VARCHAR50_V4%'
        THROW 53805,'No se encontro el tipo de descripcion subtotal B3.',1;

    SET @Upper=UPPER(@Def);
    SET @Proc=CHARINDEX(N'PROCEDURE',@Upper);
    SET @Def=N'CREATE OR ALTER '+SUBSTRING(@Def,@Proc,LEN(@Def));
    EXEC sys.sp_executesql @Def;
END;

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache'))
   NOT LIKE N'%BF3_CACHE_SUBTOTAL_VARCHAR50_V4%'
    THROW 53802,'No se instalo la correccion del filtro cache B3.',1;
IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache'))
   NOT LIKE N'%BF3_CACHE_FILTRO_EMPRESA_NUM_V3%'
    THROW 53806,'No se instalo filtro empresa-numero del cache B3.',1;

/* Recompila bajo las opciones ANSI correctas incluso si el marcador ya
   existia por una ejecucion previa desde un cliente con QI OFF. */
SET @Def=OBJECT_DEFINITION(OBJECT_ID(N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_Cache'));
SET @Upper=UPPER(@Def);
SET @Proc=CHARINDEX(N'PROCEDURE',@Upper);
SET @Def=N'CREATE OR ALTER '+SUBSTRING(@Def,@Proc,LEN(@Def));
EXEC sys.sp_executesql @Def;

SELECT N'OK' AS Estado,N'Solo lector cache B3; datos almacenados no cambiaron' AS Alcance;
