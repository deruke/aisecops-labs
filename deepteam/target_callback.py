"""
Target callback for DeepTeam to interact with Open WebUI CTF challenges.

This callback sends prompts to Open WebUI's API and returns the model's response.
Configure OPENWEBUI_URL and OPENWEBUI_API_KEY as environment variables.
"""

import os
import requests


OPENWEBUI_URL = os.environ.get("OPENWEBUI_URL", "http://open-webui:8080")
OPENWEBUI_API_KEY = os.environ.get("OPENWEBUI_API_KEY", "")


def openwebui_callback(prompt: str, model_id: str = "jackson_no_protections") -> str:
    """Send a prompt to Open WebUI and return the response.

    Args:
        prompt: The attack prompt to send.
        model_id: The Open WebUI model ID to target.
                  Defaults to Challenge 1 (no protections).

    Returns:
        The model's response text.
    """
    headers = {
        "Content-Type": "application/json",
    }
    if OPENWEBUI_API_KEY:
        headers["Authorization"] = f"Bearer {OPENWEBUI_API_KEY}"

    payload = {
        "model": model_id,
        "messages": [
            {"role": "user", "content": prompt}
        ],
        "stream": False,
    }

    try:
        resp = requests.post(
            f"{OPENWEBUI_URL}/api/chat/completions",
            json=payload,
            headers=headers,
            timeout=60,
        )
        resp.raise_for_status()
        data = resp.json()
        return data["choices"][0]["message"]["content"]
    except requests.RequestException as e:
        return f"Error communicating with Open WebUI: {e}"
