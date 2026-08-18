USE [FlexiForbesv2]
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.bf_RepConf_Columna', N'U') IS NULL
        THROW 50020, 'No existe dbo.bf_RepConf_Columna.', 1;

    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Costo'
     WHERE idEmpresa = 0 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'Costo11';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 64 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 64 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 64 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 66 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 66 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 66 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 67 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 67 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 67 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 71 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 71 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 71 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 72 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 72 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 72 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 73 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 73 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 73 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 77 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 77 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 77 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 89 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 89 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Oro (Sin Límite)'
     WHERE idEmpresa = 89 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'OroSinLimite';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Visión Plan Básico'
     WHERE idEmpresa = 89 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'VisionPlanBasico';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Visión Plan Plus'
     WHERE idEmpresa = 89 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'VisionPlanPlus';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 89 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 89 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 90 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 90 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 90 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 90 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 92 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 92 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 92 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 93 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 93 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 93 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 94 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 94 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 94 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 94 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 115 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 115 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 115 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 115 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 119 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 119 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 142 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 142 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 143 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 143 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 144 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 144 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 145 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 145 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 149 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 149 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 150 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 150 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 151 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 151 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 152 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 152 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 153 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 153 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 155 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 155 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 155 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 160 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 160 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 160 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 161 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 161 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 161 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 164 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 164 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 164 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 166 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 166 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 166 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 168 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 168 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 169 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 169 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 173 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 173 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 173 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 173 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 174 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 174 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 174 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 174 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 177 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 177 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 177 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 178 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 178 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 178 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 180 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 180 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 180 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 187 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 187 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 187 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 191 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 191 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 191 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 191 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 197 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 197 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 197 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 199 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 199 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 199 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 214 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 214 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 214 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 218 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 218 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 218 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 236 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 236 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 236 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 238 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 238 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 238 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 248 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 248 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 248 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 249 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 249 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 249 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 256 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 256 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 256 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 257 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 257 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 257 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 261 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 261 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 261 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 262 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 262 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 262 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 288 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 288 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 290 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 290 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 290 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 290 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 293 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 293 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 293 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 308 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 308 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 308 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 332 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 332 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 332 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 333 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 333 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 333 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 365 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 365 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 365 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 369 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 369 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 369 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 373 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 373 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 373 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 378 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 378 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 378 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 380 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 380 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 380 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 419 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 419 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 419 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 425 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 425 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 425 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 431 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 431 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Oro (Sin Límite)'
     WHERE idEmpresa = 431 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'OroSinLimite';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Visión Plan Básico'
     WHERE idEmpresa = 431 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'VisionPlanBasico';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Visión Plan Plus'
     WHERE idEmpresa = 431 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'VisionPlanPlus';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 431 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 431 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 432 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 432 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Oro (Sin Límite)'
     WHERE idEmpresa = 432 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'OroSinLimite';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Visión Plan Básico'
     WHERE idEmpresa = 432 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'VisionPlanBasico';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Visión Plan Plus'
     WHERE idEmpresa = 432 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'VisionPlanPlus';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 432 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 432 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 434 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 434 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 434 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 439 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 439 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 439 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 443 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 443 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 443 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 444 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 444 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 444 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 445 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 445 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 445 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 446 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 446 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 446 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 479 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 479 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 479 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 498 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 498 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 498 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 506 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 506 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 506 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 517 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 517 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 517 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 518 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 518 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 518 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 546 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 546 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 546 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 547 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 547 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 547 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 548 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 548 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 548 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 581 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 581 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 581 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 582 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 582 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 582 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 676 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 676 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Oro (Sin Límite)'
     WHERE idEmpresa = 676 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'OroSinLimite';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Visión Plan Básico'
     WHERE idEmpresa = 676 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'VisionPlanBasico';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Visión Plan Plus'
     WHERE idEmpresa = 676 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'VisionPlanPlus';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 676 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 676 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 677 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 677 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Oro (Sin Límite)'
     WHERE idEmpresa = 677 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'OroSinLimite';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Visión Plan Básico'
     WHERE idEmpresa = 677 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'VisionPlanBasico';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Visión Plan Plus'
     WHERE idEmpresa = 677 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'VisionPlanPlus';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 677 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 677 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 678 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 678 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Oro (Sin Límite)'
     WHERE idEmpresa = 678 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'OroSinLimite';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Visión Plan Básico'
     WHERE idEmpresa = 678 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'VisionPlanBasico';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Visión Plan Plus'
     WHERE idEmpresa = 678 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'VisionPlanPlus';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 678 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 678 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 679 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 679 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Oro (Sin Límite)'
     WHERE idEmpresa = 679 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'OroSinLimite';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Visión Plan Básico'
     WHERE idEmpresa = 679 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'VisionPlanBasico';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Visión Plan Plus'
     WHERE idEmpresa = 679 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'VisionPlanPlus';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 679 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 679 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 680 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 680 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Oro (Sin Límite)'
     WHERE idEmpresa = 680 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'OroSinLimite';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Visión Plan Básico'
     WHERE idEmpresa = 680 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'VisionPlanBasico';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Visión Plan Plus'
     WHERE idEmpresa = 680 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'VisionPlanPlus';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 680 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 680 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 684 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 684 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 684 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 856 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 856 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 856 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 857 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 857 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 857 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Número Certificado'
     WHERE idEmpresa = 900 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMCertificado';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 900 AND catReportesId = 3
       AND grupo = N'GMM' AND campoOrigen = N'EMFechaIngresoEmpresa';
    UPDATE dbo.bf_RepConf_Columna
       SET encabezado = N'Fecha Antigüedad'
     WHERE idEmpresa = 900 AND catReportesId = 3
       AND grupo = N'Vida' AND campoOrigen = N'EMFechaIngresoEmpresa';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=155 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'Plan_Visi?n')
    BEGIN
        UPDATE dbo.bf_RepConf_Columna
           SET campoOrigen=N'Plan_Visión', encabezado=N'Plan_Visión_BÁSICO', visible=1
         WHERE idEmpresa=155 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'Plan_Visi?n';
    END
    ELSE IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=155 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'Plan_Visión')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 155,3,N'GMM',ISNULL(MAX(orden),0)+1,N'Plan_Visión',N'Plan_Visión_BÁSICO',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=155 AND catReportesId=3 AND grupo=N'GMM';
    END
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=155 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'Plan_Visi?n2')
    BEGIN
        UPDATE dbo.bf_RepConf_Columna
           SET campoOrigen=N'Plan_Visión2', encabezado=N'Plan_Visión_STANDAR', visible=1
         WHERE idEmpresa=155 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'Plan_Visi?n2';
    END
    ELSE IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=155 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'Plan_Visión2')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 155,3,N'GMM',ISNULL(MAX(orden),0)+1,N'Plan_Visión2',N'Plan_Visión_STANDAR',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=155 AND catReportesId=3 AND grupo=N'GMM';
    END
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=155 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'Plan_Visi?n3')
    BEGIN
        UPDATE dbo.bf_RepConf_Columna
           SET campoOrigen=N'Plan_Visión3', encabezado=N'Plan_Visión_PLUS', visible=1
         WHERE idEmpresa=155 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'Plan_Visi?n3';
    END
    ELSE IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=155 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'Plan_Visión3')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 155,3,N'GMM',ISNULL(MAX(orden),0)+1,N'Plan_Visión3',N'Plan_Visión_PLUS',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=155 AND catReportesId=3 AND grupo=N'GMM';
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'Vida-18_meses_sueldo')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 186,3,N'Vida',ISNULL(MAX(orden),0)+1,N'Vida-18_meses_sueldo',N'VIDA-18_meses_sueldo',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida';
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'Costo_4')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 186,3,N'Vida',ISNULL(MAX(orden),0)+1,N'Costo_4',N'Costo_4',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida';
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'Vida-24_meses_sueldo')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 186,3,N'Vida',ISNULL(MAX(orden),0)+1,N'Vida-24_meses_sueldo',N'Vida-24_meses_sueldo',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida';
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'Costo_3')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 186,3,N'Vida',ISNULL(MAX(orden),0)+1,N'Costo_3',N'Costo_3',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida';
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'Vida-30_meses_sueldo')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 186,3,N'Vida',ISNULL(MAX(orden),0)+1,N'Vida-30_meses_sueldo',N'Vida-30_meses_sueldo',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida';
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'Costo_2')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 186,3,N'Vida',ISNULL(MAX(orden),0)+1,N'Costo_2',N'Costo_2',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida';
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'Vida-36_meses_sueldo')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 186,3,N'Vida',ISNULL(MAX(orden),0)+1,N'Vida-36_meses_sueldo',N'Vida-36_meses_sueldo',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida';
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'Costo_1')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 186,3,N'Vida',ISNULL(MAX(orden),0)+1,N'Costo_1',N'Costo_1',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida';
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'Vida-42_meses_sueldo')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 186,3,N'Vida',ISNULL(MAX(orden),0)+1,N'Vida-42_meses_sueldo',N'Vida-42_meses_sueldo',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida';
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'Costo_5')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 186,3,N'Vida',ISNULL(MAX(orden),0)+1,N'Costo_5',N'Costo_5',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida';
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'Vida-48_meses_sueldo')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 186,3,N'Vida',ISNULL(MAX(orden),0)+1,N'Vida-48_meses_sueldo',N'Vida-48_meses_sueldo',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida';
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'Costo_6')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 186,3,N'Vida',ISNULL(MAX(orden),0)+1,N'Costo_6',N'Costo_6',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida';
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'SS_18_MESES')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 186,3,N'Vida',ISNULL(MAX(orden),0)+1,N'SS_18_MESES',N'SS_18 MESES',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida';
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'Costo_7')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 186,3,N'Vida',ISNULL(MAX(orden),0)+1,N'Costo_7',N'Costo_7',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida';
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'SS_24_MESES')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 186,3,N'Vida',ISNULL(MAX(orden),0)+1,N'SS_24_MESES',N'SS_24 MESES',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida';
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'Costo_8')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 186,3,N'Vida',ISNULL(MAX(orden),0)+1,N'Costo_8',N'Costo_8',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida';
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'SS_30_MESES')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 186,3,N'Vida',ISNULL(MAX(orden),0)+1,N'SS_30_MESES',N'SS_30 MESES',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida';
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'Costo_9')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 186,3,N'Vida',ISNULL(MAX(orden),0)+1,N'Costo_9',N'Costo_9',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida';
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'SS_36_MESES')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 186,3,N'Vida',ISNULL(MAX(orden),0)+1,N'SS_36_MESES',N'SS_36 MESES',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida';
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'Costo_10')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 186,3,N'Vida',ISNULL(MAX(orden),0)+1,N'Costo_10',N'Costo_10',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida';
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'SS_42_MESES')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 186,3,N'Vida',ISNULL(MAX(orden),0)+1,N'SS_42_MESES',N'SS_42 MESES',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida';
    END
    IF NOT EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'Costo_11')
    BEGIN
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 186,3,N'Vida',ISNULL(MAX(orden),0)+1,N'Costo_11',N'Costo_11',1,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=186 AND catReportesId=3 AND grupo=N'Vida';
    END
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'NombrePestana')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'NombrePestana';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'GMM',ISNULL(MAX(orden),0)+1,N'NombrePestana',N'NombrePestana',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'TipoSabana')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'TipoSabana';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'GMM',ISNULL(MAX(orden),0)+1,N'TipoSabana',N'TipoSabana',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'POidPlan')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'POidPlan';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'GMM',ISNULL(MAX(orden),0)+1,N'POidPlan',N'POidPlan',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'EMidParentesco')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'EMidParentesco';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'GMM',ISNULL(MAX(orden),0)+1,N'EMidParentesco',N'EMidParentesco',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'poidplanopcion')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'poidplanopcion';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'GMM',ISNULL(MAX(orden),0)+1,N'poidplanopcion',N'poidplanopcion',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'POidGrupoParentesco')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'POidGrupoParentesco';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'GMM',ISNULL(MAX(orden),0)+1,N'POidGrupoParentesco',N'POidGrupoParentesco',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'PLNombre')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'PLNombre';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'GMM',ISNULL(MAX(orden),0)+1,N'PLNombre',N'PLNombre',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'EMNombre1')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'EMNombre1';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'GMM',ISNULL(MAX(orden),0)+1,N'EMNombre1',N'EMNombre1',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'EMNombre2')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'EMNombre2';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'GMM',ISNULL(MAX(orden),0)+1,N'EMNombre2',N'EMNombre2',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'EMFechaAlta')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'EMFechaAlta';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'GMM',ISNULL(MAX(orden),0)+1,N'EMFechaAlta',N'EMFechaAlta',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'RFC')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM' AND campoOrigen=N'RFC';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'GMM',ISNULL(MAX(orden),0)+1,N'RFC',N'RFC',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'GMM';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'TipoSabana')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'TipoSabana';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'OPC',ISNULL(MAX(orden),0)+1,N'TipoSabana',N'TipoSabana',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'POidPlan')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'POidPlan';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'OPC',ISNULL(MAX(orden),0)+1,N'POidPlan',N'POidPlan',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'EMidParentesco')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'EMidParentesco';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'OPC',ISNULL(MAX(orden),0)+1,N'EMidParentesco',N'EMidParentesco',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'poidplanopcion')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'poidplanopcion';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'OPC',ISNULL(MAX(orden),0)+1,N'poidplanopcion',N'poidplanopcion',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'POidGrupoParentesco')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'POidGrupoParentesco';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'OPC',ISNULL(MAX(orden),0)+1,N'POidGrupoParentesco',N'POidGrupoParentesco',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'PLNombre')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'PLNombre';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'OPC',ISNULL(MAX(orden),0)+1,N'PLNombre',N'PLNombre',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'EMCertificado')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'EMCertificado';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'OPC',ISNULL(MAX(orden),0)+1,N'EMCertificado',N'EMCertificado',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'EMNombre1')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'EMNombre1';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'OPC',ISNULL(MAX(orden),0)+1,N'EMNombre1',N'EMNombre1',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'EMNombre2')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'EMNombre2';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'OPC',ISNULL(MAX(orden),0)+1,N'EMNombre2',N'EMNombre2',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'Perfil')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'Perfil';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'OPC',ISNULL(MAX(orden),0)+1,N'Perfil',N'Perfil',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'Calle')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'Calle';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'OPC',ISNULL(MAX(orden),0)+1,N'Calle',N'Calle',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'Colonia')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'Colonia';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'OPC',ISNULL(MAX(orden),0)+1,N'Colonia',N'Colonia',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'Del_Municipio')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'Del_Municipio';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'OPC',ISNULL(MAX(orden),0)+1,N'Del_Municipio',N'Del_Municipio',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'EstadoFiscal')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'EstadoFiscal';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'OPC',ISNULL(MAX(orden),0)+1,N'EstadoFiscal',N'EstadoFiscal',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'CP')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'CP';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'OPC',ISNULL(MAX(orden),0)+1,N'CP',N'CP',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'INFO')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'INFO';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'OPC',ISNULL(MAX(orden),0)+1,N'INFO',N'INFO',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'Categoria')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC' AND campoOrigen=N'Categoria';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 0,3,N'OPC',ISNULL(MAX(orden),0)+1,N'Categoria',N'Categoria',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=0 AND catReportesId=3 AND grupo=N'OPC';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=94 AND catReportesId=3 AND grupo=N'Opcionales' AND campoOrigen=N'SEDescripcion')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=94 AND catReportesId=3 AND grupo=N'Opcionales' AND campoOrigen=N'SEDescripcion';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 94,3,N'Opcionales',ISNULL(MAX(orden),0)+1,N'SEDescripcion',N'SEDescripcion',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=94 AND catReportesId=3 AND grupo=N'Opcionales';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=94 AND catReportesId=3 AND grupo=N'Opcionales' AND campoOrigen=N'Oficina')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=94 AND catReportesId=3 AND grupo=N'Opcionales' AND campoOrigen=N'Oficina';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 94,3,N'Opcionales',ISNULL(MAX(orden),0)+1,N'Oficina',N'Oficina',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=94 AND catReportesId=3 AND grupo=N'Opcionales';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=173 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'EMOficina')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=173 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'EMOficina';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 173,3,N'Vida',ISNULL(MAX(orden),0)+1,N'EMOficina',N'EMOficina',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=173 AND catReportesId=3 AND grupo=N'Vida';
    IF EXISTS (SELECT 1 FROM dbo.bf_RepConf_Columna WHERE idEmpresa=174 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'EMOficina')
        UPDATE dbo.bf_RepConf_Columna SET visible=0
        WHERE idEmpresa=174 AND catReportesId=3 AND grupo=N'Vida' AND campoOrigen=N'EMOficina';
    ELSE
        INSERT dbo.bf_RepConf_Columna
            (idEmpresa,catReportesId,grupo,orden,campoOrigen,encabezado,visible,repConfColumnaUsuarioAdd)
        SELECT 174,3,N'Vida',ISNULL(MAX(orden),0)+1,N'EMOficina',N'EMOficina',0,25
        FROM dbo.bf_RepConf_Columna
        WHERE idEmpresa=174 AND catReportesId=3 AND grupo=N'Vida';

    CREATE TABLE #OrdenLegacySabana (
        idEmpresa INT NOT NULL,
        grupo NVARCHAR(50) COLLATE DATABASE_DEFAULT NOT NULL,
        campoOrigen NVARCHAR(256) COLLATE DATABASE_DEFAULT NOT NULL,
        orden INT NOT NULL,
        PRIMARY KEY (idEmpresa,grupo,orden)
    );
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'EMNumeroEmpleado',1);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'EMApellidoPaterno',2);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'EMApellidoMaterno',3);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'EMNombre1',4);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'EMNombre2',5);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'SEDescripcion',6);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'PADescripcion',7);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'EMFechaNacimiento',8);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'RFC',9);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'EMEdad',10);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'EMFechaIngresoEmpresa',11);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'EMSalarioBase',12);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'Vida-18_meses_sueldo',13);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'Costo_4',14);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'Vida-24_meses_sueldo',15);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'Costo_3',16);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'Vida-30_meses_sueldo',17);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'Costo_2',18);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'Vida-36_meses_sueldo',19);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'Costo_1',20);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'Vida-42_meses_sueldo',21);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'Costo_5',22);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'Vida-48_meses_sueldo',23);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'Costo_6',24);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'SS_18_MESES',25);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'Costo_7',26);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'SS_24_MESES',27);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'Costo_8',28);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'SS_30_MESES',29);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'Costo_9',30);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'SS_36_MESES',31);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'Costo_10',32);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'SS_42_MESES',33);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'Costo_11',34);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'SS_48_MESES',35);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'Costo_12',36);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'TipoSabana',37);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'PLNombre',38);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'EMIdParentesco',39);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'EMOficina',40);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'Oficina',41);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'Ubicacion',42);
    INSERT #OrdenLegacySabana VALUES (186,N'Vida',N'SONumeroSolicitud',43);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'EMNumeroEmpleado',1);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'EMApellidoPaterno',2);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'EMApellidoMaterno',3);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'EMNombre1',4);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'EMNombre2',5);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'SEDescripcion',6);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'PADescripcion',7);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'EMFechaNacimiento',8);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'RFC',9);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'EMEdad',10);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'EMFechaIngresoEmpresa',11);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'PrimaNeta',12);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'Costo',13);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'EMOFicina',14);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'Oficina',15);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'Perfil',16);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'EMSalarioBase',17);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'SONumeroSolicitud',18);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'local_number',19);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'EMIdCentroCostos',20);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'EMArea',21);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'TipoSabana',22);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'POidPlan',23);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'EMidParentesco',24);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'poidplanopcion',25);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'POidGrupoParentesco',26);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'Nombres',27);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'PLNombre',28);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'EMCertificado',29);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'Calle',30);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'Colonia',31);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'Del_Municipio',32);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'EstadoFiscal',33);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'CP',34);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'INFO',35);
    INSERT #OrdenLegacySabana VALUES (186,N'Opcionales',N'Categoria',36);

    UPDATE C SET orden=C.orden+1000
    FROM dbo.bf_RepConf_Columna C
    WHERE C.catReportesId=3 AND EXISTS (
        SELECT 1 FROM #OrdenLegacySabana D
        WHERE D.idEmpresa=C.idEmpresa
          AND D.grupo COLLATE DATABASE_DEFAULT = C.grupo COLLATE DATABASE_DEFAULT);

    UPDATE C SET orden=D.orden
    FROM dbo.bf_RepConf_Columna C
    INNER JOIN #OrdenLegacySabana D
      ON D.idEmpresa=C.idEmpresa
     AND D.grupo COLLATE DATABASE_DEFAULT = C.grupo COLLATE DATABASE_DEFAULT
     AND D.campoOrigen COLLATE DATABASE_DEFAULT = C.campoOrigen COLLATE DATABASE_DEFAULT
    WHERE C.catReportesId=3;

    ;WITH Maximos AS (
        SELECT idEmpresa,grupo,MAX(orden) MaxOrden
        FROM #OrdenLegacySabana GROUP BY idEmpresa,grupo
    ), Extras AS (
        SELECT C.idEmpresa,C.grupo,C.orden,
               M.MaxOrden+ROW_NUMBER() OVER (PARTITION BY C.idEmpresa,C.grupo ORDER BY C.orden) NuevoOrden
        FROM dbo.bf_RepConf_Columna C
        INNER JOIN Maximos M
          ON M.idEmpresa=C.idEmpresa
         AND M.grupo COLLATE DATABASE_DEFAULT = C.grupo COLLATE DATABASE_DEFAULT
        WHERE C.catReportesId=3 AND C.orden>=1000
    )
    UPDATE Extras SET orden=NuevoOrden;

    DROP TABLE #OrdenLegacySabana;

    COMMIT TRANSACTION;
    PRINT 'Configuracion de Sabana homologada con los XML legacy.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH
GO
