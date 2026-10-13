# DANPER Salud Móvil v0.10.0 — Kardex Etapa B0

## Base
Continúa v0.9, con navegación gestual de iPhone y almacenamiento Keychain para **datos ficticios**, sin cambios en registro de atenciones, importador PERSONAL, diagnóstico presuntivo, alergias, autoguardado ni notificaciones.

## Fuente oficial realmente revisada
Archivo: `KARDEX DE ENFERMERÍA ACTUALIZADO - OCTUBRE-2026.xlsx`
- `KARDEX ENFERMERAS`, C7:C104: **98 productos**.
- `Hoja1`, A6:A11: **6 medicamentos donados**.
- Kardex diario: D inicial, E ingreso extraordinario, F total stock, G consumo, H stock final, I vencimiento y J F/S (FALTA/SOBRA).
- La numeración B7:B104 es **orden del Kardex**, no código de almacén. Los códigos de la atención siguen tomándose del catálogo independiente existente.
- Los datos históricos de saldos de las hojas NO se cargan automáticamente como existencias físicas actuales.

## Funciones nuevas
1. Inicio → **Kardex**.
2. Elegir producto del catálogo oficial y crear registro por lote, opcionalmente vencimiento.
3. Distinguir envase cerrado, unidades sueltas y contenido abierto restante; capacidad y unidad de conteo editables por producto (UND/mL/g).
4. Cálculo físico: **cerrados × capacidad + sueltos + contenido abierto restante**. El contenido del envase abierto no se cuenta dos veces.
5. Editar/corregir y eliminar recuentos ficticios con confirmación. Evita duplicar el mismo producto+lote+fecha de vencimiento.
6. Consultar productos registrados y filtrar por nombre/lote y tipo (general/donados).
7. Guardar los lotes en el mismo snapshot iOS Keychain de la v0.9, con lectura compatible hacia atrás: una versión antigua sin lotes carga el inventario como vacío **sin borrar las atenciones existentes**.
8. Eliminar datos de prueba incluye inventario.

## Aún no implementado
- Movimiento extraordinario, descuentos por atención, lógica FEFO, control automático de aperturas 0/1, kardex diario oficial imprimible, mapeo seguro entre códigos de catálogo asistencial y la numeración del Kardex.
- SQLCipher / SQLite cifrada, inventario real y uso clínico en producción.
- Ningún medicamento se descuenta automáticamente todavía.

## Pruebas a realizar con el IPA v0.10
- Comprobar que el historial ficticio v0.9 sigue presente tras actualizar SideStore.
- Registrar un frasco ficticio de 120 mL: dos cerrados, 60 mL en otro abierto; saldo **300 mL**.
- Reiniciar la app, consultar inventario, editar y borrar.
- Verificar que un lote inválido o abierto con cantidad superior a capacidad sea rechazado.
- Comprobar 98 productos generales, 6 donados y filtros.
- Comprobar que el gesto de retroceso v0.9 funciona desde la pantalla de Kardex.

**PROTOTIPO PARA DATOS FICTICIOS.** Antes de trabajar con datos reales hay que validar migraciones, cifrado de base de datos, copias, auditoría, control de acceso y requisitos de salud ocupacional.
