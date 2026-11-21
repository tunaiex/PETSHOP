"""Ollama Cloud API istemcisi (https://ollama.com)."""
import os

from ollama import Client

DEFAULT_HOST = "https://ollama.com"
DEFAULT_MODEL = "minimax-m3"


def get_client() -> Client:
    api_key = os.environ.get("OLLAMA_API_KEY")
    if not api_key:
        raise RuntimeError(
            "OLLAMA_API_KEY ortam değişkeni tanımlı değil. "
            "Anahtarınızı https://ollama.com/settings/keys adresinden alabilirsiniz."
        )
    return Client(
        host=os.environ.get("OLLAMA_HOST", DEFAULT_HOST),
        headers={"Authorization": "Bearer " + api_key},
    )


def chat(messages, model=None, client=None) -> str:
    """Mesaj listesini modele gönderir ve yanıt metnini döndürür."""
    client = client or get_client()
    response = client.chat(
        model=model or os.environ.get("OLLAMA_MODEL", DEFAULT_MODEL),
        messages=messages,
    )
    return response.message.content


if __name__ == "__main__":
    print(chat([{"role": "user", "content": "Hello!"}]))
