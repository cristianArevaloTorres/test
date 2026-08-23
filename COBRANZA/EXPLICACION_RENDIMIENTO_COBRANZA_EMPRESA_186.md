# Explicación del tiempo de ejecución de cobranza — Empresa 186

## Resumen

Para la empresa 186, el proceso anterior de cobranza podía tardar más de dos horas en generar una sola vigencia porque realizaba una gran cantidad de cálculos fila por fila, recorría repetidamente tablas históricas y ejecutaba subconsultas dentro de ciclos.

En la prueba local, utilizando únicamente el universo relacionado con la empresa 186 y la vigencia 4235, el proceso B2 produjo aproximadamente:

- 3,815 registros de cobranza concentrada.
- 26,698 registros de cobranza desglosada.
- Más de 300 millones de lecturas lógicas.
- Un tiempo aproximado de 6 a 7 minutos en una base local reducida y sin concurrencia.

Los 300 millones de lecturas se observaron en la base local. No se cuenta con las estadísticas de la ejecución realizada en DEV, pero, debido a que DEV contiene todas las empresas, más información histórica y procesos concurrentes, es razonable que el número de lecturas y el tiempo hayan sido iguales o mayores.

## Qué hacía el proceso anterior

### 1. Sincronización previa de la información

Antes de calcular el reporte, el proceso ejecutaba la sincronización de cobranza y consultaba repetidamente tablas como:

- `ff_Solicitud`
- `ff_EdoCuentaCobranza`
- `ff_PlanOpcionSeleccionCobranza`

En la base local reducida, `ff_EdoCuentaCobranza` contenía 322,794 filas. En DEV, estas tablas contienen además información histórica y registros correspondientes a otras empresas.

Aunque la solicitud correspondiera a una sola empresa y vigencia, parte del proceso trabajaba sobre tablas grandes antes de reducir completamente el universo necesario.

### 2. Reconstrucción del universo de empleados

El procedimiento `ff_ObtenEmpleadosCob_final` reconstruía la población de empleados utilizando información de:

- Empleados actuales.
- Empleados históricos.
- Solicitudes.
- Transferencias.
- Perfiles.

Esto implicaba nuevas consultas, uniones y materialización de información temporal antes de comenzar el cálculo final de cobranza.

### 3. Cálculo concentrado fila por fila

Después de construir una tabla temporal, `ObtenCobranzaConcentrada` ejecutaba un ciclo similar al siguiente:

```sql
WHILE @contador_registros <= @total_registros
```

Dentro del ciclo, para cada registro se realizaban varias operaciones independientes:

- Leer la fila de la tabla temporal.
- Volver a buscar información por empleado.
- Calcular créditos, excedentes y descuentos.
- Actualizar la tabla temporal.
- Volver a consultar la misma información temporal.
- Consultar descuentos de la primera y segunda quincena.
- Actualizar nuevamente el resultado del empleado.

Con aproximadamente 3,815 registros concentrados, ese bloque se repetía alrededor de 3,815 veces.

El problema principal no era solamente la cantidad de empleados, sino que las mismas tablas y páginas se consultaban repetidamente para procesar cada empleado.

### 4. Cálculo desglosado y división de costos

El procedimiento `ff_ObtenCobranzaDesg_Adaptada` invocaba a `ff_ObtenDivisionCtos_Adaptado` para calcular la distribución de costos.

Este último procedimiento contenía varios ciclos y tres recorridos mediante cursores. Su comportamiento era equivalente a procesar:

```text
Por cada empleado:
    Por cada plan u opción del empleado:
        Consultar tarifas
        Consultar costos
        Consultar compensaciones
        Calcular la parte de la empresa
        Calcular la parte del empleado
        Actualizar el resultado
```

Los 26,698 registros desglosados representan un promedio aproximado de siete combinaciones por cada registro concentrado:

```text
26,698 / 3,815 ≈ 7
```

Por lo tanto, una sola vigencia no representaba una sola consulta. En realidad, provocaba miles de cálculos de empleados y decenas de miles de cálculos de planes y coberturas.

### 5. Subconsultas repetidas

Entre los procedimientos concentrado, desglosado y división de costos existen numerosas subconsultas escalares. Varias se ejecutaban dentro de ciclos y volvían a consultar tablas que ya habían sido utilizadas previamente.

No todas las subconsultas tienen el mismo costo ni se ejecutan la misma cantidad de veces, pero su combinación con los ciclos provocaba que una página de datos pudiera contabilizarse miles de veces como lectura lógica.

### 6. Generación y formato del Excel

Después de terminar el procesamiento de SQL Server, la aplicación todavía tenía que construir el archivo Excel.

En el flujo Java anterior, el cálculo de los anchos de columnas volvía a recorrer las hojas por cada bloque de filas. Conforme aumentaba el número de registros, también aumentaban de forma considerable el consumo de CPU, memoria y el tiempo de generación del archivo.

Por eso era posible que SQL Server hubiera avanzado o incluso terminado parte del cálculo, pero que desde la aplicación el proceso continuara apareciendo como pendiente.

## Qué significan 300 millones de lecturas lógicas

SQL Server trabaja con páginas de 8 KB. Una lectura lógica representa el acceso a una de estas páginas desde memoria o desde el mecanismo interno de almacenamiento.

No significa que existan 300 millones de páginas diferentes. Si una misma página se consulta diez mil veces, SQL Server registra diez mil lecturas lógicas.

El volumen lógico procesado se puede representar de la siguiente manera:

```text
300,000,000 lecturas × 8 KB
= 2,400,000,000 KB
≈ 2.46 TB decimales
≈ 2.24 TiB
```

En otras palabras, para producir una sola vigencia, SQL Server procesó el equivalente aproximado a 2.4 TB de páginas lógicas, aunque buena parte de la información estuviera disponible en memoria y aunque las mismas páginas se hubieran leído repetidamente.

Si se distribuyen las lecturas entre los registros concentrados:

```text
300,000,000 / 3,815
≈ 78,637 lecturas por registro concentrado
```

Si se distribuyen entre los registros desglosados:

```text
300,000,000 / 26,698
≈ 11,237 lecturas por registro desglosado
```

Estas divisiones son promedios explicativos. No significan que cada registro haya consumido exactamente esa cantidad, sino que permiten dimensionar el trabajo total realizado por el motor.

## Cómo se relaciona con las dos horas observadas en DEV

Dos horas equivalen a 7,200 segundos. Si se tomaran como referencia únicamente 300 millones de lecturas:

```text
300,000,000 / 7,200
≈ 41,667 lecturas lógicas por segundo
```

Esto equivale aproximadamente a procesar 325 MB por segundo de páginas lógicas durante dos horas.

Las lecturas lógicas no equivalen directamente a tráfico físico de disco, porque muchas páginas pueden provenir de memoria. Sin embargo, cada acceso continúa requiriendo trabajo de CPU, validación de condiciones, uniones, agrupaciones y mantenimiento de tablas temporales.

Además, como la ejecución de DEV no había terminado después de dos horas, el total final pudo haber superado considerablemente los 300 millones de lecturas observadas localmente.

## Por qué local tardó minutos y DEV podía tardar horas

La base local utilizada para la validación contenía principalmente el universo exportado para la empresa 186. La base DEV contiene un entorno mucho más grande y compartido.

Las principales diferencias son:

| Base local de validación | Base DEV |
|---|---|
| Datos relacionados principalmente con empresa 186 | Datos de todas las empresas |
| Universo histórico reducido | Mayor volumen histórico |
| Sin usuarios concurrentes | Usuarios y procesos concurrentes |
| Menor presión sobre CPU, memoria y `tempdb` | Recursos compartidos |
| Menor tamaño de tablas e índices | Tablas e índices considerablemente mayores |
| Plan de ejecución controlado | Posibles cambios de plan y parameter sniffing |
| Sin bloqueos relevantes | Posibles bloqueos y esperas |

Aunque ambas bases contengan los registros de la empresa 186, el costo no es necesariamente el mismo. Si un procedimiento no aplica desde el inicio los filtros de empresa y vigencia, puede recorrer información de otras empresas antes de descartarla.

## Qué optimizan las implementaciones nuevas

Las implementaciones del último paquete atacan los principales puntos de costo:

- Sustituyen cálculos fila por fila por operaciones orientadas a conjuntos.
- Materializan etapas intermedias para evitar repetir consultas grandes.
- Incorporan índices para empresa, vigencia, empleado y plan-opción.
- Reducen recorridos innecesarios de tablas históricas.
- Permiten reutilizar resultados mediante caché.
- Mantienen un flujo tradicional optimizado cuando el caché está desactivado.
- Evitan copias innecesarias de resultados en memoria dentro de Java.
- Ajustan los anchos del Excel mediante recorridos lineales.
- Ordenan los resultados de forma determinista para que directo y caché produzcan el mismo orden.

La primera ejecución con caché todavía puede ser costosa, porque debe construir y almacenar los resultados. La mejora más visible se obtiene a partir de la segunda ejecución, cuando se reutiliza un caché completo para la misma combinación de empresa, vigencia, fechas y perfiles.

## Conclusión

Para la empresa 186, una vigencia podía tardar más de dos horas porque el flujo anterior combinaba sincronizaciones, consultas repetidas sobre tablas históricas, procesamiento fila por fila, cursores, ciclos, subconsultas escalares y generación costosa del Excel.

En la validación local, este comportamiento produjo aproximadamente 3,815 registros concentrados, 26,698 registros desglosados y más de 300 millones de lecturas lógicas, equivalentes a procesar alrededor de 2.4 TB de páginas SQL.

En DEV, el volumen total de datos, la concurrencia, los bloqueos y los recursos compartidos podían incrementar todavía más ese costo. Por ello, que una vigencia no terminara después de dos horas es consistente con el diseño y la escala del proceso anterior.
