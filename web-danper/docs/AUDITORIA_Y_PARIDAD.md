# Auditoría y estado real — 25 de octubre de 2026

Repositorio: `r6sh89dk52-code/danper-salud-movil-pruebas`.
Rama fuente consultada mediante el conector autenticado de GitHub: `feat/build222-native-ui-parity-20261020`.
HEAD obtenido de GitHub: `9bec8e01ccbb3f1a674372cf6e48df049dc4f014`, árbol `c11531f379e7971893c70def31e677dcd714322a`.
Se consultó el HEAD antes de descargar: coincidía con la referencia de la instrucción. No se asumió que seguía vigente.
Rama independiente creada: `feat/danper-web-integral-20261025`.

Se recuperaron 456 archivos del árbol de referencia. No se alteraron el proyecto iOS, main, datos de usuario ni respaldos. La copia local se materializó mediante el conector porque Git por HTTPS sin esa sesión no tenía acceso al repositorio privado. Su commit local de referencia no pretende ser el commit original; los commits publicados se basan directamente en el HEAD original mediante la API de GitHub.

## Matriz funcional y visual

| Fuente nativa | Equivalente web | Controles / validación implementada | Estado y límites |
|---|---|---|---|
| `N2ClinicalWorkspaceView.swift` | Inicio y navegación | Inicio, Registrar, Historial, Ajustes; estadísticas desde registros persistidos | Implementado; comparación visual simultánea con simulador pendiente |
| `DanperUITheme.swift` | `style.css` | Paleta roja 0.89/0.094/0.176, azul 0.04/0.43/0.80; superficies claras/oscuras; sistema; preferencias | Implementado; controles, tablas, paneles y formularios usan variables semánticas |
| `N2NativeWorkerEditorView.swift` | Editor de trabajador | DNI de ocho dígitos, ficha laboral, nacimiento, área oficial y sede | Implementado; cambios canónicos por DNI conservan snapshot de atenciones |
| `N2NativePersonalImportView.swift` (ruta real: App) y `N2PersonalWorkbookReader.swift` | Importación PERSONAL | Lectura local XLSX, vista previa, duplicados, conflicto de identidad, bloques de 100 | Parcial: se reutiliza importador TS y se añaden nacimiento/sede; falta probar todas las variantes del lector Swift |
| `N2ClinicalFormOptions.swift` | Contrato generado | Seis categorías, trece sistemas, diagnósticos originales | Generado desde fuente; no lista manual alternativa |
| `N2OsteomuscularSegments.swift` | Selector con entrada libre | Segmentos específicos e históricos; solo sistema OSTEOMUSCULAR | Implementado |
| `N1hClinicalValidator.swift`, `N2NativeFormContext.swift` | Cuatro pasos | DNI/padrón; fechas; sistemas condicionales; alergias; cantidades enteras; permiso; responsable; fotografía en curaciones | Implementado para los controles incluidos; sugerencia de procedimiento exige confirmación explícita |
| `N2ProcedureRules.swift` | Tratamiento | Doce procedimientos y sugerencias deterministas | Catálogo generado; inferencia reutilizada del TS del mismo contrato |
| `N2NativeHistoryView.swift`, `N2ClinicalCorrections.swift` | Historial | Búsqueda, paginación, conservación original, eventos de rectificación | Parcial: diagnóstico, sistema, segmento y responsable; no todas las operaciones de rectificación Swift |
| `N2NativeInventoryView.swift`, `N2NativeInventoryCommands.swift` | Kardex e inventario | Lotes, fechas, FEFO, ingresos, conteos/ajustes auditados, cierres declarados | Implementación parcial del motor; inventario auxiliar y todas las variantes de comandos pendientes |
| `N2ContainerAccounting.swift`, `N3DeclaredContainerTests.swift` | `accounting.ts` | R=N declarado; reutilización R=0; cierre solo explícito; agotamiento no inferido por volumen | Casos automatizados; falta comparación ejecutando Swift y TS contra el mismo conjunto completo de fixtures |
| `N2AutomaticCutAccounting.swift`, `N2KardexCutPreview.swift` | Reportes / proyección | Corte 9–8 Lima, estado histórico de lotes, consumo clínico proyectado sin descuento | Parcial: falta portar todas las evidencias históricas y conciliación del motor nativo |
| `N2VerifiedIndicatorWorkbook.swift` | Indicador | Escritor OOXML del repositorio; 10 hojas, 19 tablas, 432 materiales, A–AD, fórmulas | Pruebas estructurales; falta conciliación material completa y comparación de todos los estilos/campos con ejecución nativa |
| `N2VerifiedNursingWorkbook.swift` | Kardex | Plantilla original incluida; 98 productos, movimientos R, fechas y saldos | Casos automatizados; ajustes bloquean exportación hasta conciliación completa |
| `N2OccupationalVigilanceWorkbook.swift` | Vigilancia osteomuscular | Encabezados, anchos, estilos y códigos generados desde Swift | Exportador implementado y probado estructuralmente; ejecución comparativa Swift pendiente |
| Fuentes EMO locales | EMO | Importación con mapeo revisado, DNI, historial, aptitud original, fechas manuales, filtros | Parcial: reglas de programación específicas de los seed originales aún no portadas por completo |
| `colinesterasa.py` local | Colinesterasa | Tipo/perfil explícito, campañas manuales, discrepancias por DNI, historial, fechas | Parcial: selección oficial original y modelo J6:J53 requieren revisar la plantilla y clasificaciones originales |
| Sin equivalente nativo auditado para cada módulo adicional | Descansos y alertas | Fechas, días inclusivos, reincorporación, seguimiento, estados de alertas | Registro, alertas y exportación de datos implementados; plantilla oficial de descansos y revisión asistida de documentos pendientes |
| Bóveda/journal nativo | IndexedDB y cola | Cambios locales atómicos, revisiones, cola y reintentos | Pruebas locales; caché clínica del navegador sin cifrado equivalente a bóveda iOS |
| Adaptador cloud nuevo aislado | `native-adapter/` y `sync.ts` | Contrato Codable, recibos, CAS, cursor incremental, bloqueo por conflicto | No activado. Journal cifrado nativo concreto, compilación Swift y prueba bidireccional real pendientes |

## Recursos externos encontrados

Sin copiar registros personales al código ni a GitHub:

- `C:\Users\felip\Downloads\VERIFICADOR_EMO_HOME_SAFETY_HOJA1_TUNEL_VERIFICADO\core.py`.
- Mismo directorio: `colinesterasa.py`, `excel_output.py`, `plantilla_colin_2026.xlsx`, `PROGRAMACION_EMO_HOJA1_2026_CORREGIDA.xlsx`, `seed_workers.json`, `col_seed.json`.
- `C:\Users\felip\Desktop\ACP_SALUD_BETA22SEP - CODEX\docs\EMO_ARCHITECTURE.md`.
- Configuración del prototipo local `DANPER-SALUD-WEB-WINDOWS-v0.3-SWIFTUI`: campos Firebase vacíos; no ID real utilizable.

Reglas verificadas: un examen general EMO no acredita colinesterasa; el resultado original se conserva; vínculo por DNI; ninguna periodicidad anual se asigna por coincidencia textual amplia con “operador”; la plantilla de colinesterasa original solo autoriza cambiar fechas en J6:J53. La nueva herramienta genérica de actualización exige elegir y revisar explícitamente las celdas, pero aún no certifica esa plantilla local específica.

## No finalizado

La plataforma integral solicitada **no está terminada**. No hay URL publicada, migración cloud habilitada ni sincronización comprobada con iPhone. Falta implementar/validar los puntos marcados parciales, en especial conciliación completa, conflictos cloud, journal nativo, conciliación del indicador y reportes estadísticos adicionales. No debe confundirse una compilación correcta o las pruebas de casos cubiertos con validación clínica completa.
