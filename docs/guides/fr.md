# Installer et utiliser Game Center

[English](en.md) · [Türkçe](tr.md) · [Français](fr.md) · [Español](es.md) · [Projet](../../README.fr.md)

L’interface 2.0.0 est en turc. Les numéros de page et les libellés ci-dessous permettent de la suivre. Utilisez Windows 10/11 Intel/AMD x64 avec .NET Framework 4.8, PowerShell 5.1, un pilote GPU récent et un encodeur compatible Sunshine. Internet sert à télécharger les composants ; PC et client doivent partager le même réseau.

## Parcours de configuration

Téléchargez le ZIP des [versions publiées](https://github.com/ozi-dev/game-center/releases/latest), extrayez-le entièrement et ouvrez `Kurulum.exe`.

| Page | Libellé turc | Action |
| --- | --- | --- |
| 1 | Başlangıç ve tanı | Attendre la détection. Choisir le dossier d’installation. Laisser Playnite vide pour l’installer, ou sélectionner son dossier existant. |
| 2 | Kitaplıklar ve giriş | Choisir les boutiques. Legendary gère l’installation Epic directe ; installer les autres clients si nécessaire. |
| 3 | Emülatörler | `Emülatör ekle` : ajouter un émulateur. Choisir EXE, dossier ROM, plateforme/extensions et dossier de données. RetroArch nécessite un cœur DLL par système. |
| 4 | Yayın ve ekran | Régler commandes, accès bureau/bibliothèque, écran virtuel facultatif, signal des moniteurs, restauration et résolution/fréquence. |
| 5 | Shield / TV bağlantısı | Suivre l’association Moonlight/Sunshine. ADB est facultatif. |
| 6 | Kurulum ve bakım | Fermer Playnite et le streaming. `Kur / eksikleri tamamla` installe ; `Ayarları uygula / onar` applique/répare. Accepter l’élévation nécessaire et redémarrer si demandé. |
| 7 | Yardım ve geri alma | Aide, journaux, récupération de l’écran et restauration. |

`Ayarları kaydet` signifie Enregistrer. Les modifications système nécessitent ensuite Appliquer. Le débit et le HDR doivent aussi être choisis dans Moonlight.

## Comptes et connexion

Dans Playnite bureau : menu principal → Add-ons/F9 → paramètres des extensions → bibliothèques → fournisseur → Authenticate. Pour Epic direct, choisissez **Legendary (Epic Games)**. Effectuez vous-même l’authentification et actualisez avec F5. N’envoyez aucun mot de passe ou code au mainteneur.

Installez Moonlight depuis la boutique du Shield/TV. Sur le PC, ouvrez [Sunshine](https://localhost:47990), créez son compte local à la première utilisation et saisissez le PIN affiché par Moonlight. Ajoutez l’IPv4 du PC manuellement si la détection échoue. Choisissez **Oyun Kütüphanesi - Playnite** pour la bibliothèque ou **Masaüstü - Desktop** pour le bureau.

Commencez en 1080p60 / 20 Mbit/s, puis augmentez selon le réseau. Sur Shield, la 4K reste limitée à 60 Hz, même avec une dalle TV à fréquence supérieure. Activez **Optimize game settings** dans Moonlight pour le changement automatique d’écran. ADB n’est pas nécessaire pour le streaming normal.

## Utilisation quotidienne

- Réglages ultérieurs : Démarrer → Oyun Merkezi → **Oyun Merkezi Ayarları**.
- Confirmation d’une boutique : maintenez Start sur la manette pour activer le mode souris ; stick pour déplacer, A clic gauche, B clic droit. Le bouton Steam peut nécessiter un redémarrage de Steam avec `-cef-force-accessibility`. EA/Ubisoft/Xbox et certains jeux demandent leur propre interface.
- Historique : dossier utilisateur Fritchii/Lichii contenant un `play_time\playtime.bin` compatible, ou journaux `.lrtl` de RetroArch. Un journal absent ne permet pas de reconstruire les anciennes durées. Pour les fichiers hors NUP, un identifiant correct de 16 caractères hexadécimaux ou une correspondance explicite peut être nécessaire.
- Jaquette locale : `Jeu.cover.jpg` ou `Jeu.cover.png` à côté de `Jeu.xci`. Les icônes NUP disponibles et les métadonnées Playnite complètent les autres cas.

## En cas de problème

Écran noir ou moniteur physique désactivé : terminez le streaming puis utilisez **Ctrl+Alt+F11**, ou Démarrer → Oyun Merkezi → **Ekranı Geri Getir**. Win+P et les paramètres d’affichage Windows sont des solutions de secours.

Un mode Hz absent nécessite de vérifier la sortie du client, le câble, le décodage et les FPS Moonlight ; redémarrez après l’ajout d’un mode VDD si demandé. Si ADB indique unauthorized, validez la demande sur le téléviseur ; vous pouvez aussi utiliser uniquement la boutique d’applications.

Les sauvegardes se trouvent dans `data/backups`. La restauration refuse d’écraser les fichiers modifiés depuis l’installation : inspectez et fusionnez-les manuellement. Le programme personnalisé n’est pas signé ; utilisez le ZIP officiel et ses sommes de contrôle, ou compilez les sources, sans désactiver les protections Windows.

Les jeux, ROM, BIOS, firmware, clés et sauvegardes ne sont pas fournis. Les profils FPS facultatifs exigent déjà un mod local compatible et ne garantissent pas de performances.

[Tests](../TESTING.md) · [Crédits](../CREDITS.md) · [Manuel turc complet](../../README.html)
