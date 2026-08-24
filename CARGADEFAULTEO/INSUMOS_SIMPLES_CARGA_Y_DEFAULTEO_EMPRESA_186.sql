/*
  INSUMOS SIMPLES DE PRUEBA - EMPRESA 186

  SOLO LECTURA. No ejecuta cargas, no genera solicitudes y no modifica datos.

  SOLO CAMBIE ESTOS TRES PARAMETROS:

    @CasoCarga:
       1 = Alta de dependiente
       2 = Alta de titular
       5 = Conciliacion
      13 = Cambio de numero de empleado
      14 = Reactivacion de empleado
      15 = Transferencia de empleado
      16 = Compensacion

    @TipoDefaulteo:
       0 = Mostrar tipos 1, 2 y 3
       1 = Defaulteo tipo 1
       2 = Defaulteo tipo 2
       3 = Defaulteo tipo 3

    @IdEmpresaOrigenCarga:
       Solo se captura para el caso 15 (transferencia).

  IMPORTANTE PARA ALTA DE DEPENDIENTE:
    EMNumeroEmpleado es el numero DEL TITULAR EXISTENTE. No invente un numero
    distinto para el dependiente. El SP legacy usa ese numero para encontrar al
    titular y ligar el nuevo dependiente.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET LOCK_TIMEOUT 15000;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

/* ====================== CAMBIE SOLO ESTO ====================== */
DECLARE @IdEmpresa             INT = 186;  -- Mantener 186 para estas pruebas.
DECLARE @CasoCarga             INT = 1;    -- Elegir: 1, 2, 5, 13, 14, 15 o 16.
DECLARE @TipoDefaulteo         INT = 0;    -- Elegir: 0, 1, 2 o 3.
DECLARE @IdEmpresaOrigenCarga  INT = NULL; -- Solo para transferencia (caso 15).
DECLARE @Tope                  INT = 20;   -- Maximo de candidatos mostrados.
/* ============================================================= */

IF @CasoCarga NOT IN (1, 2, 5, 13, 14, 15, 16)
    THROW 52100, '@CasoCarga debe ser 1, 2, 5, 13, 14, 15 o 16.', 1;
IF @TipoDefaulteo NOT BETWEEN 0 AND 3
    THROW 52101, '@TipoDefaulteo debe ser 0, 1, 2 o 3.', 1;
IF @Tope NOT BETWEEN 1 AND 100
    THROW 52102, '@Tope debe estar entre 1 y 100.', 1;
IF NOT EXISTS
(
    SELECT 1 FROM dbo.ff_Empresa
    WHERE EMIdEmpresa = @IdEmpresa AND EMIdEstatus = 1
)
    THROW 52103, 'La empresa indicada no existe o esta inactiva.', 1;

DECLARE @CasosCarga TABLE
(
    caso INT NOT NULL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    seUsaPara VARCHAR(500) NOT NULL,
    numeroEmpleadoSignifica VARCHAR(500) NOT NULL
);

INSERT @CasosCarga (caso, nombre, seUsaPara, numeroEmpleadoSignifica)
VALUES
(1,  'ALTA DE DEPENDIENTE',
 'Agregar un dependiente a un titular activo que ya existe.',
 'NUMERO DEL TITULAR EXISTENTE. No es un numero nuevo para el dependiente.'),
(2,  'ALTA DE TITULAR',
 'Crear un titular que todavia no existe.',
 'NUMERO NUEVO Y UNICO que se asignara al nuevo titular.'),
(5,  'CONCILIACION',
 'Registrar el monto conciliado de un periodo y registro de aseguradora.',
 'Numero de un empleado existente al que pertenece la conciliacion.'),
(13, 'CAMBIO DE NUMERO',
 'Sustituir el numero actual de un titular por otro numero no utilizado.',
 'Numero actual del titular; el nuevo va en EMNuevoNumeroEmpleado.'),
(14, 'REACTIVACION',
 'Reactivar un titular que actualmente esta inactivo.',
 'Numero existente del titular inactivo.'),
(15, 'TRANSFERENCIA',
 'Transferir un titular desde una empresa origen hacia la empresa destino.',
 'Numero existente del titular en la empresa origen.'),
(16, 'COMPENSACION',
 'Agregar, actualizar o dar de baja una compensacion.',
 'Numero de un titular activo existente.');

SELECT
    '1_CASOS_DE_CARGA' AS bloque,
    C.caso,
    C.nombre,
    C.seUsaPara,
    C.numeroEmpleadoSignifica,
    CASE WHEN C.caso = @CasoCarga THEN 'SELECCIONADO' ELSE '' END AS seleccion
FROM @CasosCarga C
ORDER BY C.caso;

DECLARE @Campos TABLE
(
    caso INT NOT NULL,
    orden INT NOT NULL,
    campo SYSNAME NOT NULL,
    obligatorio BIT NOT NULL,
    valorQueDebeCapturar VARCHAR(1000) NOT NULL,
    marcador NVARCHAR(300) NOT NULL,
    PRIMARY KEY (caso, orden)
);

/* Solo aparecen campos que el usuario debe capturar o revisar. Los campos de
   empresa que el sistema puede resolver se agregan automaticamente al TXT. */
INSERT @Campos
    (caso, orden, campo, obligatorio, valorQueDebeCapturar, marcador)
VALUES
/* 1 - Alta de dependiente */
(1,  1, 'EMIdSexo',               1, 'Sexo del NUEVO dependiente; use un ID valido del catalogo.', N'<SEXO_DEPENDIENTE>'),
(1,  2, 'EMNumeroEmpleado',        1, 'Numero del TITULAR ACTIVO existente al que se ligara el dependiente.', N'<NUMERO_TITULAR_EXISTENTE>'),
(1,  3, 'EMApellidoPaterno',       1, 'Apellido paterno del nuevo dependiente.', N'<APELLIDO_PATERNO_DEPENDIENTE>'),
(1,  4, 'EMApellidoMaterno',       0, 'Apellido materno del nuevo dependiente; dejar vacio si no aplica.', N'<APELLIDO_MATERNO_DEPENDIENTE>'),
(1,  5, 'EMNombre1',               1, 'Primer nombre del nuevo dependiente.', N'<NOMBRE_DEPENDIENTE>'),
(1,  6, 'EMNombre2',               0, 'Segundo nombre; dejar vacio si no aplica.', N'<SEGUNDO_NOMBRE_DEPENDIENTE>'),
(1,  7, 'EMFechaNacimiento',       1, 'Fecha de nacimiento del dependiente en formato DD/MM/AAAA.', N'<DD/MM/AAAA_NACIMIENTO>'),
(1,  8, 'EMFechaAntiguedadGMM',    0, 'Fecha de antiguedad GMM; puede dejarse vacia para que el SP la calcule.', N'<DD/MM/AAAA_ANTIGUEDAD_O_VACIO>'),
(1,  9, 'EMIdParentesco',          1, 'Parentesco del nuevo dependiente; use un ID valido del catalogo.', N'<ID_PARENTESCO>'),
(1, 10, 'EMFechaAlta',             1, 'Fecha de alta del dependiente en formato DD/MM/AAAA.', N'<DD/MM/AAAA_ALTA>'),
(1, 11, 'EMObservaciones',         0, 'Observaciones; dejar vacio si no aplica.', N'<OBSERVACIONES_O_VACIO>'),
(1, 12, 'EMCertificado',           0, 'Certificado; puede dejarse vacio para que el SP aplique la configuracion.', N'<CERTIFICADO_O_VACIO>'),

/* 2 - Alta de titular */
(2,  1, 'EMNumeroEmpleado',        1, 'Numero NUEVO que no exista en la empresa/corporativo.', N'<NUMERO_NUEVO_TITULAR>'),
(2,  2, 'EMPuestoDescripcion',     0, 'Descripcion del puesto; completar si el archivo origen la proporciona.', N'<PUESTO_O_VACIO>'),
(2,  3, 'EMNombre1',               1, 'Nombre del nuevo titular.', N'<NOMBRE_TITULAR>'),
(2,  4, 'EMApellidoPaterno',       1, 'Apellido paterno del nuevo titular.', N'<APELLIDO_PATERNO_TITULAR>'),
(2,  5, 'EMApellidoMaterno',       0, 'Apellido materno; dejar vacio si no aplica.', N'<APELLIDO_MATERNO_TITULAR>'),
(2,  6, 'EMFechaNacimiento',       1, 'Fecha de nacimiento DD/MM/AAAA.', N'<DD/MM/AAAA_NACIMIENTO>'),
(2,  7, 'EMIdSexo',                0, 'ID de sexo valido.', N'<ID_SEXO>'),
(2,  8, 'EMFechaIngresoEmpresa',   0, 'Fecha de ingreso DD/MM/AAAA.', N'<DD/MM/AAAA_INGRESO>'),
(2,  9, 'EMCentroCostos_text',     1, 'Descripcion de centro de costos reconocida por el catalogo legacy.', N'<CENTRO_COSTOS>'),
(2, 10, 'EMOficina_text',          0, 'Descripcion de oficina reconocida por el catalogo.', N'<OFICINA_O_VACIO>'),
(2, 11, 'EMArea_text',             0, 'Descripcion de area reconocida por el catalogo.', N'<AREA_O_VACIO>'),
(2, 12, 'EMCorreoElectronico',     0, 'Correo del nuevo titular; dejar vacio si no aplica.', N'<CORREO_O_VACIO>'),
(2, 13, 'EMSalarioBase',           0, 'Valor de salario/clasificacion esperado por el SP configurado.', N'<SALARIO_O_VACIO>'),

/* 5 - Conciliacion */
(5, 1, 'EMNumeroEmpleado',             1, 'Numero de empleado existente.', N'<NUMERO_EMPLEADO_EXISTENTE>'),
(5, 2, 'Quincenaanio',                 1, 'Periodo/quincena con el formato esperado por la operacion.', N'<QUINCENA_ANIO>'),
(5, 3, 'SANumeroRegistroAseguradora',  1, 'Numero de registro/CIS de la aseguradora.', N'<REGISTRO_ASEGURADORA>'),
(5, 4, 'EMUsuarioUMod',                1, 'ID del administrador que ejecuta la carga.', N'<ID_ADMINISTRADOR>'),
(5, 5, 'CDMontoConciliacion',          1, 'Monto a conciliar, sin simbolo de moneda.', N'<MONTO_CONCILIACION>'),

/* 13 - Cambio de numero */
(13, 1, 'EMNumeroEmpleado',       1, 'Numero ACTUAL de un titular activo.', N'<NUMERO_ACTUAL>'),
(13, 2, 'EMNuevoNumeroEmpleado',  1, 'Numero NUEVO que no este utilizado.', N'<NUMERO_NUEVO>'),

/* 14 - Reactivacion */
(14, 1, 'EMNumeroEmpleado',  1, 'Numero de un titular actualmente INACTIVO.', N'<NUMERO_INACTIVO>'),
(14, 2, 'EMFechaReingreso',  1, 'Fecha de reingreso DD/MM/AAAA.', N'<DD/MM/AAAA_REINGRESO>'),

/* 15 - Transferencia */
(15, 1, 'EMIdEmpresaOrigen',              1, 'ID de la empresa donde actualmente existe el titular.', N'<ID_EMPRESA_ORIGEN>'),
(15, 2, 'EMNumeroEmpleado',                1, 'Numero del titular en la empresa origen.', N'<NUMERO_EN_EMPRESA_ORIGEN>'),
(15, 3, 'EMIdPerfil',                      1, 'Perfil que tendra en la empresa destino.', N'<ID_PERFIL_DESTINO>'),
(15, 4, 'EMSalarioBase',                   0, 'Salario base; dejar vacio si la operacion no requiere cambio.', N'<SALARIO_O_VACIO>'),
(15, 5, 'EMCorreoElectronico',             0, 'Correo; dejar vacio si no cambia.', N'<CORREO_O_VACIO>'),
(15, 6, 'EMFecha_solicitud_movimiento',    1, 'Fecha del movimiento DD/MM/AAAA.', N'<DD/MM/AAAA_MOVIMIENTO>'),
(15, 7, 'EMSeleccionUsuario',              1, 'Opcion de generacion de solicitud esperada por el SP.', N'<OPCION_SOLICITUD>'),
(15, 8, 'EMObservacionesTransferencia',    0, 'Motivo u observaciones; dejar vacio si no aplica.', N'<OBSERVACIONES_O_VACIO>'),

/* 16 - Compensacion */
(16, 1, 'EMNumeroEmpleado',     1, 'Numero de un titular activo.', N'<NUMERO_EMPLEADO_EXISTENTE>'),
(16, 2, 'CSIdCompensacion',     1, 'ID de la compensacion configurada.', N'<ID_COMPENSACION>'),
(16, 3, 'CSMontoCompensacion',  1, 'Monto sin simbolo de moneda.', N'<MONTO_COMPENSACION>'),
(16, 4, 'EMTipoCargaComp',      1, '1=alta/actualizacion; 2=baja.', N'<1_O_2>');

SELECT
    '2_SOLO_CAMPOS_QUE_DEBE_CAMBIAR' AS bloque,
    @CasoCarga AS caso,
    C.nombre,
    F.orden,
    F.campo,
    CASE WHEN F.obligatorio = 1 THEN 'SI' ELSE 'SOLO SI APLICA' END AS obligatorio,
    F.valorQueDebeCapturar
FROM @Campos F
INNER JOIN @CasosCarga C ON C.caso = F.caso
WHERE F.caso = @CasoCarga
ORDER BY F.orden;

IF @CasoCarga = 1
BEGIN
    SELECT TOP (@Tope)
        '3_TITULARES_VALIDOS_PARA_ALTA_DEPENDIENTE' AS bloque,
        E.Id AS idTitular,
        E.EMNumeroEmpleado AS usarEsteNumeroEn_EMNumeroEmpleado,
        LTRIM(RTRIM(ISNULL(E.EMNombre1, '') + ' ' + ISNULL(E.EMNombre2, '') + ' ' +
                    ISNULL(E.EMApellidoPaterno, '') + ' ' + ISNULL(E.EMApellidoMaterno, ''))) AS titular,
        E.EMIdPerfil AS idPerfil,
        (SELECT COUNT(*) FROM dbo.ff_Empleado D
         WHERE D.EMIdEmpresa = E.EMIdEmpresa
           AND D.EMIdTitular = E.Id
           AND D.EMIdParentesco <> 1
           AND D.EMIdEstatus = 1) AS dependientesActivos,
        'EMNumeroEmpleado debe conservar este numero; cambie los datos personales del dependiente.' AS instruccion
    FROM dbo.ff_Empleado E
    WHERE E.EMIdEmpresa = @IdEmpresa
      AND E.EMIdEstatus = 1
      AND E.EMIdParentesco = 1
      AND E.EMIdTitular = 1
    ORDER BY CASE WHEN E.EMNumeroEmpleado LIKE 'QADEF%' THEN 0 ELSE 1 END, E.Id DESC;
END;
ELSE IF @CasoCarga IN (5, 13, 16)
BEGIN
    SELECT TOP (@Tope)
        '3_EMPLEADOS_EXISTENTES_PARA_LA_OPERACION' AS bloque,
        E.Id AS idEmpleado,
        E.EMNumeroEmpleado,
        LTRIM(RTRIM(ISNULL(E.EMNombre1, '') + ' ' + ISNULL(E.EMNombre2, '') + ' ' +
                    ISNULL(E.EMApellidoPaterno, '') + ' ' + ISNULL(E.EMApellidoMaterno, ''))) AS empleado,
        E.EMIdPerfil AS idPerfil
    FROM dbo.ff_Empleado E
    WHERE E.EMIdEmpresa = @IdEmpresa
      AND E.EMIdEstatus = 1
      AND E.EMIdParentesco = 1
      AND E.EMIdTitular = 1
    ORDER BY CASE WHEN E.EMNumeroEmpleado LIKE 'QADEF%' THEN 0 ELSE 1 END, E.Id DESC;
END;
ELSE IF @CasoCarga = 14
BEGIN
    SELECT TOP (@Tope)
        '3_TITULARES_INACTIVOS_PARA_REACTIVACION' AS bloque,
        E.Id AS idEmpleado,
        E.EMNumeroEmpleado,
        LTRIM(RTRIM(ISNULL(E.EMNombre1, '') + ' ' + ISNULL(E.EMNombre2, '') + ' ' +
                    ISNULL(E.EMApellidoPaterno, '') + ' ' + ISNULL(E.EMApellidoMaterno, ''))) AS empleado,
        E.EMIdEstatus AS estatusActual,
        E.EMFechaBaja
    FROM dbo.ff_Empleado E
    WHERE E.EMIdEmpresa = @IdEmpresa
      AND E.EMIdEstatus <> 1
      AND E.EMIdParentesco = 1
      AND E.EMIdTitular = 1
    ORDER BY E.Id DESC;
END;
ELSE IF @CasoCarga = 15 AND @IdEmpresaOrigenCarga IS NOT NULL
BEGIN
    SELECT TOP (@Tope)
        '3_TITULARES_EN_EMPRESA_ORIGEN' AS bloque,
        E.EMIdEmpresa AS idEmpresaOrigen,
        E.Id AS idEmpleado,
        E.EMNumeroEmpleado,
        LTRIM(RTRIM(ISNULL(E.EMNombre1, '') + ' ' + ISNULL(E.EMNombre2, '') + ' ' +
                    ISNULL(E.EMApellidoPaterno, '') + ' ' + ISNULL(E.EMApellidoMaterno, ''))) AS empleado,
        E.EMIdPerfil AS perfilOrigen
    FROM dbo.ff_Empleado E
    WHERE E.EMIdEmpresa = @IdEmpresaOrigenCarga
      AND E.EMIdEstatus = 1
      AND E.EMIdParentesco = 1
      AND E.EMIdTitular = 1
    ORDER BY E.Id DESC;
END;

/* Construye el TXT usando el orden exacto de la plantilla configurada. */
DECLARE @IdPlantilla INT;
DECLARE @NombreOperacion VARCHAR(200);
DECLARE @StoredProcedure VARCHAR(300);
DECLARE @ClaveEmpresaLegacy VARCHAR(150);

SELECT
    @IdPlantilla = CE.CEIdPlantilla,
    @StoredProcedure = LTRIM(RTRIM(CE.CEStoredProc)),
    @NombreOperacion = O.CONombre
FROM dbo.ff_CargaMasivaOperacionEmpresa CE
INNER JOIN dbo.ff_CargaMasivaOperacion O
    ON O.COIdOperacion = CE.CEIdOperacion
WHERE CE.CEIdEmpresa = @IdEmpresa
  AND CE.CEIdOperacion = @CasoCarga
  AND CE.CEIdEstatus = 1;

SELECT @ClaveEmpresaLegacy = NULLIF(LTRIM(RTRIM(EMIdEmpresaFlexiForbes)), '')
FROM dbo.ff_Empresa
WHERE EMIdEmpresa = @IdEmpresa;

IF @IdPlantilla IS NULL
    THROW 52104, 'No existe una plantilla activa para el caso seleccionado.', 1;

DECLARE @CRLF NCHAR(2) = NCHAR(13) + NCHAR(10);
DECLARE @CommonFields NVARCHAR(MAX) = N'';
DECLARE @FieldNames NVARCHAR(MAX) = N'';
DECLARE @Data NVARCHAR(MAX) = N'';
DECLARE @ContenidoTxt NVARCHAR(MAX);

DECLARE @Plantilla TABLE
(
    orden INT NOT NULL,
    idConfiguracion INT NOT NULL,
    campo SYSNAME NOT NULL,
    marcador NVARCHAR(300) NULL,
    PRIMARY KEY (orden, idConfiguracion)
);

INSERT @Plantilla (orden, idConfiguracion, campo, marcador)
SELECT
    CP.CPOrden,
    CP.CPIdConfiguracionPlantilla,
    LTRIM(RTRIM(C.CANombreCampo)),
    G.marcador
FROM dbo.ff_ConfiguracionPlantilla CP
INNER JOIN dbo.ff_Campo C
    ON C.CAIdCampo = CP.CAIdCampo
   AND C.CAIdEstatus = 1
LEFT JOIN @Campos G
    ON G.caso = @CasoCarga
   AND UPPER(G.campo) = UPPER(LTRIM(RTRIM(C.CANombreCampo)))
WHERE CP.PLIdPlantilla = @IdPlantilla
  AND CP.CPIdEstatus = 1;

SELECT @CommonFields =
(
    SELECT P.campo + N'=' +
           CASE UPPER(P.campo)
             WHEN 'EMIDEMPRESA' THEN CONVERT(NVARCHAR(30), @IdEmpresa)
             WHEN 'EMEMPRESA' THEN COALESCE(CONVERT(NVARCHAR(150), @ClaveEmpresaLegacy),
                                             N'<CLAVE_EMPRESA_LEGACY>')
           END + @CRLF
    FROM @Plantilla P
    WHERE UPPER(P.campo) IN ('EMIDEMPRESA', 'EMEMPRESA')
    ORDER BY P.orden, P.idConfiguracion
    FOR XML PATH(''), TYPE
).value('.', 'nvarchar(max)');

SELECT @FieldNames = STUFF
((
    SELECT N',' + P.campo
    FROM @Plantilla P
    WHERE UPPER(P.campo) NOT IN ('EMIDEMPRESA', 'EMEMPRESA')
    ORDER BY P.orden, P.idConfiguracion
    FOR XML PATH(''), TYPE
).value('.', 'nvarchar(max)'), 1, 1, N'');

SELECT @Data = STUFF
((
    SELECT N'|' + COALESCE(P.marcador, N'')
    FROM @Plantilla P
    WHERE UPPER(P.campo) NOT IN ('EMIDEMPRESA', 'EMEMPRESA')
    ORDER BY P.orden, P.idConfiguracion
    FOR XML PATH(''), TYPE
).value('.', 'nvarchar(max)'), 1, 1, N'');

SET @ContenidoTxt =
    N'# REEMPLACE LOS MARCADORES <...> ANTES DE EJECUTAR' + @CRLF +
    N'# Caso ' + CONVERT(NVARCHAR(20), @CasoCarga) + N': ' + @NombreOperacion + @CRLF +
    CASE WHEN @CasoCarga = 1
         THEN N'# EMNumeroEmpleado pertenece al TITULAR EXISTENTE.' + @CRLF
         WHEN @CasoCarga = 2
         THEN N'# EMNumeroEmpleado debe ser NUEVO Y UNICO.' + @CRLF
         ELSE N'' END +
    N'@commonFields:' + @CRLF + COALESCE(@CommonFields, N'') + @CRLF +
    N'@fieldNames:' + COALESCE(@FieldNames, N'') + @CRLF +
    N'##' + @CRLF +
    N'@data:' + @CRLF + COALESCE(@Data, N'') + @CRLF;

SELECT
    '4_TXT_LISTO_PARA_COPIAR_Y_COMPLETAR' AS bloque,
    @CasoCarga AS caso,
    @NombreOperacion AS operacion,
    @IdPlantilla AS idPlantilla,
    @StoredProcedure AS storedProcedure,
    @ContenidoTxt AS contenidoTxt;

/* =========================== DEFAULTEO ===========================
   Defaulteo no usa TXT. Se selecciona un empleado candidato y el token
   def1/def2/def3 indica al motor que tratamiento debe aplicar.

   Tipo 1 y tipo 3 comparten la misma base historica, por eso un empleado
   puede cumplir tecnicamente ambos. La columna usoRecomendado separa los
   registros dummy preparados especificamente para cada prueba.
   ================================================================= */
DECLARE @IdConfiguracion INT;
DECLARE @IdVigenciaDestino INT;
DECLARE @IdVigenciaOrigen INT;

SELECT @IdConfiguracion = EMIdConfiguracion
FROM dbo.ff_Empresa
WHERE EMIdEmpresa = @IdEmpresa;

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

SELECT @IdVigenciaOrigen = V.VIRenovada
FROM dbo.ff_Vigencia V
WHERE V.VIIdVigencia = @IdVigenciaDestino;

SELECT *
FROM (VALUES
    (1, 'def1', 'Conservar la seleccion autorizada de la vigencia anterior.',
     'No modificar campos: seleccionar un titular candidato.'),
    (2, 'def2', 'Asignar el plan basico configurado para el perfil en destino.',
     'No modificar campos: seleccionar un titular candidato.'),
    (3, 'def3', 'Conservar/recalcular la seleccion anterior considerando dependientes actuales.',
     'No modificar campos: seleccionar un titular candidato.')
) D(tipo, tokenMotor, queHace, camposQueDebeModificar)
WHERE @TipoDefaulteo = 0 OR D.tipo = @TipoDefaulteo
ORDER BY D.tipo;

DROP TABLE IF EXISTS #EvalDefSimple;

;WITH Base AS
(
    SELECT TOP (3000)
        E.Id AS idEmpleado,
        E.EMNumeroEmpleado AS numeroEmpleado,
        E.EMNombre1,
        E.EMNombre2,
        E.EMApellidoPaterno,
        E.EMApellidoMaterno,
        E.EMIdPerfil AS idPerfil
    FROM dbo.ff_Empleado E
    WHERE E.EMIdEmpresa = @IdEmpresa
      AND E.EMIdEstatus = 1
      AND E.EMIdParentesco = 1
      AND E.EMIdTitular = 1
      AND E.EMNumeroEmpleado NOT LIKE 'PR%'
    ORDER BY E.Id DESC
), SolicitudOrigen AS
(
    SELECT S.SOIdEmpleado AS idEmpleado, COUNT(*) AS cantidad
    FROM dbo.ff_Solicitud S
    WHERE S.SOIdEmpresa = @IdEmpresa
      AND S.SOIdVigencia = @IdVigenciaOrigen
      AND S.SOIdEstatus = 1
      AND S.SOEstatusSolicitud = 1
    GROUP BY S.SOIdEmpleado
), SeleccionOrigen AS
(
    SELECT P.POIdEmpleado AS idEmpleado, COUNT(*) AS cantidad
    FROM dbo.ff_PlanOpcionSeleccion P
    WHERE P.POIdEmpresa = @IdEmpresa
      AND P.POIdVigencia = @IdVigenciaOrigen
      AND P.POIdEstatus = 1
    GROUP BY P.POIdEmpleado
), PlanBasicoDestino AS
(
    SELECT B.PBIdPerfil AS idPerfil, COUNT(*) AS cantidad
    FROM dbo.ff_PlanBasico B
    INNER JOIN dbo.ff_PlanOpcion O
        ON O.POIdPlanOpcion = B.PBIdPlanOpcion
       AND O.POIdEstatus = 1
    WHERE B.PBIdVigencia = @IdVigenciaDestino
      AND B.PBIdEstatus = 1
    GROUP BY B.PBIdPerfil
), Dependientes AS
(
    SELECT D.EMIdTitular AS idEmpleado, COUNT(*) AS cantidad
    FROM dbo.ff_Empleado D
    WHERE D.EMIdEmpresa = @IdEmpresa
      AND D.EMIdEstatus = 1
      AND D.EMIdParentesco <> 1
    GROUP BY D.EMIdTitular
), SolicitudDestino AS
(
    SELECT S.SOIdEmpleado AS idEmpleado, COUNT(*) AS cantidad
    FROM dbo.ff_Solicitud S
    WHERE S.SOIdEmpresa = @IdEmpresa
      AND S.SOIdVigencia = @IdVigenciaDestino
      AND S.SOIdEstatus IN (1, 10)
      AND S.SOEstatusSolicitud IN (1, 3)
    GROUP BY S.SOIdEmpleado
)
SELECT
    B.*,
    LTRIM(RTRIM(ISNULL(B.EMNombre1, '') + ' ' + ISNULL(B.EMNombre2, '') + ' ' +
                ISNULL(B.EMApellidoPaterno, '') + ' ' + ISNULL(B.EMApellidoMaterno, ''))) AS empleado,
    ISNULL(SO.cantidad, 0) AS solicitudesOrigen,
    ISNULL(SE.cantidad, 0) AS seleccionesOrigen,
    ISNULL(PB.cantidad, 0) AS planesBasicosDestino,
    ISNULL(D.cantidad, 0) AS dependientesActivos,
    ISNULL(SD.cantidad, 0) AS solicitudesDestino,
    CONVERT(BIT, CASE WHEN ISNULL(SO.cantidad, 0) > 0
                           AND ISNULL(SE.cantidad, 0) > 0
                           AND ISNULL(SD.cantidad, 0) = 0 THEN 1 ELSE 0 END) AS sirveTipo1,
    CONVERT(BIT, CASE WHEN ISNULL(PB.cantidad, 0) > 0
                           AND ISNULL(SD.cantidad, 0) = 0 THEN 1 ELSE 0 END) AS sirveTipo2,
    CONVERT(BIT, CASE WHEN ISNULL(SO.cantidad, 0) > 0
                           AND ISNULL(SE.cantidad, 0) > 0
                           AND ISNULL(SD.cantidad, 0) = 0 THEN 1 ELSE 0 END) AS sirveTipo3
INTO #EvalDefSimple
FROM Base B
LEFT JOIN SolicitudOrigen SO ON SO.idEmpleado = B.idEmpleado
LEFT JOIN SeleccionOrigen SE ON SE.idEmpleado = B.idEmpleado
LEFT JOIN PlanBasicoDestino PB ON PB.idPerfil = B.idPerfil
LEFT JOIN Dependientes D ON D.idEmpleado = B.idEmpleado
LEFT JOIN SolicitudDestino SD ON SD.idEmpleado = B.idEmpleado;

SELECT TOP (@Tope)
    '5_REGISTROS_PARA_DEFAULTEO' AS bloque,
    X.tipoDefaulteo,
    X.tokenMotor,
    X.numeroEmpleado,
    X.empleado,
    X.idEmpleado,
    X.idPerfil,
    X.dependientesActivos,
    'NINGUNO: solo seleccionar el empleado en pantalla.' AS camposQueDebeModificar,
    CASE
      WHEN X.tipoDefaulteo = 1 AND X.numeroEmpleado = 'QADEF1-186'
        THEN 'RECOMENDADO PARA TIPO 1'
      WHEN X.tipoDefaulteo = 2 AND X.numeroEmpleado = 'QADEF2-186'
        THEN 'RECOMENDADO PARA TIPO 2'
      WHEN X.tipoDefaulteo = 3 AND X.numeroEmpleado = 'QADEF3D-186'
        THEN 'RECOMENDADO PARA TIPO 3 CON DEPENDIENTES'
      WHEN X.tipoDefaulteo = 3 AND X.numeroEmpleado = 'QADEF3C-186'
        THEN 'RECOMENDADO PARA TIPO 3 SIN DEPENDIENTES'
      ELSE 'CANDIDATO ALTERNATIVO'
    END AS usoRecomendado,
    X.porQueSirve
FROM
(
    SELECT 1 AS tipoDefaulteo, 'def1' AS tokenMotor, E.*,
           'Tiene solicitud/seleccion aprobada en origen y no tiene solicitud activa en destino.' AS porQueSirve
    FROM #EvalDefSimple E WHERE E.sirveTipo1 = 1
    UNION ALL
    SELECT 2, 'def2', E.*,
           'Su perfil tiene plan basico en destino y no tiene solicitud activa en destino.'
    FROM #EvalDefSimple E WHERE E.sirveTipo2 = 1
    UNION ALL
    SELECT 3, 'def3', E.*,
           CASE WHEN E.dependientesActivos > 0
                THEN 'Tiene seleccion anterior; permite probar recalculo con dependientes.'
                ELSE 'Tiene seleccion anterior; permite probar el control sin dependientes.' END
    FROM #EvalDefSimple E WHERE E.sirveTipo3 = 1
) X
WHERE @TipoDefaulteo = 0 OR X.tipoDefaulteo = @TipoDefaulteo
ORDER BY
    X.tipoDefaulteo,
    CASE
      WHEN X.tipoDefaulteo = 1 AND X.numeroEmpleado = 'QADEF1-186' THEN 0
      WHEN X.tipoDefaulteo = 2 AND X.numeroEmpleado = 'QADEF2-186' THEN 0
      WHEN X.tipoDefaulteo = 3 AND X.numeroEmpleado = 'QADEF3D-186' THEN 0
      WHEN X.tipoDefaulteo = 3 AND X.numeroEmpleado = 'QADEF3C-186' THEN 1
      ELSE 2
    END,
    X.idEmpleado DESC;

SELECT TOP (@Tope)
    '6_NO_USAR_YA_TIENE_SOLICITUD_EN_DESTINO' AS bloque,
    E.numeroEmpleado,
    E.empleado,
    E.idEmpleado,
    E.solicitudesDestino,
    'No debe volver a aparecer como procesable para esta vigencia.' AS motivo
FROM #EvalDefSimple E
WHERE E.solicitudesDestino > 0
ORDER BY CASE WHEN E.numeroEmpleado = 'QADEF-RTRY-186' THEN 0 ELSE 1 END,
         E.idEmpleado DESC;

DROP TABLE IF EXISTS #EvalDefSimple;

PRINT 'LISTO: consulta terminada. No se modifico ningun registro.';
GO
