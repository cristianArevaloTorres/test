/*
  PREPARA LOS DATOS DE LOS SIETE TXT DE CARGA MASIVA B2/BF3.

  Base local validada: FlexiForbesv2
  Empresa destino: 186
  Empresa origen de transferencia: 187

  Puede ejecutarse antes de una primera prueba o para restablecerla. Solo
  elimina/recrea registros QA identificados por los numeros QACM* listados
  abajo. Si alguno ya tiene relaciones funcionales ajenas a estas pruebas,
  una FK detendra el script y toda la transaccion se revertira.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @IdEmpresa INT = 186;
DECLARE @IdEmpresaOrigen INT = 187;
DECLARE @Usuario INT = 3043;
DECLARE @Ahora DATETIME = GETDATE();

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM dbo.ff_Empresa WHERE EMIdEmpresa = @IdEmpresa AND EMIdEstatus = 1)
        THROW 51800, 'No existe la empresa activa 186.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.ff_Empresa WHERE EMIdEmpresa = @IdEmpresaOrigen AND EMIdEstatus = 1)
        THROW 51801, 'No existe la empresa origen activa 187.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.ff_Rol WHERE ROIdRol = 575 AND ROIdEmpresa = 186 AND ROIdEstatus = 1)
        THROW 51802, 'No existe el rol activo 575 de la empresa 186.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.ff_Rol WHERE ROIdRol = 584 AND ROIdEmpresa = 187 AND ROIdEstatus = 1)
        THROW 51803, 'No existe el rol activo 584 de la empresa 187.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.ff_Vigencia WHERE VIIdVigencia = 580 AND VIIdEstatus = 1)
        THROW 51804, 'No existe la vigencia activa 580 requerida por el escenario de autos.', 1;

    /* Alta y transferencia requieren un rol default de destino. No altera un
       default existente; en el fragmento local se habilita el rol usado por
       la mayoria de titulares de la empresa 186. */
    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.ff_Rol
        WHERE ROIdEmpresa = 186 AND ROIdEstatus = 1 AND RODefault = 1
    )
    BEGIN
        UPDATE dbo.ff_Rol
        SET RODefault = 1
        WHERE ROIdRol = 575;
    END;

    DECLARE @Numeros TABLE (numero VARCHAR(20) NOT NULL PRIMARY KEY);
    INSERT @Numeros (numero)
    VALUES
        ('QACMBASE186'), ('QACMALTA186'), ('QACMCHGA186'),
        ('QACMCHGB186'), ('QACMREACT186'), ('QACMCOMP186'),
        ('QACMCONC186'), ('QACMTRANS186');

    /* Proteccion contra una coincidencia accidental con datos no dummy. */
    IF EXISTS
    (
        SELECT 1
        FROM dbo.ff_Empleado E
        INNER JOIN @Numeros N ON N.numero = E.EMNumeroEmpleado
        WHERE ISNULL(E.EMApellidoPaterno, '') NOT IN ('PRUEBA', 'ALTA')
    )
        THROW 51805, 'Un numero QACM ya pertenece a un registro que no parece dummy. No se modifico nada.', 1;

    DECLARE @EmpleadosAnteriores TABLE (idEmpleado INT NOT NULL PRIMARY KEY);
    INSERT @EmpleadosAnteriores (idEmpleado)
    SELECT DISTINCT E.Id
    FROM dbo.ff_Empleado E
    INNER JOIN @Numeros N ON N.numero = E.EMNumeroEmpleado;

    /* Limpia exclusivamente resultados generados por una prueba previa. */
    DELETE C
    FROM dbo.bf_Compensacion_STEmpleado C
    INNER JOIN @EmpleadosAnteriores E ON E.idEmpleado = C.CSIdEmpleado
    WHERE C.CSIdCompensacion = 900001;

    DELETE D
    FROM dbo.bf_DescuentoEmpleadoConciliacion D
    INNER JOIN @EmpleadosAnteriores E ON E.idEmpleado = D.DEIdEmpleado
    WHERE D.DENumeroRegistroAseguradora = 'QACM-CIS-186'
       OR D.DEPeriodo = 'QACM202699';

    DELETE L
    FROM dbo.ff_LogTranferenciaEmpleado L
    INNER JOIN @EmpleadosAnteriores E ON E.idEmpleado = L.LTEIdEmpleado
    WHERE L.LTEIdEmpresaOrigen = 187 AND L.LTEIdEmpresaDestino = 186;

    DECLARE @SolicitudesAutos TABLE (id INT NOT NULL PRIMARY KEY);
    INSERT @SolicitudesAutos (id)
    SELECT SAIdSolicitudAutos
    FROM dbo.fb_SolicitudAutos
    WHERE SANumeroRegistroAseguradora = 'QACM-CIS-186';

    DECLARE @EdoCuentaAutos TABLE (id INT NOT NULL PRIMARY KEY);
    INSERT @EdoCuentaAutos (id)
    SELECT ECIdEdoCuentaAutos
    FROM dbo.fb_EdoCuentaAutos E
    INNER JOIN @SolicitudesAutos S ON S.id = E.ECIdSolicitud;

    DECLARE @Desgloses TABLE (id INT NOT NULL PRIMARY KEY);
    INSERT @Desgloses (id)
    SELECT ECIdEdoCuentaDesglose
    FROM dbo.fb_EdoCuentaDesglose D
    INNER JOIN @EdoCuentaAutos E ON E.id = D.ECIdEdoCuentaAutos;

    DELETE L
    FROM dbo.bf_LogArchivoDescuentos L
    INNER JOIN @Desgloses D ON D.id = L.LAIdEdoCuentaDesglose;

    DELETE D
    FROM dbo.fb_EdoCuentaDesglose D
    INNER JOIN @Desgloses X ON X.id = D.ECIdEdoCuentaDesglose;

    DELETE E
    FROM dbo.fb_EdoCuentaAutos E
    INNER JOIN @EdoCuentaAutos X ON X.id = E.ECIdEdoCuentaAutos;

    DELETE S
    FROM dbo.fb_SolicitudAutos S
    INNER JOIN @SolicitudesAutos X ON X.id = S.SAIdSolicitudAutos;

    DELETE FROM dbo.fb_CalendarioIngresoNomina
    WHERE CNNombrePeriodo = 'QACM CONCILIACION'
       OR CNQuincenaAnioCalendario = 'QACM202699';

    /* Dependientes primero; luego titulares. Una relacion externa real
       detendra el DELETE y provocara ROLLBACK por XACT_ABORT. */
    DELETE E
    FROM dbo.ff_Empleado E
    INNER JOIN @Numeros N ON N.numero = E.EMNumeroEmpleado
    WHERE E.EMIdParentesco <> 1;

    DELETE E
    FROM dbo.ff_Empleado E
    INNER JOIN @Numeros N ON N.numero = E.EMNumeroEmpleado
    WHERE E.EMIdParentesco = 1;

    /* Titulares base de cada operacion. */
    INSERT dbo.ff_Empleado
    (
        EMIdEmpresa, EMIdTitular, EMIdPerfil, EMIdParentesco, EMIdSexo,
        EMIdEstatus, EMNumeroEmpleado, EMCertificado, EMNombre1,
        EMApellidoPaterno, EMApellidoMaterno, EMFechaNacimiento,
        EMFechaIngresoEmpresa, EMFechaAlta, EMFechaEstatus, EMFechaBaja,
        EMIdRol, EMArea, EMOficina, EMIdCentroCostos, EMSalarioBase,
        EMUsuarioAdd, EMFechaAdd
    )
    VALUES
    (186, 1, 678, 1, 1, 1, 'QACMBASE186',  'QACMBASE186',  'BASE',         'PRUEBA', 'CARGA', '1985-01-15', '2020-01-01', '2020-01-01', @Ahora, NULL,         575, 5, 23, 10001, 20000, @Usuario, @Ahora),
    (186, 1, 678, 1, 1, 1, 'QACMCHGA186',  'QACMCHGA186',  'CAMBIO',       'PRUEBA', 'CARGA', '1986-02-16', '2020-01-01', '2020-01-01', @Ahora, NULL,         575, 5, 23, 10001, 20000, @Usuario, @Ahora),
    (186, 1, 678, 1, 1, 2, 'QACMREACT186', 'QACMREACT186', 'REACTIVACION', 'PRUEBA', 'CARGA', '1987-03-17', '2020-01-01', '2020-01-01', @Ahora, '2026-08-01', 575, 5, 23, 10001, 20000, @Usuario, @Ahora),
    (186, 1, 678, 1, 1, 1, 'QACMCOMP186',  'QACMCOMP186',  'COMPENSACION', 'PRUEBA', 'CARGA', '1988-04-18', '2020-01-01', '2020-01-01', @Ahora, NULL,         575, 5, 23, 10001, 20000, @Usuario, @Ahora),
    (186, 1, 678, 1, 1, 1, 'QACMCONC186',  'QACMCONC186',  'CONCILIACION', 'PRUEBA', 'CARGA', '1989-05-19', '2020-01-01', '2020-01-01', @Ahora, NULL,         575, 5, 23, 10001, 20000, @Usuario, @Ahora),
    (187, 1, 677, 1, 1, 1, 'QACMTRANS186', 'QACMTRANS186', 'TRANSFERENCIA','PRUEBA', 'CARGA', '1990-06-20', '2020-01-01', '2020-01-01', @Ahora, NULL,         584, 5, 23, 10001, 20000, @Usuario, @Ahora);

    /* Cadena minima real que valida ff_XCMDescuentosCMAutos. */
    DECLARE @IdEmpleadoConciliacion INT =
    (
        SELECT Id FROM dbo.ff_Empleado
        WHERE EMIdEmpresa = 186 AND EMNumeroEmpleado = 'QACMCONC186'
          AND EMIdParentesco = 1
    );
    DECLARE @IdCalendario INT;
    DECLARE @IdSolicitudAuto INT;
    DECLARE @IdEdoCuentaAuto INT;
    DECLARE @IdDesglose INT;

    INSERT dbo.fb_CalendarioIngresoNomina
    (
        CNIdEmpresa, CNNombrePeriodo, CNFechaInicioIngreso,
        CNFechaFinIngreso, CNFechaCorteNomina, CNFechaAplicacionDescuento,
        CNNumeroQuincena, CNQuincenaAnioCalendario, CNEstatus,
        CNUsuarioAdd, CNFechaAdd, CNIdVigencia
    )
    VALUES
    (185, 'QACM CONCILIACION', '2026-08-01', '2026-08-15', '2026-08-15',
     '2026-08-16', 99, 'QACM202699', 1, @Usuario, @Ahora, 580);
    SET @IdCalendario = CONVERT(INT, SCOPE_IDENTITY());

    INSERT dbo.fb_SolicitudAutos
    (
        SAIdVigencia, SAIdPaquete, SAIdTarifaVehiculo, SAIdPaqueteCopia,
        SANumeroRegistroAseguradora, SAIdEmpresaTitular, SAIdEmpleadoTitular,
        SAFechaInicioContratacion, SAFechaSolicitud, SANumeroSerieAuto,
        SAEstatus, SAUsuarioAdd, SAFechaAdd
    )
    VALUES
    (580, 0, 0, 0, 'QACM-CIS-186', 186, @IdEmpleadoConciliacion,
     '2026-01-01', @Ahora, 'QACM-SERIE-186', 1, @Usuario, @Ahora);
    SET @IdSolicitudAuto = CONVERT(INT, SCOPE_IDENTITY());

    INSERT dbo.fb_EdoCuentaAutos
        (ECIdSolicitud, ECNumeroRecibosADN, ECNumeroDescuentos, ECStatus,
         ECUsuarioAdd, ECFechaAdd)
    VALUES
        (@IdSolicitudAuto, 1, 1, 1, @Usuario, @Ahora);
    SET @IdEdoCuentaAuto = CONVERT(INT, SCOPE_IDENTITY());

    INSERT dbo.fb_EdoCuentaDesglose
    (
        ECIdEdoCuentaAutos, ECNumeroRecibo, ECPrimaTotalRecibo,
        ECProgramado, ECConciliado, ECLiquidado,
        ECIdCalendarioIngresoNomina, ECEstatus, ECUsuarioAdd, ECFechaAdd
    )
    VALUES
    (@IdEdoCuentaAuto, 1, 100.00, 1, 0, 0,
     @IdCalendario, 1, @Usuario, @Ahora);
    SET @IdDesglose = CONVERT(INT, SCOPE_IDENTITY());

    INSERT dbo.bf_LogArchivoDescuentos
    (
        LAIdEdoCuentaDesglose, LAIdCalendarioIngresoNomina,
        LAFechaCorteNomina, LANombreArchivoEnvio, LAFechaEnvio,
        LAEstatus, LAUsuarioAdd, LAFechaAdd
    )
    VALUES
    (@IdDesglose, @IdCalendario, '2026-08-15',
     'QACM_CONCILIACION.txt', @Ahora, 1, @Usuario, @Ahora);

    COMMIT TRANSACTION;

    SELECT
        E.EMIdEmpresa,
        E.Id AS IdEmpleado,
        E.EMNumeroEmpleado,
        E.EMNombre1,
        E.EMApellidoPaterno,
        E.EMIdEstatus,
        E.EMFechaBaja,
        E.EMIdRol,
        CASE E.EMNumeroEmpleado
            WHEN 'QACMBASE186' THEN '01 ALTA DEPENDIENTE'
            WHEN 'QACMCHGA186' THEN '13 CAMBIO DE NUMERO'
            WHEN 'QACMREACT186' THEN '14 REACTIVACION'
            WHEN 'QACMCOMP186' THEN '16 COMPENSACION'
            WHEN 'QACMCONC186' THEN '05 CONCILIACION AUTOS'
            WHEN 'QACMTRANS186' THEN '15 TRANSFERENCIA'
        END AS escenarioPreparado
    FROM dbo.ff_Empleado E
    WHERE E.EMNumeroEmpleado IN
    (
        'QACMBASE186', 'QACMCHGA186', 'QACMREACT186',
        'QACMCOMP186', 'QACMCONC186', 'QACMTRANS186'
    )
    ORDER BY E.EMIdEmpresa, E.EMNumeroEmpleado;

    SELECT
        'OK' AS Resultado,
        'Los dummies estan listos. El titular QACMALTA186 se crea al cargar el TXT 02.' AS Mensaje,
        'EJEMPLOS_TXT_CARGA_186' AS CarpetaArchivos;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
