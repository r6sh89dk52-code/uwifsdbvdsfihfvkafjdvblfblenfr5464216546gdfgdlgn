# N1n — Preparación cifrada INACTIVA de un respaldo seleccionado en iPhone

Base validada: N1m PR #75; 122/122 Swift Linux y compilación Xcode real sin firma.

- **No hay migración clínica real.** El único efecto nuevo, voluntario y explícito, es guardar el snapshot íntegro de nueve colecciones como AES-256-GCM en la bóveda N1m separada.
- Pantalla en «Más → Preparar respaldo cifrado · inactivo»: tres declaraciones obligatorias, contraseña local y confirmación antes de abrir el selector del iPhone.
- PortableBackupInspector utiliza el lector existente para descifrar localmente; el filtro N1n verifica las mismas invariantes N1l y el staging N1m vuelve a validarlas. No se mezcla con N1g/N1i.
- El recibo contiene solo huellas y recuentos; los registros en claro no persisten en archivos ni se incorporan a SwiftUI.
- Una segunda fuente distinta es rechazada por N1m. La preparación no cambia main, release build222, las existencias ni el historial.
- Declarar el origen auténtico **NO demuestra** que no haya ficticios sin marcar. provenAuthentic y canActivate son siempre false. Inspeccionar la estructura no es activar una base clínica.
- Pruebas sintéticas: aceptación condicionada, marcadores ficticios, faltantes, duplicados, correcciones rotas y preservación de consumos no conciliados. CI sin registros reales.
- Pendiente: verificación de procedencia real y paridad 1:1 del Excel de diez hojas, stock, FEFO, historial, validación clínica y almacén transaccional con recuperación antes de ofrecer acceso operativo.
