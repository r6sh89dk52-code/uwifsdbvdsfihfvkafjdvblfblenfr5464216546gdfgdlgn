# Estado real del IPA nativo — 27/10/2026

Rama de trabajo: `build/native-premium-ipa-20261027`, basada en Premium `2c776e88bc8b83e68ea85060263d204ca57025da`.

## Resultados registrados

| Ejecución | SHA | Resultado |
|---|---|---|
| [40521486342](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/40521486342) | 4750cd7f51048a7d4bc73fa085382ecd31b1a79d | Workflow inválido por runner.temp en jobs.env; corregido después. |
| [40521728126](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/40521728126) | b7b3934c518a2b46b8c930a733b0f3337e025b0c | JavaScript y auditorías PASS; 383/383 Swift core; Release iphoneos ARM64 BUILD SUCCEEDED; 15/15 XCTest nativos; 3/7 interacción. No se publicó IPA. |
| [40526585973](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/40526585973) | 2f4e7186a401976c58c93d0a2ce66862aae86fdc | Cancelado por @r6sh89dk52-code mientras estaba en cola; cero pasos ejecutados. |

El aviso de GitHub también menciona restricciones de capacidad para runners macOS arm64. La causa explícita del fin de la última ejecución es la cancelación por la cuenta del propietario, no una compilación fallida.

## Correcciones pendientes de nueva validación

- Se crea un iPhone 16 aislado, se verifica su arranque y se inscribe Face ID usando el procedimiento ya incluido en la documentación del repositorio. La ejecución anterior mostraba un formulario de código de iPhone sin biometría inscrita.
- La prueba del borrador realiza una selección explícita antes de editar. Conserva las verificaciones del teclado, el sufijo y la persistencia, y añade igualdad exacta del contenido completo. La hipótesis de posición del cursor aún debe confirmarse con la nueva ejecución.
- La aplicación, el cifrado, Keychain, el formato de respaldo, el motor clínico, FEFO y las exportaciones conservan el código Premium. Solo se modificaron automatización, una prueba de interacción y documentación.
- No hay IPA ni SHA-256 de IPA para entregar todavía. El empaquetado se ejecuta después del gate XCTest y verifica de forma independiente el binario, bundle, recursos, ZIP y checksum.
- La integración visual Glass no se inició: depende de completar primero el pipeline.

## Referencias preservadas

`main`: `19118cc687a65923504a304089b53997935463e8`.
Rama estable: `9bec8e01ccbb3f1a674372cf6e48df049dc4f014`.
Premium: `2c776e88bc8b83e68ea85060263d204ca57025da`.
Glass: `4f3c0c0dec1a6dbe27988f1577d5e81bb5ffbbea`; PR #8 sigue sin integrar.

Para continuar con el mismo SHA corregido, GitHub permite volver a ejecutar el job cancelado `122267736197` del run `40526585973`. Se pausa antes de relanzarlo para respetar la cancelación explícita registrada por la cuenta propietaria.
