#!/usr/bin/env python3
"""Oyun seslerini kodla uretir (kayit / indirme yok). 22050 Hz, 16 bit, mono WAV.

Kullanim: python3 -I araclar/ses_uret.py CIKTI_DIZINI
"""
import sys
import wave

import numpy as np

HZ = 22050
rng = np.random.default_rng(42)


def kaydet(yol, x, tepe=0.8):
    x = np.asarray(x, dtype=np.float64)
    x = x / (np.max(np.abs(x)) + 1e-9) * tepe
    with wave.open(yol, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(HZ)
        w.writeframes((x * 32767).astype("<i2").tobytes())


def t(sure):
    return np.arange(int(sure * HZ)) / HZ


def alcak_gecir(x, kesim):
    # tek kutuplu alcak geciren (yumusak)
    a = np.exp(-2 * np.pi * kesim / HZ)
    y = np.empty_like(x); s = 0.0
    for i, v in enumerate(x):
        s = (1 - a) * v + a * s; y[i] = s
    return y


def kabarcik(tt, f0, f1, sure):
    # yukselen frekansli "blop": suda kabarcik sesi
    f = f0 + (f1 - f0) * (tt / sure) ** 0.5
    faz = 2 * np.pi * np.cumsum(f) / HZ
    return np.sin(faz) * np.exp(-tt / (sure * 0.35))


def ortam(yol):
    # 8 sn dongulu su ortami: derin ugultu + hafif akis + seyrek kabarciklar
    sure = 8.0; n = int(sure * HZ); tt = t(sure)
    kahve = np.cumsum(rng.normal(0, 1, n)); kahve -= np.linspace(kahve[0], kahve[-1], n)  # dongu icin uclari esitle
    kahve = alcak_gecir(kahve - kahve.mean(), 400)
    akis = alcak_gecir(rng.normal(0, 1, n), 1500) * (0.6 + 0.4 * np.sin(2 * np.pi * tt / sure * 2))
    x = kahve / (np.abs(kahve).max() + 1e-9) * 0.7 + akis / (np.abs(akis).max() + 1e-9) * 0.25
    for _ in range(14):
        b = rng.uniform(0.2, sure - 0.3); d = rng.uniform(0.04, 0.09)
        i = int(b * HZ); tb = t(d)
        x[i:i + len(tb)] += kabarcik(tb, rng.uniform(500, 800), rng.uniform(900, 1500), d) * rng.uniform(0.08, 0.2)
    # dongu dikisini yumusat
    k = int(0.25 * HZ); x[:k] *= np.linspace(0.6, 1, k); x[-k:] *= np.linspace(1, 0.6, k)
    kaydet(yol, x, 0.5)


def yem(yol):
    # suya dusen yem: kisa "plip" + minik sicrama
    tt = t(0.22)
    x = kabarcik(tt, 1400, 700, 0.22) * 0.8
    x += alcak_gecir(rng.normal(0, 1, len(tt)), 3000) * np.exp(-tt / 0.02) * 0.3
    kaydet(yol, x, 0.6)


def silme(yol):
    # camda parmak gicirtisi: titresimli yuksek ton
    tt = t(0.28)
    f = 1900 + 250 * np.sin(2 * np.pi * 38 * tt) + 300 * tt
    x = np.sin(2 * np.pi * np.cumsum(f) / HZ) * np.sin(np.pi * tt / 0.28) ** 1.5
    x += alcak_gecir(rng.normal(0, 1, len(tt)), 4000) * 0.15 * np.sin(np.pi * tt / 0.28)
    kaydet(yol, x, 0.35)


def su_degisimi(yol):
    # hortumla su: kabaran ve sonen akis + kabarciklar
    sure = 2.6; tt = t(sure); n = len(tt)
    zarf = np.sin(np.pi * tt / sure) ** 0.7
    x = alcak_gecir(rng.normal(0, 1, n), 1200) * zarf
    for _ in range(25):
        b = rng.uniform(0.1, sure - 0.2); d = rng.uniform(0.03, 0.08); i = int(b * HZ); tb = t(d)
        x[i:i + len(tb)] += kabarcik(tb, rng.uniform(400, 700), rng.uniform(800, 1400), d) * 0.4
    kaydet(yol, x, 0.6)


def inci(yol):
    # inci toplama: parlak iki notalik zil
    tt = t(0.55)
    x = (np.sin(2 * np.pi * 1318.5 * tt) * np.exp(-tt / 0.18)
         + 0.7 * np.sin(2 * np.pi * 1975.5 * tt) * np.exp(-np.clip(tt - 0.08, 0, None) / 0.2) * (tt > 0.08)
         + 0.2 * np.sin(2 * np.pi * 3951 * tt) * np.exp(-tt / 0.05))
    kaydet(yol, x, 0.5)


def tik(yol):
    # menu: yumusak, kisa tik
    tt = t(0.035)
    x = np.sin(2 * np.pi * 2200 * tt) * np.exp(-tt / 0.006)
    kaydet(yol, x, 0.4)


def kabarma(yol):
    # kabarma: kisa, yukselen "vuuup" su hareketi
    tt = t(0.35)
    x = alcak_gecir(rng.normal(0, 1, len(tt)), 900) * np.sin(np.pi * tt / 0.35)
    x += kabarcik(tt, 200, 500, 0.35) * 0.4
    kaydet(yol, x, 0.45)


if __name__ == "__main__":
    d = sys.argv[1].rstrip("/") + "/"
    ortam(d + "ortam.wav"); yem(d + "yem.wav"); silme(d + "silme.wav")
    su_degisimi(d + "su_degisimi.wav"); inci(d + "inci.wav"); tik(d + "tik.wav"); kabarma(d + "kabarma.wav")
    print("tamam")
