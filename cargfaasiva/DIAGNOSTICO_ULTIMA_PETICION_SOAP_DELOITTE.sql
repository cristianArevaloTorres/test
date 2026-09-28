/*
  DIAGNOSTICO DE LA ULTIMA PETICION SOAP DE DELOITTE

  SOLO LECTURA:
    - Nunca devuelve usuario ni contrasena.
    - Por defecto oculta la cadena completa.
    - Para comparar el payload exacto, cambiar @MostrarCadenaCompleta a 1.

  LIMITACION DEL CODIGO ACTUAL:
    El resultado de parser 2 no se inserta como un segundo registro de error.
    bf_RegistroCargaRapida conserva la recepcion original (CMResultado = 0) y
    los errores capturados al ejecutar el SP (CMResultado = 3), pero no guarda
    la columna exacta que fallo cuando FastParse devuelve ParsingError.
*/

SET NOCOUNT ON;
SET LOCK_TIMEOUT 15000;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @MostrarCadenaCompleta BIT;
DECLARE @IdOperacion INT;
DECLARE @IdEmpresa INT;
DECLARE @PlantillaBF2 INT;
DECLARE @PlantillaBF3 INT;

SET @MostrarCadenaCompleta = 0;
SET @IdOperacion = 2;
SET @IdEmpresa = 186;
SET @PlantillaBF2 = 507;
SET @PlantillaBF3 = 12062;

/* 00. Contexto del ambiente realmente consultado. */
SELECT
    '00_CONTEXTO' AS bloque,
    CONVERT(NVARCHAR(128), SERVERPROPERTY('ServerName')) AS servidor,
    DB_NAME() AS baseDatos,
    GETDATE() AS fechaConsulta;

/*
  01. Ultimas recepciones Deloitte.
  Se extrae solamente lo posterior a :Cadena:, descartando credenciales.
*/
;WITH Ultimas AS
(
    SELECT TOP (20)
        R.CMId,
        R.CMFecha,
        R.CMResultado,
        R.CMCadena,
        PosUsuario = CHARINDEX(':Usuario:', R.CMCadena),
        PosCadena = CHARINDEX(':Cadena:', R.CMCadena)
    FROM dbo.bf_RegistroCargaRapida R
    WHERE R.CMCadena LIKE 'Empresa:%'
      AND
      (
          R.CMCadena LIKE 'Empresa:S001:Usuario:%'
          OR R.CMCadena LIKE 'Empresa:186:Usuario:%'
      )
      AND CHARINDEX(':Cadena:', R.CMCadena) > 0
    ORDER BY R.CMId DESC
),
Recepciones AS
(
    SELECT
        U.CMId,
        U.CMFecha,
        U.CMResultado,
        EmpresaRecibida = SUBSTRING
        (
            U.CMCadena,
            LEN('Empresa:') + 1,
            U.PosUsuario - (LEN('Empresa:') + 1)
        ),
        Cadena = SUBSTRING
        (
            U.CMCadena,
            U.PosCadena + LEN(':Cadena:'),
            LEN(U.CMCadena) - (U.PosCadena + LEN(':Cadena:')) + 1
        )
    FROM Ultimas U
    WHERE U.PosUsuario > LEN('Empresa:')
),
Partes AS
(
    SELECT
        R.*,
        PrimerSeparador = CHARINDEX('|', R.Cadena),
        SegundoSeparador = CASE
            WHEN CHARINDEX('|', R.Cadena) > 0
            THEN CHARINDEX('|', R.Cadena, CHARINDEX('|', R.Cadena) + 1)
            ELSE 0
        END,
        TercerSeparador = CASE
            WHEN CHARINDEX('|', R.Cadena, CHARINDEX('|', R.Cadena) + 1) > 0
            THEN CHARINDEX
            (
                '|',
                R.Cadena,
                CHARINDEX('|', R.Cadena, CHARINDEX('|', R.Cadena) + 1) + 1
            )
            ELSE 0
        END
    FROM Recepciones R
)
SELECT
    '01_CADENAS_RECIBIDAS' AS bloque,
    P.CMId,
    P.CMFecha,
    P.CMResultado,
    P.EmpresaRecibida,
    LEN(P.Cadena) AS longitudCadena,
    LEN(P.Cadena) - LEN(REPLACE(P.Cadena, '|', '')) + 1 AS posiciones,
    CASE
        WHEN P.PrimerSeparador > 0
        THEN SUBSTRING(P.Cadena, 1, P.PrimerSeparador - 1)
        ELSE NULL
    END AS posicion1EmpresaInterna,
    CASE
        WHEN P.SegundoSeparador > P.PrimerSeparador
        THEN SUBSTRING
        (
            P.Cadena,
            P.PrimerSeparador + 1,
            P.SegundoSeparador - P.PrimerSeparador - 1
        )
        ELSE NULL
    END AS posicion2Perfil,
    CASE
        WHEN P.TercerSeparador > P.SegundoSeparador
        THEN SUBSTRING
        (
            P.Cadena,
            P.SegundoSeparador + 1,
            P.TercerSeparador - P.SegundoSeparador - 1
        )
        ELSE NULL
    END AS posicion3Sexo,
    CASE WHEN LEFT(P.Cadena, 1) IN ('"', '''') THEN 1 ELSE 0 END AS iniciaConComilla,
    CASE WHEN RIGHT(P.Cadena, 1) IN ('"', '''') THEN 1 ELSE 0 END AS terminaConComilla,
    CASE WHEN P.Cadena <> LTRIM(RTRIM(P.Cadena)) THEN 1 ELSE 0 END AS tieneEspaciosEnExtremos,
    CASE WHEN CHARINDEX(CHAR(13), P.Cadena) > 0 THEN 1 ELSE 0 END AS contieneRetornoCarro,
    CASE WHEN CHARINDEX(CHAR(10), P.Cadena) > 0 THEN 1 ELSE 0 END AS contieneSaltoLinea,
    ASCII(LEFT(P.Cadena, 1)) AS codigoPrimerCaracter,
    ASCII(RIGHT(P.Cadena, 1)) AS codigoUltimoCaracter,
    CASE
        WHEN @MostrarCadenaCompleta = 1 THEN P.Cadena
        ELSE '[OCULTA; CAMBIAR @MostrarCadenaCompleta A 1 PARA COMPARAR]'
    END AS cadenaRecibidaSinCredenciales
FROM Partes P
ORDER BY P.CMId DESC;

/* 02. Configuraciones que el servicio obtiene actualmente. */
SELECT
    '02_CONFIGURACIONES_DELOITTE' AS bloque,
    CE.CEIdOperacionEmpresa,
    CE.CEIdEmpresa,
    CE.CEIdOperacion,
    CE.CEIdPlantilla,
    LTRIM(RTRIM(CE.CEStoredProc)) AS storedProcedure,
    CE.CEStoredProcAtributos,
    CE.CEIdEstatus,
    CE.CEFechaAdd,
    CE.CEFechaUMod
FROM dbo.ff_CargaMasivaOperacionEmpresa CE
WHERE CE.CEIdEmpresa = @IdEmpresa
  AND CE.CEIdOperacion = @IdOperacion
ORDER BY CE.CEIdEstatus DESC, CE.CEIdOperacionEmpresa;

/* 03. Resultado exacto del resolver consumido por CargaMasivaProcess. */
EXEC dbo.ff_CCMOperacionPropiedades
    @IdOperacion = @IdOperacion,
    @IdEmpresa = @IdEmpresa;

/* 04. Cantidad real de campos de ambas plantillas. */
SELECT
    '04_CANTIDAD_CAMPOS' AS bloque,
    V.PLIdPlantilla,
    COUNT(CP.CPIdConfiguracionPlantilla) AS camposActivos
FROM
(
    SELECT @PlantillaBF2 AS PLIdPlantilla
    UNION ALL
    SELECT @PlantillaBF3
) V
LEFT JOIN dbo.ff_ConfiguracionPlantilla CP
    ON CP.PLIdPlantilla = V.PLIdPlantilla
   AND CP.CPIdEstatus = 1
LEFT JOIN dbo.ff_Campo C
    ON C.CAIdCampo = CP.CAIdCampo
   AND C.CAIdEstatus = 1
WHERE CP.CPIdConfiguracionPlantilla IS NULL
   OR C.CAIdCampo IS NOT NULL
GROUP BY V.PLIdPlantilla
ORDER BY V.PLIdPlantilla;

/*
  05. Registros posteriores cercanos a la ultima recepcion.
  No muestra CMCadena para evitar revelar credenciales o datos personales.
  Un ParsingError=2 normalmente NO genera una segunda fila.
*/
;WITH UltimaPeticion AS
(
    SELECT TOP (1)
        R.CMId,
        R.CMFecha
    FROM dbo.bf_RegistroCargaRapida R
    WHERE
    (
        R.CMCadena LIKE 'Empresa:S001:Usuario:%'
        OR R.CMCadena LIKE 'Empresa:186:Usuario:%'
    )
      AND CHARINDEX(':Cadena:', R.CMCadena) > 0
    ORDER BY R.CMId DESC
)
SELECT TOP (30)
    '05_EVENTOS_CERCANOS' AS bloque,
    R.CMId,
    R.CMFecha,
    R.CMResultado,
    CASE
        WHEN R.CMCadena LIKE 'Empresa:%' THEN 'RECEPCION_SOAP'
        WHEN R.CMResultado = 3 THEN 'ERROR_DB_CAPTURADO'
        ELSE 'OTRO_REGISTRO'
    END AS tipoRegistro,
    LEN(R.CMCadena) AS longitudRegistro
FROM dbo.bf_RegistroCargaRapida R
CROSS JOIN UltimaPeticion U
WHERE R.CMId >= U.CMId
  AND R.CMFecha <= DATEADD(MINUTE, 1, U.CMFecha)
ORDER BY R.CMId;

/*
  06. Detalle de errores de base de datos capturados despues de la peticion.
  Estas filas contienen ex.Message; no contienen la recepcion con credenciales.
*/
;WITH UltimaPeticion AS
(
    SELECT TOP (1)
        R.CMId,
        R.CMFecha
    FROM dbo.bf_RegistroCargaRapida R
    WHERE
    (
        R.CMCadena LIKE 'Empresa:S001:Usuario:%'
        OR R.CMCadena LIKE 'Empresa:186:Usuario:%'
    )
      AND CHARINDEX(':Cadena:', R.CMCadena) > 0
    ORDER BY R.CMId DESC
)
SELECT TOP (20)
    '06_ERRORES_DB_CERCANOS' AS bloque,
    R.CMId,
    R.CMFecha,
    R.CMResultado,
    LEFT
    (
        REPLACE(REPLACE(R.CMCadena, CHAR(13), ' '), CHAR(10), ' '),
        2000
    ) AS detalleError
FROM dbo.bf_RegistroCargaRapida R
CROSS JOIN UltimaPeticion U
WHERE R.CMId > U.CMId
  AND R.CMResultado = 3
  AND R.CMFecha <= DATEADD(MINUTE, 1, U.CMFecha)
ORDER BY R.CMId;

/* 07. Dictamen automatico de los requisitos que necesita el selector nuevo. */
;WITH Configuracion AS
(
    SELECT
        configuracionesBF2 = SUM
        (
            CASE
                WHEN CE.CEIdPlantilla = @PlantillaBF2
                 AND LTRIM(RTRIM(CE.CEStoredProc)) IN
                     ('ff_XCMTitularesAltaCMDeloitte', 'dbo.ff_XCMTitularesAltaCMDeloitte')
                THEN 1 ELSE 0
            END
        ),
        configuracionesBF3 = SUM
        (
            CASE
                WHEN CE.CEIdPlantilla = @PlantillaBF3
                 AND LTRIM(RTRIM(CE.CEStoredProc)) IN
                     ('ff_XCMTitularesAltaCMM_BF3', 'dbo.ff_XCMTitularesAltaCMM_BF3')
                THEN 1 ELSE 0
            END
        )
    FROM dbo.ff_CargaMasivaOperacionEmpresa CE
    WHERE CE.CEIdEmpresa = @IdEmpresa
      AND CE.CEIdOperacion = @IdOperacion
      AND CE.CEIdEstatus = 1
),
Campos AS
(
    SELECT
        camposBF2 = SUM(CASE WHEN CP.PLIdPlantilla = @PlantillaBF2 THEN 1 ELSE 0 END),
        camposBF3 = SUM(CASE WHEN CP.PLIdPlantilla = @PlantillaBF3 THEN 1 ELSE 0 END)
    FROM dbo.ff_ConfiguracionPlantilla CP
    INNER JOIN dbo.ff_Campo C
        ON C.CAIdCampo = CP.CAIdCampo
       AND C.CAIdEstatus = 1
    WHERE CP.PLIdPlantilla IN (@PlantillaBF2, @PlantillaBF3)
      AND CP.CPIdEstatus = 1
)
SELECT
    '07_DICTAMEN_CONFIGURACION' AS bloque,
    ISNULL(X.configuracionesBF2, 0) AS configuracionesBF2,
    ISNULL(X.configuracionesBF3, 0) AS configuracionesBF3,
    ISNULL(C.camposBF2, 0) AS camposBF2,
    ISNULL(C.camposBF3, 0) AS camposBF3,
    CASE
        WHEN ISNULL(X.configuracionesBF2, 0) = 1
         AND ISNULL(X.configuracionesBF3, 0) = 1
         AND ISNULL(C.camposBF2, 0) = 32
         AND ISNULL(C.camposBF3, 0) = 23
        THEN 'LISTO_PARA_BF2_Y_BF3'
        ELSE 'INCOMPLETO_NO_PROBAR_SOAP_TODAVIA'
    END AS dictamen
FROM Configuracion X
CROSS JOIN Campos C;

/* 08. Explicacion de lo que puede concluirse de la bitacora. */
SELECT
    '08_NOTA_PARSER' AS bloque,
    'Si la peticion aparece con 23 posiciones y no existe un evento posterior con resultado 3, la bitacora no conserva el detalle del ParsingError=2. En ese caso debe verificarse la DLL publicada o utilizar temporalmente el metodo que devuelve Mensaje.Detalle.' AS observacion;
