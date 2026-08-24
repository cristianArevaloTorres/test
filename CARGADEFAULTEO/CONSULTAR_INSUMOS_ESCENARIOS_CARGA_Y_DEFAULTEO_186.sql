/*
  CONSULTA DE INSUMOS PARA PRUEBAS - EMPRESA 186

  SOLO LECTURA: este archivo no contiene INSERT, UPDATE, DELETE ni ejecuta
  el motor de carga/defaulteo.

  QUE CAMBIAR:
    @IdEmpresa             Empresa que se desea revisar. Para esta prueba: 186.
    @IdOperacionCarga      Primera ejecucion: dejar NULL. Copiar despues el
                            COIdOperacion del primer resultado y volver a ejecutar.
    @IdEmpleadoBaseCarga   Id devuelto en las muestras. Si se captura, genera
                            tambien un TXT usando sus valores como referencia.
    @IdEmpresaOrigenCarga  Se utiliza para el campo comun EMIdEmpresaOrigen.
    @IdAdministradorCarga  Se utiliza para EMUsuarioAdd/EMUsuarioUMod.
    @NumeroEmpleadoBase    NULL devuelve candidatos; capturar un numero para
                            revisar solamente ese empleado.
    @IdVigenciaDestino     NULL la resuelve por fecha/configuracion. Se puede
                            capturar un ID cuando se necesite probar otra vigencia.
    @IdVigenciaOrigen      NULL usa VIRenovada de la vigencia destino.
    @TopeCarga             Filas de referencia para cada escenario de carga.
    @TopeDefaulteo         Candidatos mostrados para cada tipo de defaulteo.
    @TopeEvaluar           Universo maximo evaluado; no exceder 3000.

  IMPORTANTE:
    - Para Carga Masiva, el input cambia por operacion. La plantilla y el SP se
      leen de ff_CargaMasivaOperacionEmpresa, igual que los flujos B2/B3.
    - Para Defaulteo no se fabrica un input. Se localizan empleados que ya
      cumplen las condiciones de los tipos 1, 2 y 3.
    - Un empleado puede ser candidato simultaneamente para tipo 1 y tipo 3.
      La diferencia funcional esta en el token que se envia al motor: def1/def3.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET LOCK_TIMEOUT 15000;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

/* ===================== PARAMETROS EDITABLES ===================== */
DECLARE @IdEmpresa             INT         = 186;
DECLARE @IdOperacionCarga      INT         = NULL; -- Ejemplo: 2. Primero dejar NULL.
DECLARE @IdEmpleadoBaseCarga   INT         = NULL; -- Copiar el Id de una muestra.
DECLARE @IdEmpresaOrigenCarga  INT         = NULL; -- Obligatorio para transferencia.
DECLARE @IdAdministradorCarga  INT         = NULL; -- Usuario que ejecutara la prueba.
DECLARE @NumeroEmpleadoBase    VARCHAR(50) = NULL; -- Ejemplo: 'QADEF1-186'.
DECLARE @IdVigenciaDestino     INT         = NULL; -- NULL = resolver automaticamente.
DECLARE @IdVigenciaOrigen      INT         = NULL; -- NULL = usar VIRenovada del destino.
DECLARE @TopeCarga             INT         = 5;
DECLARE @TopeDefaulteo         INT         = 20;
DECLARE @TopeEvaluar           INT         = 3000;
/* =============================================================== */

IF @TopeCarga NOT BETWEEN 1 AND 100
    THROW 52000, '@TopeCarga debe estar entre 1 y 100.', 1;
IF @TopeDefaulteo NOT BETWEEN 1 AND 100
    THROW 52001, '@TopeDefaulteo debe estar entre 1 y 100.', 1;
IF @TopeEvaluar NOT BETWEEN 1 AND 3000
    THROW 52002, '@TopeEvaluar debe estar entre 1 y 3000.', 1;

DECLARE @IdConfiguracion INT;
DECLARE @IdCorporativo INT;

SELECT
    @IdConfiguracion = E.EMIdConfiguracion,
    @IdCorporativo = E.EMIdCorporativo
FROM dbo.ff_Empresa E
WHERE E.EMIdEmpresa = @IdEmpresa;

IF @IdConfiguracion IS NULL
    THROW 52003, 'La empresa indicada no existe o no tiene configuracion.', 1;

IF @IdVigenciaDestino IS NULL
BEGIN
    SELECT TOP (1) @IdVigenciaDestino = V.VIIdVigencia
    FROM dbo.ff_Vigencia V
    WHERE V.VIIdConfiguracion = @IdConfiguracion
      AND V.VIIdEstatus = 1
      AND CONVERT(DATE, GETDATE()) BETWEEN CONVERT(DATE, V.VIVigenciaIni)
                                      AND CONVERT(DATE, V.VIVigenciaFin)
    ORDER BY V.VIVigenciaIni DESC, V.VIIdVigencia DESC;

    IF @IdVigenciaDestino IS NULL
        SELECT TOP (1) @IdVigenciaDestino = V.VIIdVigencia
        FROM dbo.ff_Vigencia V
        WHERE V.VIIdConfiguracion = @IdConfiguracion
          AND V.VIIdEstatus = 1
        ORDER BY V.VIVigenciaIni DESC, V.VIIdVigencia DESC;
END;

IF @IdVigenciaOrigen IS NULL
    SELECT @IdVigenciaOrigen = V.VIRenovada
    FROM dbo.ff_Vigencia V
    WHERE V.VIIdVigencia = @IdVigenciaDestino
      AND V.VIIdConfiguracion = @IdConfiguracion;

SELECT
    'PARAMETROS_RESUELTOS' AS bloque,
    E.EMIdEmpresa AS idEmpresa,
    E.EMNombre AS empresa,
    @IdCorporativo AS idCorporativo,
    @IdConfiguracion AS idConfiguracion,
    @IdVigenciaOrigen AS idVigenciaOrigen,
    VO.VINombre AS vigenciaOrigen,
    @IdVigenciaDestino AS idVigenciaDestino,
    VD.VINombre AS vigenciaDestino
FROM dbo.ff_Empresa E
LEFT JOIN dbo.ff_Vigencia VO ON VO.VIIdVigencia = @IdVigenciaOrigen
LEFT JOIN dbo.ff_Vigencia VD ON VD.VIIdVigencia = @IdVigenciaDestino
WHERE E.EMIdEmpresa = @IdEmpresa;

/* =================================================================
   CARGA MASIVA - PASO 1
   La primera vez deje @IdOperacionCarga = NULL. Este resultado muestra los
   IDs que puede copiar al parametro para consultar una operacion concreta.
   ================================================================= */
SELECT
    'OPERACIONES_CARGA' AS bloque,
    O.COIdOperacion,
    O.CONombre AS operacion,
    O.CODescripcion,
    CE.CEIdOperacionEmpresa,
    CE.CEIdPlantilla,
    P.PLDescripcion AS plantilla,
    LTRIM(RTRIM(CE.CEStoredProc)) AS storedProcedure,
    CE.CEStoredProcAtributos,
    CE.CEIdEstatus AS estatus,
    CASE WHEN OBJECT_ID(LTRIM(RTRIM(CE.CEStoredProc)), 'P') IS NULL
         THEN 'REVISAR: EL SP NO EXISTE' ELSE 'OK' END AS validacionSP,
    CASE O.COIdOperacion
      WHEN 1 THEN 'Dar de alta un dependiente ligado a un titular existente.'
      WHEN 2 THEN 'Dar de alta un titular que todavia no exista en la empresa.'
      WHEN 5 THEN 'Registrar el importe conciliado de un periodo/CIS para un empleado.'
      WHEN 13 THEN 'Cambiar el numero de un empleado ya existente.'
      WHEN 14 THEN 'Reactivar un titular actualmente inactivo.'
      WHEN 15 THEN 'Transferir un empleado desde una empresa origen a una empresa destino.'
      WHEN 16 THEN 'Dar de alta, actualizar o dar de baja una compensacion de un empleado.'
      ELSE 'Ejecutar la operacion configurada para la empresa.'
    END AS seUsaPara,
    CASE O.COIdOperacion
      WHEN 1 THEN 'Titular activo; el numero identifica al titular al que se agregara el dependiente.'
      WHEN 2 THEN 'Empleado activo solamente como referencia de formatos/catalogos; no copiar identificadores unicos.'
      WHEN 5 THEN 'Empleado existente al que corresponden el periodo, CIS e importe.'
      WHEN 13 THEN 'Titular activo con el numero actual que se desea sustituir.'
      WHEN 14 THEN 'Titular inactivo conservando su numero de empleado.'
      WHEN 15 THEN 'Titular activo de la empresa origen.'
      WHEN 16 THEN 'Titular activo que recibira el movimiento de compensacion.'
      ELSE 'Revisar la plantilla de la operacion.'
    END AS registroQueDebeUsarse,
    CASE O.COIdOperacion
      WHEN 1 THEN 'Sexo, numero del titular, nombres, nacimiento, parentesco, fecha alta y certificado del dependiente.'
      WHEN 2 THEN 'Numero nuevo, nombre, apellido, nacimiento y centro de costos; los demas segun plantilla.'
      WHEN 5 THEN 'Numero de empleado, periodo, CIS, importe y usuario.'
      WHEN 13 THEN 'Empresa 186, numero actual y numero nuevo no utilizado.'
      WHEN 14 THEN 'Empresa 186, numero del inactivo y fecha de reingreso.'
      WHEN 15 THEN 'Empresa destino, empresa origen, empleado, perfil, fecha y opcion de solicitud.'
      WHEN 16 THEN 'Empresa, empleado, compensacion, monto y tipo 1=alta/actualizacion o 2=baja.'
      ELSE 'Los campos marcados como requeridos por la plantilla.'
    END AS datosQueDebeCapturar
FROM dbo.ff_CargaMasivaOperacionEmpresa CE
INNER JOIN dbo.ff_CargaMasivaOperacion O
    ON O.COIdOperacion = CE.CEIdOperacion
LEFT JOIN dbo.ff_Plantilla P
    ON P.PLIdPlantilla = CE.CEIdPlantilla
WHERE CE.CEIdEmpresa = @IdEmpresa
  AND CE.CEIdEstatus = 1
ORDER BY O.COIdOperacion, CE.CEIdOperacionEmpresa;

/* =================================================================
   CARGA MASIVA - PASO 2
   Cuando @IdOperacionCarga tenga valor, devuelve la estructura exacta que
   utiliza B2/BF3 para construir el TXT y ejecutar el SP configurado.
   ================================================================= */
DECLARE @IdPlantillaCarga INT;
DECLARE @StoredProcedureCarga VARCHAR(300);
DECLARE @NombreOperacionCarga VARCHAR(500);

IF @IdOperacionCarga IS NOT NULL
BEGIN
    IF (SELECT COUNT(*)
        FROM dbo.ff_CargaMasivaOperacionEmpresa CE
        WHERE CE.CEIdEmpresa = @IdEmpresa
          AND CE.CEIdOperacion = @IdOperacionCarga
          AND CE.CEIdEstatus = 1) <> 1
    BEGIN
        SELECT
            'OPERACION_SELECCIONADA' AS bloque,
            'REVISAR' AS resultado,
            'La operacion debe tener exactamente una configuracion activa para la empresa.' AS detalle;
    END
    ELSE
    BEGIN
        SELECT
            @IdPlantillaCarga = CE.CEIdPlantilla,
            @StoredProcedureCarga = LTRIM(RTRIM(CE.CEStoredProc)),
            @NombreOperacionCarga = O.CONombre
        FROM dbo.ff_CargaMasivaOperacionEmpresa CE
        INNER JOIN dbo.ff_CargaMasivaOperacion O
            ON O.COIdOperacion = CE.CEIdOperacion
        WHERE CE.CEIdEmpresa = @IdEmpresa
          AND CE.CEIdOperacion = @IdOperacionCarga
          AND CE.CEIdEstatus = 1;

        SELECT
            'OPERACION_SELECCIONADA' AS bloque,
            @IdOperacionCarga AS idOperacion,
            @NombreOperacionCarga AS operacion,
            @IdPlantillaCarga AS idPlantilla,
            @StoredProcedureCarga AS storedProcedure,
            CASE WHEN OBJECT_ID(@StoredProcedureCarga, 'P') IS NULL
                 THEN 'REVISAR: EL SP NO EXISTE' ELSE 'OK' END AS resultado;

        IF OBJECT_ID('dbo.ff_CCMOperacionPropiedades', 'P') IS NOT NULL
            EXEC dbo.ff_CCMOperacionPropiedades
                @IdOperacion = @IdOperacionCarga,
                @IdEmpresa = @IdEmpresa;
        ELSE
            SELECT 'FALTA dbo.ff_CCMOperacionPropiedades' AS advertencia;

        IF OBJECT_ID('dbo.ff_CPlantillaCampos', 'P') IS NOT NULL
            EXEC dbo.ff_CPlantillaCampos @IdPlantilla = @IdPlantillaCarga;
        ELSE
            SELECT 'FALTA dbo.ff_CPlantillaCampos' AS advertencia;

        SELECT
            'GUIA_INPUT_OPERACION' AS bloque,
            CP.CPOrden AS orden,
            LTRIM(RTRIM(C.CANombreCampo)) AS campo,
            LTRIM(RTRIM(CP.CPEtiqueta)) AS etiqueta,
            C.CATipoDato AS tipoDato,
            C.CALongitud AS longitud,
            CP.CPRequerido AS requerido,
            CP.CPRangoValores AS rangoOCatalogo,
            CASE WHEN UPPER(LTRIM(RTRIM(C.CANombreCampo))) IN
                           ('EMIDEMPRESA', 'EMIDEMPRESAORIGEN',
                            'EMUSUARIOADD', 'EMUSUARIOUMOD')
                 THEN 'COMUN SUGERIDO: si aplica igual a toda la carga'
                 ELSE 'POR REGISTRO SUGERIDO; puede moverse a comun si el valor no cambia' END AS grupoTxtSugerido,
            'B2 permite que cualquier campo valido de la plantilla este en @commonFields si su valor es igual para todos los renglones.' AS reglaCampoComunB2,
            CASE
              WHEN UPPER(LTRIM(RTRIM(C.CANombreCampo)))
                   IN ('EMIDEMPRESA', 'EMIDEMPRESAORIGEN')
                THEN CONVERT(VARCHAR(30), @IdEmpresa)
              WHEN UPPER(LTRIM(RTRIM(C.CANombreCampo)))
                   IN ('EMUSUARIOADD', 'EMUSUARIOUMOD')
                THEN '<CAMBIAR POR ID DEL ADMINISTRADOR QUE PRUEBA>'
              WHEN EXISTS
              (
                  SELECT 1 FROM sys.columns SC
                  WHERE SC.object_id = OBJECT_ID('dbo.ff_Empleado')
                    AND UPPER(SC.name) = UPPER(LTRIM(RTRIM(C.CANombreCampo)))
              ) THEN 'Copiar el valor de la columna homonima del empleado base.'
              WHEN NULLIF(LTRIM(RTRIM(CP.CPRangoValores)), '') IS NOT NULL
                THEN 'Elegir un valor permitido por rango/catalogo.'
              ELSE 'Capturar de acuerdo con la operacion.'
            END AS deDondeTomarElValor
        FROM dbo.ff_ConfiguracionPlantilla CP
        INNER JOIN dbo.ff_Campo C
            ON C.CAIdCampo = CP.CAIdCampo
           AND C.CAIdEstatus = 1
        WHERE CP.PLIdPlantilla = @IdPlantillaCarga
          AND CP.CPIdEstatus = 1
        ORDER BY CP.CPOrden, CP.CPIdConfiguracionPlantilla;

        SELECT
            'PARAMETROS_SP' AS bloque,
            SP.parameter_id,
            SP.name AS parametro,
            TYPE_NAME(SP.user_type_id) AS tipo,
            SP.max_length,
            SP.precision,
            SP.scale,
            SP.is_output
        FROM sys.parameters SP
        WHERE SP.object_id = OBJECT_ID(@StoredProcedureCarga, 'P')
        ORDER BY SP.parameter_id;

        /* ==========================================================
           CONTENIDO TXT PARA COPIAR Y PEGAR

           - Mueve a @commonFields empresa/origen/usuario cuando esos
             campos formen parte de la plantilla. EMEmpresa usa la clave
             externa que el SP legacy resuelve en ff_Empresa (S001 para 186).
           - Conserva el orden real de los demas campos en @fieldNames.
           - Siempre genera una plantilla con marcadores.
           - Si @IdEmpleadoBaseCarga tiene valor, genera una segunda version
             usando las columnas homonimas de ff_Empleado. Los campos que no
             existen en ff_Empleado permanecen como <CAPTURAR_CAMPO>.
           ========================================================== */
        DECLARE @CRLF NCHAR(2) = NCHAR(13) + NCHAR(10);
        DECLARE @CamposComunes NVARCHAR(MAX) = N'';
        DECLARE @NombresCampos NVARCHAR(MAX) = N'';
        DECLARE @DatosMarcadores NVARCHAR(MAX) = N'';
        DECLARE @ContenidoPlantilla NVARCHAR(MAX);
        DECLARE @ContenidoEmpleado NVARCHAR(MAX);
        DECLARE @ClaveEmpresaCarga NVARCHAR(150);

        SELECT @ClaveEmpresaCarga = NULLIF(LTRIM(RTRIM(E.EMIdEmpresaFlexiForbes)), '')
        FROM dbo.ff_Empresa E
        WHERE E.EMIdEmpresa = @IdEmpresa;

        DECLARE @CamposRegistro TABLE
        (
            orden INT NOT NULL,
            idConfiguracion INT NOT NULL,
            campo SYSNAME NOT NULL,
            tipoDato VARCHAR(20) NULL,
            requerido VARCHAR(10) NULL,
            columnaEmpleado SYSNAME NULL,
            tipoColumnaEmpleado SYSNAME NULL
        );

        INSERT @CamposRegistro
        (
            orden, idConfiguracion, campo, tipoDato, requerido,
            columnaEmpleado, tipoColumnaEmpleado
        )
        SELECT
            CP.CPOrden,
            CP.CPIdConfiguracionPlantilla,
            LTRIM(RTRIM(C.CANombreCampo)),
            C.CATipoDato,
            CP.CPRequerido,
            EC.name,
            ET.name
        FROM dbo.ff_ConfiguracionPlantilla CP
        INNER JOIN dbo.ff_Campo C
            ON C.CAIdCampo = CP.CAIdCampo
           AND C.CAIdEstatus = 1
        OUTER APPLY
        (
            SELECT TOP (1) SC.name, SC.user_type_id
            FROM sys.columns SC
            WHERE SC.object_id = OBJECT_ID('dbo.ff_Empleado')
              AND UPPER(SC.name) = UPPER
              (
                  CASE UPPER(LTRIM(RTRIM(C.CANombreCampo)))
                    WHEN 'EMPUESTODESCRIPCION' THEN 'EMPUESTO'
                    WHEN 'EMCENTROCOSTOS_TEXT' THEN 'EMIDCENTROCOSTOS'
                    WHEN 'EMOFICINA_TEXT' THEN 'EMOFICINA'
                    WHEN 'EMAREA_TEXT' THEN 'EMAREA'
                    WHEN 'EMJEFE' THEN 'EMIDJEFE'
                    ELSE LTRIM(RTRIM(C.CANombreCampo))
                  END
              )
        ) EC
        LEFT JOIN sys.types ET ON ET.user_type_id = EC.user_type_id
        WHERE CP.PLIdPlantilla = @IdPlantillaCarga
          AND CP.CPIdEstatus = 1
          AND UPPER(LTRIM(RTRIM(C.CANombreCampo))) NOT IN
              ('EMIDEMPRESA', 'EMEMPRESA', 'EMIDEMPRESAORIGEN',
               'EMUSUARIOADD', 'EMUSUARIOUMOD');

        SELECT @CamposComunes =
        (
            SELECT
                LTRIM(RTRIM(C.CANombreCampo)) + N'=' +
                CASE UPPER(LTRIM(RTRIM(C.CANombreCampo)))
                  WHEN 'EMIDEMPRESA' THEN CONVERT(NVARCHAR(30), @IdEmpresa)
                  WHEN 'EMEMPRESA' THEN COALESCE(
                       @ClaveEmpresaCarga, N'<CAPTURAR_CLAVE_EMPRESA_LEGACY>')
                  WHEN 'EMIDEMPRESAORIGEN' THEN COALESCE(
                       CONVERT(NVARCHAR(30), @IdEmpresaOrigenCarga),
                       N'<CAPTURAR_EMPRESA_ORIGEN>')
                  WHEN 'EMUSUARIOADD' THEN COALESCE(
                       CONVERT(NVARCHAR(30), @IdAdministradorCarga),
                       N'<CAPTURAR_ID_ADMINISTRADOR>')
                  WHEN 'EMUSUARIOUMOD' THEN COALESCE(
                       CONVERT(NVARCHAR(30), @IdAdministradorCarga),
                       N'<CAPTURAR_ID_ADMINISTRADOR>')
                END + @CRLF
            FROM dbo.ff_ConfiguracionPlantilla CP
            INNER JOIN dbo.ff_Campo C
                ON C.CAIdCampo = CP.CAIdCampo
               AND C.CAIdEstatus = 1
            WHERE CP.PLIdPlantilla = @IdPlantillaCarga
              AND CP.CPIdEstatus = 1
              AND UPPER(LTRIM(RTRIM(C.CANombreCampo))) IN
                  ('EMIDEMPRESA', 'EMEMPRESA', 'EMIDEMPRESAORIGEN',
                   'EMUSUARIOADD', 'EMUSUARIOUMOD')
            ORDER BY CP.CPOrden, CP.CPIdConfiguracionPlantilla
            FOR XML PATH(''), TYPE
        ).value('.', 'nvarchar(max)');

        SELECT @NombresCampos = STUFF
        ((
            SELECT N',' + R.campo
            FROM @CamposRegistro R
            ORDER BY R.orden, R.idConfiguracion
            FOR XML PATH(''), TYPE
        ).value('.', 'nvarchar(max)'), 1, 1, N'');

        SELECT @DatosMarcadores = STUFF
        ((
            SELECT N'|' +
                CASE
                  WHEN UPPER(R.campo) = 'EMNUMEROEMPLEADO'
                    THEN N'<CAPTURAR_NUMERO_EMPLEADO>'
                  WHEN UPPER(R.campo) = 'EMNUEVONUMEROEMPLEADO'
                    THEN N'<CAPTURAR_NUMERO_NUEVO_NO_UTILIZADO>'
                  WHEN UPPER(R.campo) LIKE '%FECHA%'
                    THEN N'<DD/MM/AAAA>'
                  WHEN R.requerido = '1'
                    THEN N'<CAPTURAR_' + UPPER(R.campo) + N'>'
                  ELSE N''
                END
            FROM @CamposRegistro R
            ORDER BY R.orden, R.idConfiguracion
            FOR XML PATH(''), TYPE
        ).value('.', 'nvarchar(max)'), 1, 1, N'');

        SET @ContenidoPlantilla =
            N'# NO EJECUTAR SIN REEMPLAZAR LOS MARCADORES <CAPTURAR_...>' + @CRLF +
            N'# Operacion ' + CONVERT(NVARCHAR(20), @IdOperacionCarga) +
                N': ' + COALESCE(@NombreOperacionCarga, N'') + @CRLF +
            N'@commonFields:' + @CRLF + COALESCE(@CamposComunes, N'') + @CRLF +
            N'@fieldNames:' + COALESCE(@NombresCampos, N'') + @CRLF +
            N'##' + @CRLF + N'@data:' + @CRLF +
            COALESCE(@DatosMarcadores, N'') + @CRLF;

        SELECT
            'TXT_PLANTILLA_PARA_COPIAR' AS bloque,
            @IdOperacionCarga AS idOperacion,
            @NombreOperacionCarga AS operacion,
            'Reemplace todos los marcadores <CAPTURAR_...> antes de ejecutar.' AS instruccion,
            @ContenidoPlantilla AS contenidoTxt;

        IF @IdEmpleadoBaseCarga IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.ff_Empleado WHERE Id = @IdEmpleadoBaseCarga)
            BEGIN
                SELECT
                    'TXT_CON_EMPLEADO_BASE' AS bloque,
                    'REVISAR' AS resultado,
                    'El @IdEmpleadoBaseCarga indicado no existe.' AS detalle;
            END
            ELSE
            BEGIN
                DECLARE @ExpresionDatos NVARCHAR(MAX) = N'';
                DECLARE @CampoActual SYSNAME;
                DECLARE @ColumnaActual SYSNAME;
                DECLARE @TipoColumnaActual SYSNAME;
                DECLARE @Primero BIT = 1;

                DECLARE campos_txt_cursor CURSOR LOCAL FAST_FORWARD FOR
                    SELECT campo, columnaEmpleado, tipoColumnaEmpleado
                    FROM @CamposRegistro
                    ORDER BY orden, idConfiguracion;

                OPEN campos_txt_cursor;
                FETCH NEXT FROM campos_txt_cursor
                    INTO @CampoActual, @ColumnaActual, @TipoColumnaActual;
                WHILE @@FETCH_STATUS = 0
                BEGIN
                    IF @Primero = 0
                        SET @ExpresionDatos += N' + N''|'' + ';

                    IF @ColumnaActual IS NOT NULL
                    BEGIN
                        SET @ExpresionDatos +=
                            N'COALESCE(REPLACE(REPLACE(REPLACE(' +
                            CASE WHEN @TipoColumnaActual IN
                                           ('date', 'datetime', 'datetime2', 'smalldatetime')
                                 THEN N'CONVERT(NVARCHAR(10), E.' +
                                      QUOTENAME(@ColumnaActual) + N', 103)'
                                 ELSE N'CONVERT(NVARCHAR(MAX), E.' +
                                      QUOTENAME(@ColumnaActual) + N')' END +
                            N', N''|'', N'' ''), CHAR(13), N'' ''), CHAR(10), N'' ''), N'''')';
                    END
                    ELSE
                        SET @ExpresionDatos += N'N''<CAPTURAR_' +
                            REPLACE(UPPER(@CampoActual), '''', '''''') + N'>''';

                    SET @Primero = 0;
                    FETCH NEXT FROM campos_txt_cursor
                        INTO @CampoActual, @ColumnaActual, @TipoColumnaActual;
                END;
                CLOSE campos_txt_cursor;
                DEALLOCATE campos_txt_cursor;

                DECLARE @DatosEmpleado NVARCHAR(MAX);
                DECLARE @SqlDatos NVARCHAR(MAX) =
                    N'SELECT @Salida = ' + @ExpresionDatos +
                    N' FROM dbo.ff_Empleado E WHERE E.Id = @IdEmpleado;';

                EXEC sys.sp_executesql
                    @SqlDatos,
                    N'@IdEmpleado INT, @Salida NVARCHAR(MAX) OUTPUT',
                    @IdEmpleado = @IdEmpleadoBaseCarga,
                    @Salida = @DatosEmpleado OUTPUT;

                SET @ContenidoEmpleado =
                    N'# REVISAR Y CAMBIAR IDENTIFICADORES/VALORES ANTES DE EJECUTAR' + @CRLF +
                    N'# Empleado base Id=' + CONVERT(NVARCHAR(30), @IdEmpleadoBaseCarga) + @CRLF +
                    N'# Operacion ' + CONVERT(NVARCHAR(20), @IdOperacionCarga) +
                        N': ' + COALESCE(@NombreOperacionCarga, N'') + @CRLF +
                    N'@commonFields:' + @CRLF + COALESCE(@CamposComunes, N'') + @CRLF +
                    N'@fieldNames:' + COALESCE(@NombresCampos, N'') + @CRLF +
                    N'##' + @CRLF + N'@data:' + @CRLF +
                    COALESCE(@DatosEmpleado, N'') + @CRLF;

                SELECT
                    'TXT_CON_EMPLEADO_BASE' AS bloque,
                    @IdOperacionCarga AS idOperacion,
                    @NombreOperacionCarga AS operacion,
                    @IdEmpleadoBaseCarga AS idEmpleadoBase,
                    'No ejecute un alta sin cambiar numero, certificado y demas identificadores unicos. Reemplace todos los marcadores.' AS instruccion,
                    @ContenidoEmpleado AS contenidoTxt;
            END;
        END
        ELSE
        BEGIN
            SELECT
                'TXT_CON_EMPLEADO_BASE' AS bloque,
                'Capture @IdEmpleadoBaseCarga con el Id de una muestra para generar una segunda version poblada.' AS instruccion;
        END;
    END;
END
ELSE
BEGIN
    SELECT
        'SIGUIENTE_PASO_CARGA' AS bloque,
        'Copie un COIdOperacion del bloque OPERACIONES_CARGA en @IdOperacionCarga y vuelva a ejecutar.' AS instruccion;
END;

/* =================================================================
   CARGA MASIVA - PASO 3
   Filas pequeñas de referencia. E.* permite copiar los campos que solicite
   la plantilla elegida. No use directamente identificadores unicos para una
   ALTA: cambie numero, certificado, RFC, CURP y correo cuando apliquen.
   ================================================================= */
SELECT TOP (@TopeCarga)
    'ACTUALIZACION_BAJA_TRANSFERENCIA_COMPENSACION' AS escenarioUso,
    'Empleado titular activo. Conservar EMNumeroEmpleado para operaciones sobre un registro existente.' AS queCambiar,
    E.Id, E.EMIdEmpresa, E.EMIdTitular, E.EMIdPerfil, E.EMIdParentesco,
    E.EMIdSexo, E.EMIdAcceso, E.EMIdEstatus, E.EMNumeroEmpleado,
    E.EMCertificado, E.EMApellidoPaterno, E.EMApellidoMaterno, E.EMNombre1,
    E.EMNombre2, E.EMFechaNacimiento, E.EMFechaIngresoEmpresa,
    E.EMFechaAntiguedadGMM, E.EMPuesto, E.EMArea, E.EMOficina, E.EMrfc,
    E.EMcurp, E.EMTipoEmpleado, E.EMSalarioBase, E.EMidCentroCostos,
    E.EMVIP, E.EMCorreoElectronico
FROM dbo.ff_Empleado E
WHERE E.EMIdEmpresa = @IdEmpresa
  AND E.EMIdEstatus = 1
  AND E.EMIdParentesco = 1
  AND E.EMIdTitular = 1
  AND (@NumeroEmpleadoBase IS NULL OR E.EMNumeroEmpleado = @NumeroEmpleadoBase)
ORDER BY E.Id DESC;

SELECT TOP (@TopeCarga)
    'ALTA_DEPENDIENTE_O_ACTUALIZACION_DEPENDIENTE' AS escenarioUso,
    'Dependiente existente de referencia. Para un alta cambie los identificadores unicos y conserve la liga correcta al titular.' AS queCambiar,
    E.Id, E.EMIdEmpresa, E.EMIdTitular, E.EMIdPerfil, E.EMIdParentesco,
    E.EMIdSexo, E.EMIdAcceso, E.EMIdEstatus, E.EMNumeroEmpleado,
    E.EMCertificado, E.EMApellidoPaterno, E.EMApellidoMaterno, E.EMNombre1,
    E.EMNombre2, E.EMFechaNacimiento, E.EMFechaIngresoEmpresa,
    E.EMFechaAntiguedadGMM, E.EMPuesto, E.EMArea, E.EMOficina, E.EMrfc,
    E.EMcurp, E.EMTipoEmpleado, E.EMSalarioBase, E.EMidCentroCostos,
    E.EMVIP, E.EMCorreoElectronico
FROM dbo.ff_Empleado E
WHERE E.EMIdEmpresa = @IdEmpresa
  AND E.EMIdEstatus = 1
  AND E.EMIdParentesco <> 1
  AND (@NumeroEmpleadoBase IS NULL OR E.EMNumeroEmpleado = @NumeroEmpleadoBase)
ORDER BY E.Id DESC;

SELECT TOP (@TopeCarga)
    'REACTIVACION' AS escenarioUso,
    'Empleado titular inactivo; no inventar el numero porque la reactivacion debe localizar un registro existente.' AS queCambiar,
    E.Id, E.EMIdEmpresa, E.EMIdTitular, E.EMIdPerfil, E.EMIdParentesco,
    E.EMIdSexo, E.EMIdAcceso, E.EMIdEstatus, E.EMNumeroEmpleado,
    E.EMCertificado, E.EMApellidoPaterno, E.EMApellidoMaterno, E.EMNombre1,
    E.EMNombre2, E.EMFechaNacimiento, E.EMFechaIngresoEmpresa,
    E.EMFechaAntiguedadGMM, E.EMPuesto, E.EMArea, E.EMOficina, E.EMrfc,
    E.EMcurp, E.EMTipoEmpleado, E.EMSalarioBase, E.EMidCentroCostos,
    E.EMVIP, E.EMCorreoElectronico
FROM dbo.ff_Empleado E
WHERE E.EMIdEmpresa = @IdEmpresa
  AND E.EMIdEstatus <> 1
  AND E.EMIdParentesco = 1
  AND E.EMIdTitular = 1
  AND (@NumeroEmpleadoBase IS NULL OR E.EMNumeroEmpleado = @NumeroEmpleadoBase)
ORDER BY E.Id DESC;

/* =================================================================
   DEFAULTEO - CLASIFICACION DE CANDIDATOS

   Tipo 1: solicitud autorizada + seleccion en origen, sin solicitud activa
           o por autorizar en destino.
   Tipo 2: plan basico para el perfil en destino, sin solicitud activa o por
           autorizar en destino.
   Tipo 3: misma base historica del tipo 1, distinguiendo si actualmente tiene
           dependientes activos.
   ================================================================= */
DROP TABLE IF EXISTS #BaseDefaulteo;
DROP TABLE IF EXISTS #EvaluacionDefaulteo;

SELECT TOP (@TopeEvaluar)
    E.Id AS idEmpleado,
    E.EMNumeroEmpleado AS numeroEmpleado,
    E.EMApellidoPaterno AS apellidoPaterno,
    E.EMApellidoMaterno AS apellidoMaterno,
    E.EMNombre1 AS nombre1,
    E.EMNombre2 AS nombre2,
    E.EMIdPerfil AS idPerfil,
    E.EMIdAcceso AS idAcceso,
    E.EMIdSexo AS idSexo,
    E.EMFechaNacimiento AS fechaNacimiento
INTO #BaseDefaulteo
FROM dbo.ff_Empleado E
WHERE E.EMIdEmpresa = @IdEmpresa
  AND E.EMIdEstatus = 1
  AND E.EMIdParentesco = 1
  AND E.EMIdTitular = 1
  AND E.EMNumeroEmpleado NOT LIKE 'PR%'
  AND (@NumeroEmpleadoBase IS NULL OR E.EMNumeroEmpleado = @NumeroEmpleadoBase)
ORDER BY E.Id DESC;

;WITH SolicitudOrigen AS
(
    SELECT S.SOIdEmpleado AS idEmpleado, COUNT(*) AS solicitudesOrigenAprobadas
    FROM dbo.ff_Solicitud S
    WHERE S.SOIdEmpresa = @IdEmpresa
      AND S.SOIdVigencia = @IdVigenciaOrigen
      AND S.SOIdEstatus = 1
      AND S.SOEstatusSolicitud = 1
    GROUP BY S.SOIdEmpleado
), SeleccionOrigen AS
(
    SELECT P.POIdEmpleado AS idEmpleado, COUNT(*) AS seleccionesOrigen
    FROM dbo.ff_PlanOpcionSeleccion P
    WHERE P.POIdEmpresa = @IdEmpresa
      AND P.POIdVigencia = @IdVigenciaOrigen
      AND P.POIdEstatus = 1
    GROUP BY P.POIdEmpleado
), PlanBasicoDestino AS
(
    SELECT B.PBIdPerfil AS idPerfil, COUNT(*) AS planesBasicosDestino
    FROM dbo.ff_PlanBasico B
    INNER JOIN dbo.ff_PlanOpcion O
        ON O.POIdPlanOpcion = B.PBIdPlanOpcion
       AND O.POIdEstatus = 1
    WHERE B.PBIdVigencia = @IdVigenciaDestino
      AND B.PBIdEstatus = 1
    GROUP BY B.PBIdPerfil
), Dependientes AS
(
    SELECT D.EMIdTitular AS idEmpleado, COUNT(*) AS dependientesActivos
    FROM dbo.ff_Empleado D
    WHERE D.EMIdEmpresa = @IdEmpresa
      AND D.EMIdEstatus = 1
      AND D.EMIdParentesco <> 1
    GROUP BY D.EMIdTitular
), SolicitudDestino AS
(
    SELECT S.SOIdEmpleado AS idEmpleado, COUNT(*) AS solicitudesDestinoActivas
    FROM dbo.ff_Solicitud S
    WHERE S.SOIdEmpresa = @IdEmpresa
      AND S.SOIdVigencia = @IdVigenciaDestino
      AND S.SOIdEstatus IN (1, 10)
      AND S.SOEstatusSolicitud IN (1, 3)
    GROUP BY S.SOIdEmpleado
)
SELECT
    B.*,
    P.PENombre AS perfil,
    ISNULL(SO.solicitudesOrigenAprobadas, 0) AS solicitudesOrigenAprobadas,
    ISNULL(SEL.seleccionesOrigen, 0) AS seleccionesOrigen,
    ISNULL(PB.planesBasicosDestino, 0) AS planesBasicosDestino,
    ISNULL(D.dependientesActivos, 0) AS dependientesActivos,
    ISNULL(SD.solicitudesDestinoActivas, 0) AS solicitudesDestinoActivas,
    CONVERT(BIT, CASE WHEN ISNULL(SO.solicitudesOrigenAprobadas, 0) > 0
                           AND ISNULL(SEL.seleccionesOrigen, 0) > 0
                           AND ISNULL(SD.solicitudesDestinoActivas, 0) = 0
                      THEN 1 ELSE 0 END) AS listoTipo1,
    CONVERT(BIT, CASE WHEN ISNULL(PB.planesBasicosDestino, 0) > 0
                           AND ISNULL(SD.solicitudesDestinoActivas, 0) = 0
                      THEN 1 ELSE 0 END) AS listoTipo2,
    CONVERT(BIT, CASE WHEN ISNULL(SO.solicitudesOrigenAprobadas, 0) > 0
                           AND ISNULL(SEL.seleccionesOrigen, 0) > 0
                           AND ISNULL(SD.solicitudesDestinoActivas, 0) = 0
                      THEN 1 ELSE 0 END) AS listoTipo3
INTO #EvaluacionDefaulteo
FROM #BaseDefaulteo B
LEFT JOIN dbo.ff_Perfil P ON P.PEIdPerfil = B.idPerfil
LEFT JOIN SolicitudOrigen SO ON SO.idEmpleado = B.idEmpleado
LEFT JOIN SeleccionOrigen SEL ON SEL.idEmpleado = B.idEmpleado
LEFT JOIN PlanBasicoDestino PB ON PB.idPerfil = B.idPerfil
LEFT JOIN Dependientes D ON D.idEmpleado = B.idEmpleado
LEFT JOIN SolicitudDestino SD ON SD.idEmpleado = B.idEmpleado;

SELECT TOP (@TopeDefaulteo)
    'TIPO 1' AS escenario,
    'def1' AS tokenMotor,
    'Conservar selecciones de la vigencia origen.' AS objetivo,
    E.*
FROM #EvaluacionDefaulteo E
WHERE E.listoTipo1 = 1
ORDER BY E.solicitudesOrigenAprobadas DESC, E.seleccionesOrigen DESC, E.idEmpleado DESC;

SELECT TOP (@TopeDefaulteo)
    'TIPO 2' AS escenario,
    'def2' AS tokenMotor,
    'Asignar el plan basico configurado para el perfil en la vigencia destino.' AS objetivo,
    E.*
FROM #EvaluacionDefaulteo E
WHERE E.listoTipo2 = 1
ORDER BY E.planesBasicosDestino DESC, E.idEmpleado DESC;

SELECT TOP (@TopeDefaulteo)
    'TIPO 3' AS escenario,
    'def3' AS tokenMotor,
    CASE WHEN E.dependientesActivos > 0
         THEN 'Conservar seleccion anterior y recalcular con dependientes actuales.'
         ELSE 'Control sin dependientes: conservar seleccion anterior y recalcular titular.' END AS objetivo,
    E.*
FROM #EvaluacionDefaulteo E
WHERE E.listoTipo3 = 1
ORDER BY CASE WHEN E.dependientesActivos > 0 THEN 0 ELSE 1 END,
         E.dependientesActivos DESC, E.idEmpleado DESC;

/* Estos empleados NO deben mostrarse como procesables en la pantalla para
   la vigencia destino, porque ya tienen solicitud activa o por autorizar. */
SELECT TOP (@TopeDefaulteo)
    'EXCLUIR / YA TIENE SOLICITUD DESTINO' AS escenario,
    E.*
FROM #EvaluacionDefaulteo E
WHERE E.solicitudesDestinoActivas > 0
ORDER BY E.idEmpleado DESC;

/* Validacion directa de los dummy instalados anteriormente, si existen. */
SELECT
    CASE E.numeroEmpleado
      WHEN 'QADEF1-186' THEN 'TIPO 1'
      WHEN 'QADEF2-186' THEN 'TIPO 2'
      WHEN 'QADEF3C-186' THEN 'TIPO 3 SIN DEPENDIENTES'
      WHEN 'QADEF3D-186' THEN 'TIPO 3 CON DEPENDIENTES'
      WHEN 'QADEF-RTRY-186' THEN 'EXCLUIR: SOLICITUD EN DESTINO'
    END AS escenarioEsperado,
    E.*
FROM #EvaluacionDefaulteo E
WHERE E.numeroEmpleado IN
(
    'QADEF1-186', 'QADEF2-186', 'QADEF3C-186',
    'QADEF3D-186', 'QADEF-RTRY-186'
)
ORDER BY escenarioEsperado;

DROP TABLE IF EXISTS #EvaluacionDefaulteo;
DROP TABLE IF EXISTS #BaseDefaulteo;

PRINT 'LISTO: consulta terminada. No se modifico ningun registro.';
