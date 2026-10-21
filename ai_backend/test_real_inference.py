import urllib.request
import io
import base64
import time
from main import app
from fastapi.testclient import TestClient

def main():
    client = TestClient(app)
    dog_url = "https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=400&q=80"
    print("Baixando foto real de cachorro para teste...")
    req = urllib.request.Request(dog_url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        img_bytes = resp.read()

    b64 = base64.b64encode(img_bytes).decode("utf-8")
    print(f"Foto baixada com sucesso ({len(img_bytes)} bytes)")

    t0 = time.time()
    res = client.post("/analyze", json={"image_base64": b64, "pet_type": "dog"})
    elapsed = time.time() - t0
    print(f"HTTP Status: {res.status_code}, Tempo de inferencia total: {elapsed:.2f}s")
    
    assert res.status_code == 200
    data = res.json()
    detections = data.get("detections", [])
    print(f"Detecções retornadas pelo YOLOv8n: {len(detections)}")
    for i, d in enumerate(detections):
        print(f"  [{i+1}] Classe: {d['label']}, Confiança: {d['confidence']*100:.1f}%, BBox: ({d['x_min']}, {d['y_min']}, {d['x_max']}, {d['y_max']})")

    embedding = data.get("embedding")
    assert embedding is not None, "Embedding não foi gerado!"
    assert len(embedding) == 768, f"Dimensão incorreta: {len(embedding)}"
    norm = sum(x*x for x in embedding) ** 0.5
    print(f"Embedding SigLIP validado! Dimensão: {len(embedding)}, Norma L2: {norm:.4f}")
    print("=== TESTE REAL COM MODELOS CONCLUÍDO COM SUCESSO ===")

if __name__ == "__main__":
    main()
