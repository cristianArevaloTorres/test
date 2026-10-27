# Justificación del rechazo de la cadena de empleado

## 1. Alcance del análisis

Este análisis corresponde a la siguiente configuración:

- Empresa enviada al servicio: `1718`.
- Operación: `2`.
- Plantilla configurada: `12062`.
- Procedimiento almacenado: `ff_XCMTitularesAltaCMM_BF3`.

La relación se puede comprobar con el siguiente SQL:

```sql
SELECT
    CEIdEmpresa,
    CEIdOperacion,
    CEIdPlantilla,
    CEStoredProc,
    CEIdEstatus
FROM ff_CargaMasivaOperacionEmpresa
WHERE CEIdEmpresa = 1718
  AND CEIdOperacion = 2
  AND CEIdEstatus = 1;
```

Resultado relevante:

| Empresa | Operación | Plantilla | Procedimiento |
|---:|---:|---:|---|
| 1718 | 2 | 12062 | `ff_XCMTitularesAltaCMM_BF3` |

## 2. Cadena original recibida

```text
1718|201|0000201A|ALMANZA|ARTEAGA|IKER|JULIO|8223|F|1980-10-22||2026-01-01|2025-12-03|||ZMZ03SRO42|||||||
```

La cadena original contiene **23 valores**, por lo que su primer problema no es la cantidad de campos. El problema es que los valores no se encuentran en el orden definido por la plantilla `12062`.

## 3. Orden definido por la plantilla

El orden real de los campos activos puede consultarse con:

```sql
SELECT
    ROW_NUMBER() OVER (
        ORDER BY cp.CPIdConfiguracionPlantilla
    ) AS Posicion,
    RTRIM(c.CANombreCampo) AS Campo,
    c.CATipoDato AS TipoDato,
    c.CATipoValor AS TipoValor,
    cp.CPRequerido AS Requerido,
    cp.CPRangoValores
FROM ff_ConfiguracionPlantilla cp
INNER JOIN ff_Campo c
    ON c.CAIdCampo = cp.CAIdCampo
WHERE cp.PLIdPlantilla = 12062
  AND cp.CPIdEstatus = 1
  AND c.CAIdEstatus = 1
ORDER BY cp.CPIdConfiguracionPlantilla;
```

La plantilla tiene los siguientes 23 campos activos:

| Posición | Campo esperado | Obligatorio | Valor de la cadena original | Resultado |
|---:|---|:---:|---|---|
| 1 | `EMIdEmpresa` | Sí | `1718` | Posición correcta |
| 2 | `EMIdPerfil` | Sí | `201` | Posición correcta |
| 3 | `EMIdSexo` | Sí | `0000201A` | Incorrecto: se recibe el número de empleado |
| 4 | `EMNumeroEmpleado` | Sí | `ALMANZA` | Incorrecto: se recibe el apellido |
| 5 | `EMApellidoPaterno` | Sí | `ARTEAGA` | Incorrecto: los datos ya están desplazados |
| 6 | `EMApellidoMaterno` | No | `IKER` | Incorrecto |
| 7 | `EMNombre1` | Sí | `JULIO` | Incorrecto |
| 8 | `EMNombre2` | No | `8223` | Incorrecto |
| 9 | `EMFechaNacimiento` | Sí | `F` | Incorrecto: `F` no es una fecha |
| 10 | `EMFechaIngresoEmpresa` | Sí | `1980-10-22` | Fecha válida, pero corresponde al nacimiento |
| 11 | `EMOficina` | No | Vacío | Sin valor |
| 12 | `EMrfc` | No | `2026-01-01` | Incorrecto: se recibe una fecha como RFC |
| 13 | `EMSalarioBase` | Sí | `2025-12-03` | Incorrecto: se esperaba un importe numérico |
| 14 | `EMObservaciones` | No | Vacío | Sin valor |
| 15 | `EMCertificado` | Sí | Vacío | Incorrecto: campo obligatorio |
| 16 | `EMFechaAlta` | Sí | `ZMZ03SRO42` | Incorrecto: el código no es una fecha |
| 17 | `EMBeneficioMaximoM` | No | Vacío | Sin valor |
| 18 | `EMidCentroCostos` | No | Vacío | Sin valor |
| 19 | `EMArea` | No | Vacío | Sin valor |
| 20 | `EMPuesto` | No | Vacío | Sin valor |
| 21 | `EMcurp` | No | Vacío | Sin valor |
| 22 | `EMFechaAntiguedadGMM` | No | Vacío | Sin valor |
| 23 | `EMCorreoElectronico` | No | Vacío | Sin valor |

El desalineamiento comienza en la posición 3. La plantilla espera el sexo, pero la cadena envía `0000201A`, que corresponde al número de empleado.

## 4. Validación del sexo

La posición 3 utiliza el catálogo `ff_CMCSexo_BF3`. Sus valores pueden consultarse con:

```sql
EXEC ff_CMCSexo_BF3;
```

En la base revisada, los valores aceptados son:

```text
MASCULINO
FEMENINO
```

Por lo tanto, para este registro se debe enviar `FEMENINO`, no `F` y tampoco `0000201A`.

## 5. Motivo técnico del rechazo

El servicio no identifica ni reordena los valores por su contenido. Su funcionamiento es el siguiente:

1. Divide la cadena utilizando el carácter `|`.
2. Obtiene los nombres de los campos de la plantilla.
3. Relaciona el valor de la posición 1 con el campo 1, el valor 2 con el campo 2 y así sucesivamente.
4. Valida cada valor utilizando el tipo y las reglas del campo que ocupa esa posición.

Referencias en el código:

- `WS_Empleados/DAO/CargaEmpleado.cs`, línea 255: separación de la cadena mediante `Split('|')`.
- `WS_Empleados/DAO/CargaMasivaParser.cs`, líneas 37-40: verificación de cantidad y asociación de campos y valores por el mismo índice.
- `WS_Empleados/Model/PlantillaCampoItem.cs`, línea 139: validación de valores específicos contra su catálogo.

Por este motivo, cuando se envía `0000201A` en la posición 3, el servicio intenta validarlo como sexo y rechaza el registro.

## 6. Cadena propuesta en el orden correcto

Tomando los datos disponibles y reordenándolos conforme a la plantilla `12062`, la cadena propuesta es:

```text
1718|201|FEMENINO|0000201A|ALMANZA|ARTEAGA|IKER|JULIO|1980-10-22|2025-12-03|||8223||0000201A|2026-01-01||||ZMZ03SRO42||2025-12-03|
```

Esta cadena contiene exactamente 23 campos y se interpreta así:

| Posición | Campo | Valor propuesto |
|---:|---|---|
| 1 | `EMIdEmpresa` | `1718` |
| 2 | `EMIdPerfil` | `201` |
| 3 | `EMIdSexo` | `FEMENINO` |
| 4 | `EMNumeroEmpleado` | `0000201A` |
| 5 | `EMApellidoPaterno` | `ALMANZA` |
| 6 | `EMApellidoMaterno` | `ARTEAGA` |
| 7 | `EMNombre1` | `IKER` |
| 8 | `EMNombre2` | `JULIO` |
| 9 | `EMFechaNacimiento` | `1980-10-22` |
| 10 | `EMFechaIngresoEmpresa` | `2025-12-03` |
| 11 | `EMOficina` | Vacío |
| 12 | `EMrfc` | Vacío |
| 13 | `EMSalarioBase` | `8223` |
| 14 | `EMObservaciones` | Vacío |
| 15 | `EMCertificado` | `0000201A` |
| 16 | `EMFechaAlta` | `2026-01-01` |
| 17 | `EMBeneficioMaximoM` | Vacío |
| 18 | `EMidCentroCostos` | Vacío |
| 19 | `EMArea` | Vacío |
| 20 | `EMPuesto` | `ZMZ03SRO42` |
| 21 | `EMcurp` | Vacío |
| 22 | `EMFechaAntiguedadGMM` | `2025-12-03` |
| 23 | `EMCorreoElectronico` | Vacío |

## 7. Supuestos que deben confirmarse antes de producción

La cadena propuesta es estructuralmente compatible con la plantilla, pero utiliza los siguientes supuestos de negocio:

- `8223` representa el salario base.
- `ZMZ03SRO42` representa el puesto.
- `2025-12-03` corresponde a la fecha de ingreso y a la antigüedad GMM.
- `2026-01-01` corresponde a la fecha de alta.
- El certificado debe ser igual al número de empleado: `0000201A`.

Si `8223` fuera una oficina, un centro de costos u otro identificador, no debe utilizarse como salario. En ese caso se necesita proporcionar el salario base real, porque `EMSalarioBase` es obligatorio.

## 8. Conclusión para comunicar

> La cadena original tiene la cantidad correcta de campos, pero no respeta el orden definido en la plantilla 12062. El desalineamiento comienza en la posición 3: la plantilla espera `EMIdSexo`, pero recibe el número de empleado `0000201A`. Como el servicio asigna y valida los valores estrictamente por posición, los campos posteriores también quedan asociados a datos incorrectos. La cadena debe reordenarse conforme a la plantilla y deben confirmarse los valores de salario, puesto, certificado y fechas antes de enviarla a producción.
