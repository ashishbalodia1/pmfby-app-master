import json
import os
import sys
import urllib.error
import urllib.request

MODEL = "gemini-2.5-flash"
ENDPOINT = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"

def main():
    api_key = os.getenv("GEMINI_API_KEY") or (sys.argv[1] if len(sys.argv) > 1 else None)
    if not api_key:
        print("Set GEMINI_API_KEY env var or pass it as the first argument.")
        sys.exit(1)

    payload = {
        "contents": [
            {
                "parts": [
                    {
                        "text": "Say a short hello and tell me the current model name you are using."
                    }
                ]
            }
        ]
    }

    data = json.dumps(payload).encode("utf-8")
    url = f"{ENDPOINT}?key={api_key}"
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read().decode("utf-8")
            print(f"Status: {resp.status}")
            print("Response:")
            print(body)
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="replace")
        print(f"HTTPError: {e.code}")
        print(err_body)
        sys.exit(1)
    except Exception as e:
        print(f"Request failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
