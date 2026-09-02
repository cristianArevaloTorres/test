/*
    DATOS DUMMY PARA DEFAULTEO 1, 2 Y 3 - EMPRESA 186

    Crea exactamente 90 titulares aislados e idempotentes:
      QD1-186-001 a QD1-186-030: 30 casos para Defaulteo tipo 1.
      QD2-186-001 a QD2-186-030: 30 casos para Defaulteo tipo 2.
      QD3-186-001 a QD3-186-030: 30 casos para Defaulteo tipo 3.

    En tipo 3, los casos 001 a 015 incluyen un dependiente activo y los casos
    016 a 030 sirven como control sin dependientes.

    Vigencia origen: 3924 (2025-2026).
    Vigencia destino: 4235 (2026-2027).
    No ejecuta el motor de defaulteo; prepara los insumos para probarlo.

    SOLO QA: la vigencia 4235 debe tener estatus 1 para que la pantalla y
    bf_DefaulteoAvanzado_ResolverVigencia la acepten. La variable
    @ActivarVigenciaDestino permite realizar esa activacion de forma explicita.
    La configuracion 40 es compartida por varias empresas; no ejecutar en PROD.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_WARNINGS ON;
SET ANSI_PADDING ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @IdEmpresa INT = 186;
/* Pareja BF3 mas reciente de la configuracion 40: 3924 -> 4235. */
DECLARE @IdVigenciaOrigen INT = 3924;
DECLARE @IdVigenciaDestino INT = 4235;
DECLARE @ActivarVigenciaDestino BIT = 1; -- SOLO QA. Use 0 para exigir que ya este activa.
/* Opcion con tarifa de titular, necesaria para que V31 produzca renglones Checked. */
DECLARE @IdPlanOpcion INT = 1775;
DECLARE @IdPlan INT = 2050;
DECLARE @IdRamo INT = 159;
DECLARE @IdTarifaFuente INT = 2047;
DECLARE @IdTarifaDummy INT = 918604;
DECLARE @IdTarifaDummyOrigen INT = 918605;
DECLARE @UsuarioDummy INT = 0;
DECLARE @Ahora DATETIME = GETDATE();

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM dbo.ff_Empresa WHERE EMIdEmpresa=@IdEmpresa)
        THROW 51300, 'No existe la empresa 186.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.ff_Vigencia WHERE VIIdVigencia=@IdVigenciaOrigen)
        THROW 51301, 'No existe la vigencia origen 3924.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.ff_Vigencia WHERE VIIdVigencia=@IdVigenciaDestino)
        THROW 51302, 'No existe la vigencia destino 4235.', 1;

    DECLARE @IdConfiguracionEmpresa INT =
    (
        SELECT EMIdConfiguracion
        FROM dbo.ff_Empresa
        WHERE EMIdEmpresa=@IdEmpresa
    );

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ff_Vigencia
        WHERE VIIdVigencia=@IdVigenciaOrigen
          AND VIIdConfiguracion=@IdConfiguracionEmpresa
    )
        THROW 51309, 'La vigencia origen no pertenece a la configuracion de la empresa 186.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ff_Vigencia
        WHERE VIIdVigencia=@IdVigenciaDestino
          AND VIIdConfiguracion=@IdConfiguracionEmpresa
          AND VIRenovada=@IdVigenciaOrigen
          AND VITipoNegocio=1
    )
        THROW 51310, 'La vigencia destino no es BF3 tipo 1 o no renueva a la vigencia origen.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.ff_Vigencia
        WHERE VIIdVigencia=@IdVigenciaDestino
          AND VIIdEstatus=1
    )
    BEGIN
        IF @ActivarVigenciaDestino=0
            THROW 51311, 'La vigencia destino 4235 no tiene estatus 1. Active @ActivarVigenciaDestino solo en QA.', 1;

        UPDATE dbo.ff_Vigencia
        SET VIIdEstatus=1,
            VIUsuarioUMod=@UsuarioDummy,
            VIFechaUMod=@Ahora
        WHERE VIIdVigencia=@IdVigenciaDestino;
    END;
    IF NOT EXISTS (SELECT 1 FROM dbo.ff_PlanOpcion WHERE POIdPlanOpcion=@IdPlanOpcion AND POIdEstatus=1)
        THROW 51303, 'No existe la opcion de plan 1775 activa.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.ff_Perfil WHERE PEIdPerfil=678 AND PEIdEmpresa=@IdEmpresa)
        THROW 51304, 'No existe el perfil fuente 678.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.ff_Perfil WHERE PEIdPerfil=680 AND PEIdEmpresa=@IdEmpresa)
        THROW 51305, 'No existe el perfil fuente 680.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.ff_TarifaCosto WHERE TCIdTarifa=@IdTarifaFuente AND TCIdPlanOpcion=@IdPlanOpcion)
        THROW 51306, 'La tarifa fuente no tiene costos para la opción seleccionada.', 1;

    /* Perfiles exclusivos para no volver elegibles a empleados reales. */
    DECLARE @PerfilTipo13 INT;
    DECLARE @PerfilTipo2 INT;

    SELECT @PerfilTipo13=PEIdPerfil
    FROM dbo.ff_Perfil
    WHERE PEIdEmpresa=@IdEmpresa AND PENombre='QA DEF 1-3';

    IF @PerfilTipo13 IS NULL
    BEGIN
        INSERT dbo.ff_Perfil
        (
            PEIdEmpresa,PENombre,PEDescripcion,PEIdPeriodicidadNomina,
            PEMuestraSueldo,PEAdministrador,PEIdRolDefault,PECarpetaDefault,
            PEIdEstatus,PEUsuarioAdd,PEFechaAdd,PEUsuarioUMod,PEFechaUMod,
            PEUsuarioDel,PEFechaDel
        )
        SELECT
            @IdEmpresa,'QA DEF 1-3','QA DUMMY DEFAULTEO TIPOS 1 Y 3',
            PEIdPeriodicidadNomina,PEMuestraSueldo,PEAdministrador,
            PEIdRolDefault,PECarpetaDefault,1,@UsuarioDummy,@Ahora,
            @UsuarioDummy,@Ahora,NULL,NULL
        FROM dbo.ff_Perfil
        WHERE PEIdPerfil=680;

        SET @PerfilTipo13=CONVERT(INT,SCOPE_IDENTITY());
    END;

    SELECT @PerfilTipo2=PEIdPerfil
    FROM dbo.ff_Perfil
    WHERE PEIdEmpresa=@IdEmpresa AND PENombre='QA DEF 2';

    IF @PerfilTipo2 IS NULL
    BEGIN
        INSERT dbo.ff_Perfil
        (
            PEIdEmpresa,PENombre,PEDescripcion,PEIdPeriodicidadNomina,
            PEMuestraSueldo,PEAdministrador,PEIdRolDefault,PECarpetaDefault,
            PEIdEstatus,PEUsuarioAdd,PEFechaAdd,PEUsuarioUMod,PEFechaUMod,
            PEUsuarioDel,PEFechaDel
        )
        SELECT
            @IdEmpresa,'QA DEF 2','QA DUMMY DEFAULTEO TIPO 2',
            PEIdPeriodicidadNomina,PEMuestraSueldo,PEAdministrador,
            PEIdRolDefault,PECarpetaDefault,1,@UsuarioDummy,@Ahora,
            @UsuarioDummy,@Ahora,NULL,NULL
        FROM dbo.ff_Perfil
        WHERE PEIdPerfil=678;

        SET @PerfilTipo2=CONVERT(INT,SCOPE_IDENTITY());
    END;

    /* Elegibilidad de la opción real para ambos perfiles dummy. */
    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.ff_PlanOpcionPerfil
        WHERE PPIdPlanOpcion=@IdPlanOpcion AND PPIdPerfil=@PerfilTipo13 AND PPIdEstatus=1
    )
        INSERT dbo.ff_PlanOpcionPerfil
        (PPIdPlanOpcion,PPIdPerfil,PPIdEstatus,PPUsuarioAdd,PPFechaAdd,PPUsuarioUMod,PPFechaUMod)
        VALUES(@IdPlanOpcion,@PerfilTipo13,1,@UsuarioDummy,@Ahora,@UsuarioDummy,@Ahora);

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.ff_PlanOpcionPerfil
        WHERE PPIdPlanOpcion=@IdPlanOpcion AND PPIdPerfil=@PerfilTipo2 AND PPIdEstatus=1
    )
        INSERT dbo.ff_PlanOpcionPerfil
        (PPIdPlanOpcion,PPIdPerfil,PPIdEstatus,PPUsuarioAdd,PPFechaAdd,PPUsuarioUMod,PPFechaUMod)
        VALUES(@IdPlanOpcion,@PerfilTipo2,1,@UsuarioDummy,@Ahora,@UsuarioDummy,@Ahora);

    /* Relaciones de elegibilidad que consume V31 antes de cotizar. */
    INSERT dbo.ff_PlanOpcionSexo
    (PSIdPlanOpcion,PSIdSexo,PSIdEstatus,PSUsuarioAdd,PSFechaAdd,PSUsuarioUMod,PSFechaUMod)
    SELECT @IdPlanOpcion,S.IdSexo,1,@UsuarioDummy,@Ahora,@UsuarioDummy,@Ahora
    FROM (VALUES(1),(2)) S(IdSexo)
    WHERE NOT EXISTS
      (SELECT 1 FROM dbo.ff_PlanOpcionSexo X
       WHERE X.PSIdPlanOpcion=@IdPlanOpcion AND X.PSIdSexo=S.IdSexo AND X.PSIdEstatus=1);

    INSERT dbo.ff_PlanOpcionParentescoEdad
    (PPIdPlanOpcion,PPIdParentesco,PPEdadMin,PPEdadMax,PPEdadMinR,PPEdadMaxR,
     PPIdEstatus,PPUsuarioAdd,PPFechaAdd,PPUsuarioUMod,PPFechaUMod,PPAplicaReporte)
    SELECT @IdPlanOpcion,P.IdParentesco,0,120,0,120,
           1,@UsuarioDummy,@Ahora,@UsuarioDummy,@Ahora,0
    FROM (VALUES(1),(2),(3)) P(IdParentesco)
    WHERE NOT EXISTS
      (SELECT 1 FROM dbo.ff_PlanOpcionParentescoEdad X
       WHERE X.PPIdPlanOpcion=@IdPlanOpcion
         AND X.PPIdParentesco=P.IdParentesco AND X.PPIdEstatus=1);

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.ff_PlanOpcionVigencia
        WHERE VCIdPlanOpcion=@IdPlanOpcion AND VCIdVigencia=@IdVigenciaOrigen
    )
        INSERT dbo.ff_PlanOpcionVigencia
        (VCIdPlanOpcion,VCIdVigencia,VCIdEstatus,VCUsuarioAdd,VCFechaAdd,VCUsuarioUMod,VCFechaUMod)
        VALUES(@IdPlanOpcion,@IdVigenciaOrigen,2,@UsuarioDummy,@Ahora,@UsuarioDummy,@Ahora);
    ELSE
        UPDATE dbo.ff_PlanOpcionVigencia
        SET VCIdEstatus=2,VCUsuarioUMod=@UsuarioDummy,VCFechaUMod=@Ahora
        WHERE VCIdPlanOpcion=@IdPlanOpcion AND VCIdVigencia=@IdVigenciaOrigen;

    /* El SP multivigencia filtra expresamente VCIdEstatus=2 en la vigencia origen
       del cálculo (@idVigenciaD).  En esta tabla 2 representa la relación publicada. */
    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.ff_PlanOpcionVigencia
        WHERE VCIdPlanOpcion=@IdPlanOpcion AND VCIdVigencia=@IdVigenciaDestino
    )
        INSERT dbo.ff_PlanOpcionVigencia
        (VCIdPlanOpcion,VCIdVigencia,VCIdEstatus,VCUsuarioAdd,VCFechaAdd,VCUsuarioUMod,VCFechaUMod)
        VALUES(@IdPlanOpcion,@IdVigenciaDestino,2,@UsuarioDummy,@Ahora,@UsuarioDummy,@Ahora);
    ELSE
        UPDATE dbo.ff_PlanOpcionVigencia
        SET VCIdEstatus=2,VCUsuarioUMod=@UsuarioDummy,VCFechaUMod=@Ahora
        WHERE VCIdPlanOpcion=@IdPlanOpcion AND VCIdVigencia=@IdVigenciaDestino;

    /* Tarifa minima realista para que el motor pueda cotizar la opcion en destino. */
    IF EXISTS (SELECT 1 FROM dbo.ff_Tarifa WHERE TAIdTarifa=@IdTarifaDummy AND TAIdVigencia<>@IdVigenciaDestino)
        THROW 51307, 'El ID de tarifa dummy ya está ocupado por otra vigencia.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.ff_Tarifa WHERE TAIdTarifa=@IdTarifaDummy)
        INSERT dbo.ff_Tarifa
        (TAIdTarifa,TANombre,TADescripcion,TAIdVigencia,TAIdEstatus,
         TAUsuarioAdd,TAFechaAdd,TAUsuarioUMod,TAFechaUMod)
        VALUES
        (@IdTarifaDummy,'QA DUMMY DEF 186 V4235','QA DUMMY DEF 186 V4235',
         @IdVigenciaDestino,2,@UsuarioDummy,@Ahora,@UsuarioDummy,@Ahora);
    ELSE
        UPDATE dbo.ff_Tarifa
        SET TAIdEstatus=2,TAUsuarioUMod=@UsuarioDummy,TAFechaUMod=@Ahora
        WHERE TAIdTarifa=@IdTarifaDummy;

    IF EXISTS (SELECT 1 FROM dbo.ff_Tarifa WHERE TAIdTarifa=@IdTarifaDummyOrigen AND TAIdVigencia<>@IdVigenciaOrigen)
        THROW 51308, 'El ID de tarifa dummy de origen ya está ocupado por otra vigencia.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.ff_Tarifa WHERE TAIdTarifa=@IdTarifaDummyOrigen)
        INSERT dbo.ff_Tarifa
        (TAIdTarifa,TANombre,TADescripcion,TAIdVigencia,TAIdEstatus,
         TAUsuarioAdd,TAFechaAdd,TAUsuarioUMod,TAFechaUMod)
        VALUES
        (@IdTarifaDummyOrigen,'QA DUMMY DEF 186 V3924','QA DUMMY DEF 186 V3924',
         @IdVigenciaOrigen,2,@UsuarioDummy,@Ahora,@UsuarioDummy,@Ahora);
    ELSE
        UPDATE dbo.ff_Tarifa
        SET TAIdEstatus=2,TAUsuarioUMod=@UsuarioDummy,TAFechaUMod=@Ahora
        WHERE TAIdTarifa=@IdTarifaDummyOrigen;

    INSERT dbo.ff_TarifaCosto
    (
        TCIdTarifa,TCIdPlanOpcion,TCIdTipoTarifa,TCIdGrupoParentesco,
        TCIdParentesco,TCIdSexo,TCEdad,TCIdTipoFumador,TCPrimaNeta,
        TCPrimaTotal,TCIdEstatus,TCUsuarioAdd,TCFechaAdd,
        TCUsuarioUMod,TCFechaUMod,TCUsuarioDel,TCFechaDel
    )
    SELECT
        @IdTarifaDummy,S.TCIdPlanOpcion,S.TCIdTipoTarifa,S.TCIdGrupoParentesco,
        S.TCIdParentesco,S.TCIdSexo,S.TCEdad,S.TCIdTipoFumador,S.TCPrimaNeta,
        S.TCPrimaTotal,1,@UsuarioDummy,@Ahora,@UsuarioDummy,@Ahora,NULL,NULL
    FROM dbo.ff_TarifaCosto S
    WHERE S.TCIdTarifa=@IdTarifaFuente
      AND S.TCIdPlanOpcion=@IdPlanOpcion
      AND S.TCIdEstatus=1
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.ff_TarifaCosto D
          WHERE D.TCIdTarifa=@IdTarifaDummy
            AND D.TCIdPlanOpcion=S.TCIdPlanOpcion
            AND D.TCIdTipoTarifa=S.TCIdTipoTarifa
            AND ISNULL(D.TCIdGrupoParentesco,-1)=ISNULL(S.TCIdGrupoParentesco,-1)
            AND ISNULL(D.TCIdParentesco,-1)=ISNULL(S.TCIdParentesco,-1)
            AND ISNULL(D.TCIdSexo,-1)=ISNULL(S.TCIdSexo,-1)
            AND ISNULL(D.TCEdad,-1)=ISNULL(S.TCEdad,-1)
            AND ISNULL(D.TCIdTipoFumador,-1)=ISNULL(S.TCIdTipoFumador,-1)
      );

    /* El motor V31 multivigencia cotiza contra ff_TarifaCosto_hist. La carga en
       ff_TarifaCosto se conserva porque otros flujos usan la tabla vigente. */
    INSERT dbo.ff_TarifaCosto_hist
    (
        TCIdTarifa,TCIdPlanOpcion,TCIdTipoTarifa,TCIdGrupoParentesco,
        TCIdParentesco,TCIdSexo,TCEdad,TCIdTipoFumador,TCPrimaNeta,
        TCPrimaTotal,TCIdEstatus,TCUsuarioAdd,TCFechaAdd,
        TCUsuarioUMod,TCFechaUMod,TCUsuarioDel,TCFechaDel
    )
    SELECT
        @IdTarifaDummy,S.TCIdPlanOpcion,S.TCIdTipoTarifa,S.TCIdGrupoParentesco,
        S.TCIdParentesco,S.TCIdSexo,S.TCEdad,S.TCIdTipoFumador,S.TCPrimaNeta,
        S.TCPrimaTotal,1,@UsuarioDummy,@Ahora,@UsuarioDummy,@Ahora,NULL,NULL
    FROM dbo.ff_TarifaCosto S
    WHERE S.TCIdTarifa=@IdTarifaDummy
      AND S.TCIdPlanOpcion=@IdPlanOpcion
      AND S.TCIdEstatus=1
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.ff_TarifaCosto_hist H
          WHERE H.TCIdTarifa=@IdTarifaDummy
            AND H.TCIdPlanOpcion=S.TCIdPlanOpcion
            AND H.TCIdTipoTarifa=S.TCIdTipoTarifa
            AND ISNULL(H.TCIdGrupoParentesco,-1)=ISNULL(S.TCIdGrupoParentesco,-1)
            AND ISNULL(H.TCIdParentesco,-1)=ISNULL(S.TCIdParentesco,-1)
            AND ISNULL(H.TCIdSexo,-1)=ISNULL(S.TCIdSexo,-1)
            AND ISNULL(H.TCEdad,-1)=ISNULL(S.TCEdad,-1)
            AND ISNULL(H.TCIdTipoFumador,-1)=ISNULL(S.TCIdTipoFumador,-1)
      );

    INSERT dbo.ff_TarifaCosto_hist
    (
        TCIdTarifa,TCIdPlanOpcion,TCIdTipoTarifa,TCIdGrupoParentesco,
        TCIdParentesco,TCIdSexo,TCEdad,TCIdTipoFumador,TCPrimaNeta,
        TCPrimaTotal,TCIdEstatus,TCUsuarioAdd,TCFechaAdd,
        TCUsuarioUMod,TCFechaUMod,TCUsuarioDel,TCFechaDel
    )
    SELECT
        @IdTarifaDummyOrigen,S.TCIdPlanOpcion,S.TCIdTipoTarifa,S.TCIdGrupoParentesco,
        S.TCIdParentesco,S.TCIdSexo,S.TCEdad,S.TCIdTipoFumador,S.TCPrimaNeta,
        S.TCPrimaTotal,1,@UsuarioDummy,@Ahora,@UsuarioDummy,@Ahora,NULL,NULL
    FROM dbo.ff_TarifaCosto S
    WHERE S.TCIdTarifa=@IdTarifaDummy
      AND S.TCIdPlanOpcion=@IdPlanOpcion
      AND S.TCIdEstatus=1
      AND NOT EXISTS
      (
          SELECT 1 FROM dbo.ff_TarifaCosto_hist H
          WHERE H.TCIdTarifa=@IdTarifaDummyOrigen
            AND H.TCIdPlanOpcion=S.TCIdPlanOpcion
            AND H.TCIdTipoTarifa=S.TCIdTipoTarifa
            AND ISNULL(H.TCIdGrupoParentesco,-1)=ISNULL(S.TCIdGrupoParentesco,-1)
            AND ISNULL(H.TCIdParentesco,-1)=ISNULL(S.TCIdParentesco,-1)
            AND ISNULL(H.TCIdSexo,-1)=ISNULL(S.TCIdSexo,-1)
            AND ISNULL(H.TCEdad,-1)=ISNULL(S.TCEdad,-1)
            AND ISNULL(H.TCIdTipoFumador,-1)=ISNULL(S.TCIdTipoFumador,-1)
      );

    INSERT dbo.ff_VigenciaCalendarioPago
        (
            VCIdVigencia,VCIdPeriodicidadPago,VCConsecutivo,VCFechaPago,
            VCFechaPeriodoIni,VCFechaPeriodoFin,VCPA_Visible,VCIdEstatus,
            VCUsuarioAdd,VCFechaAdd,VCUsuarioUMod,VCFechaUMod
        )
    SELECT V.VIIdVigencia,8,1,V.VIVigenciaFin,V.VIVigenciaIni,V.VIVigenciaFin,
           1,1,@UsuarioDummy,@Ahora,@UsuarioDummy,@Ahora
    FROM dbo.ff_Vigencia V
    WHERE V.VIIdVigencia IN(@IdVigenciaOrigen,@IdVigenciaDestino)
      AND NOT EXISTS
      (SELECT 1 FROM dbo.ff_VigenciaCalendarioPago C
       WHERE C.VCIdVigencia=V.VIIdVigencia
         AND C.VCIdPeriodicidadPago=8 AND C.VCIdEstatus=1);

    /* Plan espejo de los perfiles QA. Tipo 2 lo usa directamente y tipo 3 lo
       usa cuando reconstruye el nucleo familiar. */
    INSERT dbo.ff_PlanBasico
        (
            PBIdVigencia,PBIdPerfil,PBIdPlanOpcion,PBFlexible,
            PBParentescoDefaulteo,PBFormaCredito,PBIdCompensacion,
            PBIdOficina,PBIdEstatus,PBUsuarioAdd,PBFechaAdd,
            PBUsuarioUMod,PBFechaUMod,PBUsuarioDel,PBFechaDel,
            PBIdPlan,PBSoloCotizacion
        )
    SELECT V.IdVigencia,P.IdPerfil,@IdPlanOpcion,'0',1,'0',NULL,
           NULL,1,@UsuarioDummy,@Ahora,@UsuarioDummy,@Ahora,NULL,NULL,@IdPlan,0
    FROM (VALUES(@PerfilTipo13),(@PerfilTipo2)) P(IdPerfil)
    CROSS JOIN (VALUES(@IdVigenciaOrigen),(@IdVigenciaDestino)) V(IdVigencia)
    WHERE NOT EXISTS
      (SELECT 1 FROM dbo.ff_PlanBasico B
       WHERE B.PBIdVigencia=V.IdVigencia AND B.PBIdPerfil=P.IdPerfil
         AND B.PBIdPlanOpcion=@IdPlanOpcion AND B.PBIdEstatus=1);

    UPDATE dbo.ff_PlanBasico
    SET PBFlexible='0',PBParentescoDefaulteo=1,PBFormaCredito='0',
        PBIdEstatus=1,PBUsuarioUMod=@UsuarioDummy,PBFechaUMod=@Ahora
    WHERE PBIdVigencia IN(@IdVigenciaOrigen,@IdVigenciaDestino)
      AND PBIdPerfil IN(@PerfilTipo13,@PerfilTipo2)
      AND PBIdPlanOpcion=@IdPlanOpcion;

    INSERT dbo.ff_PlanBasicoDetalle
    (PBIdPlanBasico,PBConsecutivo,PBIdParentesco,PBIdGrupoParentesco,
     PBCantidad,PBPorcentaje,PBIdEstatus,PBUsuarioAdd,PBFechaAdd,
     PBUsuarioUMod,PBFechaUMod)
    SELECT B.PBIdPlanBasico,1,1,NULL,0,100,1,
           @UsuarioDummy,@Ahora,@UsuarioDummy,@Ahora
    FROM dbo.ff_PlanBasico B
    WHERE B.PBIdVigencia IN(@IdVigenciaOrigen,@IdVigenciaDestino)
      AND B.PBIdPerfil IN(@PerfilTipo13,@PerfilTipo2)
      AND B.PBIdPlanOpcion=@IdPlanOpcion AND B.PBIdEstatus=1
      AND NOT EXISTS
        (SELECT 1 FROM dbo.ff_PlanBasicoDetalle D
         WHERE D.PBIdPlanBasico=B.PBIdPlanBasico
           AND D.PBIdParentesco=1 AND D.PBIdEstatus=1);

    /* Construye un INSERT de empleado copiando las columnas no identity. */
    DECLARE @ColumnasEmpleado NVARCHAR(MAX);
    DECLARE @ValoresEmpleado NVARCHAR(MAX);
    DECLARE @SqlEmpleado NVARCHAR(MAX);

    SELECT @ColumnasEmpleado=STUFF
    ((
        SELECT ','+QUOTENAME(C.name)
        FROM sys.columns C
        WHERE C.object_id=OBJECT_ID('dbo.ff_Empleado')
          AND C.is_identity=0
          AND C.is_computed=0
        ORDER BY C.column_id
        FOR XML PATH(''),TYPE
    ).value('.','nvarchar(max)'),1,1,'');

    SELECT @ValoresEmpleado=STUFF
    ((
        SELECT ','+
        CASE C.name
            WHEN 'EMIdEmpresa' THEN '186'
            WHEN 'EMNumeroEmpleado' THEN '@Numero'
            WHEN 'EMIdPerfil' THEN '@Perfil'
            WHEN 'EMIdTitular' THEN '@Titular'
            WHEN 'EMIdParentesco' THEN '@Parentesco'
            WHEN 'EMIdSexo' THEN '@Sexo'
            WHEN 'EMIdAcceso' THEN '1'
            WHEN 'EMIdEstatus' THEN '1'
            WHEN 'EMApellidoPaterno' THEN '''PRUEBA'''
            WHEN 'EMApellidoMaterno' THEN '''DEFAULTEO'''
            WHEN 'EMNombre1' THEN '@Nombre'
            WHEN 'EMNombre2' THEN ''''''
            WHEN 'EMFechaNacimiento' THEN 'CASE WHEN @Parentesco=1 THEN CONVERT(datetime,''1985-01-15'') ELSE CONVERT(datetime,''2015-01-15'') END'
            WHEN 'EMFechaIngresoEmpresa' THEN 'CONVERT(datetime,''2010-01-01'')'
            WHEN 'EMFechaAntiguedadGMM' THEN 'CONVERT(datetime,''2010-01-01'')'
            WHEN 'EMFechaAlta' THEN 'CONVERT(datetime,''2010-01-01'')'
            WHEN 'EMCertificado' THEN '@Certificado'
            WHEN 'EMUsuarioAdd' THEN '0'
            WHEN 'EMFechaAdd' THEN 'GETDATE()'
            WHEN 'EMUsuarioUMod' THEN '0'
            WHEN 'EMFechaUMod' THEN 'GETDATE()'
            WHEN 'EMUsuarioDel' THEN 'NULL'
            WHEN 'EMFechaDel' THEN 'NULL'
            ELSE 'SRC.'+QUOTENAME(C.name)
        END
        FROM sys.columns C
        WHERE C.object_id=OBJECT_ID('dbo.ff_Empleado')
          AND C.is_identity=0
          AND C.is_computed=0
        ORDER BY C.column_id
        FOR XML PATH(''),TYPE
    ).value('.','nvarchar(max)'),1,1,'');

    SET @SqlEmpleado=N'
        INSERT dbo.ff_Empleado('+@ColumnasEmpleado+N')
        SELECT '+@ValoresEmpleado+N'
        FROM dbo.ff_Empleado SRC
        WHERE SRC.Id=@Plantilla;
        SET @NuevoId=CONVERT(INT,SCOPE_IDENTITY());';

    DECLARE @PlantillaTitular678 INT=(SELECT TOP(1) Id FROM dbo.ff_Empleado WHERE EMIdEmpresa=186 AND EMIdPerfil=678 AND EMIdParentesco=1 AND EMIdEstatus=1 ORDER BY Id DESC);
    DECLARE @PlantillaTitular680 INT=(SELECT TOP(1) Id FROM dbo.ff_Empleado WHERE EMIdEmpresa=186 AND EMIdPerfil=680 AND EMIdParentesco=1 AND EMIdEstatus=1 ORDER BY Id DESC);
    DECLARE @PlantillaDependiente INT=(SELECT TOP(1) Id FROM dbo.ff_Empleado WHERE EMIdEmpresa=186 AND EMIdParentesco<>1 AND EMIdEstatus=1 ORDER BY Id DESC);

    IF @PlantillaTitular678 IS NULL OR @PlantillaTitular680 IS NULL OR @PlantillaDependiente IS NULL
        THROW 51308, 'No existen empleados fuente suficientes para clonar los casos dummy.', 1;

    DECLARE @Casos TABLE
    (
        TipoDefaulteo INT NOT NULL,
        Consecutivo INT NOT NULL,
        Escenario VARCHAR(20) NOT NULL,
        ConDependiente BIT NOT NULL,
        Numero VARCHAR(20) NOT NULL,
        Perfil INT NOT NULL,
        Plantilla INT NOT NULL,
        Nombre VARCHAR(70) NOT NULL,
        IdEmpleado INT NULL,
        PRIMARY KEY(TipoDefaulteo,Consecutivo),
        UNIQUE(Numero)
    );

    ;WITH N AS
    (
        SELECT 1 AS Numero
        UNION ALL
        SELECT Numero+1 FROM N WHERE Numero<30
    )
    INSERT @Casos
        (TipoDefaulteo,Consecutivo,Escenario,ConDependiente,Numero,Perfil,Plantilla,Nombre)
    SELECT 1,N.Numero,'TIPO1',0,
           CONCAT('QD1-186-',RIGHT('000'+CONVERT(varchar(3),N.Numero),3)),
           @PerfilTipo13,@PlantillaTitular680,
           CONCAT('QA DEF TIPO 1 ',RIGHT('000'+CONVERT(varchar(3),N.Numero),3))
    FROM N
    UNION ALL
    SELECT 2,N.Numero,'TIPO2',0,
           CONCAT('QD2-186-',RIGHT('000'+CONVERT(varchar(3),N.Numero),3)),
           @PerfilTipo2,@PlantillaTitular678,
           CONCAT('QA DEF TIPO 2 ',RIGHT('000'+CONVERT(varchar(3),N.Numero),3))
    FROM N
    UNION ALL
    SELECT 3,N.Numero,'TIPO3',CONVERT(bit,CASE WHEN N.Numero<=15 THEN 1 ELSE 0 END),
           CONCAT('QD3-186-',RIGHT('000'+CONVERT(varchar(3),N.Numero),3)),
           @PerfilTipo13,@PlantillaTitular680,
           CONCAT('QA DEF TIPO 3 ',RIGHT('000'+CONVERT(varchar(3),N.Numero),3))
    FROM N
    OPTION (MAXRECURSION 30);

    DECLARE @Escenario VARCHAR(20),@Numero VARCHAR(20),@Perfil INT,@Plantilla INT,@Nombre VARCHAR(70),@NuevoId INT;
    DECLARE CasosCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT Escenario,Numero,Perfil,Plantilla,Nombre
        FROM @Casos
        ORDER BY TipoDefaulteo,Consecutivo;
    OPEN CasosCursor;
    FETCH NEXT FROM CasosCursor INTO @Escenario,@Numero,@Perfil,@Plantilla,@Nombre;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SELECT @NuevoId=Id
        FROM dbo.ff_Empleado
        WHERE EMIdEmpresa=@IdEmpresa AND EMNumeroEmpleado=@Numero AND EMIdParentesco=1;

        IF @NuevoId IS NULL
            EXEC sys.sp_executesql
                @SqlEmpleado,
                N'@Numero varchar(20),@Perfil int,@Titular int,@Parentesco int,@Sexo int,@Nombre varchar(70),@Certificado varchar(20),@Plantilla int,@NuevoId int OUTPUT',
                @Numero=@Numero,@Perfil=@Perfil,@Titular=1,@Parentesco=1,@Sexo=1,
                @Nombre=@Nombre,@Certificado=@Numero,@Plantilla=@Plantilla,@NuevoId=@NuevoId OUTPUT;

        UPDATE @Casos SET IdEmpleado=@NuevoId WHERE Numero=@Numero;
        SET @NuevoId=NULL;
        FETCH NEXT FROM CasosCursor INTO @Escenario,@Numero,@Perfil,@Plantilla,@Nombre;
    END;
    CLOSE CasosCursor;
    DEALLOCATE CasosCursor;

    /* Normaliza también corridas previas del script (los empleados existentes no se clonan otra vez). */
    UPDATE E
    SET E.EMIdPerfil=C.Perfil,
        E.EMIdTitular=1,
        E.EMIdParentesco=1,
        E.EMIdSexo=1,
        E.EMIdEstatus=1,
        E.EMFechaNacimiento='1985-01-15',
        E.EMEdad=DATEDIFF(YEAR,'1985-01-15',GETDATE())
             - CASE WHEN DATEADD(YEAR,DATEDIFF(YEAR,'1985-01-15',GETDATE()),'1985-01-15')>GETDATE() THEN 1 ELSE 0 END,
        E.EMFechaIngresoEmpresa='2010-01-01',
        E.EMFechaAntiguedadGMM='2010-01-01',
        E.EMUsuarioUMod=@UsuarioDummy,
        E.EMFechaUMod=@Ahora
    FROM dbo.ff_Empleado E
    INNER JOIN @Casos C ON C.IdEmpleado=E.Id;

    /* Los primeros 15 tipo 3 tienen dependiente; los otros 15 son controles. */
    DECLARE @IdEmpleado INT,@IdSolicitud INT,@LegacySeleccion INT,@IdDependiente INT;
    DECLARE DependientesCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT Numero,IdEmpleado
        FROM @Casos
        WHERE TipoDefaulteo=3 AND ConDependiente=1
        ORDER BY Consecutivo;
    OPEN DependientesCursor;
    FETCH NEXT FROM DependientesCursor INTO @Numero,@IdEmpleado;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SET @IdDependiente=NULL;
        SELECT @IdDependiente=Id
        FROM dbo.ff_Empleado
        WHERE EMIdEmpresa=@IdEmpresa
          AND EMNumeroEmpleado=@Numero
          AND EMIdParentesco=2
          AND EMIdTitular=@IdEmpleado;

        IF @IdDependiente IS NULL
            EXEC sys.sp_executesql
                @SqlEmpleado,
                N'@Numero varchar(20),@Perfil int,@Titular int,@Parentesco int,@Sexo int,@Nombre varchar(70),@Certificado varchar(20),@Plantilla int,@NuevoId int OUTPUT',
                @Numero=@Numero,@Perfil=@PerfilTipo13,@Titular=@IdEmpleado,
                @Parentesco=2,@Sexo=2,@Nombre='QA DEPENDIENTE TIPO TRES',
                @Certificado=@Numero,@Plantilla=@PlantillaDependiente,@NuevoId=@IdDependiente OUTPUT;

        FETCH NEXT FROM DependientesCursor INTO @Numero,@IdEmpleado;
    END;
    CLOSE DependientesCursor;
    DEALLOCATE DependientesCursor;

    /* Solicitudes y selecciones aprobadas en la vigencia origen. */
    DECLARE SolicitudesCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT Escenario,Numero,IdEmpleado
        FROM @Casos
        WHERE TipoDefaulteo IN(1,3)
        ORDER BY TipoDefaulteo,Consecutivo;
    OPEN SolicitudesCursor;
    FETCH NEXT FROM SolicitudesCursor INTO @Escenario,@Numero,@IdEmpleado;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SELECT @IdSolicitud=SOIdSolicitud
        FROM dbo.ff_Solicitud
        WHERE SOIdEmpresa=@IdEmpresa
          AND SOIdEmpleado=@IdEmpleado
          AND SOIdVigencia=@IdVigenciaOrigen
          AND SOIdEstatus=1
          AND SOEstatusSolicitud=1;

        IF @IdSolicitud IS NULL
        BEGIN
            INSERT dbo.ff_Solicitud
            (
                SOSolicitudEmpleado,SOIdEmpresa,SOIdEmpleado,SONumEmpleado,
                SOIdRamo,SOIdSolicitudTipo,SOIdEstatus,SOFechaEstatus,
                SODetalleEstatus,SOUsuarioAdd,SOFechaAdd,SOUsuarioUMod,
                SOFechaUMod,SONumeroSolicitud,SOFechaAprovacion,
                SOEstatusSolicitud,SOAnexoSolicitud,SOIdVigencia
            )
            VALUES
            (
                @IdEmpleado,@IdEmpresa,@IdEmpleado,@Numero,@IdRamo,1,1,@Ahora,
                'QA DUMMY APROBADA',@UsuarioDummy,@Ahora,@UsuarioDummy,@Ahora,
                CONVERT(varchar(20),980000000+(@IdEmpleado%10000000)),DATEADD(DAY,-1,@Ahora),1,0,@IdVigenciaOrigen
            );
            SET @IdSolicitud=CONVERT(INT,SCOPE_IDENTITY());
        END;

        IF NOT EXISTS
        (
            SELECT 1 FROM dbo.ff_PlanOpcionSeleccion
            WHERE POIdEmpresa=@IdEmpresa
              AND POIdEmpleado=@IdEmpleado
              AND POIdVigencia=@IdVigenciaOrigen
              AND POIdPlanOpcion=@IdPlanOpcion
              AND POIdEstatus=1
        )
        BEGIN
            SELECT @LegacySeleccion=ISNULL(MAX(POIdPlanOpcionSeleccion),900000000)+1
            FROM dbo.ff_PlanOpcionSeleccion WITH(UPDLOCK,HOLDLOCK);

            INSERT dbo.ff_PlanOpcionSeleccion
            (
                POIdPlanOpcionSeleccion,POIdEmpresaFlexiForbes,POIdEmpresa,
                PONumeroEmpleado,POIdEmpleado,POIdParentesco,POEdad,
                POIdGrupoParentesco,POIdPlanOpcion,POTarifaNeta,POIdSolicitud,
                POAnexo,POCostoRestante,POIdPeriodicidadPago,
                PORequiereAutorizacion,POIdVigencia,PODefaulteo,POIdEstatus,
                POUsuarioAdd,POFechaAdd,POUsuarioUMod,POFechaUMod,
                POAutorizado,POFechaAutorizacion
            )
            VALUES
            (
                @LegacySeleccion,'S001',@IdEmpresa,@Numero,@IdEmpleado,1,41,
                1,@IdPlanOpcion,100,@IdSolicitud,0,0,8,'0',
                @IdVigenciaOrigen,0,1,@UsuarioDummy,@Ahora,@UsuarioDummy,@Ahora,
                1,DATEADD(DAY,-1,@Ahora)
            );
        END;

        SET @IdSolicitud=NULL;
        FETCH NEXT FROM SolicitudesCursor INTO @Escenario,@Numero,@IdEmpleado;
    END;
    CLOSE SolicitudesCursor;
    DEALLOCATE SolicitudesCursor;

    /* ff_CreateSolicitudTest calcula MAX(CONVERT(int,SONumeroSolicitud)); por
       ello todos los folios dummy deben ser numericos, incluso los de corridas anteriores. */
    UPDATE S
    SET S.SONumeroSolicitud=CONVERT(varchar(20),
          CASE WHEN S.SOIdVigencia=@IdVigenciaDestino THEN 990000000 ELSE 980000000 END
          +(S.SOIdEmpleado%10000000)),
        S.SOUsuarioUMod=@UsuarioDummy,S.SOFechaUMod=@Ahora
    FROM dbo.ff_Solicitud S
    INNER JOIN @Casos C ON C.IdEmpleado=S.SOIdEmpleado
    WHERE TRY_CONVERT(int,S.SONumeroSolicitud) IS NULL;

    COMMIT TRANSACTION;

    /* Matriz final de comprobación. */
    SELECT
        C.TipoDefaulteo,C.Consecutivo,C.Escenario,C.ConDependiente,
        C.IdEmpleado,C.Numero,C.Perfil,
        @IdVigenciaOrigen AS IdVigenciaOrigen,
        @IdVigenciaDestino AS IdVigenciaDestino,
        SO.SolicitudesOrigenAprobadas,
        POS.SeleccionesOrigen,
        PB.PlanesBasicosDestino,
        D.DependientesActivos,
        SD.SolicitudesDestinoActivas,
        CASE C.TipoDefaulteo
            WHEN 1 THEN
                CASE WHEN SO.SolicitudesOrigenAprobadas>0 AND POS.SeleccionesOrigen>0
                           AND SD.SolicitudesDestinoActivas=0
                     THEN 'LISTO TIPO 1' ELSE 'REVISAR TIPO 1' END
            WHEN 2 THEN
                CASE WHEN PB.PlanesBasicosDestino>0 AND SD.SolicitudesDestinoActivas=0
                     THEN 'LISTO TIPO 2' ELSE 'REVISAR TIPO 2' END
            WHEN 3 THEN
                CASE WHEN SO.SolicitudesOrigenAprobadas>0 AND POS.SeleccionesOrigen>0
                           AND SD.SolicitudesDestinoActivas=0
                           AND ((C.ConDependiente=1 AND D.DependientesActivos>0)
                             OR (C.ConDependiente=0 AND D.DependientesActivos=0))
                     THEN CASE WHEN C.ConDependiente=1
                               THEN 'LISTO TIPO 3 CON DEPENDIENTE'
                               ELSE 'LISTO TIPO 3 SIN DEPENDIENTE' END
                     ELSE 'REVISAR TIPO 3' END
        END AS ResultadoTipoAsignado
    FROM @Casos C
    OUTER APPLY(SELECT COUNT(*) SolicitudesOrigenAprobadas FROM dbo.ff_Solicitud S WHERE S.SOIdEmpleado=C.IdEmpleado AND S.SOIdEmpresa=@IdEmpresa AND S.SOIdVigencia=@IdVigenciaOrigen AND S.SOIdEstatus=1 AND S.SOEstatusSolicitud=1) SO
    OUTER APPLY(SELECT COUNT(*) SeleccionesOrigen FROM dbo.ff_PlanOpcionSeleccion P WHERE P.POIdEmpleado=C.IdEmpleado AND P.POIdEmpresa=@IdEmpresa AND P.POIdVigencia=@IdVigenciaOrigen AND P.POIdEstatus=1) POS
    OUTER APPLY(SELECT COUNT(*) PlanesBasicosDestino FROM dbo.ff_PlanBasico B INNER JOIN dbo.ff_PlanOpcion O ON O.POIdPlanOpcion=B.PBIdPlanOpcion AND O.POIdEstatus=1 WHERE B.PBIdPerfil=C.Perfil AND B.PBIdVigencia=@IdVigenciaDestino AND B.PBIdEstatus=1) PB
    OUTER APPLY(SELECT COUNT(*) DependientesActivos FROM dbo.ff_Empleado E WHERE E.EMIdEmpresa=@IdEmpresa AND E.EMIdTitular=C.IdEmpleado AND E.EMIdParentesco<>1 AND E.EMIdEstatus=1) D
    OUTER APPLY(SELECT COUNT(*) SolicitudesDestinoActivas FROM dbo.ff_Solicitud S WHERE S.SOIdEmpleado=C.IdEmpleado AND S.SOIdEmpresa=@IdEmpresa AND S.SOIdVigencia=@IdVigenciaDestino AND S.SOIdEstatus=1 AND S.SOEstatusSolicitud IN(1,3)) SD
    ORDER BY C.TipoDefaulteo,C.Consecutivo;

    SELECT
        'VIGENCIA_DE_PRUEBA' AS Bloque,
        @IdEmpresa AS IdEmpresa,
        E.EMNombre AS EmpresaLogin,
        E.EMClaveAcceso AS ClaveAccesoEmpresa,
        V.VIIdVigencia AS IdVigenciaSeleccionar,
        V.VINombre AS VigenciaSeleccionar,
        V.VIRenovada AS IdVigenciaOrigen,
        V.VITipoNegocio,
        V.VIIdEstatus,
        CASE WHEN V.VIIdEstatus=1 THEN 'LISTA PARA SELECCIONAR EN QA'
             ELSE 'NO UTILIZABLE DESDE LA PANTALLA' END AS Resultado
    FROM dbo.ff_Empresa E
    INNER JOIN dbo.ff_Vigencia V
        ON V.VIIdConfiguracion=E.EMIdConfiguracion
       AND V.VIIdVigencia=@IdVigenciaDestino
    WHERE E.EMIdEmpresa=@IdEmpresa;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
