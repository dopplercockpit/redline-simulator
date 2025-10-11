from openai import OpenAI
import os

_client = None

def get_client() -> OpenAI:
    global _client
    if _client is None:
        api_key = os.getenv("OPENAI_API_KEY")
        base_url = os.getenv("OPENAI_BASE_URL")  # optional, if using Azure/open-source proxy
        _client = OpenAI(api_key=api_key, base_url=base_url) if base_url else OpenAI(api_key=api_key)
    return _client

def analyst_feedback(system: str, user: str, model: str = None) -> str:
    """
    Sends a compact chat to the model and returns plain text.
    """
    model = model or os.getenv("OPENAI_MODEL", "gpt-4o-mini")
    client = get_client()
    resp = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": user}
        ],
        temperature=0.2,
        max_tokens=350
    )
    return resp.choices[0].message.content.strip()
