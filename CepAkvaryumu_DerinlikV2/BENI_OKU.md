# Cep Akvaryumu — Derinlik V2 (Godot 4, 480×480)

Bu proje, eski birinci aşamadan **ayrı** bir projedir; mevcut projenin üzerine yazmaz. Samsung Galaxy Watch 8'de henüz test edilmemiştir. 2,5D kullanır: balık gerçek anlamda 3B bir akvaryum mesh'i içinde yüzmez, ama bağımsız bir X/Y/Z konumuyla ölçeklenir ve objelerin altına / üstüne çizilerek **önde / arkada yüzme** etkisi verir.

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
  Balik (Sprite2D, 4×4 16 yönlü betta görseli)
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
- Betta görselleri, gönderilen `3D_fish_pack.zip` içindeki `07_betta.gif` 3B dönüş önizlemesinden 16 farklı açı alınarak oluşturuldu. **Kuyruk ve yüzgeç rig animasyonu henüz yok.** Saat için hafif; 50.000 üçgenlik GLB'yi gerçek zamanlı çizdirmiyoruz.

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

- Gerçek 3D GLB mesh'i ve fizik çarpışmaları, tünelden gerçek geçiş, yüzgeç rig animasyonu
- Su temizliği, mutluluk, cam silme, para, yeni balık, satın alma, büyüme
- Akvaryumun sürekli açık saat kadranı/arka plan hizmeti olarak çalışması

## Notlar

- Görsel arka plan ve kaya/kütük katmanları, bu sohbet kapsamında üretilmiş akvaryum görsellerinden hazırlandı.
- Betta grafiği, senin balık paketin (`3D_fish_pack.zip`, CC0) içindeki `07_betta.gif` önizlemesinden hazırlandı. Paket içindeki tüm 3B modeller projeye alınmadı.
