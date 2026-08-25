/*
   DIAGNOSTICO LIMITES CONCENTRADA B3
*/
SET NOCOUNT ON;

DECLARE @Objeto nvarchar(256)=N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_OPT',
        @ObjectId int,
        @Def nvarchar(max),
        @Upper nvarchar(max),
        @InicioExacto int,
        @InicioGenerico int,
        @InicioSinInto int,
        @FinLog int,
        @FinIfSinEspacio int,
        @FinIfConEspacio int,
        @PrimerIfExists int,
        @Referencia int;

SET @ObjectId=OBJECT_ID(@Objeto,N'P');
SET @Def=OBJECT_DEFINITION(@ObjectId);
SET @Upper=UPPER(@Def);

SET @InicioExacto=CHARINDEX(
    N'INSERT INTO #TABLATEMP (EMPRESA,NUMEMPLEADO',@Upper);
SET @InicioGenerico=CHARINDEX(N'INSERT INTO #TABLATEMP',@Upper);
SET @InicioSinInto=CHARINDEX(N'INSERT #TABLATEMP',@Upper);
SET @FinLog=CHARINDEX(N'-- LOG POST-INSERT-TABLATEMP',@Upper,
                      CASE WHEN @InicioGenerico>0 THEN @InicioGenerico ELSE 1 END);
SET @FinIfSinEspacio=CHARINDEX(
    N'IF EXISTS(SELECT TOP 1 * FROM #TABLATEMP',@Upper,
    CASE WHEN @InicioGenerico>0 THEN @InicioGenerico ELSE 1 END);
SET @FinIfConEspacio=CHARINDEX(
    N'IF EXISTS (SELECT TOP 1 * FROM #TABLATEMP',@Upper,
    CASE WHEN @InicioGenerico>0 THEN @InicioGenerico ELSE 1 END);
SET @PrimerIfExists=CHARINDEX(N'IF EXISTS',@Upper,
    CASE WHEN @InicioGenerico>0 THEN @InicioGenerico ELSE 1 END);

SELECT N'RESUMEN_OBJETO_QA' AS Resultado,
       @@SERVERNAME AS Servidor,
       DB_NAME() AS BaseDatos,
       @Objeto AS Objeto,
       @ObjectId AS ObjectId,
       HAS_PERMS_BY_NAME(@Objeto,N'OBJECT',N'VIEW DEFINITION') AS PuedeVerDefinicion,
       LEN(@Def) AS LongitudDefinicion,
       CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Def)),2)
           AS SHA256Definicion,
       @InicioExacto AS PosInicioExacto,
       @InicioGenerico AS PosInicioGenerico,
       @InicioSinInto AS PosInicioSinInto,
       @FinLog AS PosFinLog,
       @FinIfSinEspacio AS PosFinIfSinEspacio,
       @FinIfConEspacio AS PosFinIfConEspacio,
       @PrimerIfExists AS PosPrimerIfExists;

SELECT N'ESTADO_OBJETOS_SET' AS Resultado,
       V.Objeto,
       OBJECT_ID(V.Objeto,N'P') AS ObjectId,
       LEN(OBJECT_DEFINITION(OBJECT_ID(V.Objeto,N'P'))) AS LongitudDefinicion,
       CASE
         WHEN V.Marcador IS NULL THEN NULL
         WHEN OBJECT_DEFINITION(OBJECT_ID(V.Objeto,N'P')) LIKE N'%'+V.Marcador+N'%'
           THEN 1 ELSE 0
       END AS TieneMarcadorEsperado
FROM
(
    VALUES
      (N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_LEGACY',CAST(NULL AS nvarchar(200))),
      (N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_OPT',CAST(NULL AS nvarchar(200))),
      (N'dbo.ff_ObtenDivisionCtos_Adaptado_bf3_SET',N'BF3_DIVISION_SET_V1'),
      (N'dbo.ff_ObtenCobranzaDesg_Adaptada_bf3_SET',N'BF3_DESGLOSADA_ETAPAS_SET_V1'),
      (N'dbo.ObtenCobranzaConcentrada_otro_V2_BF3_SET',N'BF3_CONCENTRADA_ETAPAS_SET_V1')
) AS V(Objeto,Marcador)
ORDER BY V.Objeto;

IF @ObjectId IS NULL
BEGIN
    SELECT N'NO_EXISTE' AS Estado,
           N'El script 04 no creo el procedimiento OPT en esta base.' AS Detalle;
    RETURN;
END;

IF @Def IS NULL
BEGIN
    SELECT N'SIN_PERMISO' AS Estado,
           N'El objeto existe, pero el usuario no puede leer su definicion. Solicitar VIEW DEFINITION.' AS Detalle;
    RETURN;
END;

SET @Referencia=COALESCE(NULLIF(@InicioExacto,0),NULLIF(@InicioGenerico,0),
                         NULLIF(@InicioSinInto,0),NULLIF(CHARINDEX(N'#TABLATEMP',@Upper),0),1);

SELECT N'FRAGMENTO_ALREDEDOR_DEL_INSERT' AS Resultado,
       SUBSTRING(@Def,
                 CASE WHEN @Referencia>1000 THEN @Referencia-1000 ELSE 1 END,
                 7000) AS Fragmento;

SELECT N'FRAGMENTO_ALREDEDOR_DEL_PRIMER_IF_EXISTS' AS Resultado,
       SUBSTRING(@Def,
                 CASE WHEN @PrimerIfExists>1000 THEN @PrimerIfExists-1000 ELSE 1 END,
                 5000) AS Fragmento;

SELECT N'DEFINICION_COMPLETA_OPT' AS Resultado,@Def AS DefinicionCompleta;
