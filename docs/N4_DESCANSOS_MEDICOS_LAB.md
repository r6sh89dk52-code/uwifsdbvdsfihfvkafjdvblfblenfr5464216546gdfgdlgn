# DANPER N4 — Descansos médicos (laboratorio aislado)

## Aislamiento obligatorio
- Base: commit 9bec8e01ccbb3f1a674372cf6e48df049dc4f014.
- Rama exclusiva: feat/n4-descansos-medicos-isolated-20261025.
- Bundle ID: pe.danper.saludmovil.native.n4dm.lab.
- NO modificar main ni feat/build222-native-ui-parity-20261020.
- NO instalar como actualización de la app nativa actualmente utilizada.
- NO crear IPA de distribución ni usar datos reales de pacientes o trabajadores en pruebas.

## Implementación
- Acceso SwiftUI desde Inicio > Gestión ocupacional > Descansos médicos (mantiene cuatro pestañas).
- Comando DEBUG --danper-dm-lab para abrir la pantalla directamente sin acceder a bóveda clínica N2.
- Fecha de recepción física elegida antes de cada documento, independiente de fecha de emisión o incapacidad.
- Importación desde galería, escáner de documento y OCR local mediante Vision; no almacenamiento voluntario de imágenes.
- Confirmación manual del DNI, CITT, fechas, días, contingencia, entidad y diagnóstico (nunca inventar).
- Padrón sólo lectura por DNI para conciliación cuando se accede desde fuente clínica.
- AES-GCM y Keychain de N4 totalmente separados de N2, registro de revisión y cambios.
- Validación de días inclusivos, alerta ante discrepancia, duplicados, hospitalización no confirmada por defecto.
- Checklist persistente de contacto, ampliación, revisión ocupacional y alta.
- Regla operacional inicial: cinco días o más, o internamiento confirmado, requieren alta verificada antes de marcar reincorporación.
- Avisos locales privados de reincorporación.
- Exportador OOXML: modifica sólo filas vacías dentro de las 4093 preparadas de DM2026, preservando hojas auxiliares, celdas históricas, estilos de celdas y fórmulas restantes. La plantilla real se elige temporalmente desde Archivos.

## Estado pendiente
- Google Drive OAuth, backend para actualización del mismo XLSX y sincronización Android: NO implementados ni conectados. La exportación actual es local/manual.
- Cámara física no funciona en iPhone 16 Simulator: usar galería o registro manual para pruebas.
- OCR multi-página requiere revisar/conciliar el texto de cada hoja; no tratar varias páginas como CITT distintos automáticamente.
- Excel debe comprobarse en Microsoft Excel macOS/Windows con una copia ficticia. La fórmula J/K/L puede mostrar vacío si el DNI no está en BASE TRAB del propio libro original.
- No se han ejecutado las pruebas Xcode de esta nueva implementación sobre el Mac del usuario. No declarar PASS hasta ver los logs.

## Comandos en tu Mac SIN cambiar la rama nativa activa

1. Entra a la carpeta del repositorio original y ejecuta:

    git fetch origin feat/n4-descansos-medicos-isolated-20261025

2. Crea un worktree separado:

    git worktree add --detach "$HOME/Downloads/DANPER-N4-DM" origin/feat/n4-descansos-medicos-isolated-20261025

3. Ejecútalo:

    cd "$HOME/Downloads/DANPER-N4-DM"
    bash scripts/n4-dm-simulator-iphone16.sh

4. Para abrir manualmente el laboratorio ya instalado en el simulador:

    xcrun simctl launch booted pe.danper.saludmovil.native.n4dm.lab --danper-dm-lab

Si tienes más de un simulador encendido, sustituir booted por el UDID de iPhone 16.

## Puertas de validación
- DMCoreTests: fechas, OCR sintético, acumulados, duplicados y regla de alta.
- DMExcelWriterTests: plantilla XML sintética, celdas históricas y preservación de hojas.
- DMModuleInteractionTests: pantalla N4 y formulario obligatorio en Xcode iPhone 16 Simulator.
- Comparación Excel con modelo oficial, rendimiento y navegación sin alterar el flujo clínico.
- Antes de uso productivo: permisos de empresa, políticas de privacidad y diseño autorizado de Drive/Android.
