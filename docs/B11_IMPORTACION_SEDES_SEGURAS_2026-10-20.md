# B11 — Importación PERSONAL con clasificación segura de sedes

## Alcance

Rama aislada de `fix/b10-trabajadores-exportacion-ux-20261018`. No modifica `release/v0.21.12-build222-provisional-consumptions`, `main`, el identificador de paquete iOS, el almacenamiento Keychain ni los datos existentes.

## Comportamientos implementados

- El importador ya NO preselecciona Fundo para cada archivo: el usuario debe elegir un criterio.
- Si la hoja PERSONAL trae columna `SEDE`, `SUBDIVISION` o `SUBDIVISION OPERATIVA`, reconoce únicamente los valores explícitos `LA VENTUROSA` / `FUNDO LA VENTUROSA` y `PLVENTUROSA` / `PLANTA LA VENTUROSA`.
- En modo `DESDE_EXCEL`, cada DNI conserva su sede comprobable; un solo archivo puede reunir trabajadores de ambas sedes, sin inventar ubicaciones.
- Cuando el archivo incorpora una sede, la selección masiva contradictoria queda bloqueada.
- Si existe una columna de sede pero hay filas vacías, valores no reconocidos o el mismo DNI con sedes opuestas, se bloquea la importación de TODO el archivo; no hay escrituras parciales.
- Si el Excel no contiene sede, se exige elegir explícitamente Fundo o Planta para un padrón previamente verificado de una sola sede. **No se puede inferir la sede real de un Excel mixto sin columna SEDE.**
- La validación de merge conserva registros previos y bloquea el cambio silencioso de sede de DNI existentes. No se fusionan bases DEMO y CLÍNICA.

## Pruebas agregadas (datos sintéticos)

- Archivo mixto con columna SEDE: dos DNIs y dos sedes con salida conservada, reimportación idempotente.
- Rechazo de intento de asignar todo un archivo mixto a una sola sede.
- Rechazo de sede faltante o no reconocida.
- Rechazo de DNI duplicado con sedes contradictorias.

## Pendientes obligatorios

1. Corregir los fallos preexistentes de CI B11; obtener PASSED en Swift Linux, compilación Xcode y XCTest con simulador.
2. Probar realmente con una **copia desidentificada** representativa de la plantilla institucional; la hoja original de Build 222 normalmente no incluye una columna de sede verificable.
3. Ensayar importación y conciliación de archivo de Fundo y archivo de Planta por separado, y también un archivo explícitamente clasificado por SEDE.
4. Probar pantalla compacta, teclado, persistencia de datos entre lanzamientos y bóveda clínica cifrada, sin pacientes reales.
5. Comparar recuentos, datos y Excel de salida con una versión Build 222 congelada. No distribuir IPA de reemplazo ni llamar 'estable' a B11 hasta superar las pruebas.

Los recordatorios de reincorporación y escaneo de DNI se consideran mejoras opcionales posteriores en ramas independientes.
