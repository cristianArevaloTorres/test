USE [FlexiForbesv2];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER FUNCTION dbo.bf_SabanaQuitarColumnasB2
(
    @Sql nvarchar(max),
    @QuitarPrimaCosto bit
)
RETURNS nvarchar(max)
AS
BEGIN
    IF @Sql IS NULL OR LEN(@Sql)=0
        RETURN @Sql;

    DECLARE @Objetivos TABLE
    (
        Nombre nvarchar(50) NOT NULL PRIMARY KEY
    );

    INSERT @Objetivos(Nombre)
    VALUES (N'CALLE'),(N'NUMEXT'),(N'NUMINT'),(N'COLONIA'),
           (N'DEL_MUNICIPIO'),(N'ESTADOFISCAL'),(N'CP');

    IF @QuitarPrimaCosto=1
        INSERT @Objetivos(Nombre)
        VALUES (N'PRIMANETA'),(N'PRIMENETA'),(N'COSTO');

    DECLARE @Longitud int=LEN(@Sql),
            @SelectPos int=CHARINDEX(N'SELECT',UPPER(@Sql)),
            @InicioLista int,
            @FromPos int=0,
            @I int,
            @Profundidad int=0,
            @EnCadena bit=0,
            @EnCorchete bit=0,
            @Caracter nchar(1),
            @Siguiente nchar(1),
            @Anterior nchar(1),
            @Posterior nchar(1),
            @Mayusculas nvarchar(max)=UPPER(@Sql);

    IF @SelectPos=0
        RETURN @Sql;

    SET @InicioLista=@SelectPos+6;
    SET @I=@InicioLista;

    WHILE @I<=@Longitud
    BEGIN
        SET @Caracter=SUBSTRING(@Sql,@I,1);
        SET @Siguiente=CASE WHEN @I<@Longitud
                            THEN SUBSTRING(@Sql,@I+1,1) ELSE N'' END;

        IF @EnCadena=1
        BEGIN
            IF @Caracter=N'''' AND @Siguiente=N''''
            BEGIN
                SET @I=@I+2;
                CONTINUE;
            END;
            IF @Caracter=N'''' SET @EnCadena=0;
            SET @I=@I+1;
            CONTINUE;
        END;

        IF @EnCorchete=1
        BEGIN
            IF @Caracter=N']' AND @Siguiente=N']'
            BEGIN
                SET @I=@I+2;
                CONTINUE;
            END;
            IF @Caracter=N']' SET @EnCorchete=0;
            SET @I=@I+1;
            CONTINUE;
        END;

        IF @Caracter=N''''
        BEGIN
            SET @EnCadena=1;
            SET @I=@I+1;
            CONTINUE;
        END;
        IF @Caracter=N'['
        BEGIN
            SET @EnCorchete=1;
            SET @I=@I+1;
            CONTINUE;
        END;
        IF @Caracter=N'(' SET @Profundidad=@Profundidad+1;
        IF @Caracter=N')' AND @Profundidad>0
            SET @Profundidad=@Profundidad-1;

        IF @Profundidad=0
           AND SUBSTRING(@Mayusculas,@I,4)=N'FROM'
        BEGIN
            SET @Anterior=CASE WHEN @I>@InicioLista
                               THEN SUBSTRING(@Mayusculas,@I-1,1) ELSE N' ' END;
            SET @Posterior=CASE WHEN @I+4<=@Longitud
                               THEN SUBSTRING(@Mayusculas,@I+4,1) ELSE N' ' END;
            IF @Anterior NOT LIKE N'[A-Z0-9_]'
               AND @Posterior NOT LIKE N'[A-Z0-9_]'
            BEGIN
                SET @FromPos=@I;
                BREAK;
            END;
        END;
        SET @I=@I+1;
    END;

    IF @FromPos=0
        RETURN @Sql;

    DECLARE @Lista nvarchar(max)=SUBSTRING
            (@Sql,@InicioLista,@FromPos-@InicioLista),
            @NuevaLista nvarchar(max)=N'',
            @LongitudLista int,
            @InicioElemento int=1,
            @Elemento nvarchar(max),
            @Normalizado nvarchar(max),
            @Quitar bit,
            @NombreObjetivo nvarchar(50);

    SET @LongitudLista=LEN(@Lista);
    SET @I=1;
    SET @Profundidad=0;
    SET @EnCadena=0;
    SET @EnCorchete=0;

    WHILE @I<=@LongitudLista+1
    BEGIN
        SET @Caracter=CASE WHEN @I<=@LongitudLista
                           THEN SUBSTRING(@Lista,@I,1) ELSE N',' END;
        SET @Siguiente=CASE WHEN @I<@LongitudLista
                            THEN SUBSTRING(@Lista,@I+1,1) ELSE N'' END;

        IF @EnCadena=1
        BEGIN
            IF @Caracter=N'''' AND @Siguiente=N''''
            BEGIN
                SET @I=@I+2;
                CONTINUE;
            END;
            IF @Caracter=N'''' SET @EnCadena=0;
            SET @I=@I+1;
            CONTINUE;
        END;

        IF @EnCorchete=1
        BEGIN
            IF @Caracter=N']' AND @Siguiente=N']'
            BEGIN
                SET @I=@I+2;
                CONTINUE;
            END;
            IF @Caracter=N']' SET @EnCorchete=0;
            SET @I=@I+1;
            CONTINUE;
        END;

        IF @Caracter=N''''
        BEGIN
            SET @EnCadena=1;
            SET @I=@I+1;
            CONTINUE;
        END;
        IF @Caracter=N'['
        BEGIN
            SET @EnCorchete=1;
            SET @I=@I+1;
            CONTINUE;
        END;
        IF @Caracter=N'(' SET @Profundidad=@Profundidad+1;
        IF @Caracter=N')' AND @Profundidad>0
            SET @Profundidad=@Profundidad-1;

        IF @Caracter=N',' AND @Profundidad=0
        BEGIN
            SET @Elemento=SUBSTRING
                (@Lista,@InicioElemento,@I-@InicioElemento);
            SET @Normalizado=UPPER(LTRIM(RTRIM(@Elemento)));
            SET @Normalizado=REPLACE(@Normalizado,N'[',N'');
            SET @Normalizado=REPLACE(@Normalizado,N']',N'');
            SET @Normalizado=REPLACE(@Normalizado,N' ',N'');
            SET @Normalizado=REPLACE(@Normalizado,NCHAR(9),N'');
            SET @Normalizado=REPLACE(@Normalizado,NCHAR(10),N'');
            SET @Normalizado=REPLACE(@Normalizado,NCHAR(13),N'');
            SET @Quitar=0;

            IF EXISTS
            (
                SELECT 1
                FROM @Objetivos AS O
                WHERE @Normalizado=O.Nombre
                   OR @Normalizado=N'P.'+O.Nombre
                   OR LEFT(@Normalizado,LEN(O.Nombre)+1)=O.Nombre+N'='
                   OR RIGHT(@Normalizado,LEN(O.Nombre)+2)=N'AS'+O.Nombre
            )
                SET @Quitar=1;

            IF @Quitar=0
                SET @NuevaLista=@NuevaLista+
                    CASE WHEN LEN(@NuevaLista)>0 THEN N',' ELSE N'' END+
                    @Elemento;

            SET @InicioElemento=@I+1;
        END;
        SET @I=@I+1;
    END;

    IF LEN(LTRIM(RTRIM(@NuevaLista)))=0
        RETURN @Sql;

    RETURN SUBSTRING(@Sql,1,@InicioLista-1)+@NuevaLista+N' '+
           SUBSTRING(@Sql,@FromPos,@Longitud-@FromPos+1);
END;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.ff_SabanaGMM_v2',N'P') IS NULL
    THROW 50210,'No existe dbo.ff_SabanaGMM_v2.',1;
IF OBJECT_ID(N'dbo.ff_SabanaVIDA_v2',N'P') IS NULL
    THROW 50211,'No existe dbo.ff_SabanaVIDA_v2.',1;
IF OBJECT_ID(N'dbo.ff_SabanaOPC_v2',N'P') IS NULL
    THROW 50212,'No existe dbo.ff_SabanaOPC_v2.',1;

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @Definicion nvarchar(max),
            @NuevaDefinicion nvarchar(max),
            @Posicion int,
            @PosProcedimiento int,
            @Inyeccion nvarchar(max),
            @Prueba nvarchar(max);

    SELECT @Definicion=OBJECT_DEFINITION
           (OBJECT_ID(N'dbo.ff_SabanaGMM_v2'));

    IF CHARINDEX(N'BF3_SOLO_SQL_OCULTA_COLUMNAS_B2',@Definicion)=0
    BEGIN
        SET @Inyeccion=N'
IF @idEmpresa IN (856,1038,1806,1807)
BEGIN
    /* BF3_SOLO_SQL_OCULTA_COLUMNAS_B2 */
    SET @Kueri=dbo.bf_SabanaQuitarColumnasB2
        (@Kueri+@KueriII,0);
    SET @Kueri=REPLACE(@Kueri,
        N''isnull(emCalleFiscal,''+CHAR(39)+CHAR(39)+N'') as Calle,'',N'''');
    SET @Kueri=REPLACE(@Kueri,
        N''isnull(EMColoniaFisico,''+CHAR(39)+CHAR(39)+N'') as NumExt,'',N'''');
    SET @Kueri=REPLACE(@Kueri,
        N''isnull(EMCalleFisico,''+CHAR(39)+CHAR(39)+N'') as NumInt,'',N'''');
    SET @Kueri=REPLACE(@Kueri,
        N''isnull(emColoniaFiscal,''+CHAR(39)+CHAR(39)+N'') as Colonia,'',N'''');
    SET @Kueri=REPLACE(@Kueri,
        N''isnull(EMMunicipioDelegacionFiscal,''+CHAR(39)+CHAR(39)+
        N'') as Del_Municipio,'',N'''');
    SET @Kueri=REPLACE(@Kueri,
        N''EstadoFiscal = (Select esDescripcion from ff_Estado where ''+
        N''esidEstado = emEstadofiscal),'',N'''');
    SET @Kueri=REPLACE(@Kueri,
        N''isnull(''+CHAR(39)+CHAR(39)+N''+emcodigoPostalFiscal,''+
        CHAR(39)+CHAR(39)+N'') as CP,'',N'''');
    SET @KueriII=N'''';
END;
execute(@Kueri + @KueriII)';

        SET @NuevaDefinicion=REPLACE
            (@Definicion,N'execute(@Kueri + @KueriII)',@Inyeccion);

        IF @NuevaDefinicion=@Definicion
            THROW 50213,'No se encontro el punto de ejecucion de GMM.',1;

        SET @Posicion=CHARINDEX(N'CREATE',UPPER(@NuevaDefinicion));
        SET @PosProcedimiento=CHARINDEX
            (N'PROCEDURE',UPPER(@NuevaDefinicion),@Posicion);
        IF @Posicion=0 OR @PosProcedimiento=0
            THROW 50214,'No se pudo convertir GMM a ALTER PROCEDURE.',1;
        SET @NuevaDefinicion=STUFF
            (@NuevaDefinicion,@Posicion,6,N'ALTER');
        EXEC sys.sp_executesql @NuevaDefinicion;
    END;

    SELECT @Definicion=OBJECT_DEFINITION
           (OBJECT_ID(N'dbo.ff_SabanaVIDA_v2'));

    IF CHARINDEX(N'BF3_SOLO_SQL_OCULTA_COLUMNAS_B2',@Definicion)=0
    BEGIN
        SET @Inyeccion=N'
IF @idEmpresa IN (856,1038,1806,1807)
BEGIN
    /* BF3_SOLO_SQL_OCULTA_COLUMNAS_B2 */
    SET @KueriI=dbo.bf_SabanaQuitarColumnasB2
        (@KueriI+ISNULL(@KueriII,N'''')+ISNULL(@KueriIII,N''''),1);
    SET @KueriII=N'''';
    SET @KueriIII=N'''';
END;
execute (@KueriI + @KueriII + @KueriIII)';

        SET @NuevaDefinicion=REPLACE
            (@Definicion,
             N'execute (@KueriI + @KueriII + @KueriIII)',@Inyeccion);

        IF @NuevaDefinicion=@Definicion
            THROW 50215,'No se encontro el punto de ejecucion de VIDA.',1;

        SET @Posicion=CHARINDEX(N'CREATE',UPPER(@NuevaDefinicion));
        SET @PosProcedimiento=CHARINDEX
            (N'PROCEDURE',UPPER(@NuevaDefinicion),@Posicion);
        IF @Posicion=0 OR @PosProcedimiento=0
            THROW 50216,'No se pudo convertir VIDA a ALTER PROCEDURE.',1;
        SET @NuevaDefinicion=STUFF
            (@NuevaDefinicion,@Posicion,6,N'ALTER');
        EXEC sys.sp_executesql @NuevaDefinicion;
    END;

    SELECT @Definicion=OBJECT_DEFINITION
           (OBJECT_ID(N'dbo.ff_SabanaOPC_v2'));

    IF CHARINDEX(N'BF3_SOLO_SQL_OCULTA_COLUMNAS_B2',@Definicion)=0
    BEGIN
        SET @Inyeccion=N'
IF @idEmpresa IN (116,117,166,856,1038)
BEGIN
    /* BF3_SOLO_SQL_OCULTA_COLUMNAS_B2 */
    SET @KueriI=dbo.bf_SabanaQuitarColumnasB2
        (@KueriI+ISNULL(@KueriII,N'''')+ISNULL(@KueriIII,N''''),0);
    SET @KueriI=REPLACE(@KueriI,N'', Calle'',N'''');
    SET @KueriI=REPLACE(@KueriI,N'', NumExt'',N'''');
    SET @KueriI=REPLACE(@KueriI,N'', NumInt'',N'''');
    SET @KueriI=REPLACE(@KueriI,N'', Colonia'',N'''');
    SET @KueriI=REPLACE(@KueriI,N'', Del_Municipio'',N'''');
    SET @KueriI=REPLACE(@KueriI,N'', EstadoFiscal'',N'''');
    SET @KueriI=REPLACE(@KueriI,N'', CP'',N'''');
    SET @KueriII=N'''';
    SET @KueriIII=N'''';
END;
execute (@KueriI + @KueriII + @KueriIII)';

        SET @NuevaDefinicion=REPLACE
            (@Definicion,
             N'execute (@KueriI + @KueriII + @KueriIII)',@Inyeccion);

        IF @NuevaDefinicion=@Definicion
            THROW 50217,'No se encontro el punto de ejecucion de OPC.',1;

        SET @Posicion=CHARINDEX(N'CREATE',UPPER(@NuevaDefinicion));
        SET @PosProcedimiento=CHARINDEX
            (N'PROCEDURE',UPPER(@NuevaDefinicion),@Posicion);
        IF @Posicion=0 OR @PosProcedimiento=0
            THROW 50218,'No se pudo convertir OPC a ALTER PROCEDURE.',1;
        SET @NuevaDefinicion=STUFF
            (@NuevaDefinicion,@Posicion,6,N'ALTER');
        EXEC sys.sp_executesql @NuevaDefinicion;
    END;

    SET @Prueba=dbo.bf_SabanaQuitarColumnasB2
    (
        N'SELECT DISTINCT X,
          ISNULL(A,N'''') AS Calle,
          ISNULL(B,N'''') AS NumExt,
          ISNULL(C,N'''') AS NumInt,
          ISNULL(D,N'''') AS Colonia,
          Del_Municipio=(SELECT TOP 1 M FROM T2 WHERE T2.Id=T.Id),
          EstadoFiscal=(SELECT TOP 1 E FROM T2 WHERE T2.Id=T.Id),
          CP,P.PrimaNeta,P.Costo AS Costo,Costo_1,Cobertura
          FROM T',1
    );

    IF UPPER(@Prueba) LIKE N'%AS CALLE%'
       OR UPPER(@Prueba) LIKE N'%AS NUMEXT%'
       OR UPPER(@Prueba) LIKE N'%AS NUMINT%'
       OR UPPER(@Prueba) LIKE N'%AS COLONIA%'
       OR UPPER(@Prueba) LIKE N'%DEL_MUNICIPIO=%'
       OR UPPER(@Prueba) LIKE N'%ESTADOFISCAL=%'
       OR UPPER(@Prueba) LIKE N'%,CP,%'
       OR UPPER(@Prueba) LIKE N'%P.PRIMANETA%'
       OR UPPER(@Prueba) LIKE N'% AS COSTO%'
       OR UPPER(@Prueba) NOT LIKE N'%COSTO_1%'
       OR UPPER(@Prueba) NOT LIKE N'%COBERTURA%'
        THROW 50219,'Fallo la validacion del filtro de columnas.',1;

    IF CHARINDEX(N'BF3_SOLO_SQL_OCULTA_COLUMNAS_B2',
                 OBJECT_DEFINITION(OBJECT_ID(N'dbo.ff_SabanaGMM_v2')))=0
       OR CHARINDEX(N'BF3_SOLO_SQL_OCULTA_COLUMNAS_B2',
                    OBJECT_DEFINITION(OBJECT_ID(N'dbo.ff_SabanaVIDA_v2')))=0
       OR CHARINDEX(N'BF3_SOLO_SQL_OCULTA_COLUMNAS_B2',
                    OBJECT_DEFINITION(OBJECT_ID(N'dbo.ff_SabanaOPC_v2')))=0
        THROW 50220,'No quedaron actualizados todos los procedimientos.',1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT O.name AS Procedimiento,
       CASE WHEN CHARINDEX(N'BF3_SOLO_SQL_OCULTA_COLUMNAS_B2',M.definition)>0
            THEN N'ACTUALIZADO' ELSE N'PENDIENTE' END AS Estado
FROM sys.objects AS O
INNER JOIN sys.sql_modules AS M ON M.object_id=O.object_id
WHERE O.name IN
      (N'ff_SabanaGMM_v2',N'ff_SabanaVIDA_v2',N'ff_SabanaOPC_v2')
ORDER BY O.name;
GO
