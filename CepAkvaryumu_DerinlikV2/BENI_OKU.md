# Cep Akvaryumu — Derinlik V2 (Godot 4, Galaxy Watch 8: 480×480 / 438×438)

Bu proje, eski birinci aşamadan **ayrı** bir projedir; mevcut projenin üzerine yazmaz. Samsung Galaxy Watch 8'de henüz test edilmemiştir. **Balık artık gerçek, rig'li (iskeletli) 3B modeldir** (`modeller/betta_splendens.glb`, ~10.700 üçgen, 53 kemik): küçük bir 3B görüntü alanında (`Balik3D`, profile göre 128–224 px) çizilir ve 2B akvaryumun içine yerleştirilir. Akvaryum dekoru 2B katmandır; balık bağımsız bir X/Y/Z konumuyla ölçeklenir ve objelerin altına / üstüne çizilerek **önde / arkada yüzme** etkisi verir.

## Nasıl açılır?

1. ZIP'i bir klasöre çıkar.
2. Godot 4.3 veya daha yeni sürümde **Import** > `project.godot` dosyasını seç > aç.
3. Sağ üstte çalıştır (▶). 480×480 önizlemede akvaryum görünür.
4. Kısa tık/dokunuş: yem. Balık yeme gider, tokluk +22 artar.
5. Ekranda 1 saniye basılı tut: ışığı aç/kapat. Kapatınca balık durur.
6. Bilgisayardayken `Z` balığı kayanın arkasına yollar, `X` ön cama getirir. Sonra rastgele 3B hedeflerde yüzmeye devam eder.
7. 60 piksel kaydırma henüz bir eylem yapmaz; cam temizliği sonraya bırakıldı.

## Sahne ve kod

```text
Akvaryum (Node2D) - betikler/akvaryum.gd
  ArkaPlan (Sprite2D)
  Baloncuklar (Node2D) - betikler/baloncuklar.gd
  Balik3D (SubViewport) - betikler/balik_3d.gd  → rig'li 3B betta, kamera, ışık, animasyon
  Balik (Sprite2D, Balik3D'nin görüntüsünü gösterir)
  Yem (Node2D) - betikler/yem.gd
  Tas (Sprite2D, z_index=2)
  Kutuk (Sprite2D, z_index=4)
  Yapraklar (Sprite2D, z_index=5)
  YuvarlakMaske (Sprite2D, z_index=40)
  Gosterge (Node2D) - betikler/gosterge.gd
```

### Z ekseni nasıl çalışıyor?

- `balik_konumu: Vector3(x, y, z)`. 0.07 ön cam, 0.97 arka bölge.
- `z > 0.64` ise balık kaya, kütük ve yaprakların **arkasında** (`z_index = 0`).
- `0.33 < z <= 0.64` ise kaya önünde, kütük ve yaprakların **arkasında** (`z_index = 3`).
- `z <= 0.33` ise tüm dekorların **önünde** (`z_index = 7`).
- Uzaklaştıkça ölçek 0.66 → 0.43, hafif mavimsi renk ve konum düzeltmesi uygulanır.
- Balık önce burnunu hedefe çevirir (dönüş hızı sınırlı: normalde 2,4, yeme giderken 3,6 rad/sn), sonra baktığı yöne yüzer. Ters yöndeki hedefe ayna gibi anında dönmez: kameraya ya da arkaya bakarak 3B **U dönüşü** yapar. Hedefe bakmıyorsa yavaşlar, yerinde döner.
- Derinlik (z: 0–1) yön hesabında `DERINLIK_PIKSEL` = 260 piksel sayılır; böylece balık öne / arkaya da yüzer ve o sırada kameraya dönük görünür.
- Yukarı / aşağı eğilir (en fazla `MAKS_EGIM`), dönerken yana yatar ve gövdesi dönüş yönüne bükülür.
- Modelin kendi yüzgeç animasyonu (`Take 01`) döngüde oynar. Hızı yüzme hızına bağlıdır: yeme giderken ~2,6 kat hızlı, ışık kapalıyken (uyurken) yavaş.
- Dönerken omurga kemikleri (`Bone.002`–`Bone.005`) kodla ek olarak bükülür: gövde dönüş yönüne C şeklinde kıvrılır.
- Yarı saydam yüzgeçler için `Balik` Sprite2D'si "premultiplied alpha" karışımı kullanır (kenarlarda koyu çizgi olmasın diye).
- Modeli değiştirirsen `balik_3d.gd` içindeki `OLCEK` (boyut), `MERKEZ` (dönme noktası) ve `OMURGA` (kemik adları) ayarlanmalı.
- Önceki dokulu ama iskeletsiz model `../modeller/beta3d.glb` olarak projenin dışında saklanıyor.
- Eski 16 yönlü 2B görsel (`gorseller/betta_yonler.png`) artık kullanılmıyor.

### Dokunma ve çerçeve

| Hareket | Sonuç |
|---|---|
| Kısa dokunuş (18 px'ten az kayma, 1 sn'den kısa) | Yem (balık çok tokken yemez, yem dibe çöker) |
| 1 sn basılı tutma (parmak kaymadan) | Işık aç / kapat (kapalıyken balık bitkilerin yanında uyur) |
| 60 px'ten uzun kaydırma | Camı siler: parmağın geçtiği yerdeki yosun canlı olarak silinir |
| Kenar halkasında (merkezden ≥165 px) **tam tur** dairesel kaydırma | Su değişimi (ilerleme kenarda mavi halka olarak görünür) |
| Galaxy Watch çerçevesini 4 sn içinde **12 tık** çevirmek | Su değişimi |
| 18–60 px arası kayma | Bilinçli olarak hiçbir şey |

- Dairesel kaydırma cam temizleme sayılmaz; basılı tutarken parmak kayarsa ışık değişmez.
- Geri tuşu sistem davranışını korur (önce kaydeder, sonra uygulama kapanır). Home tuşuna dokunulmaz.
- Dokunma alanı merkezden 236 px'e kadar (neredeyse tüm ekran).

### Bakım: yosun, su, mutluluk (`betikler/bakim.gd`)

Hepsi gerçek zamanla ilerler, uygulama kapalıyken de hesaplanır.

| | Nasıl kötüleşir | Nasıl düzelir | Nerede görünür |
|---|---|---|---|
| **Tokluk** | 3 saatte 100 → 0 | Yem | Sol yay (turuncu) |
| **Su kalitesi** | 48 saatte 100 → 0; dipteki her yem tanesi saatte +6 puan kirletir | Su değişimi (tam tur / 12 tık) | Sağ yay (mavi → sarı-yeşil), suyun rengi bulanıklaşır |
| **Cam yosunu** | 12 leke, her biri 8–20 saatte dolar; kirli suda 1,7 kat hızlı | Kaydırarak silme (her geçiş −%55) | Camda yeşil lekeler (en önde) |
| **Mutluluk** | %40 tokluk + %35 su + %25 cam; çok açken en fazla 30 | Üçüne bakmak (hedefe ~30 dk'da yaklaşır) | Balığın davranışı (gösterge yok) |

- **Tok balık** (tokluk ≥95) yemi yemez; yem dibe çöker, 3 saatte çözünür ve o sürede suyu kirletir. Su değişimi dipteki yemi de alır.
- **Mutlu balık** (≥75) yüzeyde (sağ üst) **köpük yuvası** yapar (6 saatte tamamlanır) ve arada yuvasına uğrar. Mutluluk 50'nin altına düşerse yuva 3 saatte söner.
- **Mutsuz balık** yavaş yüzer (%60'a kadar), solgun görünür, 35'in altında dibe yakın durur.
- **Kirli cam tamamen temizlenince** balık cama gelip 3 saniye sana bakar (kendi yansımasını görür).
- Işık kapanınca suda kalan yem dibe çöker.
- Bilgisayarda test: `T` tuşu zamanı 1 saat ileri sarar.

### Sensörler (yalnızca Android, yalnızca ışık açık ve uygulama ön plandayken)

- Saniyede ~10 okuma. Godot, uygulama arka plana geçince sensörleri kendisi kapatır.
- **İvmeölçer:** yürürken yüzme hızı yavaşça artar. Irkilme için tek bir bilek hareketi yetmez: arka arkaya 3 ölçümde (~0,3 sn) güçlü sarsıntı (`5.8` m/s² üstü) gerekir, sonrasında 10 sn bekleme. Ön plana dönüşte sensör yeniden kalibre edilir.
- **Jiroskop:** bilek dönüşü (`x` ekseni) 0,4 rad/sn eşiğinin üstündeyse suya hafif akıntı verir: kabarcıklar yana kayar, balık birkaç piksel sürüklenir. Yön, hedef ve mekanik değişmez. Gerçek saatte eksen yönü farklı çıkarsa `akvaryum.gd` → `_sensoru_kontrol_et` içindeki `jiroskop_suzgec.x` değiştirilmeli.
- **Titreşim:** balık yemi yediğinde 60 ms kısa titreşim (`VIBRATE` izni).
- Not: Godot 4.3'te `input_devices/sensors/enable_*` diye bir ayar yok; eski projedeki bu satır etkisizdi ve kaldırıldı.

### Tokluk ve kayıt

- Açlık olarak isimlendirilen `aclik` değişkeni tokluktur: 100 tam tok, 0 aç. Her 3 saatte 100 puan eksilir.
- `user://akvaryum_kaydi.json` dosyasında tokluk, zaman, ışık ve balığın X/Y/Z konumu tutulur.
- Her 15 saniyede, yem yendiğinde, ışık değiştiğinde, ekran kapandığında / uygulama arka plana geçtiğinde ve geri tuşunda kaydeder.
- Yeniden açılınca geçen gerçek süre tokluğa yansıtılır (1 saat kapalı kaldıysa ~33 puan düşer).

## Galaxy Watch 8 uyarlaması

### Ekran

- Tasarım çözünürlüğü 480×480 (44 mm). `canvas_items` + `keep` ölçekleme ile 438×438'de (40 mm) her şey 0,9125 oranında küçülür; kare ekran olduğu için siyah şerit oluşmaz.
- `yuvarlak_maske.png` tam 240 px yarıçaplı: saatte siyah halka bırakmaz, sadece bilgisayardaki kare önizlemede köşeleri kapatır.
- Göstergeler kenardan en az ~19 px içeride (güvenli bölge). Gece karartması tüm daireyi kaplar.
- Ekran dikey kilitli, cihaz hareketiyle dönmez. `keep_screen_on = false`: saat kendi zaman aşımıyla kararabilir.

### Grafik profilleri (`betikler/ayarlar.gd`, autoload `Ayarlar`)

| | Düşük | **Dengeli (varsayılan)** | Yüksek |
|---|---|---|---|
| FPS (ışık açık) | 24 | 30 | 30 |
| 3B balık dahili çözünürlüğü | 128 px | 160 px | 224 px |
| 3B kenar yumuşatma (MSAA) | yok | 2x | 4x |
| Pul kabartması (normal harita) + AO dokusu | kapalı | açık | açık |
| Kabarcık sayısı | 6 | 9 | 11 |

- Işık kapalıyken 6 FPS, uygulama arka plandayken 5 FPS ve 3B çizim tamamen durur.
- Profil `user://ayarlar.cfg` içinde saklanır. Şimdilik değiştirme arayüzü yok (dairesel menü gelince bağlanacak); bilgisayarda `1` / `2` / `3` tuşları.
- Gerçek zamanlı gölge yok. Su ışık huzmeleri ve caustics arka plan görselinin içinde (ayrı shader yok, ek maliyet yok).
- Balık modeli `araclar/glb_optimize.py` ile hafifletildi: 3 doku 2048 → 512 px, kullanılmayan UV kanalları atıldı (9,2 MB → 1,4 MB). Orijinali: `../modeller/betta_splendens_orijinal.glb`.
- Model dokuları Android için ETC2/ASTC ile sıkıştırılır (`import_etc2_astc = true`).

### Android / Wear OS export

`export_presets.cfg` → **"Galaxy Watch (Android)"**:

- Gradle'sız export (Godot'un hazır şablonu), yalnızca `arm64-v8a`.
- Paket: `com.tuni.cepakvaryumu`, saat menüsündeki ad: **Cep Akvaryumu**, sürüm 1.0 (kod 1).
- Simge: `simge.png` (192) + uyarlanabilir simge `android_simge/on.png` / `arka.png` (432).
- İzin: yalnızca `VIBRATE`. İnternet, depolama vb. istenmez. Tam ekran (immersive).
- Kullanılmayan `gorseller/betta_yonler.png` ve `android_arac/` APK'ya girmez.

Godot 4.3 Gradle'sız export manifest'e saat tanımı ekleyemez. Bu yüzden `android_arac/wear_uyarla.py` APK'yı açıp şunları ekler, sonra hizalar ve imzalar:

- `<uses-feature android:name="android.hardware.type.watch"/>`
- `<meta-data android:name="com.google.android.wearable.standalone" android:value="true"/>` (telefon uygulaması gerekmez)
- `minSdkVersion 30` (Wear OS 3+; Watch 8 = Wear OS 6). `targetSdkVersion 34` (Godot 4.3 şablonu).
- Dikey ekran özelliği "zorunlu değil" olarak işaretlenir.
- Godot'un izin satırlarındaki namespace hatası düzeltilir (yoksa titreşim izni kaybolur).

### APK oluşturma

Gerekenler (bilgisayar, Linux/macOS): Godot 4.3 + **Android export şablonları**, JDK 17, Android SDK (build-tools: `apksigner`, `zipalign`), `apktool` ve `aapt2`.
Ubuntu/Debian: `sudo apt install openjdk-17-jdk-headless apktool aapt zipalign apksigner`

1. Godot'ta **Editor > Editor Settings > Export > Android**: Java SDK yolu, Android SDK yolu ve debug keystore tanımla.
2. Terminalde: `GODOT=/yol/Godot_v4.3-stable_linux.x86_64 ./android_arac/apk_olustur.sh`
3. Çıktı: `../build/CepAkvaryumu_saat.apk` (debug imzalı, ~27 MB).

Wear OS eklemelerini istemezsen Godot'ta **Project > Export > Galaxy Watch (Android) > Export Project** de olur: o APK da saate yüklenir, sadece "saat uygulaması" ve "standalone" olarak işaretlenmez.

### Telefondan (S25 FE + Termux) saate kablosuz yükleme

**Saatte (bir kez):**
1. **Ayarlar > Saat hakkında > Yazılım bilgisi > Yazılım sürümü**'ne 7 kez dokun → Geliştirici seçenekleri açılır.
2. **Ayarlar > Geliştirici seçenekleri**: **ADB hata ayıklama**'yı ve **Kablosuz hata ayıklama**'yı aç.
3. Saat ve telefon **aynı Wi-Fi ağında** olmalı (saatte Wi-Fi açık; yalnızca Bluetooth yetmez).

**Telefonda, Termux:**
```sh
pkg update
pkg install android-tools
termux-setup-storage          # APK'yı İndirilenler'den okuyabilmek için
```

**Eşleştirme (bir kez):** saatte *Kablosuz hata ayıklama > Yeni cihaz eşleştir*. Ekranda bir **IP:port** ve **6 haneli kod** çıkar. Bu, *eşleştirme portu*dur.
```sh
adb pair SAATIN_IP:ESLESTIRME_PORTU
# Sorulunca saatte görünen 6 haneli kodu yaz
```

**Bağlanma:** Kablosuz hata ayıklama ana ekranındaki **IP adresi ve port**u kullan. Bu, *bağlantı portu*dur ve eşleştirme portundan **farklıdır**.
```sh
adb connect SAATIN_IP:BAGLANTI_PORTU
adb devices                   # saat "device" olarak görünmeli
adb install -r ~/storage/downloads/CepAkvaryumu_saat.apk
```

- IP ve portları saatin ekranından oku; her kablosuz hata ayıklama açılışında port değişebilir.
- `-r`: güncellerken kayıtlı veriyi korur.
- `adb devices` "unauthorized" gösterirse saatte çıkan izin penceresini onayla.
- Uygulama saatin uygulama listesinde **Cep Akvaryumu** adıyla, balık simgesiyle görünür.

### Test durumu

| # | Test | Durum |
|---|---|---|
| 1 | Ekranı doldurma (480 ve 438) | ✅ Bilgisayarda: daire içinde siyah piksel 0, 438'de 0,9125 ölçek. ❓ Saatte görülmedi. |
| 2 | Balık gerçekten 3B mi | ✅ Bilgisayarda (rig, U dönüşü, gövde bükülmesi). ❓ Saatte görülmedi. |
| 3 | FPS kararlı mı | ❓ **Test edilmedi.** Saatte ölçülmeli; düşükse "Düşük" profil. |
| 4 | Işık / su görünümü | ✅ Bilgisayarda (OpenGL / Compatibility). ❓ Saatin GPU'sunda görülmedi. |
| 5 | Dokunma hareketleri | ✅ Bilgisayarda benzetilmiş dokunma olaylarıyla 8 senaryo. ❓ Gerçek parmakla denenmedi. |
| 6 | İvmeölçer / jiroskop veri veriyor mu | ❓ **Test edilmedi** (bilgisayarda sensör yok). |
| 7 | Çıkıp girince kayıt | ✅ Bilgisayarda: kayıt yazılıyor, yükleniyor, geçen süre tokluğa yansıyor. |
| 8 | Sistem tuşları / ekran kapanması | ✅ Arka plan bildirimleriyle: 3B duruyor, 5 FPS, kayıt. ❓ Gerçek tuş ve ekran kapanması denenmedi. |
| 9 | APK saatte açılıyor mu | ❓ **Test edilmedi.** APK üretildi, imza ve manifest doğrulandı; saate yüklenmedi. |

## Yapılmayanlar (sonraki aşama)

- Fizik çarpışmaları, tünelden gerçek geçiş
- Ek animasyonlar (kabarma/flare, yaprakta uyuma, kapalı yüzgeç, yem kapma) — kemikler hazır, kodla eklenebilir
- Watch 8'de 3B balığın pil / ısınma testi (gerekirse `Balik3D` boyutu 160'a, MSAA kapalıya düşürülebilir)
- Su temizliği, mutluluk, cam silme, para, yeni balık, satın alma, büyüme
- Akvaryumun sürekli açık saat kadranı/arka plan hizmeti olarak çalışması
- Menü ve grafik profili seçme ekranı (`menu_adimi` sinyali hazır)
- Kabarma (flare), iskeletle kapalı yüzgeç ve yaprakta uzanma animasyonları
- Wear OS "ambient" (her zaman açık ekran) modu: ekran kararınca oyun durur, bilinçli olarak
- Google Play yayını için release imzası (şu an debug imzalı)

## Notlar

- Görsel arka plan ve kaya/kütük katmanları, bu sohbet kapsamında üretilmiş akvaryum görsellerinden hazırlandı.
- Betta grafiği, senin balık paketin (`3D_fish_pack.zip`, CC0) içindeki `07_betta.gif` önizlemesinden hazırlandı. Paket içindeki tüm 3B modeller projeye alınmadı.
