# DANPER Salud Móvil v0.14 — Exportación del Kardex diario con el formato original

## Fuente preservada
Archivo aportado: **KARDEX DE ENFERMERÍA ACTUALIZADO - OCTUBRE-2026.xlsx**.
Se conservan las hojas **KARDEX ENFERMERAS** (98 productos, filas 7–104) y **Hoja1** (6 donados, filas 6–11), celdas combinadas, bordes, estilos, títulos y configuración de impresión A4 vertical/90 % que existe en la hoja principal.

**La plantilla NO se reconstruye ni se modifica de origen:** en el iPhone se selecciona el Excel desde la aplicación Archivos en cada sesión. La app lee ese archivo localmente, reemplaza únicamente los datos diarios y exporta una copia. No es necesario conectarse a un servidor. La nueva integración Capacitor FileSystem/Share utiliza la hoja nativa de compartir para WhatsApp, correo o Archivos cuando funciona en el dispositivo.

## Cálculo original
En cada producto de KARDEX ENFERMERAS:
- D Stock inicial del día (en unidades de reporte).
- E Ingresos extraordinarios.
- F Total de stock = D + E (fórmula Excel con resultado en caché).
- G Consumo del día.
- H Stock final = F − G (fórmula Excel con resultado en caché).
- I FV más próxima conocida.
- J F/S: **FALTA/SOBRA = recuento físico − saldo teórico**. En esta versión permanece vacío si aún no hay recuento confirmado (no inventar).
Para Hoja1 donados B inicial, C consumo, D final y E F/S, con su formato anterior conservado.

### Reglas de envases
Los productos con envases (frascos, cajas, paquetes, blísteres) se informan en **envases cerrados** para D/H; G computa aperturas registradas como 1. Los usos posteriores del envase abierto no descuentan otro envase (R=0). El saldo parcial en mL permanece en el control físico interno, no se convierte incorrectamente en frascos. Los productos individuales se reportan por unidades efectivamente consumidas.

### Advertencias que impiden exportar
- Ajustes auditados del día aún no conciliados.
- Ingresos extraordinarios de donados (su hoja no tiene columna E).
- Mezcla de modo de conteo individual y por envase para el mismo producto.
- Saldo teórico discordante del historial o inventario histórico incompleto.

### Alcances todavía pendientes
- Recuento físico diario confirmado y validación F/S (por ahora J/E queda en blanco).
- Cierre formal de turno con saldos de entrada/salida de cada franja. **Actualmente el reporte abarca todo el día**, aunque se selecciona un turno para identificación. No se inventan horarios.
- Exportación directa sin seleccionar plantilla (requeriría empaquetar y versionar la plantilla oficial dentro de la aplicación).
- Exportación de las atenciones CONSUMOS al Excel ambulatorio (otra función).
- Copia/recuperación SQLite cifrada para datos clínicos reales.

## Prueba en SideStore
1. Conservar IPA anterior como respaldo.
2. En el iPhone guardar el Excel original en **Archivos** (una sola vez).
3. Abrir DANPER → Kardex → Reporte diario.
4. Seleccionar fecha, turno y el archivo original.
5. Revisar los 98 + 6 productos y eventuales observaciones.
6. Generar Excel y compartir mediante iOS. Abrir en Microsoft Excel y verificar datos, fórmulas y formato A4 vertical.
7. Comprobar que no altera los movimientos ni el historial; usar solo datos ficticios.
