USE [FlexiForbesv2];
GO

ALTER PROCEDURE [dbo].[bf_ReactivacionEmpleadosTitular](
	 @EMIdEmpresa INT
	,@EMNumeroEmpleado VARCHAR(20)
	,@EMFechaReingreso VARCHAR(23)
	,@EMUsuarioUMod INT 
)
AS
BEGIN

DECLARE 
	@Registros INT
	,@codigo INT = 0
	,@mensaje VARCHAR(200) = ''
	,@idEmpleado INT
	,@FechaBaja DATETIME

-- CAT: ESTO SE CAMBIO PARA QUE CUMPLIERA CON LO QUE SE SOLICITO QUE ERA CONSERVAR LA FECHA Y HORA DE ALTA ORIGINAL DURANTE LA REACTIVACION.

-- Validar existencia de empleado, activo
IF NOT EXISTS (
	SELECT 
		Id
	FROM FF_EMPLEADO 
	WHERE 
			EMIdestatus=1
		AND EMNumeroempleado=@EMNumeroEmpleado 
		AND EMIdempresa=@EMIdEmpresa 
		AND EMIDParentesco=1
)
BEGIN
	SET @Registros=0
	-- Existe empleado dado de baja
	 IF EXISTS(
		SELECT 
			ID 
		FROM FF_EMPLEADO 
		WHERE 
				EMIdestatus=2 
			AND EMNumeroempleado=@EMNumeroEmpleado 
			AND EMIdempresa=@EMIdEmpresa 
			AND EMIDParentesco=1
	)
	 BEGIN
		-- Recuperar fecha baja
		SELECT 
			@FechaBaja = EMFechabaja
		FROM FF_EMPLEADO 
		WHERE 
				EMIdestatus=2 
			AND EMNumeroempleado=@EMNumeroEmpleado 
			AND EMIdempresa=@EMIdEmpresa 
			AND EMIDParentesco=1
		-- Actualizar empleado
		UPDATE 
			ff_Empleado  
		SET 
			EMUsuarioUmod=@EMUsuarioUmod
			,EMFechaUmod=GETDATE()
			
			,EMFechaEstatus=GETDATE()
			,EMFECHAALTA=@EMFechaReingreso
			,EMFECHAANtiguedadGMM=@EMFechaReingreso
			,EMFechaBaja=NULL
			,EMIDEstatus=1
			,EMFechaIngresoEmpresa=@EMFechaReingreso
		WHERE 
				EMIdestatus=2 
			AND EMNumeroempleado=@EMNumeroEmpleado 
			AND EMIdempresa=@EMIdEmpresa 
			AND EMFechaBaja=@FechaBaja 
			AND EMIDParentesco<>1
		SET @Registros=@@ROWCOUNT
		-- Actualizar Dependientes
		UPDATE 
			ff_Empleado  
		SET 
			EMUsuarioUmod=@EMUsuarioUmod
			,EMFechaUmod=GETDATE()
			
			,EMFechaEstatus=GETDATE()
			, EMFECHAALTA=@EMFechaReingreso
			,EMFECHAANtiguedadGMM=@EMFechaReingreso
			,EMFechaBaja=NULL
			,EMIDEstatus=1
			,EMFechaIngresoEmpresa=@EMFechaReingreso
		WHERE 
				EMIdestatus=2 
			AND EMNumeroempleado=@EMNumeroEmpleado 
			AND EMIdempresa=@EMIdEmpresa 
			AND EMFechaBaja=@FechaBaja 
			AND EMIDParentesco=1
		SET @Registros= @@ROWCOUNT + @Registros
		IF @@ROWCOUNT = 0 
		BEGIN
			SET @codigo = 0;
			SET @mensaje = 'No se actualizaron los registros correctamente';
			PRINT 'No se actualizaron los registros correctamente'
		END
		ELSE
		BEGIN
			SET @codigo = 1;
			SET @mensaje = 'Se reactivo el empleado: ' + @EMNumeroEmpleado;
			PRINT 'Se reactivo el empleado: ' + @EMNumeroEmpleado
			PRINT @Registros
		END
	END
	ELSE
	BEGIN
		SET @codigo = 0;
		SET @mensaje = 'No existe el empleado titular o no pertenece a la empresa seleccionada: ' + @EMNumeroEmpleado
		PRINT 'NO EXISTE EL TITULAR'
	END
END
ELSE
BEGIN
	SET @codigo = 0;
	SET @mensaje = 'No se puede reactivar el empleado, ya existe un empleado activo con el mismo número de empleado';
END

SELECT @codigo as codigo, @mensaje as mensaje

END
GO

ALTER PROCEDURE [dbo].[ff_transferenciaMasivaEmpleado]
(
     @parametrosCarga NVARCHAR(MAX)
)
AS
BEGIN

SET NOCOUNT ON;

DECLARE
    @empleadoBaja INT,
    @codigo INT,
    @mensaje VARCHAR(MAX),
    @rowsEmpleado INT,
    @existen_registros INT,
    @idPerfilOrigen int,
	@mensajePlanesSolicitud VARCHAR(MAX) = '',
	@numeroPlanesOpacionales INT = 0

	-- Parametros transferencia masiva
DECLARE
	@IdEmpleado INT
    ,@EMIdEmpresa INT -- Empresa destino
    ,@EMIdEmpresaOrigen INT -- Empresa origen
    ,@EMNumeroEmpleado VARCHAR(20)
    ,@EMIdPerfil INT = NULL
    ,@EMRegimen INT  = NULL
    ,@EMVIP VARCHAR(50) = NULL
    ,@EMidCentroCostos VARCHAR(50) = NULL
    ,@EMTipoEmpleado VARCHAR(50) = NULL
    ,@EMPuesto VARCHAR(100) = NULL
    ,@EMArea INT = NULL
    ,@EMOficina INT = NULL
    
    ,@EMSalarioBase MONEY = 0
    ,@EMrfc VARCHAR(20) = NULL
    ,@EMcurp VARCHAR(50) = NULL
    ,@EMCorreoElectronico VARCHAR(500) = NULL
    ,@EMFecha_solicitud_movimiento VARCHAR(24) = NULL
    ,@EMSeleccionUsuario INT = 0
    ,@idSolicitud INT = 0
    ,@EMObservacionesTransferencia VARCHAR(500) = NULL
    ,@EMUsuarioUMod INT


-- Tabla obtener parametros

DECLARE 
@parametrosTransferenciaTMP AS TABLE
	(
		 IdEmpleado INT
		,EMIdEmpresa INT -- Empresa destino
		,EMIdEmpresaOrigen INT -- Empresa origen
		,EMNumeroEmpleado VARCHAR(20)
		,EMIdPerfil INT
		,EMRegimen INT 
		,EMVIP VARCHAR(50)
		,EMidCentroCostos VARCHAR(50)
		,EMTipoEmpleado VARCHAR(50)
		,EMPuesto VARCHAR(100)
		,EMArea INT
		,EMOficina INT    
		,EMSalarioBase MONEY
		,EMrfc VARCHAR(20)
		,EMcurp VARCHAR(50)
		,EMCorreoElectronico VARCHAR(500)
		,EMFecha_solicitud_movimiento VARCHAR(24)
		,EMSeleccionUsuario INT
		,idSolicitud INT
		,EMObservacionesTransferencia VARCHAR(500)
		,EMUsuarioUMod INT
	)

-- Volcar parametros a tabla

INSERT INTO @parametrosTransferenciaTMP
SELECT * 
FROM OPENJSON (@parametrosCarga)
	WITH (
		IdEmpleado INT N'$.IdEmpleado'
		,EMIdEmpresa INT N'$.EMIdEmpresa'
		,EMIdEmpresaOrigen INT N'$.EMIdEmpresaOrigen'
		,EMNumeroEmpleado VARCHAR(20) N'$.EMNumeroEmpleado'
		,EMIdPerfil INT N'$.EMIdPerfil'
		,EMRegimen INT  N'$.EMRegimen'
		,EMVIP VARCHAR(50) N'$.EMVIP'
		,EMidCentroCostos VARCHAR(50) N'$.EMidCentroCostos'
		,EMTipoEmpleado VARCHAR(50) N'$.EMTipoEmpleado'
		,EMPuesto VARCHAR(100) N'$.EMPuesto'
		,EMArea INT N'$.EMArea'
		,EMOficina INT     N'$.EMOficina'
		,EMSalarioBase MONEY N'$.EMSalarioBase'
		,EMrfc VARCHAR(20) N'$.EMrfc'
		,EMcurp VARCHAR(50) N'$.EMcurp'
		,EMCorreoElectronico VARCHAR(500) N'$.EMCorreoElectronico'
		,EMFecha_solicitud_movimiento VARCHAR(24) N'$.EMFecha_solicitud_movimiento'
		,EMSeleccionUsuario INT N'$.EMSeleccionUsuario'
		,idSolicitud INT N'$.idSolicitud'
		,EMObservacionesTransferencia VARCHAR(500) N'$.EMObservacionesTransferencia'
		,EMUsuarioUMod INT N'$.EMUsuarioUMod'
	);

-- Convertir tabla a variables

SELECT TOP 1
	 @IdEmpleado = IdEmpleado
    ,@EMIdEmpresa = EMIdEmpresa
    ,@EMIdEmpresaOrigen = EMIdEmpresaOrigen
    ,@EMNumeroEmpleado = EMNumeroEmpleado
    ,@EMIdPerfil = EMIdPerfil
    ,@EMRegimen = EMRegimen
    ,@EMVIP = EMVIP
    ,@EMidCentroCostos = EMidCentroCostos
    ,@EMTipoEmpleado = EMTipoEmpleado
    ,@EMPuesto = EMPuesto
    ,@EMArea = EMArea
    ,@EMOficina = EMOficina
    ,@EMSalarioBase = EMSalarioBase
    ,@EMrfc = EMrfc
    ,@EMcurp = EMcurp
    ,@EMCorreoElectronico = EMCorreoElectronico
    ,@EMFecha_solicitud_movimiento = EMFecha_solicitud_movimiento
    ,@EMSeleccionUsuario = EMSeleccionUsuario
    ,@idSolicitud = idSolicitud
    ,@EMObservacionesTransferencia = EMObservacionesTransferencia
    ,@EMUsuarioUMod = EMUsuarioUMod
FROM 
@parametrosTransferenciaTMP

-- Inicar procedimiento

-- Cargar datos originales
SELECT	@idPerfilOrigen = EMIdPerfil
FROM ff_Empleado 
WHERE ID=@IdEmpleado

BEGIN TRY
	
    /* Validar empleado baja */
    DECLARE 
		@ExisteEmpleado INT = 0
		,@IdEmpresaEmpleado INT = 0;

    SELECT
		TOP 1
        @ExisteEmpleado = EMIdEstatus
		,@IdEmpresaEmpleado = EMIdEmpresa
    FROM FF_EMPLEADO
    WHERE EMIDEMPRESA = @EMIdEmpresaOrigen
    AND EMNumeroEmpleado = @EMNumeroEmpleado
    AND EMIdParentesco = 1

	-- Iniciar validaciones
	IF (@EMIdEmpresa = @IdEmpresaEmpleado)
	BEGIN
		SET @codigo = 0
		SET @mensaje = 'El empleado ya pertenece a la empresa destino, no se realiza acción'
		SET @ExisteEmpleado = 0
	END
	ELSE
	BEGIN
		IF (@ExisteEmpleado = 0)
		BEGIN
			SET @codigo = 0
			SET @mensaje = 'No existe el empleado ' + @EMNumeroEmpleado + ' para la empresa seleccionada, no se realiza acción'
		END
    
		IF (@ExisteEmpleado = 2)
		BEGIN
			SET @codigo = 0
			SET @mensaje = 'El empleado ' + @EMNumeroEmpleado + ' tiene estatus baja para la empresa seleccionada, no se realiza acción'
		END
		IF (@ExisteEmpleado = 1)
		BEGIN 
			-- Validar existencia de empleado en empresa destino
			IF EXISTS (
				SELECT TOP 1 Id
				FROM ff_Empleado
				WHERE 
					EMIdEmpresa = @EMIdEmpresa -- Empresa destino
					AND EMNumeroEmpleado = @EMNumeroEmpleado
					AND EMIdParentesco = 1
			)
			BEGIN
				SET @codigo = 0
				SET @mensaje = 'Ya existe el empleado ' + @EMNumeroEmpleado + ' en la empresa destino, no se realiza acción'
				SET @ExisteEmpleado = 0
			END
		END
	END
	
	/* 
	* Catalogo de opciones seleccion usuario @EMSeleccionUsuario
	* 0 - No aplica
	* 1 - Defaulteo solicitud
	* 2 - Cambios calificados
	* 3 - Rechazo solicitud
	* 4 - Regenerar solicitud - Default cuando no hay diferencia de planes en transferencia individual
	*/

    IF (@ExisteEmpleado = 1)
    BEGIN 
        BEGIN TRAN
            -- Actualizar planes opcionales 
	        IF(@EMSeleccionUsuario in (1,2,3,4,0) and @idSolicitud <> 0)
	        BEGIN
		        DECLARE @Ids_PlanesEmpleado TABLE (IdPlan INT, IdPlanOpcion INT);
		        DECLARE @Ids_PlanesPerfilDestino TABLE (IdPlan INT, IdPlanOpcion INT);
		        DECLARE @Ids_PlanesSinPerfilDestino TABLE (IdPlan INT, IdPlanOpcion INT);
		        DECLARE @Ids_PlanesOpcionales TABLE (IdPlan INT, IdPlanOpcion INT);
		        DECLARE @Ids_PlanesOpcionalesDestino TABLE (IdPlanOpcion INT, IdPlanOpcionDestino INT);

		        -- Planes seleccionados para la solicitud actual
		        INSERT INTO @Ids_PlanesEmpleado
		        select 
			        pl.PLidPlan
			        ,pop.PPidPlanOpcion
		        from 
			        ff_PlanOpcionSeleccion pos 
			        inner join ff_PlanOpcion po
				        on po.POidPlanOpcion = pos.POidPlanOpcion
			        inner join ff_Plan pl
				        on pl.PLidPlan = po.POidPlan
			        left join ff_PlanOpcionPerfil pop
				        on pop.PPidPlanOpcion = pos.POidPlanOpcion
				        and pop.PPidPerfil = @idPerfilOrigen
		        where pos.POidSolicitud = @idSolicitud
		        group by pop.PPidPlanOpcion, pl.PLidPlan
		        order by pop.PPidPlanOpcion, pl.PLidPlan 

		        -- Recuperar planes que no existan en la empresa y perfil destino
		        INSERT INTO @Ids_PlanesPerfilDestino
		        -- Planes disponibles en la empresa y perfil destino
		        select 
			        pl.PLidPlan
			        ,pop.PPidPlanOpcion
		        from 
			        ff_PlanOpcionSeleccion pos 
			        inner join ff_PlanOpcion po
				        on po.POidPlanOpcion = pos.POidPlanOpcion
			        inner join ff_Plan pl
				        on pl.PLidPlan = po.POidPlan
			        left join ff_PlanOpcionPerfil pop
				        on pop.PPidPlanOpcion = pos.POidPlanOpcion
				        and pop.PPidPerfil = @EMIdPerfil
		        where 
			        pos.POidSolicitud = @idSolicitud
			        and pop.PPidPlanOpcion is null
		        group by pop.PPidPlanOpcion, pl.PLidPlan
		        order by pop.PPidPlanOpcion, pl.PLidPlan 

		        -- Recuperar planes de la empreas perfil origen que no existen en la empresa perfil destino
		        INSERT INTO @Ids_PlanesOpcionales
		        SELECT * 
		        FROM @Ids_PlanesEmpleado 
		        WHERE IdPlan in (select IdPlan from @Ids_PlanesPerfilDestino);

				-- Generar log diferencia planes
				select @numeroPlanesOpacionales = count(*) from @Ids_PlanesPerfilDestino

				IF(@numeroPlanesOpacionales = 0)
				BEGIN
					SET @mensajePlanesSolicitud = ', Planes equivalentes, procede transferencia de empleado.'
				END
				ELSE
				BEGIN
					IF(@numeroPlanesOpacionales > 0)
					BEGIN
						SET @mensajePlanesSolicitud  = ', Solicitud activa con diferencia de planes de acuerdo a su nuevo perfil.'
					END
				END

				-- Recuperar planes con equivalencia
		        INSERT INTO @Ids_PlanesOpcionalesDestino
		        select 
			        EP.EPidPlanOpcion
			        ,EP.EPidPlanOpcionDestino
		        from ff_EquivalenciaPlanesEmpresa EP
			        JOIN @Ids_PlanesOpcionales PLO
				        ON EP.EPidPlan = PLO.IdPlan 
				        AND EP.EPidPlanOpcion = PLO.IdPlanOpcion
		        where 
			        EP.EPidEmpresaOrigen = @EMIdEmpresaOrigen
			        and EP.EPidEmpresaDestino = @EMIdEmpresa
			        AND EP.EPIdPerfilOrigen = @idPerfilOrigen
			        AND EP.EPIdPerfilDestino = @EMIdPerfil
		
		        -- Actualizar id plan opcion de seleccion de empleado
		        UPDATE PTMP
		        SET PTMP.POidPlanOpcion = PD.IdPlanOpcionDestino
		        from ff_PlanOpcionSeleccionTmp PTMP
		        JOIN @Ids_PlanesOpcionalesDestino PD
			        ON PD.IdPlanOpcion = PTMP.POidPlanOpcion		
		        where PTMP.PONumeroEmpleado = @EMNumeroempleado
			        and PTMP.POidEmpresa = @EMIdEmpresaOrigen
			
	        END

            -- Rechazar solicitud
	        IF(@EMSeleccionUsuario in (1,2,3) and @idSolicitud <> 0)
	        BEGIN
		        EXEC ff_UpdateSolicitud
			        @SODetalleEstatus = 'Rechazada'
			        ,@SOEstatusSolicitud = 5
			        ,@SOUsuarioUMod = @EMUsuarioUMod
			        ,@SOIdSolicitud = @idSolicitud
	        END


            -- PLAN OPCION 
	        UPDATE FF_PLANOPCIONSELECCION 
	        SET POIDEMPRESA=@EMIdEmpresa,
		        POFechaUMod=GETDATE(),
		        POUsuarioUMod = @EMUsuarioUMod
	        where POidEmpresa = @EMIdEmpresaOrigen
	        and PONumeroEmpleado = @EMNumeroempleado


	        -- PO COBRANZA
	        UPDATE ff_PlanOpcionSeleccionCobranza  
	        SET POIDEMPRESA=@EMIdEmpresa,
		        POFechaUMod=GETDATE(),
		        POUsuarioUMod = @EMUsuarioUMod
	        where POidEmpresa = @EMIdEmpresaOrigen
		        and PONumeroEmpleado = @EMNumeroempleado

	        -- EDO CUENTA
	        UPDATE ff_EdoCuenta 
	        SET ECIDEMPRESA=@EMIdEmpresa,
	            ECUsuarioUMod = @EMUsuarioUMod,
		        ECFechaUMod=GETDATE() 
	        WHERE ecidsolicitud in (SELECT SOIdSolicitud
							        FROM ff_Solicitud 
							        WHERE SOIdEmpleado=@IdEmpleado 
								        and SOIdEmpresa =@EMIdEmpresaOrigen)

	        -- EDO CUENTA COBRANZA
	        UPDATE ff_EdoCuentaCobranza 
		        SET ECIDEMPRESA=@EMIdEmpresa,
			        ECUsuarioUMod = @EMUsuarioUMod,
			        ECFechaUMod=GETDATE() 
	        WHERE ecidsolicitud in (SELECT SOIdSolicitud
							        FROM ff_Solicitud 
							        WHERE SOIdEmpleado=@IdEmpleado 
							        and SOIdEmpresa =@EMIdEmpresaOrigen)

	        -- SOLICITUD
	        UPDATE  ff_Solicitud 
	        SET SOIDEMPRESA=@EMIdEmpresa,
		        SOFechaUMod=GETDATE(),
		        SOUsuarioUMod = @EMUsuarioUMod
	        WHERE   SOIdEmpleado=@IdEmpleado 
		        AND SOIdEmpresa = @EMIdEmpresaOrigen 	

            -- CAT: ESTO SE CAMBIO PARA QUE CUMPLIERA CON LO QUE SE SOLICITO QUE ERA ASIGNAR EL ROL DEFAULT NO ADMINISTRATIVO O, EN SU AUSENCIA, EL ROL NO ADMINISTRATIVO CON MENOR ID.
			DECLARE @IdRolDestino INT = NULL;

			SELECT TOP (1)
				@IdRolDestino = R.ROIdRol
			FROM dbo.ff_Rol R
			INNER JOIN dbo.ff_Perfil P
				ON P.PEIdRolDefault = R.ROIdRol
				AND P.PEIdEmpresa = @EMIdEmpresa
				AND P.PEIdEstatus = 1
			WHERE R.ROIdEmpresa = @EMIdEmpresa
				AND R.ROIdEstatus = 1
				AND R.RODefault = 1
				AND P.PEAdministrador = 0
			ORDER BY R.ROIdRol ASC;

			IF @IdRolDestino IS NULL
			BEGIN
				SELECT TOP (1)
					@IdRolDestino = R.ROIdRol
				FROM dbo.ff_Rol R
				INNER JOIN dbo.ff_Perfil P
					ON P.PEIdRolDefault = R.ROIdRol
					AND P.PEIdEmpresa = @EMIdEmpresa
					AND P.PEIdEstatus = 1
				WHERE R.ROIdEmpresa = @EMIdEmpresa
					AND R.ROIdEstatus = 1
					AND P.PEAdministrador = 0
				ORDER BY R.ROIdRol ASC;
			END;

			IF @IdRolDestino IS NULL
				THROW 51000, 'No existe un rol activo asociado a un perfil no administrador en la empresa destino.', 1;

			-- Actualizar datos EMPLEADO

			-- Tabla Temporal Empleado y dependientes
			DECLARE @EmpleadosCambioEmpresa TABLE (
				 ID INT
				,EMIdEmpresa INT
				,EMIdPerfil INT
				,EMVIP INT
				,EMTipoEmpleado [varchar](100)
				,EMArea INT
				,EMIdRol INT
				,EMRegimen INT
				,EMidCentroCostos INT
				,EMOficina INT
				,EMPuesto [varchar](100)
				,EMSalarioBase money
				,EMCorreoElectronico [varchar](500)
				,EMcurp [varchar](50)
				,EMrfc [varchar](20)
				,EMIdEstatus INT
				,EMIdTitular INT
			);

			-- Agrupar empleado y dependientes
			INSERT INTO @EmpleadosCambioEmpresa
				SELECT 
					ID
					,EMIdEmpresa	
					,EMIdPerfil
					,EMVIP
					,EMTipoEmpleado
					,EMArea
					,EMIdRol
					,EMRegimen
					,EMidCentroCostos
					,EMOficina
					,EMPuesto
					,EMSalarioBase
					,EMCorreoElectronico
					,EMcurp
					,EMrfc
					,EMIdEstatus
					,EMIdTitular
				FROM ff_Empleado 
				WHERE 
						EMIdEmpresa = @EMIdEmpresaOrigen 
					AND EMNumeroEmpleado = @EMNumeroempleado;

			-- Valicacion existencia registros con valores nulos
			DECLARE 
				 @existen_registros_EMOficina INT
				,@existen_registros_EMArea INT
				,@existen_registros_EMIdperfil INT
				,@existen_registros_emidrol INT 
				,@existen_registros_EMREGIMEN INT 
				,@existen_registros_EMVIP INT
				,@existen_registros_EMidCentroCostos INT 
				,@existen_registros_EMTipoEmpleado INT

			-- Validar existencia de valores nulos por campo
			SET @existen_registros_EMOficina = (SELECT COUNT(*) FROM @EmpleadosCambioEmpresa WHERE EMIdTitular <> 1 AND EMOficina IS NULL);
			SET @existen_registros_EMArea = (SELECT COUNT(*) FROM @EmpleadosCambioEmpresa WHERE EMIdTitular <> 1 AND EMArea IS NULL);
			SET @existen_registros_EMIdperfil = (SELECT COUNT(*) FROM @EmpleadosCambioEmpresa WHERE EMIdTitular <> 1 AND EMIdperfil IS NULL);
			SET @existen_registros_emidrol = (SELECT COUNT(*) FROM @EmpleadosCambioEmpresa WHERE EMIdTitular <> 1 AND EMIdRol IS NULL);
			SET @existen_registros_EMREGIMEN = (SELECT COUNT(*) FROM @EmpleadosCambioEmpresa WHERE EMIdTitular <> 1 AND EMRegimen IS NULL);
			SET @existen_registros_EMVIP = (SELECT COUNT(*) FROM @EmpleadosCambioEmpresa WHERE EMIdTitular <> 1 AND EMVIP IS NULL);
			SET @existen_registros_EMidCentroCostos = (SELECT COUNT(*) FROM @EmpleadosCambioEmpresa WHERE EMIdTitular <> 1 AND EMidCentroCostos IS NULL);
			SET @existen_registros_EMTipoEmpleado = (SELECT COUNT(*) FROM @EmpleadosCambioEmpresa WHERE EMIdTitular <> 1 AND EMTipoEmpleado IS NULL);

			SET NOCOUNT ON;

			-- Actualizar tabla empleado con los nuevos datos de empleado
			UPDATE ff_Empleado 
			SET
				 EMIdEmpresa =  @EMIdEmpresa
				,EMIdPerfil = CASE 
					WHEN @existen_registros_EMIdperfil = 0 THEN @EMIdPerfil
					WHEN @existen_registros_EMIdperfil <> 0 AND EMIdTitular = 1 THEN @EMIdPerfil
					ELSE EMIdPerfil END
				,EMIdRol = CASE 
					WHEN @existen_registros_emidrol = 0 THEN @IdRolDestino
					WHEN @existen_registros_emidrol <> 0 AND EMIdTitular = 1 THEN @IdRolDestino
					ELSE EMIdRol END
				,EMVIP = CASE 
					WHEN @existen_registros_EMVIP = 0 AND @EMVIP <> '' THEN @EMVIP
					WHEN @existen_registros_EMVIP <> 0 AND EMIdTitular = 1 AND @EMVIP <> '' THEN @EMVIP
					ELSE EMVIP END
				,EMTipoEmpleado = CASE 
					WHEN @existen_registros_EMTipoEmpleado = 0 AND @EMTipoEmpleado <> '' THEN @EMTipoEmpleado
					WHEN @existen_registros_EMTipoEmpleado <> 0 AND EMIdTitular = 1 AND @EMTipoEmpleado <> '' THEN @EMTipoEmpleado
					ELSE EMTipoEmpleado END
				,EMArea = CASE 
					WHEN @existen_registros_EMArea = 0 AND @EMArea <> '' THEN @EMArea
					WHEN @existen_registros_EMArea <> 0 AND EMIdTitular = 1 AND @EMArea <> '' THEN @EMArea
					ELSE EMArea END
				,EMRegimen = CASE 
					WHEN @existen_registros_EMREGIMEN = 0 AND @EMRegimen <> '' THEN @EMRegimen
					WHEN @existen_registros_EMREGIMEN <> 0 AND EMIdTitular = 1 AND @EMRegimen <> '' THEN @EMRegimen
					ELSE EMRegimen END
				,EMidCentroCostos = CASE 
					WHEN @existen_registros_EMidCentroCostos = 0 AND @EMidCentroCostos <> '' THEN @EMidCentroCostos
					WHEN @existen_registros_EMidCentroCostos <> 0 AND EMIdTitular = 1 AND @EMidCentroCostos <> '' THEN @EMidCentroCostos
					ELSE EMidCentroCostos END
				,EMOficina = CASE 
					WHEN @EMOficina <> '' THEN @EMOficina
					ELSE EMOficina END
				,EMPuesto = CASE WHEN @EMPuesto IS NOT NULL AND LTRIM(RTRIM(@EMPuesto)) <> '' AND EMIdTitular = 1 THEN @EMPuesto ELSE EMPuesto END
				,EMSalarioBase = CASE WHEN @EMSalarioBase IS NOT NULL AND EMIdTitular = 1 THEN @EMSalarioBase ELSE EMSalarioBase END
				,EMCorreoElectronico = CASE WHEN @EMCorreoElectronico IS NOT NULL AND LTRIM(RTRIM(@EMCorreoElectronico)) <> '' AND EMIdTitular = 1 THEN @EMCorreoElectronico ELSE EMCorreoElectronico END
				,EMcurp = CASE WHEN @EMcurp IS NOT NULL AND LTRIM(RTRIM(@EMcurp)) <> '' AND EMIdTitular = 1 THEN @EMcurp ELSE EMcurp END
				,EMrfc = CASE WHEN @EMrfc IS NOT NULL AND LTRIM(RTRIM(@EMrfc)) <> '' AND EMIdTitular = 1 THEN @EMrfc ELSE EMrfc END	
				,EMUsuarioUMod = @EMUsuarioUMod
				,EMObservaciones = ISNULL(@EMObservacionesTransferencia, 'Transferencia de empleado')
				,EMFechaUMod = GETDATE()
				,EMFecha_solicitud_movimiento = @EMFecha_solicitud_movimiento
				,EMFecha_ejecucion_movimiento = GETDATE()
			WHERE 
					EMIdEmpresa = @EMIdEmpresaOrigen 
				AND EMNumeroEmpleado = @EMNumeroempleado 	

            SET @rowsEmpleado = @@ROWCOUNT


            /* Validar si se actualizó empleado */
            IF @rowsEmpleado > 0
            BEGIN

                COMMIT TRAN

                SET @codigo = 200
                SET @mensaje = 'Usuario transferido correctamente.'

            END
            ELSE
            BEGIN

                ROLLBACK TRAN

                SET @codigo = 400
                SET @mensaje = 'No se encontró el empleado para transferir.'

            END


            /* TEMP EDO CUENTA */
            SELECT @existen_registros = COUNT(*)
            FROM ff_EdoCuentaTmp
            WHERE ECNumeroEmpleado = @EMNumeroEmpleado
            AND ECidEmpresa = @EMIdEmpresa


            IF @existen_registros <> 0
            BEGIN
                DELETE ff_EdoCuentaTmp
                WHERE
                ECNumeroEmpleado = @EMNumeroEmpleado
                AND ECidEmpresa = @EMIdEmpresa
            END


            UPDATE ff_EdoCuentaTmp
            SET
                ECidEmpresa = @EMIdEmpresa,
                ECUsuarioUMod = @EMUsuarioUMod,
                ECFechaUMod = GETDATE()
            WHERE
                ECNumeroEmpleado = @EMNumeroEmpleado
                AND ECidEmpresa = @EMIdEmpresaOrigen


            -- Modificacion Temporal Solicitud/Cotizador
			UPDATE ff_PlanOpcionSeleccionTmp
			SET POidEmpresa = @EMIdEmpresa,
				POUsuarioUMod = @EMUsuarioUMod, 
				POFechaUMod = GETDATE()
			WHERE 
				PONumeroEmpleado = @EMNumeroempleado 
				and POidEmpresa = @EMIdEmpresaOrigen  

			-- Guardar log 
			DECLARE @mensajeLog varchar(500) = ''
			SET @mensajeLog = case
					when @EMSeleccionUsuario = 0 AND @idSolicitud = 0 then ' Transferencia de empleado sin solicitud activa.'
					when @EMSeleccionUsuario = 1 then ' Transferencia de empleado con defaulteo de solicitud.'
					when @EMSeleccionUsuario = 2 then ' Transferencia de empleado con cambios calificados.'
					when @EMSeleccionUsuario = 3 then ' Transferencia de empleado con rechazo de solicitud activa.'
					when @EMSeleccionUsuario = 4 then ' Transferencia de empleado con regeneración de solicitud.'
					else ''
				end
			-- Mostrar mensaje estatus solicitud
			SET @mensajeLog = case
					when @idSolicitud = 0 AND @EMSeleccionUsuario <> 0 then @mensajeLog + ' No se genero la acción ya que no se encontró una solicitud activa para el empleado ' + @EMNumeroEmpleado
					else @mensajeLog + ISNULL(@mensajePlanesSolicitud,'')
				end
			-- Mostrar seleccion en el log
			SET @mensaje = @mensaje + @mensajeLog

			-- Insertar registro log
			INSERT INTO ff_LogTranferenciaEmpleado
				(LTEidEmpleado,LTEidSolicitud,LTEidAccion,LTEDetalleAccion,LTEidEmpresaOrigen,LTEidEmpresaDestino,LTEUsuarioAdd)
			VALUES
			(
				@IdEmpleado, @idSolicitud, @EMSeleccionUsuario, @mensajeLog, @EMIdEmpresaOrigen, @EMIdEmpresa, @EMUsuarioUMod
			);

    END

END TRY

BEGIN CATCH

    IF @@TRANCOUNT > 0
        ROLLBACK TRAN

    SET @codigo = 500
    SET @mensaje = ERROR_MESSAGE()

END CATCH

SELECT 
	@codigo AS code
	,@mensaje AS msg
	,@IdEmpleado AS IdEmpleado
	,@EMNumeroEmpleado AS EMNumeroEmpleado
	,@EMIdEmpresa AS EMIdEmpresa
	,@idSolicitud AS idSolicitud
	,@EMSeleccionUsuario AS EMSeleccionUsuario

END
GO

