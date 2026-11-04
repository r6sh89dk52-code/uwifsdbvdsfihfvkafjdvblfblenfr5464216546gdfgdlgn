# Controles reproducibles de rendimiento Core y permiso FaceID

Estos controles no aprueban la aplicación por sí solos ni generan IPA. La aprobación requiere Swift/Xcode/nativas/UI/Excel/compatibilidad y métricas del HEAD definitivo. Código de App/Sources, formato, clave, inventario y BundleID permanecen intactos.

Los nueve límites se fijan después de comparar varios runs v2 c274140→candidato:9648trabajadores/1005atenciones ficticias, mismo job y ciclo de sesión, estado físico completo conservado y saldo78. Son objetivos de regresión del benchmark Core Linux; no de latencia SwiftUI/iPhone.

| Operación | Límite |
|---|---:|
| Alergias p50 |≤85% del baseline |
| Borrador p50 |≤65% del baseline |
| Revisar consumos p50 |≤25% del baseline |
| Excel enfermeras p50 |≤90% del baseline |
| Backup cifrado verificado p50 |≤95% del baseline |
| Buscar último trabajador p95,100muestras |≤5ms Core |
| Buscar nombre común p95,100muestras |≤25ms Core |
| CPUusuario del workload preparado, sin compilador |≤90% del baseline |
| RSSmáxima del mismo workload |≤110% del baseline |

Las siete regresiones adicionales comprueban reversión a operaciones lentas, variación uniforme del host, consulta al final, tamaño reducido, NaN y crecimiento de memoria. Los límites no sustituyen ninguna auditoría clínica/criptográfica; comparaciones v2 distintas o incompletas fallan. La validación final recalcula los límites y exige el mismo JSON del artifact.

El diagnóstico41509657892 confirmó mediante screenshot y AUTHREQ_PROMPTING que el primer aviso de permiso FaceID estaba sin responder. La preparación UI acepta únicamente el consentimiento FaceID de DANPER en el Simulator propio, no envía eventos biométricos y exige que los controles clínicos sigan inaccesibles. Después, el caso nativo original debe obtener appCancel real:12s de cancelación/18s de espera, máximo dos solicitudes, sin cambios. Autorizar el uso de FaceID no prueba identidad.

La preparación añade un caso UI (total14) y mantiene28nativas. Dos regresiones del verificador rechazan evidencia sin preparación de permiso o sin cancelación real; pasar ambas no sustituye un caso biométrico fallido. Python total33 (24anteriores+7presupuestos+2evidencia). Los resultados locales no sustituyen la ejecución completa del SHA publicado.

Trazabilidad: presupuesto/testsbcbf7a0, UIpermiso267bfe4, checkoutdiagnóstico7841f58. El trial41516039780 aprobó permisoUI1/1 y cancelación nativa1/1, sin fallos/omisiones; appCancel-9 real en12,433s. Es validación acotada, no aprobación de28nativas/14UI del HEAD nuevo. No se modificó main ni la Build14 instalada, no se accedió al teléfono y no existe IPA aprobada.

La corrección posterior del cierre del harness añade4regresiones de integración: Python pasa de33a37. El antiguo cierre fijo13se sustituye por verificación del inventario/selectores de las fuentes; se mantienen14UI y28nativas obligatorias. Véase UI_INVENTORY_GUARD.md. Estos resultados del harness no sustituyen Swift/Xcode/UI del HEAD final.

El candidato posterior de carga clínica añade4Core y1nativa: exige437Swift/29nativas/14UI/37Python. Ausencia de archivos evita una consulta innecesaria al llavero; toda incertidumbre conserva inspección protegida. Se difiere el inicio hasta escena activa/sesión desbloqueada y se instrumenta la ruta. Véase CLINICAL_SOURCE_LOADING.md; la corrección funcional no se considera validada hasta Xcode/UI del nuevo HEAD.
