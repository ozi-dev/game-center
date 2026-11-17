# Instalar y usar SofaRelay

> **BETA PÚBLICA** — La validación de hardware continúa. Las instalaciones nuevas mantienen el monitor físico encendido; apagarlo es opcional. [Casos probados y comprobaciones pendientes](../RELEASE-STATUS.md).

[English](en.md) · [Türkçe](tr.md) · [Français](fr.md) · [Español](es.md) · [Proyecto](../readme/es.md)

El instalador 2.3.2 admite inglés, turco, francés y español. Elige **Español** en la barra lateral; la selección se guarda y la ayuda sin conexión usa ese idioma. Aplicar los ajustes también selecciona español en Playnite. Necesitas Windows 10/11 Intel/AMD x64, .NET Framework 4.8, PowerShell 5.1, un controlador GPU actual y un codificador compatible con Sunshine. La conexión a Internet descarga los componentes; PC y cliente deben estar en la misma red.

## Configuración paso a paso

Descarga el ZIP de [Versiones](https://github.com/ozi-dev/sofarelay/releases), extrae todo y abre `Installer.exe`.

| Página | Etiqueta | Acción |
| --- | --- | --- |
| 1 | Inicio y diagnóstico | Espera a la detección. Elige la carpeta de instalación. Deja Playnite vacío para instalarlo o selecciona su carpeta actual. |
| 2 | Bibliotecas y cuentas | Elige tiendas. Epic directo usa Legendary; instala los demás clientes que necesites. |
| 3 | Emuladores | `Añadir emulador`: añadir emulador. Selecciona EXE, carpeta ROM, plataforma/extensiones y carpeta de datos. RetroArch necesita un núcleo DLL por sistema. |
| 4 | Transmisión y pantalla | Configura controles, accesos de escritorio/biblioteca, pantalla virtual opcional, señal de monitores, restauración y resolución/Hz. |
| 5 | Conexión Shield / TV | Sigue el emparejamiento Moonlight/Sunshine. ADB es opcional. |
| 6 | Instalación y mantenimiento | Cierra Playnite y la transmisión. `Instalar / completar` instala; `Aplicar ajustes / reparar` aplica/repara. Acepta los permisos necesarios y reinicia si se solicita. |
| 7 | Ayuda y recuperación | Ayuda, registros, recuperación de pantalla y restauración. |

Usa `Guardar ajustes` para conservar tus preferencias. Después, los cambios del sistema requieren Aplicar. Selecciona también el bitrate y HDR en Moonlight.

## Cuentas y TV

En Playnite de escritorio: menú principal → Add-ons/F9 → ajustes de extensiones → bibliotecas → proveedor → Authenticate. Para Epic directo, elige **Legendary (Epic Games)**. Completa tú mismo la autenticación y actualiza con F5. No envíes contraseñas ni códigos al responsable del proyecto.

Instala Moonlight desde la tienda del Shield/TV. En el PC, abre [Sunshine](https://localhost:47990), crea su cuenta local la primera vez e introduce el PIN que muestra Moonlight. Si no detecta el PC, añade su IPv4 manualmente. Abre **Game Library - Playnite** para la biblioteca o **Escritorio** para el escritorio.

Empieza con 1080p60 / 20 Mbps y aumenta la calidad si la red lo permite. Shield tiene un límite de 4K60; la frecuencia del panel de TV no aumenta su salida 4K. Activa **Optimize game settings** en Moonlight para cambiar de pantalla automáticamente. No necesitas ADB para la transmisión normal.

## Uso diario

- Ajustes posteriores: Inicio → SofaRelay → **SofaRelay Settings**.
- Confirmaciones de tiendas: mantén Start en el mando para activar el modo ratón; mueve el stick, A para clic izquierdo y B para clic derecho. Steam puede necesitar reiniciarse con `-cef-force-accessibility`. EA/Ubisoft/Xbox y ciertos juegos abren sus propios pasos de instalación.
- Historial: carpeta de datos Fritchii/Lichii con un `play_time\playtime.bin` compatible o registros `.lrtl` de RetroArch. No se puede reconstruir tiempo nunca guardado. Los archivos que no sean NUP pueden necesitar un identificador hexadecimal correcto de 16 dígitos o una correspondencia explícita.
- Carátula local: `Juego.cover.jpg` o `Juego.cover.png` junto a `Juego.xci`. Los iconos NUP disponibles y los metadatos de Playnite cubren otros casos.

## Solución de problemas

Pantalla negra o monitor físico sin señal: termina la transmisión y usa **Ctrl+Alt+F11**, o Inicio → SofaRelay → **Restore Display**. También puedes usar Win+P y los ajustes de pantalla de Windows.

Si falta una frecuencia, comprueba la salida del cliente, la decodificación, el cable y los FPS de Moonlight. Reinicia cuando se solicite tras añadir un modo VDD. Si ADB aparece como unauthorized, acepta el aviso RSA del TV; puedes seguir usando la ruta de la tienda sin ADB.

Las copias están en `data/backups`. La restauración no sobrescribe archivos modificados después: revísalos y combínalos manualmente. La aplicación personalizada no está firmada; usa el ZIP oficial y sus sumas o compila las fuentes, sin desactivar las protecciones de Windows.

No se incluyen juegos, ROM, BIOS, firmware, claves ni partidas guardadas. Los perfiles FPS opcionales necesitan un mod local compatible ya instalado y no garantizan rendimiento.

[Pruebas](../TESTING.md) · [Créditos](../CREDITS.md) · [Manual turco completo](manual.tr.html)

## Verificación, recuperación y desinstalación (2.3)

Antes de ejecutar este instalador sin firma, verifica la suma y la procedencia de compilación. Ayuda ofrece eliminación según propiedad, recuperación al iniciar sesión y modo de red local. Tú creas la contraseña de Sunshine; no hace falta abrir puertos del router.

Fritchii/Lichii son compilaciones de emulador elegidas por el usuario con formatos compatibles de ejecución e historial; no se incluyen ni se avalan.

[Verification](../VERIFYING.md) · [Troubleshooting](../TROUBLESHOOTING.md) · [Uninstall](../UNINSTALL.md) · [Security model](../../SECURITY.md)

**RecoveryWatchdog / LANOnly / RemoveOwnedComponents**: La recuperación usa el usuario normal y, tras reiniciar, empieza al iniciar sesión; no se garantiza antes. El modo local limita Sunshine a Private/LocalSubnet, desactiva UPnP y mantiene la web en el PC. La eliminación de componentes está desactivada y exige propiedad protegida; revisa los archivos compartidos. Instala los runtimes Visual C++ x64/x86 que falten con los instaladores Microsoft firmados de Requisitos. No ejecutes toda la interfaz como administrador.

Microsoft prerequisites: [.NET Framework 4.8](https://dotnet.microsoft.com/en-us/download/dotnet-framework/net48) · [Visual C++ x64 + x86](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist).
