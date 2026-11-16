# Instalar y usar Game Center

[English](en.md) · [Türkçe](tr.md) · [Français](fr.md) · [Español](es.md) · [Proyecto](../../README.es.md)

La interfaz 2.0.0 está en turco. Usa los números de página y las etiquetas de esta guía. Necesitas Windows 10/11 Intel/AMD x64, .NET Framework 4.8, PowerShell 5.1, un controlador GPU actual y un codificador compatible con Sunshine. La conexión a Internet descarga los componentes; PC y cliente deben estar en la misma red.

## Configuración paso a paso

Descarga el ZIP de [Versiones](https://github.com/ozi-dev/game-center/releases/latest), extrae todo y abre `Kurulum.exe`.

| Página | Etiqueta turca | Acción |
| --- | --- | --- |
| 1 | Başlangıç ve tanı | Espera a la detección. Elige la carpeta de instalación. Deja Playnite vacío para instalarlo o selecciona su carpeta actual. |
| 2 | Kitaplıklar ve giriş | Elige tiendas. Epic directo usa Legendary; instala los demás clientes que necesites. |
| 3 | Emülatörler | `Emülatör ekle`: añadir emulador. Selecciona EXE, carpeta ROM, plataforma/extensiones y carpeta de datos. RetroArch necesita un núcleo DLL por sistema. |
| 4 | Yayın ve ekran | Configura controles, accesos de escritorio/biblioteca, pantalla virtual opcional, señal de monitores, restauración y resolución/Hz. |
| 5 | Shield / TV bağlantısı | Sigue el emparejamiento Moonlight/Sunshine. ADB es opcional. |
| 6 | Kurulum ve bakım | Cierra Playnite y la transmisión. `Kur / eksikleri tamamla` instala; `Ayarları uygula / onar` aplica/repara. Acepta los permisos necesarios y reinicia si se solicita. |
| 7 | Yardım ve geri alma | Ayuda, registros, recuperación de pantalla y restauración. |

`Ayarları kaydet` significa Guardar. Después, los cambios del sistema requieren Aplicar. Selecciona también el bitrate y HDR en Moonlight.

## Cuentas y TV

En Playnite de escritorio: menú principal → Add-ons/F9 → ajustes de extensiones → bibliotecas → proveedor → Authenticate. Para Epic directo, elige **Legendary (Epic Games)**. Completa tú mismo la autenticación y actualiza con F5. No envíes contraseñas ni códigos al responsable del proyecto.

Instala Moonlight desde la tienda del Shield/TV. En el PC, abre [Sunshine](https://localhost:47990), crea su cuenta local la primera vez e introduce el PIN que muestra Moonlight. Si no detecta el PC, añade su IPv4 manualmente. Abre **Oyun Kütüphanesi - Playnite** para la biblioteca o **Masaüstü - Desktop** para el escritorio.

Empieza con 1080p60 / 20 Mbps y aumenta la calidad si la red lo permite. Shield tiene un límite de 4K60; la frecuencia del panel de TV no aumenta su salida 4K. Activa **Optimize game settings** en Moonlight para cambiar de pantalla automáticamente. No necesitas ADB para la transmisión normal.

## Uso diario

- Ajustes posteriores: Inicio → Oyun Merkezi → **Oyun Merkezi Ayarları**.
- Confirmaciones de tiendas: mantén Start en el mando para activar el modo ratón; mueve el stick, A para clic izquierdo y B para clic derecho. Steam puede necesitar reiniciarse con `-cef-force-accessibility`. EA/Ubisoft/Xbox y ciertos juegos abren sus propios pasos de instalación.
- Historial: carpeta de datos Fritchii/Lichii con un `play_time\playtime.bin` compatible o registros `.lrtl` de RetroArch. No se puede reconstruir tiempo nunca guardado. Los archivos que no sean NUP pueden necesitar un identificador hexadecimal correcto de 16 dígitos o una correspondencia explícita.
- Carátula local: `Juego.cover.jpg` o `Juego.cover.png` junto a `Juego.xci`. Los iconos NUP disponibles y los metadatos de Playnite cubren otros casos.

## Solución de problemas

Pantalla negra o monitor físico sin señal: termina la transmisión y usa **Ctrl+Alt+F11**, o Inicio → Oyun Merkezi → **Ekranı Geri Getir**. También puedes usar Win+P y los ajustes de pantalla de Windows.

Si falta una frecuencia, comprueba la salida del cliente, la decodificación, el cable y los FPS de Moonlight. Reinicia cuando se solicite tras añadir un modo VDD. Si ADB aparece como unauthorized, acepta el aviso RSA del TV; puedes seguir usando la ruta de la tienda sin ADB.

Las copias están en `data/backups`. La restauración no sobrescribe archivos modificados después: revísalos y combínalos manualmente. La aplicación personalizada no está firmada; usa el ZIP oficial y sus sumas o compila las fuentes, sin desactivar las protecciones de Windows.

No se incluyen juegos, ROM, BIOS, firmware, claves ni partidas guardadas. Los perfiles FPS opcionales necesitan un mod local compatible ya instalado y no garantizan rendimiento.

[Pruebas](../TESTING.md) · [Créditos](../CREDITS.md) · [Manual turco completo](../../README.html)
