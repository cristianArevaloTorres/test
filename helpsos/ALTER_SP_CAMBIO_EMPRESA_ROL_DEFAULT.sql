USE [FlexiForbesv2];
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

ALTER PROCEDURE [dbo].[ff_cambioEMpresa]
(
	@IdEmpleado INT
	,@EMIdPerfil INT
	,@EMPDestino INT
	,@IdAdministrador VARCHAR(50)

	,@EMRegimen VARCHAR(50) = NULL
	,@EMOficina VARCHAR(50) = NULL
	,@EMArea VARCHAR(50) = NULL
	,@EMObservaciones VARCHAR(500) = NULL

	,@EMSalarioBase MONEY = 0
	,@EMPuesto VARCHAR(100) = NULL
	,@EMrfc VARCHAR(100) = NULL
	,@EMcurp VARCHAR(100) = NULL
	,@EMCorreoElectronico VARCHAR(500) = NULL

	,@EMVIP VARCHAR(50) = NULL
	,@EMidCentroCostos VARCHAR(50) = NULL
	,@EMTipoEmpleado VARCHAR(50) = NULL
	,@IDRol INT
	,@idSolicitud INT = 0
	,@cancelarSolicitud INT = 0
	,@ErrorMsgnum INT OUTPUT
	,@ErrorSeverity TINYINT OUTPUT
	/* Critical = 16, Exclamation = 48, Information = 64 */
)
AS
BEGIN
	DECLARE
		@EMNumeroempleado VARCHAR(20),
		@EMPOrigen INT,
		@empleadoBaja INT,
		@idPerfilOrigen INT;

	SELECT
		@EMPOrigen = EMIdEmpresa,
		@EMNumeroempleado = EMNumeroEmpleado,
		@idPerfilOrigen = EMIdPerfil
	FROM dbo.ff_Empleado
	WHERE ID = @IdEmpleado;

	SET @empleadoBaja = ISNULL
	(
		(
			SELECT COUNT(ID)
			FROM dbo.ff_Empleado
			WHERE EMIdEmpresa = @EMPOrigen
			  AND EMNumeroEmpleado = @EMNumeroempleado
			  AND EMIdParentesco = 1
			  AND EMIdEstatus = 2
		),
		0
	);

	/*
	  -- CAT: ESTO SE CAMBIO PARA QUE LA TRANSFERENCIA INDIVIDUAL QUEDE IGUAL QUE LA CARGA MASIVA: SE ASIGNA EL ROL DEFAULT ACTIVO DE UN PERFIL NO ADMINISTRADOR Y, SI NO EXISTE, EL ROL ACTIVO NO ADMINISTRADOR CON MENOR ID.
	  Se conserva el parametro @IDRol para no modificar el contrato utilizado por
	  Java, pero su valor se determina internamente con la empresa destino.
	*/
	SET @IDRol = NULL;

	SELECT TOP (1)
		@IDRol = R.ROIdRol
	FROM dbo.ff_Rol R
	INNER JOIN dbo.ff_Perfil P
		ON P.PEIdRolDefault = R.ROIdRol
		AND P.PEIdEmpresa = @EMPDestino
		AND P.PEIdEstatus = 1
	WHERE R.ROIdEmpresa = @EMPDestino
	  AND R.ROIdEstatus = 1
	  AND R.RODefault = 1
	  AND P.PEAdministrador = 0
	ORDER BY R.ROIdRol ASC;

	IF @IDRol IS NULL
	BEGIN
		SELECT TOP (1)
			@IDRol = R.ROIdRol
		FROM dbo.ff_Rol R
		INNER JOIN dbo.ff_Perfil P
			ON P.PEIdRolDefault = R.ROIdRol
			AND P.PEIdEmpresa = @EMPDestino
			AND P.PEIdEstatus = 1
		WHERE R.ROIdEmpresa = @EMPDestino
		  AND R.ROIdEstatus = 1
		  AND P.PEAdministrador = 0
		ORDER BY R.ROIdRol ASC;
	END;

	IF @IDRol IS NULL
	BEGIN
		SET @ErrorMsgnum = 51000;
		SET @ErrorSeverity = 16;
		THROW 51000, 'No existe un rol activo asociado a un perfil no administrador en la empresa destino.', 1;
	END;

	BEGIN TRAN;

	DECLARE
		@existen_registros INT,
		@mensajeLog VARCHAR(500) = '';

	/*
	 * Catalogo de opciones seleccion usuario @EMSeleccionUsuario
	 * 0 - No aplica
	 * 1 - Defaulteo solicitud
	 * 2 - Cambios calificados
	 * 3 - Rechazo solicitud
	 * 4 - Regenerar solicitud - Default cuando no hay diferencia de planes en transferencia individual
	 */

	-- Actualizar planes opcionales
	IF (@cancelarSolicitud IN (1, 2, 3, 4) AND @idSolicitud <> 0)
	BEGIN
		DECLARE @Ids_PlanesEmpleado TABLE (IdPlan INT, IdPlanOpcion INT);
		DECLARE @Ids_PlanesPerfilDestino TABLE (IdPlan INT, IdPlanOpcion INT);
		DECLARE @Ids_PlanesSinPerfilDestino TABLE (IdPlan INT, IdPlanOpcion INT);
		DECLARE @Ids_PlanesOpcionales TABLE (IdPlan INT, IdPlanOpcion INT);
		DECLARE @Ids_PlanesOpcionalesDestino TABLE (IdPlanOpcion INT, IdPlanOpcionDestino INT);

		-- Planes seleccionados para la solicitud actual
		INSERT INTO @Ids_PlanesEmpleado
		SELECT
			PL.PLIdPlan,
			POP.PPIdPlanOpcion
		FROM dbo.ff_PlanOpcionSeleccion POS
		INNER JOIN dbo.ff_PlanOpcion PO
			ON PO.POIdPlanOpcion = POS.POIdPlanOpcion
		INNER JOIN dbo.ff_Plan PL
			ON PL.PLIdPlan = PO.POIdPlan
		LEFT JOIN dbo.ff_PlanOpcionPerfil POP
			ON POP.PPIdPlanOpcion = POS.POIdPlanOpcion
			AND POP.PPIdPerfil = @idPerfilOrigen
		WHERE POS.POIdSolicitud = @idSolicitud
		GROUP BY POP.PPIdPlanOpcion, PL.PLIdPlan
		ORDER BY POP.PPIdPlanOpcion, PL.PLIdPlan;

		-- Recuperar planes que no existan en la empresa y perfil destino
		INSERT INTO @Ids_PlanesPerfilDestino
		SELECT
			PL.PLIdPlan,
			POP.PPIdPlanOpcion
		FROM dbo.ff_PlanOpcionSeleccion POS
		INNER JOIN dbo.ff_PlanOpcion PO
			ON PO.POIdPlanOpcion = POS.POIdPlanOpcion
		INNER JOIN dbo.ff_Plan PL
			ON PL.PLIdPlan = PO.POIdPlan
		LEFT JOIN dbo.ff_PlanOpcionPerfil POP
			ON POP.PPIdPlanOpcion = POS.POIdPlanOpcion
			AND POP.PPIdPerfil = @EMIdPerfil
		WHERE POS.POIdSolicitud = @idSolicitud
		  AND POP.PPIdPlanOpcion IS NULL
		GROUP BY POP.PPIdPlanOpcion, PL.PLIdPlan
		ORDER BY POP.PPIdPlanOpcion, PL.PLIdPlan;

		-- Recuperar planes de la empresa y perfil origen que no existen en el perfil destino
		INSERT INTO @Ids_PlanesOpcionales
		SELECT *
		FROM @Ids_PlanesEmpleado
		WHERE IdPlan IN (SELECT IdPlan FROM @Ids_PlanesPerfilDestino);

		INSERT INTO @Ids_PlanesOpcionalesDestino
		SELECT
			EP.EPIdPlanOpcion,
			EP.EPIdPlanOpcionDestino
		FROM dbo.ff_EquivalenciaPlanesEmpresa EP
		INNER JOIN @Ids_PlanesOpcionales PLO
			ON EP.EPIdPlan = PLO.IdPlan
			AND EP.EPIdPlanOpcion = PLO.IdPlanOpcion
		WHERE EP.EPIdEmpresaOrigen = @EMPOrigen
		  AND EP.EPIdEmpresaDestino = @EMPDestino
		  AND EP.EPIdPerfilOrigen = @idPerfilOrigen
		  AND EP.EPIdPerfilDestino = @EMIdPerfil;

		-- Actualizar id plan opcion de seleccion de empleado
		UPDATE PTMP
		SET PTMP.POIdPlanOpcion = PD.IdPlanOpcionDestino
		FROM dbo.ff_PlanOpcionSeleccionTmp PTMP
		INNER JOIN @Ids_PlanesOpcionalesDestino PD
			ON PD.IdPlanOpcion = PTMP.POIdPlanOpcion
		WHERE PTMP.PONumeroEmpleado = @EMNumeroempleado
		  AND PTMP.POIdEmpresa = @EMPOrigen;
	END;

	-- Rechazar solicitud
	IF (@cancelarSolicitud IN (1, 2, 3) AND @idSolicitud <> 0)
	BEGIN
		EXEC dbo.ff_UpdateSolicitud
			@SODetalleEstatus = 'Rechazada',
			@SOEstatusSolicitud = 5,
			@SOUsuarioUMod = @IdAdministrador,
			@SOIdSolicitud = @idSolicitud;
	END;

	PRINT 'PO';
	UPDATE dbo.ff_PlanOpcionSeleccion
	SET POIdEmpresa = @EMPDestino,
		POFechaUMod = GETDATE(),
		POUsuarioUMod = @IdAdministrador
	WHERE POIdEmpresa = @EMPOrigen
	  AND PONumeroEmpleado = @EMNumeroempleado;

	PRINT 'PO COBRANZA';
	UPDATE dbo.ff_PlanOpcionSeleccionCobranza
	SET POIdEmpresa = @EMPDestino,
		POFechaUMod = GETDATE(),
		POUsuarioUMod = @IdAdministrador
	WHERE POIdEmpresa = @EMPOrigen
	  AND PONumeroEmpleado = @EMNumeroempleado;

	PRINT 'EDO CUENTA';
	UPDATE dbo.ff_EdoCuenta
	SET ECIdEmpresa = @EMPDestino,
		ECUsuarioUMod = @IdAdministrador,
		ECFechaUMod = GETDATE()
	WHERE ECIdSolicitud IN
	(
		SELECT SOIdSolicitud
		FROM dbo.ff_Solicitud
		WHERE SOIdEmpleado = @IdEmpleado
		  AND SOIdEmpresa = @EMPOrigen
	);

	PRINT 'EDO CUENTA COBRANZA';
	UPDATE dbo.ff_EdoCuentaCobranza
	SET ECIdEmpresa = @EMPDestino,
		ECUsuarioUMod = @IdAdministrador,
		ECFechaUMod = GETDATE()
	WHERE ECIdSolicitud IN
	(
		SELECT SOIdSolicitud
		FROM dbo.ff_Solicitud
		WHERE SOIdEmpleado = @IdEmpleado
		  AND SOIdEmpresa = @EMPOrigen
	);

	PRINT 'SOLICITUD';
	UPDATE dbo.ff_Solicitud
	SET SOIdEmpresa = @EMPDestino,
		SOFechaUMod = GETDATE(),
		SOUsuarioUMod = @IdAdministrador
	WHERE SOIdEmpleado = @IdEmpleado
	  AND SOIdEmpresa = @EMPOrigen;

	-- Actualizar datos EMPLEADO
	DECLARE @EmpleadosCambioEmpresa TABLE
	(
		ID INT,
		EMIdEmpresa INT,
		EMIdPerfil INT,
		EMVIP INT,
		EMTipoEmpleado VARCHAR(100),
		EMArea INT,
		EMIdRol INT,
		EMRegimen INT,
		EMIdCentroCostos INT,
		EMOficina INT,
		EMPuesto VARCHAR(100),
		EMSalarioBase MONEY,
		EMCorreoElectronico VARCHAR(500),
		EMcurp VARCHAR(50),
		EMrfc VARCHAR(20),
		EMIdEstatus INT,
		EMIdTitular INT
	);

	-- Agrupar empleado y dependientes
	INSERT INTO @EmpleadosCambioEmpresa
	SELECT
		ID,
		EMIdEmpresa,
		EMIdPerfil,
		EMVIP,
		EMTipoEmpleado,
		EMArea,
		EMIdRol,
		EMRegimen,
		EMIdCentroCostos,
		EMOficina,
		EMPuesto,
		EMSalarioBase,
		EMCorreoElectronico,
		EMcurp,
		EMrfc,
		EMIdEstatus,
		EMIdTitular
	FROM dbo.ff_Empleado
	WHERE EMIdEmpresa = @EMPOrigen
	  AND EMNumeroEmpleado = @EMNumeroempleado;

	-- Validacion de existencia de valores nulos por campo
	DECLARE
		@existen_registros_EMOficina INT,
		@existen_registros_EMArea INT,
		@existen_registros_EMIdperfil INT,
		@existen_registros_emidrol INT,
		@existen_registros_EMREGIMEN INT,
		@existen_registros_EMVIP INT,
		@existen_registros_EMidCentroCostos INT,
		@existen_registros_EMTipoEmpleado INT;

	SET @existen_registros_EMOficina = (SELECT COUNT(*) FROM @EmpleadosCambioEmpresa WHERE EMIdTitular <> 1 AND EMOficina IS NULL);
	SET @existen_registros_EMArea = (SELECT COUNT(*) FROM @EmpleadosCambioEmpresa WHERE EMIdTitular <> 1 AND EMArea IS NULL);
	SET @existen_registros_EMIdperfil = (SELECT COUNT(*) FROM @EmpleadosCambioEmpresa WHERE EMIdTitular <> 1 AND EMIdPerfil IS NULL);
	SET @existen_registros_emidrol = (SELECT COUNT(*) FROM @EmpleadosCambioEmpresa WHERE EMIdTitular <> 1 AND EMIdRol IS NULL);
	SET @existen_registros_EMREGIMEN = (SELECT COUNT(*) FROM @EmpleadosCambioEmpresa WHERE EMIdTitular <> 1 AND EMRegimen IS NULL);
	SET @existen_registros_EMVIP = (SELECT COUNT(*) FROM @EmpleadosCambioEmpresa WHERE EMIdTitular <> 1 AND EMVIP IS NULL);
	SET @existen_registros_EMidCentroCostos = (SELECT COUNT(*) FROM @EmpleadosCambioEmpresa WHERE EMIdTitular <> 1 AND EMIdCentroCostos IS NULL);
	SET @existen_registros_EMTipoEmpleado = (SELECT COUNT(*) FROM @EmpleadosCambioEmpresa WHERE EMIdTitular <> 1 AND EMTipoEmpleado IS NULL);

	SET NOCOUNT ON;

	UPDATE dbo.ff_Empleado
	SET EMIdEmpresa = @EMPDestino,
		EMIdPerfil = CASE
			WHEN @existen_registros_EMIdperfil = 0 THEN @EMIdPerfil
			WHEN @existen_registros_EMIdperfil <> 0 AND EMIdTitular = 1 THEN @EMIdPerfil
			ELSE EMIdPerfil
		END,
		EMIdRol = CASE
			WHEN @existen_registros_emidrol = 0 THEN @IDRol
			WHEN @existen_registros_emidrol <> 0 AND EMIdTitular = 1 THEN @IDRol
			ELSE EMIdRol
		END,
		EMVIP = CASE
			WHEN @existen_registros_EMVIP = 0 AND @EMVIP <> '' THEN @EMVIP
			WHEN @existen_registros_EMVIP <> 0 AND EMIdTitular = 1 AND @EMVIP <> '' THEN @EMVIP
			ELSE EMVIP
		END,
		EMTipoEmpleado = CASE
			WHEN @existen_registros_EMTipoEmpleado = 0 AND @EMTipoEmpleado <> '' THEN @EMTipoEmpleado
			WHEN @existen_registros_EMTipoEmpleado <> 0 AND EMIdTitular = 1 AND @EMTipoEmpleado <> '' THEN @EMTipoEmpleado
			ELSE EMTipoEmpleado
		END,
		EMArea = CASE
			WHEN @existen_registros_EMArea = 0 AND @EMArea <> '' THEN @EMArea
			WHEN @existen_registros_EMArea <> 0 AND EMIdTitular = 1 AND @EMArea <> '' THEN @EMArea
			ELSE EMArea
		END,
		EMRegimen = CASE
			WHEN @existen_registros_EMREGIMEN = 0 AND @EMRegimen <> '' THEN @EMRegimen
			WHEN @existen_registros_EMREGIMEN <> 0 AND EMIdTitular = 1 AND @EMRegimen <> '' THEN @EMRegimen
			ELSE EMRegimen
		END,
		EMIdCentroCostos = CASE
			WHEN @existen_registros_EMidCentroCostos = 0 AND @EMidCentroCostos <> '' THEN @EMidCentroCostos
			WHEN @existen_registros_EMidCentroCostos <> 0 AND EMIdTitular = 1 AND @EMidCentroCostos <> '' THEN @EMidCentroCostos
			ELSE EMIdCentroCostos
		END,
		EMOficina = CASE
			WHEN @EMOficina <> '' THEN @EMOficina
			ELSE EMOficina
		END,
		EMPuesto = CASE
			WHEN @EMPuesto IS NOT NULL AND LTRIM(RTRIM(@EMPuesto)) <> '' AND EMIdTitular = 1 THEN @EMPuesto
			ELSE EMPuesto
		END,
		EMSalarioBase = CASE
			WHEN @EMSalarioBase IS NOT NULL AND @EMSalarioBase <> 0 AND EMIdTitular = 1 THEN @EMSalarioBase
			ELSE EMSalarioBase
		END,
		EMCorreoElectronico = CASE
			WHEN @EMCorreoElectronico IS NOT NULL AND LTRIM(RTRIM(@EMCorreoElectronico)) <> '' AND EMIdTitular = 1 THEN @EMCorreoElectronico
			ELSE EMCorreoElectronico
		END,
		EMcurp = CASE
			WHEN @EMcurp IS NOT NULL AND LTRIM(RTRIM(@EMcurp)) <> '' AND EMIdTitular = 1 THEN @EMcurp
			ELSE EMcurp
		END,
		EMrfc = CASE
			WHEN @EMrfc IS NOT NULL AND LTRIM(RTRIM(@EMrfc)) <> '' AND EMIdTitular = 1 THEN @EMrfc
			ELSE EMrfc
		END,
		EMUsuarioUMod = @IdAdministrador,
		EMObservaciones = CASE
			WHEN @EMObservaciones IS NOT NULL AND LTRIM(RTRIM(@EMObservaciones)) <> '' THEN @EMObservaciones
			ELSE 'Transferencia de empleado'
		END,
		EMFechaUMod = GETDATE(),
		EMFecha_solicitud_movimiento = GETDATE(),
		EMFecha_ejecucion_movimiento = GETDATE()
	WHERE EMIdEmpresa = @EMPOrigen
	  AND EMNumeroEmpleado = @EMNumeroempleado;

	PRINT 'Modificacion Temporal ff_EdoCuentaTmp';
	SET @existen_registros =
	(
		SELECT COUNT(*)
		FROM dbo.ff_EdoCuentaTmp
		WHERE ECNumeroEmpleado = @EMNumeroempleado
		  AND ECIdEmpresa = @EMPDestino
	);

	IF @existen_registros <> 0
	BEGIN
		DELETE dbo.ff_EdoCuentaTmp
		WHERE ECNumeroEmpleado = @EMNumeroempleado
		  AND ECIdEmpresa = @EMPDestino;
	END;

	UPDATE dbo.ff_EdoCuentaTmp
	SET ECIdEmpresa = @EMPDestino,
		ECUsuarioUMod = @IdAdministrador,
		ECFechaUMod = GETDATE()
	WHERE ECNumeroEmpleado = @EMNumeroempleado
	  AND ECIdEmpresa = @EMPOrigen;

	PRINT 'Modificacion Temporal Solicitud/Cotizador';
	SET @existen_registros =
	(
		SELECT COUNT(*)
		FROM dbo.ff_PlanOpcionSeleccionTmp
		WHERE POIdEmpleado = @IdEmpleado
		  AND POIdEmpresa = @EMPDestino
	);

	UPDATE dbo.ff_PlanOpcionSeleccionTmp
	SET POIdEmpresa = @EMPDestino,
		POUsuarioUMod = @IdAdministrador,
		POFechaUMod = GETDATE()
	WHERE PONumeroEmpleado = @EMNumeroempleado
	  AND POIdEmpresa = @EMPOrigen;

	-- Guardar log
	SET @mensajeLog = CASE
		WHEN @cancelarSolicitud = 0 THEN 'Transferencia de empleado sin solicitud activa'
		WHEN @cancelarSolicitud = 1 THEN 'Transferencia de empleado con defaulteo de solicitud'
		WHEN @cancelarSolicitud = 2 THEN 'Transferencia de empleado con cambios calificados'
		WHEN @cancelarSolicitud = 3 THEN 'Transferencia de empleado con rechazo de solicitud activa'
		WHEN @cancelarSolicitud = 4 THEN 'Transferencia de empleado con la misma solicitud activa'
	END;

	INSERT INTO dbo.ff_LogTranferenciaEmpleado
	(
		LTEIdEmpleado,
		LTEIdSolicitud,
		LTEIdAccion,
		LTEDetalleAccion,
		LTEIdEmpresaOrigen,
		LTEIdEmpresaDestino,
		LTEUsuarioAdd
	)
	VALUES
	(
		@IdEmpleado,
		@idSolicitud,
		@cancelarSolicitud,
		@mensajeLog,
		@EMPOrigen,
		@EMPDestino,
		@IdAdministrador
	);

	IF @@ERROR <> 0
	BEGIN
		ROLLBACK TRAN;
	END
	ELSE
	BEGIN
		COMMIT TRAN;
	END;
END;
GO

