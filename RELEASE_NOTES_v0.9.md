# DANPER Salud Móvil v0.9 — Gesto de retroceso nativo en iPhone

Base: v0.8.0 verificada por el usuario mediante SideStore. Mantiene datos ficticios en Keychain, las correcciones visuales v0.7.1, las atenciones, los borradores y los recordatorios.

## Nueva interacción

- **iOS:** se instala `UIScreenEdgePanGestureRecognizer` de UIKit en el controlador Capacitor. Un deslizamiento horizontal desde el extremo izquierdo hacia la derecha activa el retroceso visible dentro de DANPER. No utiliza la navegación web de Safari ni intenta salir de la aplicación.
- **Borradores:** salir de una atención con el gesto conserva su borrador significativo antes de navegar.
- **Padrón:** desde el padrón utiliza la flecha Volver ya existente, para regresar al formulario o a Inicio según desde dónde se abrió.
- **Teclado:** si hay un campo activo, el primer gesto cierra el teclado; un segundo gesto permite retroceder.
- **Inicio:** el gesto no hace nada si ya estás en la pantalla principal.
- **Navegador:** se incluye un gesto de respaldo solo para las pruebas web, limitado al primer tramo izquierdo de la pantalla y sin interferir con scroll vertical normal. En iOS se usa UIKit, no este gesto web.

## Comprobación automatizada

`npm run test:logic` ahora incluye casos de dirección, distancia, duración del gesto, rechazo de desplazamiento vertical/horizontal normal, e instalación idempotente de la integración Swift. GitHub Actions inserta el reconocedor nativo después de crear y sincronizar el proyecto iOS y antes de ejecutar Xcode.

## Importante

- Se trata de un gesto nativo de detección. La transición entre pantallas la ejecuta React después de completar el deslizamiento; todavía no es una animación interactiva que sigue el dedo como `UINavigationController`.
- Esta entrega no modifica ni importa datos clínicos reales. Continúa siendo un prototipo para pruebas ficticias.
- Antes de dar por validado el gesto es necesario compilar el nuevo IPA v0.9 y comprobarlo físicamente en el iPhone.
