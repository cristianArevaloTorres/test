package com.lockton.rpt.util;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.Map;

/**
 * Utilidad central para generar nombres de archivo basados en configuración de BD
 * (catReportesFormato / catReportesNombre) con soporte de tokens y patrones de fecha.
 *
 * Tokens soportados en catReportesFormato:
 *  - {nombreReporte}
 *  - {timestamp}
 *  - {timestampfull}
 *
 * Si catReportesFormato no contiene tokens y es un patrón de fecha válido,
 * se usa como patrón para generar el timestamp completo.
 */
public final class NombreArchivoUtil {

    private NombreArchivoUtil() {}

    public static String generarNombre(Map<String, Object> parametros,
                                       String prefijo,
                                       String defaultTsPattern,
                                       boolean includeIdEmpresaSuffix,
                                       boolean sabanaSoloTimestamp,
                                       boolean costosEspecial,
                                       boolean separadorAntesDeTs) {

        String formatoCfg = null;
        try { Object f = parametros == null ? null : parametros.get("catReportesFormato"); if (f != null) formatoCfg = String.valueOf(f).trim(); } catch (Exception ignore) {}

        String nombreReporte = prefijo == null || prefijo.trim().isEmpty() ? "Reporte" : prefijo;
        try {
            Object idSubReporte = parametros == null ? null : parametros.get("idSubReporte");
            if(idSubReporte == null){
                Object n = parametros == null ? null : parametros.get("catReportesNombre");
                if (n != null && !String.valueOf(n).trim().isEmpty()) nombreReporte = String.valueOf(n);
            }
        } catch (Exception ignore) {}

        String tsPattern = resolveTimestampPattern(formatoCfg, defaultTsPattern);
        String ts = new SimpleDateFormat(tsPattern, Locale.ROOT).format(new Date());

        boolean esSabana = sabanaSoloTimestamp && esReporteId(parametros, 3);
        boolean esCostos = costosEspecial && esReporteId(parametros, 4);

        if (esSabana) {
            return "Sabana" + ts + ".xlsx";
        }

        if (formatoCfg != null && !formatoCfg.isEmpty()) {
            // Si no hay tokens, tratamos el formato como patrón de fecha completo
            if (!formatoCfg.contains("{")) {
                String out = sanitizarNombreArchivo(ts);
                if (!terminaConExcel(out)) out = out + ".xlsx";
                return out;
            }
            String tsFull = new SimpleDateFormat("yyyyMMddHHmm", Locale.ROOT).format(new Date());
            String out = formatoCfg;
            out = out.replace("{nombreReporte}", nombreReporte);
            out = out.replace("{timestampfull}", tsFull);
            out = out.replace("{timestamp}", ts);
            out = sanitizarNombreArchivo(out);
            if (!terminaConExcel(out)) out = out + ".xlsx";
            return out;
        }

        if (esCostos) {
            String tsCostos = new SimpleDateFormat("ddMMyyyyHHmm", Locale.ROOT).format(new Date());
            return "ReporteCostos" + tsCostos + ".xlsx";
        }

        String sufijo = "";
        if (includeIdEmpresaSuffix) {
            String idEmp = extraerIdEmpresa(parametros);
            if (idEmp != null && !idEmp.isEmpty()) sufijo = "_" + idEmp;
            Object fs = parametros == null ? null : parametros.get("fileSuffix");
            if (fs != null) sufijo += String.valueOf(fs);
        }
        String tsDefault = new SimpleDateFormat(defaultTsPattern, Locale.ROOT).format(new Date());
        String base = nombreReporte + sufijo + (separadorAntesDeTs ? "_" : "") + tsDefault;
        base = sanitizarNombreArchivo(base);
        if (!terminaConExcel(base)) base = base + ".xlsx";
        return base;
    }

    private static String resolveTimestampPattern(String formatoCfg, String fallback) {
        String defaultPattern = (fallback == null || fallback.trim().isEmpty()) ? "yyyyMMddHHmmss" : fallback.trim();
        if (formatoCfg == null || formatoCfg.trim().isEmpty()) return defaultPattern;
        if (formatoCfg.contains("{")) return defaultPattern; // plantilla, no patrón puro
        try {
            new SimpleDateFormat(formatoCfg, Locale.ROOT);
            return formatoCfg;
        } catch (IllegalArgumentException ex) {
            return defaultPattern;
        }
    }

    private static boolean esReporteId(Map<String, Object> params, int idBuscado) {
        if (params == null) return false;
        try {
            Object ridObj = params.get("reporteId");
            if (ridObj != null) {
                int rid = Integer.parseInt(String.valueOf(ridObj));
                return rid == idBuscado;
            }
        } catch (Exception ignore) {}
        return false;
    }

    private static String extraerIdEmpresa(Map<String, Object> parametros) {
        if (parametros == null) return null;
        Object idEmp = parametros.get("idEmpresa");
        if (idEmp == null) return null;
        try {
            String raw = String.valueOf(idEmp).trim();
            raw = raw.replaceAll("[\\{\\}\\[\\]]", "");
            if (raw.contains(",")) raw = raw.split(",")[0].trim();
            String digits = raw.replaceAll("[^0-9]", "");
            return digits.isEmpty() ? null : digits;
        } catch (Exception e) {
            return null;
        }
    }

    private static String sanitizarNombreArchivo(String s) {
        if (s == null) return "Reporte.xlsx";
        String cleaned = s.replaceAll("[\\\\/:*?\"<>|]", " ").trim();
        cleaned = cleaned.replaceAll("\\s+", " ");
        if (cleaned.isEmpty()) cleaned = "Reporte";
        return cleaned;
    }

    private static boolean terminaConExcel(String s) {
        String lower = s.toLowerCase(Locale.ROOT);
        return lower.endsWith(".xlsx") || lower.endsWith(".xls");
    }
}

