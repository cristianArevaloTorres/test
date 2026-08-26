# Paquete limpio del menú BF3 de Defaulteo

Este paquete sustituye a los complementos experimentales de ruta corta. No contiene el alias `/pages/defaulteo` ni modifica el comportamiento compartido del menú.

## Aplicación

1. Reemplazar `src/app/beflex/pages-routing.module.ts` en BF3.
2. Compilar y desplegar nuevamente el frontend; no basta con copiar el archivo mientras `ng serve` o el servidor web anterior continúa ejecutándose.
3. Ejecutar `SQL/REINSTALAR_MENU_DEFAULTEO_BF3_186_ROL_570.sql`.
4. Cerrar la sesión de BF3, eliminar `localStorage.menurol`, limpiar la caché del sitio y volver a entrar.
5. Probar directamente `/pages/administracion/solicitudes/defaulteo`.
6. Ejecutar el diagnóstico si la navegación todavía regresa a Home.

## Datos de la prueba

- Empresa: `186`
- Rol: `570`
- Usuario: `JVAZQUEZ`
- Ruta guardada en base: `administracion/solicitudes/defaulteo`
- URL final: `/pages/administracion/solicitudes/defaulteo`

## Sobre borrar el registro anterior

No es necesario borrarlo manualmente. El instalador es idempotente:

- reutiliza y corrige el registro si existe;
- lo crea con un IDENTITY nuevo si ya no existe;
- copia la jerarquía, orden e icono de Carga Masiva;
- conserva una sola asignación activa para el rol 570;
- no elimina físicamente menús globales que podrían estar usados por otros roles.

El resultado final del instalador debe ser una sola fila con `Resultado = OK`.
