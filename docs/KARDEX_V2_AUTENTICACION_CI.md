# Autenticación y ciclo de vida: evidencia local y CI

Se audita el run 40576668230, commit ca95650a3ab5a47675f59677eb4249e37e48c511. No se fusionó la rama remota ni se copió su configuración de distribución.

El log de GitHub muestra que la prueba biométrica terminó en `premium-auth-error` con «No se pudo verificar tu identidad», sin acceso clínico. Esto no demuestra un bypass ni permite atribuir el fallo exclusivamente a infraestructura. CI utilizó Xcode 16.4/iOS 18.5; localmente existen Xcode 16.2/SDK 18.2 y runtime iOS 18.3.1.

Reproducción local: iPhone 16 aislado `1009FB5E-36A1-4349-B468-22D4D4FFCA08`. La primera prueba falló porque una notificación de inscripción incorrecta dejó al simulador solicitando código del dispositivo. La inscripción comprobada es:

```sh
xcrun simctl spawn "$danper_test_sim" notifyutil -s com.apple.BiometricKit.enrollmentChanged 1
xcrun simctl spawn "$danper_test_sim" notifyutil -p com.apple.BiometricKit.enrollmentChanged
```

Tras corregir esa precondición, la prueba existente `testAutomaticBiometryCancellationRetryAndForeground` pasó: cancelación, ausencia de bucle automático, reintento, autenticación simulada aceptada y nueva autenticación después del segundo plano. No se modificó producción para simular éxitos ni se eliminaron aserciones.

Se incorpora de la recuperación remota la selección explícita de todo el diagnóstico antes de editar: tocar un TextField no garantiza que el cursor quede al final en iOS 18.5. Se añade una espera verificable de `runningBackground` antes de reactivar la app; pulsar Inicio y activar inmediatamente no prueba que haya ocurrido `.background`. Las aserciones de cierre del editor y del teclado se conservan.

`LAContext` continúa perteneciendo a cada intento; se invalida al bloquear o entrar en segundo plano. El UUID del ciclo descarta callbacks tardíos. `.inactive` oculta contenido y bloquea interacción, sin invalidar el propio diálogo del sistema. Los nuevos flujos de respaldo/restauración invalidan contexto, cancelan tareas y borran credenciales al entrar en segundo plano.

Pendiente de aceptación final: repetir los tests reforzados y el recorrido v2, comprobar persistencia del borrador y auditar CI iOS 18.5 con Work. No se declara equivalencia entre versiones de simulador a partir de una sola ejecución local.
