# DANPER Salud Móvil v0.7.1 — Corrección iPhone

Actualización exclusivamente de diseño y empaquetado desde v0.7.0; **no cambia** las reglas de atenciones, borradores, alergias ni medicamentos.

- Inputs, select y textarea con 16 px mínimos para evitar el zoom automático al enfocarlos en iOS WKWebView, sin anular el zoom manual de accesibilidad.
- Fecha y hora apiladas en pantallas de teléfono; evita superposiciones de controles iOS.
- Cabecera ajustada al área segura de iPhone y al rojo del logo oficial.
- Distribución adaptable de los botones de trabajador, medicamento y barra fija.
- Mejor espaciado para alergias y margen inferior para las acciones persistentes.
- IPA actualizado a versión 0.7.1 en package.json y el Info.plist al empaquetarlo.

**Validación previa:** pruebas de lógica existentes PASS y simulación responsive Chromium (320, 350, 375, 393, 414, 540, 620 px), sin scroll horizontal ni campos de texto menores de 16 px.

**Pendiente de validar:** instalación real del IPA v0.7.1 por SideStore, comportamiento del teclado y del zoom en iPhone. No utilizar datos reales: almacenamiento local sin cifrar.
