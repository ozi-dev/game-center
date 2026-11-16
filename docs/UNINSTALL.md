# Remove SofaRelay integration

Stop the Moonlight stream and close Playnite. Open **SofaRelay Settings → Help → Remove SofaRelay integration**. The default preserves Sunshine, Playnite and shared drivers.

The operation removes the installation's recovery task and owned LAN firewall rules, restores recorded firewall scopes and trusted configuration backups, removes the companion extensions and owned Start menu shortcuts. Restore preflights changed files/rules and stops on conflicts. Review the reported manual steps; do not force a conflicting backup over newer settings.

**Remove components installed by SofaRelay** is optional. Only an administrator-protected ownership record created by this version authorizes removal. Existing or unverified components stay installed. Sunshine's product identity/version and the VDD device hardware identity are checked. ViGEm removal requires its recorded product identity and verified pinned uninstaller. Components updated outside SofaRelay may need manual removal.

## Files deliberately retained

- Games, ROMs, firmware, keys, saves, accounts, Playnite libraries and playtime data.
- The VDD driver-store package and `C:\VirtualDisplayDriver` files: another virtual display may use them. The optional removal detaches only the exact recorded `Root\MttVDD` device. Inspect Device Manager before removing its driver package. Do not delete an arbitrary `oem*.inf`.
- Portable application files, backup journals and the protected broker/state used to review or retry recovery. Close SofaRelay before deleting its portable folder. Keep backups until recovery is no longer needed. An administrator may remove `%ProgramFiles%\SofaRelay` and the corresponding `%ProgramData%\SofaRelay` state **only after checking that no other SofaRelay installation uses them**.

No general recursive deletion of shared applications or system folders is performed. Windows Installed apps and Device Manager handle remaining shared components when their owner decides they are no longer needed. Restart if Windows requests it.

## Upgrades from 2.2 and earlier

Old user-editable `installed-driver.json` and backup journals are **not proof of privileged ownership**. Their arbitrary paths are never copied by the elevated broker. Legacy protected backups require manual review against the actual Sunshine/VDD files; diagnostics/uninstall cannot safely infer who installed a shared driver. User-level Playnite configuration backups are restored separately without elevation through **Restore**.

If a component directory is owned/writable by a normal user, the new broker refuses privileged configuration. Reinstall that shared component with its official installer or have an administrator review its permissions; do not run SofaRelay's entire GUI as administrator to bypass this boundary.

Türkçe: Akışı durdurun, Playnite'ı kapatın; Yardım bölümündeki entegrasyonu kaldır düğmesini kullanın. Paylaşılan bileşenler ve oyun verileri korunur. Eski sürümlerin sürücü kayıtları otomatik kaldırma yetkisi vermez. Sürücü deposu ve korumalı yardımcı dosyaları, başka kurulumlar kullanabileceği için elle incelenir.

Français : Arrêtez le streaming, fermez Playnite puis utilisez la suppression de l'intégration dans l'aide. Les composants partagés et les jeux sont conservés. Les anciens journaux ne prouvent pas la propriété d'un pilote. Vérifiez manuellement le magasin de pilotes et les fichiers protégés partagés.

Español: Detén la transmisión, cierra Playnite y elimina la integración desde Ayuda. Se conservan componentes compartidos y juegos. Los registros antiguos no demuestran la propiedad de un controlador. Revisa manualmente el almacén de controladores y los archivos protegidos compartidos.
