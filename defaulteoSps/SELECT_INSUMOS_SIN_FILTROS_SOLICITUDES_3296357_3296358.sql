USE [FlexiForbesv2];
GO

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

/*
  INSUMOS CRUDOS PARA PRUEBAS DE BAJA Y DEFAULTEO

  Solicitud anterior : 3296357
  Solicitud posterior: 3296358

  SOLO LECTURA.

  Los unicos filtros son los identificadores necesarios para pertenecer al
  caso, titular, familia u opciones relacionadas. No se filtra por estatus,
  vigencia, fecha, plan activo, elegibilidad ni tipo de tarifa.
*/

DECLARE @SolicitudAnterior INT = 3296357;
DECLARE @SolicitudPosterior INT = 3296358;
DECLARE @IdTitular INT;
DECLARE @IdEmpresa INT;
DECLARE @NumeroEmpleado VARCHAR(50);
DECLARE @IdPerfil INT;

SELECT TOP (1)
    @IdTitular = COALESCE(NULLIF(E.EMIdTitular, 0), E.Id, S.SOIdEmpleado),
    @IdEmpresa = S.SOIdEmpresa,
    @NumeroEmpleado = S.SONumEmpleado
FROM dbo.ff_Solicitud S
LEFT JOIN dbo.ff_Empleado E
    ON E.Id = S.SOIdEmpleado
WHERE S.SOIdSolicitud IN (@SolicitudAnterior, @SolicitudPosterior)
ORDER BY
    CASE WHEN S.SOIdSolicitud = @SolicitudPosterior THEN 0 ELSE 1 END;

SELECT
    @IdPerfil = E.EMIdPerfil
FROM dbo.ff_Empleado E
WHERE E.Id = @IdTitular;

IF @IdTitular IS NULL
BEGIN
    SELECT
        'CASO_NO_ENCONTRADO' AS resultado,
        'Las solicitudes 3296357 y 3296358 no existen en esta base.' AS detalle;
    RETURN;
END;

/* 00. Contexto detectado. */
SELECT
    '00_CONTEXTO' AS bloque,
    CONVERT(NVARCHAR(128), SERVERPROPERTY('ServerName')) AS servidor,
    DB_NAME() AS baseDatos,
    GETDATE() AS fechaConsulta,
    @SolicitudAnterior AS solicitudAnterior,
    @SolicitudPosterior AS solicitudPosterior,
    @IdTitular AS idTitular,
    @IdEmpresa AS idEmpresa,
    @NumeroEmpleado AS numeroEmpleado,
    @IdPerfil AS idPerfil;

/* 01. Registro completo de la solicitud anterior. */
SELECT
    '01_SOLICITUD_ANTERIOR_SIN_FILTROS' AS bloque,
    S.*
FROM dbo.ff_Solicitud S
WHERE S.SOIdSolicitud = @SolicitudAnterior;

/* 02. Registro completo de la solicitud posterior. */
SELECT
    '02_SOLICITUD_POSTERIOR_SIN_FILTROS' AS bloque,
    S.*
FROM dbo.ff_Solicitud S
WHERE S.SOIdSolicitud = @SolicitudPosterior;

/* 03. Todas las elecciones de la solicitud anterior, sin filtrar estatus. */
SELECT
    '03_ELECCIONES_ANTERIORES_SIN_FILTROS' AS bloque,
    PS.*,
    E.EMNombre1,
    E.EMNombre2,
    E.EMApellidoPaterno,
    E.EMApellidoMaterno,
    E.EMIdEstatus AS estatusActualIntegrante,
    PA.PANombre AS parentesco,
    GP.GPNombre AS grupoParentesco,
    O.POIdPlan,
    O.PONombre AS opcionNombre,
    O.PODescripcion AS opcionDescripcion,
    PL.PLNombre AS planNombre
FROM dbo.ff_PlanOpcionSeleccion PS
LEFT JOIN dbo.ff_Empleado E
    ON E.Id = PS.POIdEmpleado
LEFT JOIN dbo.ff_Parentesco PA
    ON PA.PAIdParentesco = PS.POIdParentesco
LEFT JOIN dbo.ff_GrupoParentesco GP
    ON GP.GPIdGrupoParentesco = PS.POIdGrupoParentesco
LEFT JOIN dbo.ff_PlanOpcion O
    ON O.POIdPlanOpcion = PS.POIdPlanOpcion
LEFT JOIN dbo.ff_Plan PL
    ON PL.PLIdPlan = O.POIdPlan
WHERE PS.POIdSolicitud = @SolicitudAnterior
ORDER BY PS.POIdPlanOpcionSeleccion;

/* 04. Todas las elecciones de la solicitud posterior, sin filtrar estatus. */
SELECT
    '04_ELECCIONES_POSTERIORES_SIN_FILTROS' AS bloque,
    PS.*,
    E.EMNombre1,
    E.EMNombre2,
    E.EMApellidoPaterno,
    E.EMApellidoMaterno,
    E.EMIdEstatus AS estatusActualIntegrante,
    PA.PANombre AS parentesco,
    GP.GPNombre AS grupoParentesco,
    O.POIdPlan,
    O.PONombre AS opcionNombre,
    O.PODescripcion AS opcionDescripcion,
    PL.PLNombre AS planNombre
FROM dbo.ff_PlanOpcionSeleccion PS
LEFT JOIN dbo.ff_Empleado E
    ON E.Id = PS.POIdEmpleado
LEFT JOIN dbo.ff_Parentesco PA
    ON PA.PAIdParentesco = PS.POIdParentesco
LEFT JOIN dbo.ff_GrupoParentesco GP
    ON GP.GPIdGrupoParentesco = PS.POIdGrupoParentesco
LEFT JOIN dbo.ff_PlanOpcion O
    ON O.POIdPlanOpcion = PS.POIdPlanOpcion
LEFT JOIN dbo.ff_Plan PL
    ON PL.PLIdPlan = O.POIdPlan
WHERE PS.POIdSolicitud = @SolicitudPosterior
ORDER BY PS.POIdPlanOpcionSeleccion;

/*
  05. Todo el historial de solicitudes encontrado para el titular o su numero
  de empleado dentro de la misma empresa. No se limita por vigencia, fecha
  ni estatus.
*/
SELECT
    '05_TODO_HISTORIAL_SOLICITUDES_TITULAR' AS bloque,
    S.*,
    EM.EMNombre AS empresa,
    V.VINombre AS vigencia,
    ES.ESNombre AS nombreEstatusSolicitud,
    ES.ESDescripcion AS descripcionEstatusSolicitud
FROM dbo.ff_Solicitud S
LEFT JOIN dbo.ff_Empresa EM
    ON EM.EMIdEmpresa = S.SOIdEmpresa
LEFT JOIN dbo.ff_Vigencia V
    ON V.VIIdVigencia = S.SOIdVigencia
OUTER APPLY
(
    SELECT TOP (1)
        E.ESNombre,
        E.ESDescripcion
    FROM dbo.ff_Estatus E
    WHERE E.ESId = S.SOEstatusSolicitud
    ORDER BY
        CASE WHEN E.ESModulo = 'Solicitudes' THEN 0 ELSE 1 END,
        E.ESId
) ES
WHERE S.SOIdEmpleado = @IdTitular
   OR
      (
          S.SONumEmpleado = @NumeroEmpleado
          AND S.SOIdEmpresa = @IdEmpresa
      )
ORDER BY S.SOIdSolicitud DESC;

/*
  06. Todas las elecciones de todo el historial anterior.
  No se filtran vigencia, solicitud, estatus ni empresa.
*/
;WITH Historial AS
(
    SELECT S.SOIdSolicitud
    FROM dbo.ff_Solicitud S
    WHERE S.SOIdEmpleado = @IdTitular
       OR
          (
              S.SONumEmpleado = @NumeroEmpleado
              AND S.SOIdEmpresa = @IdEmpresa
          )
)
SELECT
    '06_TODAS_ELECCIONES_HISTORICAS' AS bloque,
    PS.*,
    S.SOIdEmpresa,
    S.SOIdVigencia,
    S.SOEstatusSolicitud,
    S.SOFechaAdd AS fechaSolicitud,
    E.EMNombre1,
    E.EMNombre2,
    E.EMApellidoPaterno,
    E.EMApellidoMaterno,
    PA.PANombre AS parentesco,
    GP.GPNombre AS grupoParentesco,
    O.POIdPlan,
    O.PONombre AS opcionNombre,
    O.PODescripcion AS opcionDescripcion,
    PL.PLNombre AS planNombre
FROM Historial H
INNER JOIN dbo.ff_PlanOpcionSeleccion PS
    ON PS.POIdSolicitud = H.SOIdSolicitud
INNER JOIN dbo.ff_Solicitud S
    ON S.SOIdSolicitud = PS.POIdSolicitud
LEFT JOIN dbo.ff_Empleado E
    ON E.Id = PS.POIdEmpleado
LEFT JOIN dbo.ff_Parentesco PA
    ON PA.PAIdParentesco = PS.POIdParentesco
LEFT JOIN dbo.ff_GrupoParentesco GP
    ON GP.GPIdGrupoParentesco = PS.POIdGrupoParentesco
LEFT JOIN dbo.ff_PlanOpcion O
    ON O.POIdPlanOpcion = PS.POIdPlanOpcion
LEFT JOIN dbo.ff_Plan PL
    ON PL.PLIdPlan = O.POIdPlan
ORDER BY PS.POIdSolicitud DESC, PS.POIdPlanOpcionSeleccion;

/*
  07. Familia completa del titular.
  Incluye integrantes activos, inactivos, eliminados o dados de baja.
*/
SELECT
    '07_FAMILIA_COMPLETA_SIN_FILTRO_ESTATUS' AS bloque,
    E.*,
    PA.PANombre AS parentesco,
    P.PENombre AS perfil,
    ES.ESNombre AS nombreEstatus
FROM dbo.ff_Empleado E
LEFT JOIN dbo.ff_Parentesco PA
    ON PA.PAIdParentesco = E.EMIdParentesco
LEFT JOIN dbo.ff_Perfil P
    ON P.PEIdPerfil = E.EMIdPerfil
OUTER APPLY
(
    SELECT TOP (1) ST.ESNombre
    FROM dbo.ff_Estatus ST
    WHERE ST.ESId = E.EMIdEstatus
    ORDER BY ST.ESId
) ES
WHERE E.Id = @IdTitular
   OR E.EMIdTitular = @IdTitular
   OR (E.EMIdEmpresa = @IdEmpresa AND E.EMNumeroEmpleado = @NumeroEmpleado)
ORDER BY E.EMIdParentesco, E.Id;

/* 07B. Registro completo de la empresa. */
SELECT
    '07B_EMPRESA' AS bloque,
    E.*
FROM dbo.ff_Empresa E
WHERE E.EMIdEmpresa = @IdEmpresa;

/* 07C. Configuracion general completa de la empresa. */
SELECT
    '07C_CONFIGURACION_EMPRESA' AS bloque,
    C.*
FROM dbo.ff_Empresa E
INNER JOIN dbo.ff_Configuracion C
    ON C.COIdConfiguracion = E.EMIdConfiguracion
WHERE E.EMIdEmpresa = @IdEmpresa;

/* 07D. Todas las vigencias de la empresa, sin filtrar estatus. */
SELECT
    '07D_VIGENCIAS_EMPRESA_SIN_FILTROS' AS bloque,
    V.*
FROM dbo.ff_Empresa E
INNER JOIN dbo.ff_Vigencia V
    ON V.VIIdConfiguracion = E.EMIdConfiguracion
WHERE E.EMIdEmpresa = @IdEmpresa
ORDER BY V.VIIdVigencia;

/* 07E. Todos los perfiles utilizados por la familia. */
SELECT
    '07E_PERFILES_FAMILIA_SIN_FILTROS' AS bloque,
    P.*
FROM dbo.ff_Perfil P
WHERE P.PEIdPerfil IN
      (
          SELECT DISTINCT E.EMIdPerfil
          FROM dbo.ff_Empleado E
          WHERE E.Id = @IdTitular
             OR E.EMIdTitular = @IdTitular
      )
ORDER BY P.PEIdPerfil;

/* 07F. Condiciones asociadas a la empresa o perfiles familiares. */
SELECT
    '07F_CONDICIONES_PLAN_SIN_FILTROS' AS bloque,
    CP.*
FROM dbo.ff_CondicionPlan CP
WHERE CP.CPIdEmpresa = @IdEmpresa
   OR CP.CPIdPerfil IN
      (
          SELECT DISTINCT E.EMIdPerfil
          FROM dbo.ff_Empleado E
          WHERE E.Id = @IdTitular
             OR E.EMIdTitular = @IdTitular
      )
ORDER BY CP.CPIdCondicionPlan;

/* 07G. Todas las selecciones temporales de la familia. */
SELECT
    '07G_SELECCIONES_TEMPORALES_SIN_FILTROS' AS bloque,
    T.*
FROM dbo.ff_PlanOpcionSeleccionTmp T
WHERE T.POIdEmpleado IN
      (
          SELECT E.Id
          FROM dbo.ff_Empleado E
          WHERE E.Id = @IdTitular
             OR E.EMIdTitular = @IdTitular
      )
   OR
      (
          T.POIdEmpresa = @IdEmpresa
          AND T.PONumeroEmpleado = @NumeroEmpleado
      )
ORDER BY T.POIdEmpleado, T.POIdPlanOpcionSeleccion;

/* 08. Definicion de los planes y opciones presentes en todo el historial. */
;WITH OpcionesCaso AS
(
    SELECT DISTINCT PS.POIdPlanOpcion
    FROM dbo.ff_PlanOpcionSeleccion PS
    INNER JOIN dbo.ff_Solicitud S
        ON S.SOIdSolicitud = PS.POIdSolicitud
    WHERE S.SOIdEmpleado = @IdTitular
       OR (S.SONumEmpleado = @NumeroEmpleado AND S.SOIdEmpresa = @IdEmpresa)
)
SELECT
    '08_PLANES_Y_OPCIONES_DEL_HISTORIAL' AS bloque,
    PL.*,
    O.*
FROM OpcionesCaso C
INNER JOIN dbo.ff_PlanOpcion O
    ON O.POIdPlanOpcion = C.POIdPlanOpcion
INNER JOIN dbo.ff_Plan PL
    ON PL.PLIdPlan = O.POIdPlan
ORDER BY PL.PLIdPlan, O.POIdPlanOpcion;

/* 09. Configuracion de esas opciones para todos los perfiles registrados. */
;WITH OpcionesCaso AS
(
    SELECT DISTINCT PS.POIdPlanOpcion
    FROM dbo.ff_PlanOpcionSeleccion PS
    INNER JOIN dbo.ff_Solicitud S
        ON S.SOIdSolicitud = PS.POIdSolicitud
    WHERE S.SOIdEmpleado = @IdTitular
       OR (S.SONumEmpleado = @NumeroEmpleado AND S.SOIdEmpresa = @IdEmpresa)
)
SELECT
    '09_OPCIONES_PERFIL_SIN_FILTRO_ESTATUS' AS bloque,
    PP.*,
    P.PENombre AS perfil,
    O.PONombre AS opcion,
    PL.PLNombre AS planNombre
FROM OpcionesCaso C
INNER JOIN dbo.ff_PlanOpcionPerfil PP
    ON PP.PPIdPlanOpcion = C.POIdPlanOpcion
LEFT JOIN dbo.ff_Perfil P
    ON P.PEIdPerfil = PP.PPIdPerfil
LEFT JOIN dbo.ff_PlanOpcion O
    ON O.POIdPlanOpcion = PP.PPIdPlanOpcion
LEFT JOIN dbo.ff_Plan PL
    ON PL.PLIdPlan = O.POIdPlan
ORDER BY PP.PPIdPlanOpcion, PP.PPIdPerfil;

/* 10. Configuracion por vigencia, sin filtrar estatus. */
;WITH OpcionesCaso AS
(
    SELECT DISTINCT PS.POIdPlanOpcion
    FROM dbo.ff_PlanOpcionSeleccion PS
    INNER JOIN dbo.ff_Solicitud S
        ON S.SOIdSolicitud = PS.POIdSolicitud
    WHERE S.SOIdEmpleado = @IdTitular
       OR (S.SONumEmpleado = @NumeroEmpleado AND S.SOIdEmpresa = @IdEmpresa)
)
SELECT
    '10_OPCIONES_VIGENCIA_SIN_FILTRO_ESTATUS' AS bloque,
    OV.*,
    V.VINombre AS vigencia,
    O.PONombre AS opcion
FROM OpcionesCaso C
INNER JOIN dbo.ff_PlanOpcionVigencia OV
    ON OV.VCIdPlanOpcion = C.POIdPlanOpcion
LEFT JOIN dbo.ff_Vigencia V
    ON V.VIIdVigencia = OV.VCIdVigencia
LEFT JOIN dbo.ff_PlanOpcion O
    ON O.POIdPlanOpcion = OV.VCIdPlanOpcion
ORDER BY OV.VCIdPlanOpcion, OV.VCIdVigencia;

/* 11. Reglas de sexo de las opciones, sin filtrar estatus. */
;WITH OpcionesCaso AS
(
    SELECT DISTINCT PS.POIdPlanOpcion
    FROM dbo.ff_PlanOpcionSeleccion PS
    INNER JOIN dbo.ff_Solicitud S
        ON S.SOIdSolicitud = PS.POIdSolicitud
    WHERE S.SOIdEmpleado = @IdTitular
       OR (S.SONumEmpleado = @NumeroEmpleado AND S.SOIdEmpresa = @IdEmpresa)
)
SELECT
    '11_REGLAS_SEXO_SIN_FILTRO_ESTATUS' AS bloque,
    OS.*,
    O.PONombre AS opcion
FROM OpcionesCaso C
INNER JOIN dbo.ff_PlanOpcionSexo OS
    ON OS.PSIdPlanOpcion = C.POIdPlanOpcion
LEFT JOIN dbo.ff_PlanOpcion O
    ON O.POIdPlanOpcion = OS.PSIdPlanOpcion
ORDER BY OS.PSIdPlanOpcion, OS.PSIdSexo;

/* 12. Reglas de parentesco y edad, sin filtrar estatus. */
;WITH OpcionesCaso AS
(
    SELECT DISTINCT PS.POIdPlanOpcion
    FROM dbo.ff_PlanOpcionSeleccion PS
    INNER JOIN dbo.ff_Solicitud S
        ON S.SOIdSolicitud = PS.POIdSolicitud
    WHERE S.SOIdEmpleado = @IdTitular
       OR (S.SONumEmpleado = @NumeroEmpleado AND S.SOIdEmpresa = @IdEmpresa)
)
SELECT
    '12_REGLAS_PARENTESCO_EDAD_SIN_FILTRO_ESTATUS' AS bloque,
    PE.*,
    PA.PANombre AS parentesco,
    O.PONombre AS opcion
FROM OpcionesCaso C
INNER JOIN dbo.ff_PlanOpcionParentescoEdad PE
    ON PE.PPIdPlanOpcion = C.POIdPlanOpcion
LEFT JOIN dbo.ff_Parentesco PA
    ON PA.PAIdParentesco = PE.PPIdParentesco
LEFT JOIN dbo.ff_PlanOpcion O
    ON O.POIdPlanOpcion = PE.PPIdPlanOpcion
ORDER BY PE.PPIdPlanOpcion, PE.PPIdParentesco, PE.PPEdadMin;

/* 13. Todas las tarifas actuales relacionadas, sin filtrar estatus o vigencia. */
;WITH OpcionesCaso AS
(
    SELECT DISTINCT PS.POIdPlanOpcion
    FROM dbo.ff_PlanOpcionSeleccion PS
    INNER JOIN dbo.ff_Solicitud S
        ON S.SOIdSolicitud = PS.POIdSolicitud
    WHERE S.SOIdEmpleado = @IdTitular
       OR (S.SONumEmpleado = @NumeroEmpleado AND S.SOIdEmpresa = @IdEmpresa)
)
SELECT
    '13_TARIFAS_ACTUALES_SIN_FILTROS' AS bloque,
    TC.*,
    TA.TAIdVigencia,
    TA.TANombre AS tarifa,
    TA.TAIdEstatus AS estatusTarifa,
    GP.GPNombre AS grupoParentesco,
    PA.PANombre AS parentesco,
    O.PONombre AS opcion
FROM OpcionesCaso C
INNER JOIN dbo.ff_TarifaCosto TC
    ON TC.TCIdPlanOpcion = C.POIdPlanOpcion
LEFT JOIN dbo.ff_Tarifa TA
    ON TA.TAIdTarifa = TC.TCIdTarifa
LEFT JOIN dbo.ff_GrupoParentesco GP
    ON GP.GPIdGrupoParentesco = TC.TCIdGrupoParentesco
LEFT JOIN dbo.ff_Parentesco PA
    ON PA.PAIdParentesco = TC.TCIdParentesco
LEFT JOIN dbo.ff_PlanOpcion O
    ON O.POIdPlanOpcion = TC.TCIdPlanOpcion
ORDER BY TC.TCIdPlanOpcion, TA.TAIdVigencia, TC.TCIdTarifaCosto;

/* 14. Todas las tarifas historicas relacionadas, sin filtrar estatus o vigencia. */
;WITH OpcionesCaso AS
(
    SELECT DISTINCT PS.POIdPlanOpcion
    FROM dbo.ff_PlanOpcionSeleccion PS
    INNER JOIN dbo.ff_Solicitud S
        ON S.SOIdSolicitud = PS.POIdSolicitud
    WHERE S.SOIdEmpleado = @IdTitular
       OR (S.SONumEmpleado = @NumeroEmpleado AND S.SOIdEmpresa = @IdEmpresa)
)
SELECT
    '14_TARIFAS_HISTORICAS_SIN_FILTROS' AS bloque,
    TC.*,
    TA.TAIdVigencia,
    TA.TANombre AS tarifa,
    TA.TAIdEstatus AS estatusTarifa,
    GP.GPNombre AS grupoParentesco,
    PA.PANombre AS parentesco,
    O.PONombre AS opcion
FROM OpcionesCaso C
INNER JOIN dbo.ff_TarifaCosto_hist TC
    ON TC.TCIdPlanOpcion = C.POIdPlanOpcion
LEFT JOIN dbo.ff_Tarifa TA
    ON TA.TAIdTarifa = TC.TCIdTarifa
LEFT JOIN dbo.ff_GrupoParentesco GP
    ON GP.GPIdGrupoParentesco = TC.TCIdGrupoParentesco
LEFT JOIN dbo.ff_Parentesco PA
    ON PA.PAIdParentesco = TC.TCIdParentesco
LEFT JOIN dbo.ff_PlanOpcion O
    ON O.POIdPlanOpcion = TC.TCIdPlanOpcion
ORDER BY TC.TCIdPlanOpcion, TA.TAIdVigencia, TC.TCIdTarifaCosto;

/* 15. Planes basicos del perfil, sin filtrar estatus ni vigencia. */
SELECT
    '15_PLANES_BASICOS_PERFIL_SIN_FILTROS' AS bloque,
    PB.*,
    PBD.*,
    O.PONombre AS opcion,
    PL.PLNombre AS planNombre,
    PA.PANombre AS parentescoDetalle,
    GP.GPNombre AS grupoDetalle
FROM dbo.ff_PlanBasico PB
LEFT JOIN dbo.ff_PlanBasicoDetalle PBD
    ON PBD.PBIdPlanBasico = PB.PBIdPlanBasico
LEFT JOIN dbo.ff_PlanOpcion O
    ON O.POIdPlanOpcion = PB.PBIdPlanOpcion
LEFT JOIN dbo.ff_Plan PL
    ON PL.PLIdPlan = O.POIdPlan
LEFT JOIN dbo.ff_Parentesco PA
    ON PA.PAIdParentesco = PBD.PBIdParentesco
LEFT JOIN dbo.ff_GrupoParentesco GP
    ON GP.GPIdGrupoParentesco = PBD.PBIdGrupoParentesco
WHERE PB.PBIdPerfil IN
      (
          SELECT DISTINCT E.EMIdPerfil
          FROM dbo.ff_Empleado E
          WHERE E.Id = @IdTitular
             OR E.EMIdTitular = @IdTitular
      )
ORDER BY PB.PBIdPlanBasico, PBD.PBIdPlanBasicoDetalle;

/* 16. Homologaciones donde participa cualquier opcion del historial. */
;WITH OpcionesCaso AS
(
    SELECT DISTINCT PS.POIdPlanOpcion
    FROM dbo.ff_PlanOpcionSeleccion PS
    INNER JOIN dbo.ff_Solicitud S
        ON S.SOIdSolicitud = PS.POIdSolicitud
    WHERE S.SOIdEmpleado = @IdTitular
       OR (S.SONumEmpleado = @NumeroEmpleado AND S.SOIdEmpresa = @IdEmpresa)
)
SELECT
    '16_HOMOLOGACIONES_SIN_FILTRO_ESTATUS' AS bloque,
    PH.*
FROM dbo.ff_PlanOpcionHomologacion PH
WHERE PH.PHIdPlanOpcionAnt IN (SELECT C.POIdPlanOpcion FROM OpcionesCaso C)
   OR PH.PHIdPlanOpcionAct IN (SELECT C.POIdPlanOpcion FROM OpcionesCaso C)
ORDER BY PH.PHIdPlanOpcionHomologacion;

/* 16B. Relaciones configuradas para los planes presentes en el historial. */
;WITH PlanesCaso AS
(
    SELECT DISTINCT O.POIdPlan
    FROM dbo.ff_PlanOpcionSeleccion PS
    INNER JOIN dbo.ff_PlanOpcion O
        ON O.POIdPlanOpcion = PS.POIdPlanOpcion
    INNER JOIN dbo.ff_Solicitud S
        ON S.SOIdSolicitud = PS.POIdSolicitud
    WHERE S.SOIdEmpleado = @IdTitular
       OR (S.SONumEmpleado = @NumeroEmpleado AND S.SOIdEmpresa = @IdEmpresa)
)
SELECT
    '16B_RELACIONES_PLAN_SIN_FILTRO_ESTATUS' AS bloque,
    PR.*,
    PL.PLNombre AS planNombre
FROM dbo.ff_PlanRelacion PR
LEFT JOIN dbo.ff_Plan PL
    ON PL.PLIdPlan = PR.PRIdPlan
WHERE PR.PRIdPlan IN (SELECT P.POIdPlan FROM PlanesCaso P)
ORDER BY PR.PRIdPlan, PR.PRIdPlanRelacion;

/* 17. Configuracion del motor para la empresa, sin filtrar Activo. */
SELECT
    '17_CONFIGURACION_MOTOR_EMPRESA' AS bloque,
    PPS.*
FROM dbo.ff_PlanesPerfilScript PPS
WHERE PPS.EMIdEmpresa = @IdEmpresa
ORDER BY PPS.Id;

/* 18. Registros que relacionan solicitudes con el proceso de defaulteo. */
SELECT
    '18_SOLICITUDES_GENERADAS_DEFAULTEO' AS bloque,
    SD.*
FROM dbo.bf_SolicitudDefaulteoGenerada SD
WHERE SD.SDIdEmpleado IN
      (
          SELECT E.Id
          FROM dbo.ff_Empleado E
          WHERE E.Id = @IdTitular
             OR E.EMIdTitular = @IdTitular
      )
   OR SD.SDIdSolicitud IN
      (
          SELECT S.SOIdSolicitud
          FROM dbo.ff_Solicitud S
          WHERE S.SOIdEmpleado = @IdTitular
             OR
                (
                    S.SONumEmpleado = @NumeroEmpleado
                    AND S.SOIdEmpresa = @IdEmpresa
                )
      )
ORDER BY SD.SDId;

/* 19. Todos los logs de defaulteo de la empresa, sin filtrar fecha o estado. */
SELECT
    '19_LOGS_DEFAULTEO_EMPRESA_SIN_FILTROS' AS bloque,
    L.*
FROM dbo.bf_LogDefaulteo L
WHERE L.LDIdEmpresa = @IdEmpresa
ORDER BY L.LDFechaInicio DESC, L.LDId DESC;

/* 20. Todos los errores registrados para la familia, sin filtrar fecha. */
SELECT
    '20_ERRORES_DEFAULTEO_FAMILIA_SIN_FILTROS' AS bloque,
    E.*
FROM dbo.bf_LogErroresDefaulteo E
WHERE E.LEDIdEmpleado IN
      (
          SELECT F.Id
          FROM dbo.ff_Empleado F
          WHERE F.Id = @IdTitular
             OR F.EMIdTitular = @IdTitular
      )
   OR
      (
          E.LEDNumeroEmpleado = @NumeroEmpleado
          AND E.LEDIdEmpresa = @IdEmpresa
      )
ORDER BY E.LEDFechaAdd DESC, E.LEDId DESC;
