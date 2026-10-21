# Orelinhas AI Backend (YOLOv8n + SigLIP 768d)

Backend local em Python/FastAPI responsável pela inferência de visão computacional da feature `pet_recognition` do Orelinhas.

## Modelos Utilizados
1. **YOLOv8n (`yolov8n.pt`)**: Detecção de animais (cão e gato) e extração de caixas delimitadoras normalizadas (`0.0` a `1.0`).
2. **SigLIP Base (`google/siglip-base-patch16-224`)**: Modelo de visão computacional da Google que gera embeddings visuais de **768 dimensões** com normalização L2.

## Pré-requisitos
- Python 3.10 ou 3.11 instalado.

## Como Executar Localmente
```bash
# 1. Entrar na pasta
cd ai_backend

# 2. Ativar ambiente virtual
# No Windows PowerShell:
.\venv\Scripts\Activate.ps1

# 3. Iniciar o servidor
python main.py
```
O servidor iniciará em `http://127.0.0.1:8000`.

## Contrato de Integração
- **Endpoint**: `POST /analyze`
- **Healthcheck**: `GET /health`

## Configuração no Flutter
No arquivo `.env` da raiz do aplicativo Flutter:
- Para testes no Windows / Desktop:
  ```env
  AI_VISION_ENDPOINT=http://127.0.0.1:8000
  ```
- Para testes no Emulador Android:
  ```env
  AI_VISION_ENDPOINT=http://10.0.2.2:8000
  ```
- Se a variável estiver vazia ou ausente, o app faz fallback gracioso para o simulador local sem quebrar o fluxo.
