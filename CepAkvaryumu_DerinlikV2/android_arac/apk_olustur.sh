#!/usr/bin/env bash
# Galaxy Watch 8 icin debug APK uretir (Linux / macOS).
# Gerekenler: Godot 4.3 (+ Android export sablonlari), JDK 17, apktool,
# zipalign, apksigner. Godot Editor Settings > Export > Android icinde
# Java SDK ve Android SDK yollari ile debug keystore tanimli olmali.
#
#   GODOT=/yol/Godot_v4.3-stable_linux.x86_64 ./android_arac/apk_olustur.sh
set -euo pipefail
PROJE="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
mkdir -p "$PROJE/../build"
cd "$PROJE"
"$GODOT" --headless --import
"$GODOT" --headless --export-debug "Galaxy Watch (Android)" "$PROJE/../build/CepAkvaryumu_ham.apk"
python3 "$PROJE/android_arac/wear_uyarla.py" \
    "$PROJE/../build/CepAkvaryumu_ham.apk" "$PROJE/../build/CepAkvaryumu_saat.apk"
echo "Saate yuklenecek dosya: $PROJE/../build/CepAkvaryumu_saat.apk"
