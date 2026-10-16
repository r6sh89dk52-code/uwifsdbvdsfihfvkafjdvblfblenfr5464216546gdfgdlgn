# DANPER N1h — Formulario guiado SwiftUI con paridad TypeScript

Esta etapa hace que la navegación **trabajador → evaluación → tratamiento → resultado** valide lo mismo que `src/attentionStepValidation.ts`, sin importar trabajadores reales ni permitir registros clínicos persistentes.

## Cambios implementados

- Un validador independiente `N1hClinicalValidator` conserva los identificadores originales de errores de validación para DNI, nombre, fecha/hora, categoría, sistema afectado, segmento osteomuscular, diagnóstico, revisión de alergias, cantidades/procedimientos y horario de permiso.
- 16 escenarios sintéticos se generan usando las funciones originales TypeScript; se contrasta cada lista ordenada de errores y primera etapa incompleta con Swift.
- El modelo de formulario volátil ahora conserva fecha/hora, sistema, segmento, permiso y hora de permiso, procedimientos independientes y los marcadores de curación, devolución y envío de foto (solamente booleanos; **sin fotos**). Corregir una atención crea un borrador que no sobrescribe la atención confirmada.
- SwiftUI presenta campos condicionales y vista de revisión. «Siguiente» evalúa y detiene el avance cuando faltan datos de la etapa. La acción Guardar revalida los cuatro pasos, no altera lotes, atenciones reales ni movimientos Kardex.
- Catálogos cerrados de personas ficticias, diagnósticos ficticios, horarios fijos y materiales de prueba. No existe entrada libre para DNI real, documentos o datos personales.
- Se ordenaron visualmente las cinco pestañas de acuerdo con su nombre y se eliminó una antigua vista de prototipo no utilizada con campos libres.

## Limitaciones verificables

Swift en Linux compila el núcleo y prueba su lógica. `swiftc -frontend -parse` sobre las vistas solo comprueba sintaxis: **no demuestra compilación ni funcionamiento de SwiftUI/UIKit para iPhone**; queda pendiente una validación iOS agrupada con Xcode cuando esté justificada. No generar ni instalar IPA ahora.

No se ha implementado restauración clínica real, Keychain del registro, FaceID auditado en N1h, escritura de historial, autoguardado durable ni exportación de los dos Excel. La build222 no se modifica y la PR sigue en borrador. Datos ficticios únicamente, almacenados en memoria del proceso.
