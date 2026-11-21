---
name: freellmapi
description: PETSHOP oyununa FreeLLMAPI (github.com/tashfeenahmed/freellmapi) üzerinden ücretsiz LLM özellikleri eklemek için kullan — müşteri/NPC diyalogları, hayvan isim ve açıklama üretimi, görev metinleri, sohbet botu. Kullanıcı "LLM", "yapay zeka", "NPC konuşması", "FreeLLMAPI", "ücretsiz model", "OpenAI uyumlu" dediğinde ya da oyuna metin üreten bir özellik istendiğinde tetiklenir.
---

# FreeLLMAPI entegrasyonu

FreeLLMAPI, onlarca sağlayıcının (Google, Groq, Cerebras, Mistral, OpenRouter…) ücretsiz
kotalarını **tek bir OpenAI uyumlu `/v1` uç noktasında** toplayan, kendi makinende çalışan
bir yönlendiricidir. Bir sağlayıcı hız sınırına takılınca otomatik olarak sıradakine geçer.

## 1. Sunucuyu çalıştırma (oyuncunun/geliştiricinin makinesinde)

```bash
curl -fsSL https://freellmapi.co/install.sh | bash   # Docker gerekir, ~/freellmapi kurar
```

- Panel: http://localhost:3001 → **Keys** sayfasından sağlayıcı anahtarlarını ekle.
- **Keys** sayfasının başlığındaki *unified API key* (`freellmapi-...`) oyunun kullanacağı tek anahtardır.
- Alternatifler: masaüstü uygulaması (macOS/Windows), `docker-compose`.

## 2. Yapılandırma kuralları

- Anahtarı **asla** koda veya repoya yazma. Ortam değişkeni kullan:
  - `FREELLMAPI_BASE_URL` (varsayılan `http://localhost:3001/v1`)
  - `FREELLMAPI_KEY`
- `.env` dosyası kullanılıyorsa `.gitignore`'a eklendiğinden emin ol; repoya sadece `.env.example` koy.
- Tarayıcıda çalışan oyun kodu anahtarı doğrudan taşımamalı: istekleri küçük bir sunucu
  (ör. Node/Express `/api/npc`) üzerinden geçir, anahtar sadece sunucuda dursun.

## 3. Çağrı

Herhangi bir OpenAI SDK'sı çalışır; sadece `baseURL` ve anahtarı değiştir.

```js
// npm i openai
import OpenAI from "openai";

const llm = new OpenAI({
  baseURL: process.env.FREELLMAPI_BASE_URL ?? "http://localhost:3001/v1",
  apiKey: process.env.FREELLMAPI_KEY,
});

export async function npcSoyle(musteri, durum) {
  const res = await llm.chat.completions.create({
    model: "auto:fast", // oyun içi diyalog için hız öncelikli
    max_tokens: 120,
    messages: [
      { role: "system", content: "Bir mahalle petshopunda müşterisin. Kısa, samimi, Türkçe konuş. En fazla 2 cümle." },
      { role: "user", content: `Müşteri: ${musteri.ad} (${musteri.kisilik}). Durum: ${durum}` },
    ],
  });
  return res.choices[0].message.content.trim();
}
```

Ham `fetch` ile:

```js
const r = await fetch(`${BASE_URL}/chat/completions`, {
  method: "POST",
  headers: { "Content-Type": "application/json", Authorization: `Bearer ${KEY}` },
  body: JSON.stringify({ model: "auto", messages }),
});
```

### Model seçimi (`model` alanı)

| Değer | Ne zaman |
|---|---|
| `auto` | Paneldeki Fallback Chain sırasıyla |
| `auto:fast` | Anlık NPC cevapları, isim üretimi |
| `auto:smart` | Görev/hikâye metni, uzun içerik |
| `auto:reliable` | Kritik akışlar (başarısızlık oranı düşük) |
| `auto:<profil>` | Panelde tanımlı adlandırılmış profil |
| `<model-id>` | Belirli bir model (`GET /v1/models` ile listele) |

## 4. Hata ve fallback kuralları

- Yönlendirici sağlayıcılar arasında kendisi geçiş yapar; tüm kotalar doluysa **HTTP 429** ve
  `Retry-After` başlığı döner. Oyun bu durumda **çökmemeli**: önceden yazılmış yedek
  diyaloglardan rastgele birini göster, `Retry-After` süresi kadar bekle.
- Sunucu kapalıysa (bağlantı hatası) yine yedek metne düş; LLM özellikleri her zaman isteğe bağlı olmalı.
- Zaman aşımı koy (ör. 8 sn) — oyun döngüsünü bloklama, istekleri asenkron yap.
- Hata ayıklarken `X-Routed-Via` (hangi sağlayıcı/model cevapladı) ve `X-Fallback-Trail` başlıklarına bak.
- Kalan kota: `GET /v1/usage` (aynı Bearer anahtarla).

## 5. Oyun için iyi uygulamalar

- Aynı girdiler için cevapları önbelleğe al (ör. hayvan açıklamaları) — kota harcama.
- `max_tokens`'ı düşük tut, sistem mesajında uzunluk ve dil (Türkçe) sınırı ver.
- Yapılandırılmış veri gerekiyorsa (ör. `{ "ad": "...", "tur": "...", "fiyat": 0 }`) JSON iste
  ve `JSON.parse`'ı try/catch ile sar; bozuk çıktıda yedek veriye dön.
- Diğer uç noktalar da var: embeddings, görsel, TTS, Anthropic Messages (`/v1/messages`).
  Ayrıntı: https://github.com/tashfeenahmed/freellmapi/blob/main/docs/en/api/01-rest-api.md
