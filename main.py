"""Mahalle petshop oyunu: yapay zekâ destekli müşteriyle sohbet."""
from ollama_client import chat

SYSTEM_PROMPT = (
    "Sen küçük bir mahalle petshop'una gelen bir müşterisin. "
    "Evcil hayvanın için bir şeyler arıyorsun (mama, oyuncak, kafes, tasma vb.). "
    "Kısa, doğal ve samimi Türkçe cümlelerle konuş. Dükkân sahibi oyuncudur."
)


def main():
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    print("Petshop açıldı! Bir müşteri içeri giriyor... (çıkmak için 'q')\n")
    messages.append({"role": "user", "content": "Hoş geldiniz! Nasıl yardımcı olabilirim?"})
    while True:
        reply = chat(messages)
        messages.append({"role": "assistant", "content": reply})
        print(f"Müşteri: {reply}\n")
        user = input("Sen: ").strip()
        if user.lower() in {"q", "quit", "çık"}:
            print("Dükkân kapandı. Görüşürüz!")
            break
        messages.append({"role": "user", "content": user})


if __name__ == "__main__":
    main()
