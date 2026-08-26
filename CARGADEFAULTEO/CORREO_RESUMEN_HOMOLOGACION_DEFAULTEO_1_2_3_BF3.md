# Correo: integración y justificación de la homologación de Defaulteo 1, 2 y 3 en BF3

## Asunto sugerido

**Integración de Defaulteo 1, 2 y 3 en BF3 y diferencias respecto de la pantalla base**

## Cuerpo del correo

Buen día,

Como parte de la homologación de los procesos de Defaulteo 1, 2 y 3, se integró una pantalla nueva en BF3 bajo la siguiente ubicación:

`Administración > Administración de titulares y dependientes > Defaulteo`

Ruta técnica:

`/pages/administracion/titulares/defaulteo`

La implementación se realizó en una ubicación independiente para no modificar el comportamiento de la pantalla base que ya existía en:

`/pages/administracion/solicitudes/defaulteo`

La pantalla base conserva su operación original. La pantalla nueva concentra las capacidades requeridas para homologar el proceso, mejorar el control operativo y permitir el seguimiento de ejecuciones masivas sin sustituir el motor de negocio existente.

### ¿Qué se reutilizó?

No se reconstruyó la lógica de cálculo de planes ni la creación de solicitudes. Se reutilizaron los componentes ya existentes y validados en BF3:

- Catálogo de tipos de defaulteo.
- Motor de búsqueda y asignación de planes.
- Reglas de elegibilidad por perfil, vigencia, edad, sexo, parentesco, tarifas, planes y coberturas.
- Procedimientos para registrar temporalmente las selecciones calculadas.
- Procedimiento de creación de solicitudes.
- Validación posterior para confirmar que la solicitud fue generada.
- Tablas actuales de empleados, empresas, perfiles, vigencias, solicitudes y selecciones de planes.

La pantalla nueva envía al motor el tipo elegido como `def1`, `def2` o `def3`, por lo que el resultado funcional continúa siendo determinado por las mismas reglas y procedimientos existentes.

### ¿Qué incorpora la pantalla nueva que no tiene la pantalla base?

#### 1. Operación guiada de Defaulteo 1, 2 y 3

La nueva pantalla explica el objetivo de cada tipo antes de ejecutarlo:

- **Tipo 1 – Conservar selecciones anteriores:** toma las elecciones elegibles de la vigencia origen y busca trasladarlas a la vigencia destino.
- **Tipo 2 – Asignar plan básico o espejo:** utiliza la configuración básica vigente del perfil y no depende de una elección anterior del empleado.
- **Tipo 3 – Recalcular titular y dependientes:** vuelve a evaluar la composición familiar y las opciones elegibles conforme a la configuración vigente.

Esta explicación reduce errores operativos al seleccionar el tipo de proceso.

#### 2. Búsqueda por empresa, perfil y vigencia

La pantalla nueva permite acotar los empleados que serán procesados mediante:

- Empresas asignadas al administrador.
- Perfiles activos.
- Vigencia destino.
- Número de empleado.
- Nombre y apellidos.
- Operadores de búsqueda simple y avanzada.

Antes de consultar la información, el backend valida que el administrador tenga acceso a las empresas solicitadas.

#### 3. Filtros avanzados

Además de la operación guiada, se integró una sección de filtros avanzados para construir grupos específicos de empleados sin procesar indiscriminadamente toda una empresa.

Esto permite realizar pruebas controladas, seleccionar únicamente los casos requeridos y disminuir el riesgo de generar solicitudes no deseadas.

#### 4. Ejecución asincrónica por lotes

La pantalla base ejecutaba el proceso dentro de la misma petición, lo que podía mantener el modal abierto durante demasiado tiempo o provocar un timeout.

En la pantalla nueva:

1. Se registra un lote y se obtiene un folio.
2. El servidor procesa cada empleado en segundo plano.
3. La pantalla consulta periódicamente el avance.
4. Un error individual no detiene el procesamiento de los demás empleados.
5. El lote termina como completado, completado con errores o error general.

El usuario puede ocultar el modal y el proceso continúa ejecutándose en el servidor.

#### 5. Recuperación después de recargar o volver a entrar

El folio activo se conserva temporalmente en el navegador. Si el usuario actualiza la página o vuelve a entrar, la pantalla intenta reconectarse al lote y recuperar su estado.

Esto evita perder la visibilidad de una ejecución que continúa en segundo plano.

#### 6. Trazabilidad y descarga de errores

Cada ejecución registra:

- Folio del lote.
- Administrador que realizó la operación.
- Empresa, vigencia y tipo de defaulteo.
- Fecha de inicio y terminación.
- Total de empleados.
- Total de casos correctos y con error.
- Estado final.
- Errores o advertencias por empleado.

Cuando existen incidencias, el usuario puede descargar un archivo CSV con el detalle para identificar el empleado y la causa reportada por el motor.

#### 7. Exclusión de empleados que ya tienen solicitud

La pantalla nueva evita mostrar como pendiente a un empleado que ya tiene una solicitud activa o por autorizar en la misma vigencia.

Después de un defaulteo correcto y de actualizar la búsqueda, el empleado debe desaparecer del listado de pendientes.

Las solicitudes rechazadas o canceladas no bloquean permanentemente al empleado, por lo que puede volver a procesarse después de corregir la causa del rechazo.

#### 8. Configuraciones guardadas

Los filtros y acciones de uso frecuente pueden guardarse para el administrador autenticado.

Las configuraciones se encuentran aisladas por usuario, empresa y corporativo; un administrador no puede consultar ni modificar configuraciones que pertenecen a otro usuario.

#### 9. Consulta histórica

Se incorporó una vista histórica para consultar las solicitudes y selecciones generadas por defaulteo.

Esta sección permite comprobar posteriormente:

- Qué empleado fue procesado.
- En qué solicitud y vigencia quedó registrado.
- Qué opciones fueron marcadas como resultado del defaulteo.

#### 10. Seguridad adicional en la consulta y ejecución

La pantalla nueva no confía directamente en los identificadores enviados por el navegador:

- El administrador efectivo se obtiene del token de sesión.
- Se validan las empresas asignadas al administrador.
- Se valida que los empleados pertenezcan a empresas accesibles.
- Se valida que la vigencia corresponda a la configuración de la empresa.
- La búsqueda guiada acepta únicamente atributos y operadores conocidos.
- La operación guiada no puede cambiarse al flujo de casos especiales agregando parámetros al request.

### ¿Cómo se homologó cada tipo?

| Tipo | Comportamiento homologado | Resultado esperado |
|---|---|---|
| Defaulteo 1 | Reutiliza las selecciones elegibles de la vigencia origen | Solicitud nueva con las opciones anteriores que continúan siendo válidas |
| Defaulteo 2 | Toma el plan básico o espejo configurado para el perfil | Solicitud nueva con la configuración básica de la vigencia destino |
| Defaulteo 3 | Recalcula las opciones considerando al titular y sus dependientes | Solicitud nueva con la composición familiar que resulte elegible |

El tipo 3 se conserva como una operación sobre empleados seleccionados, de acuerdo con la restricción identificada en el sistema legacy. En el legacy, la ejecución por empresa completa solo permite los tipos 1 y 2.

### ¿Por qué fue necesaria esta homologación?

La homologación responde principalmente a los siguientes objetivos:

- Concentrar la operación en BF3 ante el retiro gradual del sistema legacy.
- Conservar las reglas de negocio ya validadas, evitando duplicar el motor de planes.
- Permitir ejecutar los tres tipos desde una interfaz más clara y controlada.
- Evitar bloqueos y timeouts durante procesos con varios empleados.
- Contar con evidencia y trazabilidad de cada ejecución.
- Impedir solicitudes duplicadas para la misma vigencia.
- Aplicar validaciones de acceso por administrador, empresa y empleado.
- Facilitar pruebas controladas y la identificación de errores por registro.
- Mantener intacta la pantalla base para evitar regresiones en otros procesos.

### Alcance que no fue modificado

- No se modificó el proyecto ASP.NET legacy.
- No se reemplazaron los procedimientos centrales de cálculo y creación de solicitudes.
- No se modificó funcionalmente la pantalla base de solicitudes.
- La generación de PDF y el envío de notificaciones continúan siendo procesos posteriores e independientes, tal como ocurre en el legacy.
- La funcionalidad nueva quedó aislada en la ruta de Administración de titulares y dependientes.

### Validaciones realizadas

- Compilación estática del proyecto Angular sin errores.
- Validación del mapeo de los tipos 1, 2 y 3 hacia `def1`, `def2` y `def3`.
- Validación de la ruta y menú de la pantalla nueva.
- Validación de los contratos entre Java y los procedimientos de trazabilidad/configuración.
- Comparación de la pantalla base contra los archivos originales, sin diferencias funcionales.
- Pruebas unitarias para la seguridad de la nueva consulta guiada.
- Validación de la exclusión de solicitudes activas o por autorizar.

La ejecución integral contra base de datos deberá completarse en el ambiente que tenga acceso a SQL Server y a los servicios internos utilizados por el proyecto.

Saludos.

---

## Resumen ejecutivo corto

Se incorporó una nueva pantalla de Defaulteo en Administración de titulares y dependientes sin modificar la pantalla base ni el sistema legacy. La solución reutiliza el motor existente de planes y solicitudes, pero agrega operación guiada para los tipos 1, 2 y 3, filtros avanzados, ejecución asincrónica, seguimiento por folio, trazabilidad por empleado, descarga de errores, configuraciones guardadas, histórico y exclusión de empleados que ya tienen solicitud vigente. La separación permite completar la homologación hacia BF3 con menor riesgo de regresión y con mayor control operativo y de seguridad.

