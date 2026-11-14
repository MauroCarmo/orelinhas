import os
import re
import subprocess
import sys
from pathlib import Path
import requests
from dotenv import load_dotenv

# Lê o .env.local na raiz do projeto (que NÃO vai para o APK/Web nem para o Git)
ROOT_DIR = Path(__file__).resolve().parent.parent
load_dotenv(ROOT_DIR / ".env.local")

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SERVICE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")


def update_supabase_url(public_url: str) -> None:
    if not SUPABASE_URL or not SERVICE_KEY:
        print("[AVISO] SUPABASE_URL ou SUPABASE_SERVICE_ROLE_KEY ausentes no .env.local.")
        return

    endpoint = f"{SUPABASE_URL}/rest/v1/app_config"
    headers = {
        "apikey": SERVICE_KEY,
        "Authorization": f"Bearer {SERVICE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates",
    }
    payload = {"key": "AI_VISION_ENDPOINT", "value": public_url}

    try:
        resp = requests.post(endpoint, json=payload, headers=headers, timeout=10)
        if resp.status_code in (200, 201, 204):
            print(f"\n[SUCESSO] AI_VISION_ENDPOINT atualizado no Supabase: {public_url}\n")
        else:
            print(f"\n[ERRO] Falha ao atualizar Supabase ({resp.status_code}): {resp.text}\n")
    except Exception as e:
        print(f"\n[ERRO] Exceção ao conectar no Supabase: {e}\n")


def main() -> None:
    print("Iniciando Cloudflare Tunnel na porta 8000...")
    process = subprocess.Popen(
        ["cloudflared", "tunnel", "--url", "http://localhost:8000"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )

    url_pattern = re.compile(r"https://[a-zA-Z0-9-]+\.trycloudflare\.com")
    updated = False

    try:
        assert process.stdout is not None
        for line in process.stdout:
            sys.stdout.write(line)
            sys.stdout.flush()
            if not updated:
                match = url_pattern.search(line)
                if match:
                    tunnel_url = match.group(0)
                    update_supabase_url(tunnel_url)
                    updated = True
    except KeyboardInterrupt:
        print("\nEncerrando túnel...")
        process.terminate()


if __name__ == "__main__":
    main()