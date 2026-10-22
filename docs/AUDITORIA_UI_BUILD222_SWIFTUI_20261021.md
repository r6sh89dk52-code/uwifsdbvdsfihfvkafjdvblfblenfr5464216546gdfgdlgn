# Auditoría de interfaz DANPER Build 222 → SwiftUI nativo

Fecha: 21 de octubre de 2026. Referencia: `release/v0.21.12-build222-provisional-consumptions` (React/CSS). Implementación: `feat/build222-native-ui-parity-20261020` (SwiftUI). **No se declara equivalencia visual píxel a píxel sin inspección en simulador/iPhone.**

## Paridad de estructura y cambios de este pase

| Pantalla | Estructura Build 222 observada | SwiftUI nativo después de los cambios | Pendiente |
| --- | --- | --- | --- |
| Inicio | DANPER/SALUD MÓVIL, tarjeta «Bienvenido», acceso rápido, Hoy/Semana/Borradores, 6 herramientas | Portada clínica protegida con logo, bienvenida, acción principal, contadores desde historial cifrado, rejilla 2×3 y tema azul opcional | Ajustar tamaños y márgenes con capturas iPhone 16 |
| Atención: navegación | 4 etapas: Trabajador, Evaluación, Tratamiento, Resultado; mini-resumen; anterior/siguiente; borrador | Mismos nombres y secuencia; haptics y transición de 0.22s respetando Reducir movimiento; borrador nativo | Comparar tamaños de chips, scroll al cambiar etapa y teclado |
| Evaluación | Alergias en etapa 2 antes de administrar, luego fecha/hora, categoría, sistema, segmento, diagnóstico | Revisión de alergias trasladada desde Trabajador a Evaluación, seguida de campos clínicos | Probar guardado de alergias con trabajador nuevo y selección por DNI |
| Tratamiento | Medicamentos agrupados por procedimiento, grupos desplegables, productos editables, cantidades, lotes y FEFO | Grupos plegables con tarjetas vinculadas al modelo previo; controles FEFO y confirmación sin cambios | Verificar agrupación cuando se edita el procedimiento de un producto y accesibilidad con teclado |
| Kardex | 98 productos y contador de lotes reales; guía de cuatro acciones | Cuatro rutas conservadas; lotes leídos de fuente activa, sin dato inventado | «Entradas y salidas»: comprobar vista de movimientos completos, no solo formulario de ingreso |
| Excel Indicador | 10 hojas y tres pasos de exportación | Mismo formato y reglas revisadas por usuario; semáforo INGRESOS validado en Mac | Ninguna alteración en este pase |
| Excel Kardex | Una hoja, 98 productos, stock F=D+E y H=F-G | Fórmulas y plantilla preservadas; ahora se normaliza «TOTAL ESTOCK» → «TOTAL STOCK» exclusivamente en encabezado | Ejecutar prueba de etiqueta en exportador y abrir archivo |
| Personal | DNI, padrón, ficha laboral, importación | Importación PERSONAL y editor protegidos, búsqueda y propuestas nativas | Validar padrón grande y paginación en la pantalla de consulta |
| Ajustes | Modos de apariencia, hápticos, recordatorios, respaldos | Azul institucional/rojo, claro/oscuro, navegación biométrica | Probar persistencia de preferencia, permisos y contraste |

## Reglas de seguridad y alcance
- **No modificar** fórmulas, cantidades, movimientos FEFO, conciliación, stock o atenciones existentes durante el rediseño.
- Inicio normal no inicializa trabajadores ficticios. Código de demo histórico es solo aislamiento de pruebas; no se añade al flujo clínico.
- El lector de contadores y número de lotes utiliza la bóveda autenticada, sin suposiciones ni entradas automáticas.
- La corrección del encabezado del Excel no altera valores ni estilos.
- El objetivo es equivalencia de jerarquía, jerga, gestos y recorridos; SwiftUI tiene animaciones y controles nativos, por lo que la identidad píxel a píxel exige revisión visual independiente.

## Validaciones locales mínimas
1. `node scripts/test-n2-build222-ui-parity.cjs`
2. `bash scripts/audit-build222-excel-parity-macos.sh` (incluye validación «TOTAL STOCK»).
3. `bash scripts/run-build222-native-on-macos.sh` (compilación, instalación y apertura del simulador).
4. Capturas de Inicio, Trabajador, Evaluación, Tratamiento expandido/contraído, Resultado, Kardex y ambos Excel en el simulador **iPhone 16**.
5. Contraste con capturas Build 222 en modo claro y oscuro, texto grande y «Reducir movimiento»; comprobar que ninguna pantalla tape las pestañas inferiores.
6. Verificar que ediciones de procedimiento y selección de lotes no generan consumos duplicados y que el historial permanece después de cerrar/abrir.

Estado: **cambios guardados en GitHub; falta la compilación y comparación física de esta iteración**.
