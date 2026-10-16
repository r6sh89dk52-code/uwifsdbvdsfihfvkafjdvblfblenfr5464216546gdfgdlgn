# N1g — Primeras pantallas operativas SwiftUI, SOLO PRUEBA

Alcance: **padrón ficticio, registro clínico de cuatro pasos y borradores/historial de simulaciones**, con estado único Swift puro `N1gClinic` compartido entre pestañas. Se traslada la navegación nativa sin WebView, respetando el diseño rojo DANPER y modos iOS.

- Pestañas: Inicio / Personal / Atención / Borradores / Más. FEFO, verificador de respaldo y laboratorio cifrado previo siguen en Herramientas. Bundle ID permanece `pe.danper.saludmovil.native.preview`.
- Padrón: búsqueda por nombre y sede, registro exclusivo de personas **predefinidas ficticias**, y selección directa para simular una atención. **Sin importación de PERSONAL ni captura de personas reales**.
- Formulario: trabajador / evaluación y alergias / tratamiento / resultado. Todos los diagnósticos y materiales son opciones ficticias cerradas; sin texto clínico libre. Guardar crea únicamente una simulación dentro de la sesión, **sin lote FEFO, Kardex ni descuento físico**.
- Historial: reanuda/elimina borradores, presenta simulaciones confirmadas e inicia borradores de corrección. Una corrección **no puede reemplazar** un registro anterior hasta implementar revisión auditada.
- Alergias distinguen ausencia de revisión, `unknown`, `none`, `known`; el núcleo exige revisión explícita antes de guardar.
- Estado: `@State N1gClinic` en NativeRootView, sin persistencia de PII. Al terminar el proceso desaparecen todas las simulaciones. El usuario no debe registrar información clínica real ni interpretar esta vista como una historia clínica operativa.

## Validación
`swift test --jobs 2` en `ubuntu-latest` incluyendo las suites N1b–N1f + 8 tests N1g para identidad sintética, preservación y aislamiento de borradores, guardado simulado sin Kardex, correcciones e inspección de alergias. Adicionalmente `swiftc -frontend -parse native-ios/App/*.swift` comprueba **solo sintaxis** de SwiftUI en Linux. No puede comprobar tipado SwiftUI ni enlazar UIKit: eso queda pendiente de un gate conjunto de compilación iOS en macOS cuando se autorice, sin generar IPA prematura.

Sin conexión con la bóveda de trabajadores real, datos clínicos, SQLite, Keychain de producción, exportadores de 10 hojas ni inventario. No reemplazar la build222, no fusionar esta rama sin revisión.
