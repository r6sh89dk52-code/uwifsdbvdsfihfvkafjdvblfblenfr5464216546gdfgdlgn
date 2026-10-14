# DANPER SALUD MÓVIL v0.17.0 — Inventario físico compartido y reportes sin plantillas externas

## Especificación acordada
- **Kardex de Enfermería**: sigue existencias físicas por día. Saldo final de hoy = saldo inicial mañana; exportación diaria, semanal o rango propio; sin corte de día 9.
- **Indicador Ambulatorio**: informe mensual desde el día 9 inclusive hasta el día 8 del mes siguiente; incorpora la estructura interna depurada de las 10 hojas del libro original, 432 productos y 19 tablas. NO solicita adjuntar Excel.
- Sólo hay un ledger físico. Los 86 vínculos autorizados asignan 98 productos de Enfermería a los códigos oficiales correspondientes. E-62/E-63 mantienen lotes separados, se suman únicamente para reporte clínico; E-68 nylon y otras 11 referencias sin equivalencia no se asignan.
- No copiar datos de un libro a otro como si fueran stocks independientes. Cálculo temporal de movimientos auditados, iniciales y salidas confirmadas. Ceros, stocks desconocidos, altas posteriores al período y unidades incompatibles se distinguen.
- Los 346+ códigos del catálogo de 432 sin evidencia de inventario permanecen vacíos. **CONTEO físico** no se autocompleta como si fuera un recuento realizado.
- No inferir fechas de corte futuras ni cerrar períodos sin historial completo. Los movimientos históricos no se modifican.

## Control de seguridad
- Únicamente datos DEMO ficticios. No instalar con datos personales reales.
- La plantilla del Indicador ya había sido extraída y depurada en `src/ambulatoryTemplate.json`; no se incorporó el Excel de 5 MB con datos históricos.
- Pruebas de regresión (incluido carryover 50-20=30), diez hojas oficiales y snapshot de Xcode/IPA obligatorias antes de fusionar.
- La conciliación manual antigua se conserva para revisión histórica, no duplica el stock ni se aplica automáticamente.
- **Limitación importante**: las altas de lotes posteriores al día 9 no se inventan como saldo del día 9. Productos sin correspondencias o conversiones confirmadas quedan pendientes.

## Validación de dispositivo
- iPhone: mantener el mismo bundle ID, probar SideStore sin desinstalar, persistencia ficticia, exportaciones y apertura real en Excel.
- No fusionar a main mientras falten aprobaciones y comprobaciones finales.
