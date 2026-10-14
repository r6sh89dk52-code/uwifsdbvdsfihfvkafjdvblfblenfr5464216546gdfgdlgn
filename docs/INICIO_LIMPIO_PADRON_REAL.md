# DANPER Salud Móvil — comienzo limpio con padrón REAL (experimental)

## Decisión del operador
La instalación actual contiene exclusivamente trabajadores importados (mezcla de prueba/reales) y datos de inventario ficticios. No hay atenciones, alergias ni movimientos reales que conservar. El Excel PERSONAL oficial puede importarse de nuevo.

## Recursos de la aplicación que NO dependen de los datos locales
- Kardex Enfermeras: listado oficial de 98 productos, archivo de código `src/kardexCatalog.ts`.
- Indicador Ambulatorio: 432 códigos/nombres/unidades en `src/products.json`.
- 86 asociaciones revisadas entre catálogos en `src/reviewedKardexAssociations.ts`.
- Plantilla del Kardex integrada en `public/internal/kardex-template.bin`.
- Plantilla de 10 hojas del Indicador Ambulatorio en `src/ambulatoryTemplate.json`.
- Procedimientos de cálculo, asociaciones autorizadas, reportes y exportación desde el código fuente.

Todo esto se empaqueta de nuevo al compilar la IPA, incluso tras eliminar sus datos locales.

## Datos que se eliminan tras confirmación explícita
- Trabajadores de prueba y trabajadores reales previamente importados (estos se reimportan desde PERSONAL).
- Atenciones y borradores, alergias, existencias, lotes, ingresos, movimientos, conciliaciones y configuraciones locales dentro del conjunto de prueba.
- Archivos locales protegidos `Directory.Data/danper/`, referencias y claves del prefijo `danper-local-v08_` en Keychain, y antiguas claves conocidas de datos de demostración en localStorage.

**Advertencia:** es irreversible y no se ejecuta automáticamente. No debe utilizarse si existen registros clínicos o inventarios reales sin respaldo verificado. El borrado lógico a través de iOS no garantiza eliminación forense de cada bloque de almacenamiento físico.

## Procedimiento futuro, pendiente de validación física
1. Conservar el Excel PERSONAL real fuera de GitHub en almacenamiento autorizado.
2. Si se requiere volver a datos anteriores, crear y verificar un respaldo portátil cifrado.
3. Instalar mediante SideStore **solo después de revisar la IPA y el comportamiento real en el iPhone**. No borrar la app anterior únicamente para intentar iniciar limpio.
4. En Ajustes > Reiniciar completamente los datos de prueba, o desde la pantalla de recuperación, marcar la declaración y escribir la frase de confirmación. Comprobar que la app reinicie vacía.
5. En Trabajadores > Importar padrón, elegir el Excel oficial PERSONAL y comprobar cantidades y DNIs.
6. Registrar datos de prueba controlados para verificar consulta, persistencia, inventario inicial vacío, exportador del Indicador (10 hojas), exportador del Kardex (98 productos) y accesibilidad sin conexión.
7. No iniciar uso clínico con datos reales hasta completar las pruebas físicas y de restauración.

## Limitaciones
- La limpieza elimina el registro de stock y movimientos, no los catálogos.
- Face ID y el respaldo con clave ligada a dispositivo son desarrollos separados aún no fusionados.
- Los archivos .danperbackup que se hayan compartido fuera del iPhone no son eliminados por el restablecimiento de la app.
- Las instalaciones firmadas con otra identidad/identificador pueden acceder a un contenedor distinto. Confirmar en iPhone antes de operar.
- Aplicación de uso local y de un único operador, con datos laborales y clínicos sujetos a las autorizaciones y controles correspondientes.
