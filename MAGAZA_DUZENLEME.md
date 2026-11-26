# Mağazayı Godot'da düzenleme

Mağaza `scenes/magaza.tscn` sahnesinde. Godot'da **FileSystem** panelinden bu dosyaya çift tıkla.

## Sahnedeki düğümler

| Düğüm | Ne işe yarar |
|---|---|
| `Bina/Zemin`, `Tavan`, `Cati`, `Duvarlar`, `Vitrin` | Binanın parçaları (1,20 m'lik ızgara). Taşı, sil, kopyala (Ctrl+D). |
| `Bina/DisMekan` | Kaldırım, otopark, araba, lambalar, ağaçlar. |
| `Bina/Susler`, `Bina/Depo` | Poster, saat, kamera, ayna, bitki; depo rafları, dolaplar. |
| `Isiklar` | İç ışıklar. Adı **"Sokak"** ile başlayan ışıklar sadece gece yanar. |
| `Esyalar` | **Hazır gelen raf, dolap ve kasa.** Her birinin Inspector'da **Tip** seçimi var. Yeni oyunda burada **boş** olarak kurulurlar. |
| `SatisAlani` | Eşya konabilen ve müşterilerin dolaştığı yeşil alan. Duvarları taşırsan **Boyut**'unu da uydur. |
| `Kapi`, `Giris`, `Disari` | Otomatik kapının yeri, müşterilerin girdiği ve geldiği noktalar. |
| `OyuncuBaslangic`, `KopekBaslangic`, `KoliAlani`, `DijitalSaat` | Oyuncu ve köpeğin başladığı yer, kargoların bırakıldığı yer, kırmızı dijital saat. |

## Sık yapılanlar

- **Yeni parça eklemek:** `assets/modeller/magaza/bina/` ya da `assets/modeller/magaza/esya/` klasöründen bir `.glb` dosyasını sahneye sürükle. Duvar, vitrin ve kolon parçaları otomatik olarak geçilmez olur. Diğer büyük eşyalar kutu çarpışması alır. Zemin, tavan ve posterlere çarpışma verilmez.
- **Hazır bir raf eklemek:** `Esyalar` altındaki bir eşyayı seç, Ctrl+D ile çoğalt, taşı, Inspector'dan **Tip**'ini değiştir. Sadece Y ekseninde döndür.
- **Bir rafı kaldırmak:** `Esyalar` altından sil.
- **Dükkânı büyütmek ya da küçültmek:** duvar ve vitrin parçalarını taşı, zemin/tavan karolarını ekle ya da sil. Sonra `SatisAlani`'nın konumunu ve **Boyut**'unu yeni iç alana göre ayarla.
- **Kapıyı taşımak:** `shopfront_entrance_240` parçasını taşı, `Kapi`, `Giris` ve `Disari` işaretlerini de yanına götür.

## Dikkat

- `Esyalar` düğümünün kendisini taşıma ya da döndürme; içindeki eşyaları tek tek düzenle.
- Değişiklikler **yeni oyunda** görünür. Kayıtlı oyun eski yerleşimle devam eder; ana menüden **Yeni oyun** başlat.
- `tools/magaza_olustur.gd` aracını çalıştırma: sahneyi sıfırdan üretir ve senin düzenlemelerinin üzerine yazar.
