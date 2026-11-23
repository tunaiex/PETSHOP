# Cep Akvaryumu — Derinlik V2 (Godot 4, 480×480)

Bu proje, eski birinci aşamadan **ayrı** bir projedir; mevcut projenin üzerine yazmaz. Samsung Galaxy Watch 8'de henüz test edilmemiştir. **Balık artık gerçek, rig'li (iskeletli) 3B modeldir** (`modeller/betta_splendens.glb`, ~10.700 üçgen, 53 kemik): küçük bir 3B görüntü alanında (`Balik3D`, 192×192) çizilir ve 2B akvaryumun içine yerleştirilir. Akvaryum dekoru 2B katmandır; balık bağımsız bir X/Y/Z konumuyla ölçeklenir ve objelerin altına / üstüne çizilerek **önde / arkada yüzme** etkisi verir.

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

### Hareket algılama

- Yalnızca oyun açık ve ışık yanarken, Android'de ivmeölçeri saniyede yaklaşık beş kez okur.
- Yürüyüşte yüzme hızı biraz artar; ani sarsıntıda balık kaya arkasına saklanır, sonra normale döner.
- Gerçek saat hareket sensörü davranışı henüz test edilmedi. Fazla hassassa `sarsinti > 5.8` eşiğini yükselt.
- Arka planda sürekli adım/sağlık takibi **yok**; pil tüketimini korumak için.

### Tokluk ve kayıt

- Açlık olarak isimlendirilen `aclik` değişkeni tokluktur: 100 tam tok, 0 aç. Her 3 saatte 100 puan eksilir.
- `user://akvaryum_kaydi.json` dosyasında tokluk, zaman, ışık ve balığın X/Y/Z konumu tutulur.
- Her 15 saniyede, yem yendiğinde, ışık değiştiğinde ve uygulama arka plana geçtiğinde kaydeder.
- Birinci aşamadan kalan aynı dosya varsa `aclik` / `isik_acik` / `zaman` alanlarını okuyarak eski kaydı taşır.

### Android / Wear OS

1. Godot **Project > Export > Add > Android**: Android export şablonlarını kur.
2. Godot proje render yöntemi: **Compatibility** (OpenGL ES 3).
3. `arm64-v8a` seç; uygulamaya özgü paket adı belirle, ör. `com.tuni.cepakvaryumu`.
4. Saatte uygulamanın nasıl görüneceğini görmek için öncelikle bir **Debug APK** üret.
5. S25 FE telefonuna Termux/`android-tools` kur ve aynı Wi-Fi'deki saat için kablosuz ADB aç.

```sh
pkg update
pkg install android-tools
termux-setup-storage
adb pair SAAT_IP:ESLESTIRME_PORTU
# Saattaki eşleştirme kodunu yaz
adb connect SAAT_IP:BAGLANTI_PORTU
adb devices
adb install -r /sdcard/Download/CepAkvaryumu_DerinlikV2.apk
```

Dikkat: Eşleştirme ve bağlantı portları farklıdır. APK'nın Termux tarafından erişilebilir yerde bulunması gerekir. Watch 8'de Godot Android dışa aktarma uyumluluğu cihaz üzerinde doğrulanmalıdır; bu ZIP bir APK değildir ve Google Play Wear OS yayınına hazır sayılmaz.

## Yapılmayanlar (sonraki aşama)

- Fizik çarpışmaları, tünelden gerçek geçiş
- Ek animasyonlar (kabarma/flare, yaprakta uyuma, kapalı yüzgeç, yem kapma) — kemikler hazır, kodla eklenebilir
- Watch 8'de 3B balığın pil / ısınma testi (gerekirse `Balik3D` boyutu 160'a, MSAA kapalıya düşürülebilir)
- Su temizliği, mutluluk, cam silme, para, yeni balık, satın alma, büyüme
- Akvaryumun sürekli açık saat kadranı/arka plan hizmeti olarak çalışması

## Notlar

- Görsel arka plan ve kaya/kütük katmanları, bu sohbet kapsamında üretilmiş akvaryum görsellerinden hazırlandı.
- Betta grafiği, senin balık paketin (`3D_fish_pack.zip`, CC0) içindeki `07_betta.gif` önizlemesinden hazırlandı. Paket içindeki tüm 3B modeller projeye alınmadı.
