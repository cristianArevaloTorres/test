/*
    CORRECCION PARA LOS 90 QD* YA CREADOS - EMPRESA 186

    No crea otra serie de empleados. Corrige los mismos QD1/QD2/QD3 para la
    rama real utilizada por la pantalla cuando 4235 es la vigencia actual:
      ff_CBuscaPlanesPerfil_V31Test.

    SOLO QA. Es idempotente y aborta toda la transaccion si falta un supuesto.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @IdEmpresa INT=186;
DECLARE @IdVigenciaOrigen INT=3924;
DECLARE @IdVigenciaDestino INT=4235;
DECLARE @IdPlanOpcion INT=1775;
DECLARE @IdPlan INT=2050;
DECLARE @IdRamo INT=159;
DECLARE @IdTarifaReal INT=2047;
DECLARE @IdTarifaDummy INT=918604;
DECLARE @IdTarifaDummyOrigen INT=918605;
DECLARE @Ahora DATETIME=GETDATE();

BEGIN TRY
    BEGIN TRANSACTION;

    IF
    (
        SELECT COUNT(*)
        FROM dbo.ff_Empleado
        WHERE EMIdEmpresa=@IdEmpresa
          AND EMIdTitular=1
          AND EMIdEstatus=1
          AND
          (
              EMNumeroEmpleado LIKE 'QD1-186-%'
              OR EMNumeroEmpleado LIKE 'QD2-186-%'
              OR EMNumeroEmpleado LIKE 'QD3-186-%'
          )
    )<>90
        THROW 51400, 'No existen los 90 titulares QD*. Ejecute primero DUMMY_DEF_123_186.sql actualizado.', 1;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.ff_Vigencia V
        INNER JOIN dbo.ff_Empresa E ON E.EMIdConfiguracion=V.VIIdConfiguracion
        WHERE E.EMIdEmpresa=@IdEmpresa
          AND V.VIIdVigencia=@IdVigenciaDestino
          AND V.VITipoNegocio=1
    )
        THROW 51401, 'La vigencia 4235 no pertenece a la configuracion de la empresa 186.', 1;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.ff_Tarifa
        WHERE TAIdTarifa=@IdTarifaReal
          AND TAIdVigencia=@IdVigenciaDestino
    )
        THROW 51402, 'La tarifa real 2047 no pertenece a la vigencia 4235.', 1;

    UPDATE dbo.ff_Vigencia
    SET VIIdEstatus=1,VIUsuarioUMod=0,VIFechaUMod=@Ahora
    WHERE VIIdVigencia=@IdVigenciaDestino;

    UPDATE dbo.ff_PlanOpcionVigencia
    SET VCIdEstatus=1,VCUsuarioUMod=0,VCFechaUMod=@Ahora
    WHERE VCIdPlanOpcion=@IdPlanOpcion
      AND VCIdVigencia=@IdVigenciaDestino;

    IF @@ROWCOUNT=0
        THROW 51403, 'Falta la relacion de la opcion 1775 con la vigencia 4235.', 1;

    UPDATE dbo.ff_Tarifa
    SET TAIdEstatus=1,TAUsuarioUMod=0,TAFechaUMod=@Ahora
    WHERE TAIdTarifa=@IdTarifaReal;

    UPDATE dbo.ff_TarifaCosto
    SET TCIdEstatus=1,TCUsuarioUMod=0,TCFechaUMod=@Ahora
    WHERE TCIdTarifa=@IdTarifaReal
      AND TCIdPlanOpcion=@IdPlanOpcion;

    IF @@ROWCOUNT=0
        THROW 51404, 'La tarifa 2047 no tiene costos para la opcion 1775.', 1;

    /*
       V31Test sí marca el plan como Checked, pero para la empresa 186 su
       SELECT de salida hace INNER JOIN con bf_GrupoPlanesCorporativo. Sin
       esta relación Java recibe cero planes aunque el cálculo haya terminado.
    */
    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.bf_GrupoPlanesCorporativo
        WHERE GPIdPlan=@IdPlan AND GPIdEstatus=1
    )
    BEGIN
        DECLARE @IdGrupoPlanExistente INT=
        (
            SELECT TOP(1) GPIdPlanesGrupo
            FROM dbo.bf_GrupoPlanesCorporativo
            WHERE GPIdPlan=@IdPlan
            ORDER BY GPIdPlanesGrupo
        );

        IF @IdGrupoPlanExistente IS NOT NULL
            UPDATE dbo.bf_GrupoPlanesCorporativo
            SET GPIdEstatus=1,GPUsuarioUMod=0,GPFechaUMod=@Ahora,
                GPUsuarioDel=NULL,GPFechaDel=NULL
            WHERE GPIdPlanesGrupo=@IdGrupoPlanExistente;
        ELSE
            INSERT dbo.bf_GrupoPlanesCorporativo
            (
                GPIdGrupo,GPGrupoEtiqueta,GPGrupoDescripcion,GPIdPlan,GPOrden,
                GPIdEstatus,GPUsuarioAdd,GPFechaAdd,GPUsuarioUMod,GPFechaUMod,
                GPUsuarioDel,GPFechaDel,GPRutaImagenGrupo
            )
            VALUES
            (
                1,'VIDA','PLANES DE VIDA',@IdPlan,1,
                1,0,@Ahora,0,@Ahora,NULL,NULL,NULL
            );
    END;

    INSERT dbo.ff_AperturaSistema
    (
        ASIdEmpleado,ASIdMotivo,ASFechaIni,ASFechaFin,ASIdVigencia,
        ASIdEstatus,ASUsuarioAdd,ASFechaAdd,ASUsuarioUMod,ASFechaUMod,
        ASUsuarioDel,ASFechaDel
    )
    SELECT
        E.Id,1,V.VIVigenciaIni,V.VIVigenciaFin,@IdVigenciaDestino,
        1,0,@Ahora,0,@Ahora,NULL,NULL
    FROM dbo.ff_Empleado E
    CROSS JOIN dbo.ff_Vigencia V
    WHERE E.EMIdEmpresa=@IdEmpresa
      AND E.EMIdTitular=1
      AND E.EMIdEstatus=1
      AND V.VIIdVigencia=@IdVigenciaDestino
      AND
      (
          E.EMNumeroEmpleado LIKE 'QD1-186-%'
          OR E.EMNumeroEmpleado LIKE 'QD2-186-%'
          OR E.EMNumeroEmpleado LIKE 'QD3-186-%'
      )
      AND NOT EXISTS
      (
          SELECT 1 FROM dbo.ff_AperturaSistema A
          WHERE A.ASIdEmpleado=E.Id
            AND A.ASIdMotivo=1
            AND A.ASIdVigencia=@IdVigenciaDestino
            AND A.ASIdEstatus=1
      );

    /* Retira exclusivamente las tarifas reservadas por la version anterior. */
    IF EXISTS
    (
        SELECT 1 FROM dbo.ff_Excedentes_empleado
        WHERE EXIdTarifaCosto IN
        (
            SELECT C.TCIdTarifaCosto
            FROM dbo.ff_TarifaCosto C
            INNER JOIN dbo.ff_Tarifa T ON T.TAIdTarifa=C.TCIdTarifa
            WHERE T.TAIdTarifa IN(@IdTarifaDummy,@IdTarifaDummyOrigen)
              AND T.TANombre LIKE 'QA DUMMY DEF 186%'
        )
    )
        THROW 51405, 'Una tarifa QA tiene excedentes asociados y no puede retirarse automaticamente.', 1;

    DELETE B3
    FROM dbo.ff_TarifaCostoB3 B3
    INNER JOIN dbo.ff_Tarifa T ON T.TAIdTarifa=B3.TCIdTarifa
    WHERE T.TAIdTarifa IN(@IdTarifaDummy,@IdTarifaDummyOrigen)
      AND T.TANombre LIKE 'QA DUMMY DEF 186%';

    DELETE H
    FROM dbo.ff_TarifaCosto_hist H
    INNER JOIN dbo.ff_Tarifa T ON T.TAIdTarifa=H.TCIdTarifa
    WHERE T.TAIdTarifa IN(@IdTarifaDummy,@IdTarifaDummyOrigen)
      AND T.TANombre LIKE 'QA DUMMY DEF 186%';

    DELETE C
    FROM dbo.ff_TarifaCosto C
    INNER JOIN dbo.ff_Tarifa T ON T.TAIdTarifa=C.TCIdTarifa
    WHERE T.TAIdTarifa IN(@IdTarifaDummy,@IdTarifaDummyOrigen)
      AND T.TANombre LIKE 'QA DUMMY DEF 186%';

    DELETE dbo.ff_Tarifa
    WHERE TAIdTarifa IN(@IdTarifaDummy,@IdTarifaDummyOrigen)
      AND TANombre LIKE 'QA DUMMY DEF 186%';

    IF (SELECT COUNT(*) FROM dbo.ff_Tarifa WHERE TAIdVigencia=@IdVigenciaDestino)<>1
        THROW 51406, 'La vigencia 4235 no tiene exactamente una tarifa; V31Test usa una subconsulta escalar.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.ff_Empleado E
        WHERE E.EMIdEmpresa=@IdEmpresa
          AND E.EMIdTitular=1
          AND E.EMIdEstatus=1
          AND
          (
              E.EMNumeroEmpleado LIKE 'QD1-186-%'
              OR E.EMNumeroEmpleado LIKE 'QD2-186-%'
              OR E.EMNumeroEmpleado LIKE 'QD3-186-%'
          )
          AND dbo.VerificaCC(E.Id)=0
    )
        THROW 51407, 'Al menos un empleado QD sigue entrando por la vigencia de estatus 6.', 1;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.bf_GrupoPlanesCorporativo
        WHERE GPIdPlan=@IdPlan AND GPIdEstatus=1
    )
        THROW 51408, 'El plan 2050 no tiene grupo activo y V31Test no lo devolveria a Java.', 1;

    /*
       Defaulteo 1 y 3 necesitan historia en la vigencia origen. La primera
       versión del paquete podía dejar solamente los empleados y los planes
       básicos; por eso tipo 2 quedaba LISTO y 1/3 aparecían en REVISAR.

       Se reparan exclusivamente los QD1/QD3 existentes. No se crean nuevos
       empleados ni se cambian sus números.
    */
    DECLARE @IdEmpleado INT;
    DECLARE @NumeroEmpleado VARCHAR(50);
    DECLARE @IdSolicitud INT;
    DECLARE @IdSeleccion INT;

    DECLARE CurHistoria CURSOR LOCAL FAST_FORWARD FOR
        SELECT E.Id,E.EMNumeroEmpleado
        FROM dbo.ff_Empleado E
        WHERE E.EMIdEmpresa=@IdEmpresa
          AND E.EMIdTitular=1
          AND E.EMIdEstatus=1
          AND
          (
              E.EMNumeroEmpleado LIKE 'QD1-186-%'
              OR E.EMNumeroEmpleado LIKE 'QD3-186-%'
          )
        ORDER BY E.EMNumeroEmpleado;

    OPEN CurHistoria;
    FETCH NEXT FROM CurHistoria INTO @IdEmpleado,@NumeroEmpleado;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SET @IdSolicitud=NULL;

        SELECT TOP(1) @IdSolicitud=S.SOIdSolicitud
        FROM dbo.ff_Solicitud S
        WHERE S.SOIdEmpresa=@IdEmpresa
          AND S.SOIdEmpleado=@IdEmpleado
          AND S.SOIdVigencia=@IdVigenciaOrigen
        ORDER BY CASE WHEN S.SOIdEstatus=1 AND S.SOEstatusSolicitud=1 THEN 0 ELSE 1 END,
                 S.SOIdSolicitud;

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
                @IdEmpleado,@IdEmpresa,@IdEmpleado,@NumeroEmpleado,
                @IdRamo,1,1,@Ahora,'QA DUMMY APROBADA',0,@Ahora,0,@Ahora,
                CONVERT(VARCHAR(20),980000000+(@IdEmpleado%10000000)),
                DATEADD(DAY,-1,@Ahora),1,0,@IdVigenciaOrigen
            );
            SET @IdSolicitud=CONVERT(INT,SCOPE_IDENTITY());
        END
        ELSE
            UPDATE dbo.ff_Solicitud
            SET SOIdEstatus=1,
                SOEstatusSolicitud=1,
                SOFechaAprovacion=COALESCE(SOFechaAprovacion,DATEADD(DAY,-1,@Ahora)),
                SONumeroSolicitud=CASE
                    WHEN TRY_CONVERT(INT,SONumeroSolicitud) IS NULL
                    THEN CONVERT(VARCHAR(20),980000000+(@IdEmpleado%10000000))
                    ELSE SONumeroSolicitud END,
                SOUsuarioUMod=0,
                SOFechaUMod=@Ahora
            WHERE SOIdSolicitud=@IdSolicitud;

        IF EXISTS
        (
            SELECT 1 FROM dbo.ff_PlanOpcionSeleccion P
            WHERE P.POIdEmpresa=@IdEmpresa
              AND P.POIdEmpleado=@IdEmpleado
              AND P.POIdVigencia=@IdVigenciaOrigen
              AND P.POIdPlanOpcion=@IdPlanOpcion
        )
            UPDATE dbo.ff_PlanOpcionSeleccion
            SET POIdSolicitud=@IdSolicitud,
                POIdEstatus=1,
                POAutorizado=1,
                POFechaAutorizacion=COALESCE(POFechaAutorizacion,DATEADD(DAY,-1,@Ahora)),
                POUsuarioUMod=0,
                POFechaUMod=@Ahora
            WHERE POIdEmpresa=@IdEmpresa
              AND POIdEmpleado=@IdEmpleado
              AND POIdVigencia=@IdVigenciaOrigen
              AND POIdPlanOpcion=@IdPlanOpcion;
        ELSE
        BEGIN
            SELECT @IdSeleccion=ISNULL(MAX(POIdPlanOpcionSeleccion),900000000)+1
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
                @IdSeleccion,'S001',@IdEmpresa,@NumeroEmpleado,@IdEmpleado,
                1,41,1,@IdPlanOpcion,100,@IdSolicitud,0,0,8,'0',
                @IdVigenciaOrigen,0,1,0,@Ahora,0,@Ahora,1,DATEADD(DAY,-1,@Ahora)
            );
        END;

        FETCH NEXT FROM CurHistoria INTO @IdEmpleado,@NumeroEmpleado;
    END;
    CLOSE CurHistoria;
    DEALLOCATE CurHistoria;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.ff_Empleado E
        WHERE E.EMIdEmpresa=@IdEmpresa
          AND E.EMIdTitular=1
          AND E.EMIdEstatus=1
          AND (E.EMNumeroEmpleado LIKE 'QD1-186-%' OR E.EMNumeroEmpleado LIKE 'QD3-186-%')
          AND
          (
              NOT EXISTS
              (
                  SELECT 1 FROM dbo.ff_Solicitud S
                  WHERE S.SOIdEmpresa=@IdEmpresa AND S.SOIdEmpleado=E.Id
                    AND S.SOIdVigencia=@IdVigenciaOrigen
                    AND S.SOIdEstatus=1 AND S.SOEstatusSolicitud=1
              )
              OR NOT EXISTS
              (
                  SELECT 1 FROM dbo.ff_PlanOpcionSeleccion P
                  WHERE P.POIdEmpresa=@IdEmpresa AND P.POIdEmpleado=E.Id
                    AND P.POIdVigencia=@IdVigenciaOrigen
                    AND P.POIdPlanOpcion=@IdPlanOpcion AND P.POIdEstatus=1
              )
          )
    )
        THROW 51409, 'No fue posible completar la historia de los QD1/QD3 en la vigencia 3924.', 1;

    COMMIT TRANSACTION;

    SELECT
        CASE WHEN EMNumeroEmpleado LIKE 'QD1-186-%' THEN 1
             WHEN EMNumeroEmpleado LIKE 'QD2-186-%' THEN 2 ELSE 3 END AS TipoDefaulteo,
        COUNT(*) AS Empleados,
        SUM(CASE WHEN dbo.VerificaCC(Id)>0 THEN 1 ELSE 0 END) AS PreparadosParaVigenciaActual,
        (SELECT COUNT(*) FROM dbo.bf_GrupoPlanesCorporativo
         WHERE GPIdPlan=@IdPlan AND GPIdEstatus=1) AS GrupoPlanVisibleParaB3
    FROM dbo.ff_Empleado
    WHERE EMIdEmpresa=@IdEmpresa
      AND EMIdTitular=1
      AND EMIdEstatus=1
      AND
      (
          EMNumeroEmpleado LIKE 'QD1-186-%'
          OR EMNumeroEmpleado LIKE 'QD2-186-%'
          OR EMNumeroEmpleado LIKE 'QD3-186-%'
      )
    GROUP BY CASE WHEN EMNumeroEmpleado LIKE 'QD1-186-%' THEN 1
                  WHEN EMNumeroEmpleado LIKE 'QD2-186-%' THEN 2 ELSE 3 END
    ORDER BY TipoDefaulteo;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
