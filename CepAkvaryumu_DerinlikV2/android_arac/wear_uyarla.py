#!/usr/bin/env python3
"""Godot'un urettigi APK'yi Wear OS (Galaxy Watch 8) icin uyarlar.

Godot 4.3 Gradle'siz export manifest'e saat tanimlari ekleyemez; bu betik
apktool ile ekler, sonra zipalign + apksigner ile yeniden imzalar.

Eklenenler:
  <uses-feature android:name="android.hardware.type.watch" />
  <meta-data android:name="com.google.android.wearable.standalone" android:value="true" />
  <uses-feature android:name="android.hardware.screen.portrait" android:required="false" />
  minSdkVersion 30 (Wear OS 3 ve sonrasi; Watch 8 = Wear OS 6)

Gerekenler: apktool, aapt2, zipalign, apksigner, keytool (JDK 17).
Ubuntu/Debian: sudo apt install apktool aapt zipalign apksigner openjdk-17-jdk-headless
Kullanim:
  python3 wear_uyarla.py GIRDI.apk CIKTI.apk [--keystore yol] [--ks-pass sifre] [--alias ad]
Keystore verilmezse ~/.android/debug.keystore kullanilir (yoksa olusturulur).
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile

MIN_SDK = 30


def calistir(*komut):
    print("+", " ".join(komut))
    subprocess.run(komut, check=True)


def manifest_duzenle(yol):
    m = open(yol, encoding="utf-8").read()
    # Godot izinleri (uses-permission) "android" adli bir namespace ile yazar;
    # apktool bunu xmlns:n1="android" olarak cozer ve yeniden paketlerken izin
    # kaybolur (titresim calismaz). Standart android: onekine cevir.
    def duzelt(es):
        etiket = es.group(0)
        for onek in re.findall(r'xmlns:(\w+)="android"', etiket):
            etiket = etiket.replace(f' xmlns:{onek}="android"', "").replace(f"{onek}:", "android:")
        return etiket
    m = re.sub(r"<[^>]*xmlns:\w+=\"android\"[^>]*>", duzelt, m)
    if "android.hardware.type.watch" not in m:
        m = m.replace("<application", '<uses-feature android:name="android.hardware.type.watch"/>\n    <application', 1)
    if "android.hardware.screen.portrait" not in m:
        # Dikey kilit, "dikey ekran zorunlu" ozelligi ima eder; saatte filtrelenmesin.
        m = m.replace("<application", '<uses-feature android:name="android.hardware.screen.portrait" android:required="false"/>\n    <application', 1)
    if "com.google.android.wearable.standalone" not in m:
        m = re.sub(r"(<application[^>]*>)",
                   r'\1\n        <meta-data android:name="com.google.android.wearable.standalone" android:value="true"/>',
                   m, count=1)
    open(yol, "w", encoding="utf-8").write(m)


def sdk_duzenle(yol):
    y = open(yol, encoding="utf-8").read()
    y = re.sub(r"minSdkVersion: '?\d+'?", f"minSdkVersion: '{MIN_SDK}'", y)
    open(yol, "w", encoding="utf-8").write(y)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("girdi")
    ap.add_argument("cikti")
    ap.add_argument("--keystore", default=os.path.expanduser("~/.android/debug.keystore"))
    ap.add_argument("--ks-pass", default="android")
    ap.add_argument("--alias", default="androiddebugkey")
    a = ap.parse_args()

    if not os.path.exists(a.keystore):
        os.makedirs(os.path.dirname(a.keystore), exist_ok=True)
        calistir("keytool", "-genkeypair", "-v", "-keystore", a.keystore, "-storepass", a.ks_pass,
                 "-alias", a.alias, "-keypass", a.ks_pass, "-keyalg", "RSA", "-keysize", "2048",
                 "-validity", "10000", "-dname", "CN=Android Debug,O=Android,C=US")

    gecici = tempfile.mkdtemp(prefix="wear_apk_")
    try:
        acik = os.path.join(gecici, "acik")
        calistir("apktool", "d", "-f", "-o", acik, a.girdi)
        manifest_duzenle(os.path.join(acik, "AndroidManifest.xml"))
        sdk_duzenle(os.path.join(acik, "apktool.yml"))
        imzasiz = os.path.join(gecici, "imzasiz.apk")
        # Eski aapt (aapt1) Godot kaynaklarini derleyemiyor; aapt2 kullan.
        aapt2 = shutil.which("aapt2")
        if aapt2:
            calistir("apktool", "b", "--use-aapt2", "-a", aapt2, "-o", imzasiz, acik)
        else:
            calistir("apktool", "b", "--use-aapt2", "-o", imzasiz, acik)
        hizali = os.path.join(gecici, "hizali.apk")
        calistir("zipalign", "-p", "-f", "4", imzasiz, hizali)
        # v2 + v3 imza: Android 11+ (Wear OS 3+) ve Wear Installer gibi araclarla uyumlu
        calistir("apksigner", "sign", "--ks", a.keystore, "--ks-pass", "pass:" + a.ks_pass,
                 "--ks-key-alias", a.alias, "--key-pass", "pass:" + a.ks_pass,
                 "--v1-signing-enabled", "false", "--v2-signing-enabled", "true", "--v3-signing-enabled", "true",
                 "--out", a.cikti, hizali)
        calistir("apksigner", "verify", "--verbose", a.cikti)
    finally:
        shutil.rmtree(gecici, ignore_errors=True)
    print("Hazir:", a.cikti)


if __name__ == "__main__":
    sys.exit(main())
