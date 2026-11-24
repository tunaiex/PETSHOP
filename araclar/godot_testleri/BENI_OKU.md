# Otomatik testler (Godot 4.3, bilgisayarda)

Dokunma jestleri, bakım, menü / mağaza / ilerleme, yaşam döngüsü (Tamagotchi) ve
kostik davranışını benzetilmiş girdilerle sınar. Gerçek saat sensörlerini, sesi ve
saatteki performansı **sınamaz**.

Çalıştırmak için dosyaları projede `arac/` klasörüne kopyala (proje kökünde):

```sh
mkdir -p CepAkvaryumu_DerinlikV2/arac && cp araclar/godot_testleri/*.gd CepAkvaryumu_DerinlikV2/arac/
cd CepAkvaryumu_DerinlikV2
godot --headless --import
for t in testler bakim_test yeni_test yasam_test gece_kostik; do
  godot --rendering-driver opengl3 --resolution 480x480 --fixed-fps 30 --script res://arac/$t.gd | grep -E "GECTI|KALDI|kostik|Dusuk"
done
```
Her satır `GECTI` (geçti) ya da `KALDI` (kaldı) ile başlar. Testler `user://` kaydını siler; kendi oyun kaydının olduğu makinede çalıştırma.
