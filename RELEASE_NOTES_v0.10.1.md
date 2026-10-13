# DANPER Salud Móvil v0.10.1 — Corrección del gate de Kardex

## Incidente reproducido en GitHub Actions
La compilación v0.10 se detuvo durante `npm run test:logic`, después de que pasaran las pruebas anteriores, con `Error: Cantidad inválida para fecha de modificación`.

## Causa raíz
`validateStockLot()` reutilizaba un validador de cantidades con máximo 10 000 000 para la propiedad `updatedAt`. En cambio, `Date.now()` devuelve milisegundos desde Unix Epoch (aprox. 1,8 × 10¹²), por lo que cualquier lote legítimo quedaba rechazado.

## Correcciones
- `updatedAt`: ahora se valida por separado como entero seguro no negativo, sin el tope de cantidades de inventario.
- Mantiene el tope físico de cantidades de stock, de capacidad y de envases.
- Pruebas de regresión con `Date.now()`, epoch 0, marca negativa, decimal, infinita y fuera del rango seguro.
- Eliminados `React` y `visibleCatalog` sin usar en `KardexPanel.tsx`, que habrían impedido `tsc -b` por la opción `noUnusedLocals`.
- Versión npm `0.10.1`, IPA `0.10.1`, compilación interna `101`.

## Alcance
Sin alteraciones al flujo de atención, cálculo físico de existencias, notificaciones, gestos de iOS ni cifrado de Keychain. No se descuenta stock de forma automática.

## Validación pendiente
Se requiere que GitHub Actions pase `npm run test:logic`, `npm run build` y la compilación con Xcode. No utilizar información clínica real.
