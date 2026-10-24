# DANPER N2 — reconstrucción integral del corte 9–8
Fecha de implementación: 2026-10-24 · Rama: `feat/build222-native-ui-parity-20261020`

## Objetivo y regla contable

Cuando se registra hoy el **stock físico realmente contado**, se conserva ese
saldo sin descontar de nuevo una atención pasada. Para el corte mensual
9–8, el saldo inicial se reconstruye de forma **solo lectura**:

`Saldo inicial = conteo físico posterior + consumos contables confirmados − ingresos posteriores − ajustes netos`

- La atención clínica guardada se cuenta una sola vez por ID de atención y línea.
- Si ya existe una salida FEFO real, su cantidad contable `excelQuantity`
  tiene prioridad sobre la atención clínica y sobre declaraciones históricas.
- Para artículos `UND/TBL/PAR`, un consumo clínico guardado y vinculado puede
  integrar la reconstrucción aunque el lote se haya dado de alta más tarde.
- Para `FCO/CJA`, jamás se infiere una apertura por atención o volumen:
  se usa R=1/0 de movimientos físicos existentes o una declaración histórica
  explícita de apertura, con responsable y motivo.
- Una declaración histórica puede señalar un lote hoy agotado, pero **no**
  habilita FEFO sobre lote agotado ni altera existencias actuales.
- Las 86 correspondencias oficiales siguen inmutables; se reconocen las seis
  asociaciones confirmadas en bloque y las reglas operativas ya registradas.
- Los 98 productos del Kardex conservan sus filas; sin lote se escribe
  `0`, conservando `stockKnown=false` para distinguirlo de un conteo certificado.

## Dónde quedó conectado

1. `N2AutomaticCutAccounting`: cálculo 9–8, 86+6+operativas,
   consumos unitarios previos y aperturas históricas declaradas.
2. `N2NursingReportBuilder.reconstructedCut`: 98 filas, saldo inicial
   reconstruido, consumo una vez y cierre igual al conteo físico.
3. `N2VerifiedNursingWorkbook.exportRange`: opción de reconstrucción
   exclusiva para la modalidad **Desde el 9 hasta la fecha**; diario,
   semanal y rango personalizado conservan la ruta física anterior.
4. `N2VerifiedIndicatorWorkbook`: admite las seis asociaciones en
   auditoría de movimientos y calcula apertura/conteo en el **libro
   provisional** del período 9–8 completo y ámbito Ambas sedes,
   solo con correspondencia única y balances verificables. La
   exportación oficial estricta **no omite controles de revisión**.
5. `N2NativeHistoryView`: identifica cuándo una línea se incluyó
   en el saldo reconstruido, sin marcar ficticiamente salida FEFO.
6. `N2PendingDispensingView` y `N2NativeFormContext`: declaración
   histórica R=1/0 incluso sobre lote actualmente agotado, sin
   permitir su consumo FEFO en nuevas atenciones.

## Casos de aceptación en iPhone 16 Simulator (solo datos ficticios)

- **Paracetamol:** atención ficticia de 3 UND sin lote previo. Más tarde
  registrar un conteo físico real simulado de 20 UND. Vista de corte:
  saldo inicial estimado 23, consumo 3, cierre 20. Historial: incluido
  en proyección pero sin salida física retroactiva.
- **Envase declarado:** dos frascos registrados con un uso antiguo.
  Declarar apertura histórica real `1`, después reutilizar el mismo
  envase con apertura `0`. Ver R=1 y R=0 y ningún doble descuento.
- **Sin apertura declarada:** un FCO sin evidencia de apertura debe
  continuar pendiente; nunca convertir usos en R=1 automáticamente.
- **Sin lote:** cada fila de los 98 artículos en el Excel conserva
  stock 0 visible, incluidos los seis marcados NO CORRESPONDE.
- **Día 9:** los consumos del día 8 pertenecen al corte anterior;
  el día 9 inicia un nuevo período sin borrar la historia.
- **Excel diez hojas:** no duplicar saldos por sede ni emitir una
  apertura automáticamente como certificada; distinguir claramente
  borrador provisional y exportación oficial.
- **Idempotencia:** repetir la consulta/exportación no genera nuevos
  movimientos físicos, ni cambia lotes o atención original.

## Validación local necesaria

En el Mac del usuario, con repositorio actualizado en esta rama:

```bash
cd ~/Downloads/DANPER-N2-Paridad
git pull --ff-only origin feat/build222-native-ui-parity-20261020
node scripts/test-n2-build222-ui-parity.cjs
bash docs/N2_PROBAR_PARIDAD_MAC_SIN_ACTIONS.command
```

La ejecución completa de las pruebas Swift y la compilación Xcode
**no se pueden certificar desde GitHub por sí solos**. Registrar cualquier
fallo de `swift test`, XcodeGen, xcodebuild o prueba manual en Simulator
antes de intentar un IPA o fusionar el PR.

No se modifica el inventario real, la bóveda clínica, el Keychain de
producción, la Build 222 ni `main` para este trabajo.
