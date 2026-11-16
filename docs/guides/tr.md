# Oyun Merkezi kurulum rehberi

[English](en.md) · [Türkçe](tr.md) · [Français](fr.md) · [Español](es.md) · [Proje](../../README.tr.md)

2.1.0 kurucusu İngilizce, Türkçe, Fransızca ve İspanyolca çalışır. Sol menüden **Türkçe** seç; dil kaydedilir ve çevrimdışı yardım aynı dilde açılır. Ayarları uygulayınca Playnite dili de Türkçe seçilir.

Tam Türkçe rehber paketteki **[README.html](../../README.html)** dosyasında bulunur ve çevrimdışı okunabilir.

1. [Sürümler](https://github.com/ozi-dev/game-center/releases/latest) sayfasından Windows x64 ZIP'i indir; tamamını çıkar ve `Kurulum.exe` aç.
2. **Başlangıç ve tanı:** var olan Playnite/Sunshine bulunur. Playnite yoksa alanı boş bırak; kurucu indirir.
3. **Kitaplıklar ve giriş:** mağazaları seç. Epic doğrudan indirmede Legendary kullanılır. Hesaplarını kendi giriş pencerelerinde bağlayacaksın.
4. **Emülatörler:** uygulama EXE'sini, ROM klasörünü, platform/uzantıları ve veri klasörünü seç. RetroArch'ta her sistem için uygun çekirdek DLL'sini göster. Veri klasörü kayıtların taşınacağı yer değildir; mevcut ayar/geçmiş klasörüdür.
5. **Yayın ve ekran:** giriş aygıtları, Moonlight kutuları, sanal ekran, fiziksel monitör sinyali ve geri dönüş davranışını seç. Shield için 4K60 ile başla. Bit hızı ve HDR'yi Moonlight'ta da ayarla.
6. **Kurulum ve bakım:** Playnite ve yayını kapat. **Kur / eksikleri tamamla** düğmesine bas; gerekirse yönetici onayı ve yeniden başlatmayı tamamla.
7. Playnite masaüstünde **Eklentiler (F9) → Uzantı Ayarları → Kütüphaneler** üzerinden hesaplarını bağla. Epic için **Legendary (Epic Games)** seç. F5 ile tümünü güncelle.
8. PC'de [Sunshine](https://localhost:47990) panelini aç. Shield/TV'deki Moonlight'ın PIN'ini buraya gir. Aynı ağda değilsen veya PC görünmüyorsa ağ/IPv4 adresini kontrol et.
9. Moonlight'ta **Oyun Kütüphanesi - Playnite** veya **Masaüstü - Desktop** kutusunu aç.

Sonraki ayarlar **Başlat → Oyun Merkezi → Oyun Merkezi Ayarları** içindedir. **Ayarları kaydet** sonrasında sistem değişiklikleri için **Ayarları uygula / onar** kullanılır.

## Bilmekte fayda var

- **ADB isteğe bağlıdır.** Normal yayın Play Store'dan kurulu Moonlight ile çalışır; cihaz tanısı veya APK kurulumu için açılırsa TV'deki izni onaylaman gerekir.
- **Shield 4K60:** TV panelinin yüksek Hz değeri Shield'ın 4K çıkış sınırını aşmaz. Yeni VDD modunda yeniden başlatma gerekebilir.
- **TV'den onay:** kumandada Start'a uzun basınca fare modu açılır; analog imleci, A sol ve B sağ tıklamayı kontrol eder. Steam yardımcısı için gerekirse Steam'i `-cef-force-accessibility` ile yeniden aç.
- **Süreler:** Fritchii/Lichii veri klasöründeki uyumlu `play_time\playtime.bin` ve RetroArch `.lrtl` günlükleri okunur. Kaydedilmemiş eski süreler sonradan çıkarılamaz. NUP dışındaki oyunlarda doğru 16 haneli başlık kimliği/eşleme gerekebilir.
- **Kapaklar:** NUP ikonu, ROM'un yanındaki `Oyun.cover.jpg` / `.png` veya Playnite metadata sağlayıcısı kullanılır.
- **Ekran dönmezse:** yayını bitir, **Ctrl+Alt+F11** veya Başlat menüsündeki **Ekranı Geri Getir** kullan. Gerekirse Win+P ve Windows Ekran Ayarları'ndan fiziksel ekranı aç.
- **Yedekler:** kurulu klasörde `data/backups` içinde. Geri alma, sonradan değiştirilmiş dosyaların üzerine otomatik yazmaz.
- **Hesaplar ve dosyalar:** hesap girişi/PIN kullanıcıya aittir. Paket oyun, firmware, BIOS, anahtar ve kişisel kayıt içermez. EA/Ubisoft/Xbox ve bazı üçüncü taraf oyunların kurulum akışı ek onay isteyebilir.

[Gereksinimler ve ayrıntılı sorun çözme](../../README.html) · [Test kapsamı](../TESTING.md) · [Emeği geçenler](../CREDITS.md)
