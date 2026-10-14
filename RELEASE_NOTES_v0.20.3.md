# DANPER Salud Móvil v0.20.3 — acceso adicional por contraseña local

Base: PR #31 v0.20.2, migración clínica cifrada solo con respaldo externo coincidente.

- Bloqueo opcional de acceso a la aplicación mediante contraseña de 12 a 200 caracteres.
- No se guarda la contraseña: verificador PBKDF2-SHA256 en Keychain local (260 000 iteraciones, salt aleatoria).
- Pantalla de acceso antes de montar React/App y cargar trabajadores, atenciones, inventario o ejecutar efectos de autoguardado.
- Ajustes permite activar, bloquear inmediatamente y desactivar con contraseña actual.
- Demasiados intentos incorrectos: espera recuperable de 15 minutos. Falla cerrada si Keychain no está disponible.
- NO es Face ID ni cifrado adicional de la base: refuerza la privacidad visual en una aplicación con pantalla desbloqueada. El iPhone debe estar protegido con código y biometría propia del sistema.
- NO se modifica el cifrado clínico ni los registros previos. El estado activado por usuario se conserva en Keychain entre sesiones.
- Pruebas dinámicas con contraseña correcta, errónea, límite, desbloqueo, desactivación, Keychain inaccesible y navegador.
- CI, Xcode y validación física iPhone pendientes. La restauración real en un segundo dispositivo y auditoría final son puertas todavía abiertas. No declarar producción, no fusionar main.
