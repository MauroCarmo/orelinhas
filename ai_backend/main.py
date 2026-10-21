import base64
import io
import time
import logging
from contextlib import asynccontextmanager
from typing import Optional
import requests
from PIL import Image, UnidentifiedImageError
from fastapi import FastAPI, HTTPException, Header, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from config import settings
from pipeline import pipeline
from schemas import AnalyzeRequest, AnalyzeResponse, BoundingBox

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger("ai_backend")

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Inicialização dos modelos uma única vez
    logger.info("Iniciando serviço de IA e pré-carregando modelos...")
    t0 = time.time()
    try:
        pipeline.load_models()
        logger.info(f"Modelos prontos para inferência em {time.time() - t0:.2f}s")
    except Exception as e:
        logger.error(f"Falha ao carregar modelos na inicialização: {e}", exc_info=True)
    yield
    logger.info("Encerrando serviço de IA.")

app = FastAPI(
    title="Orelinhas AI Backend",
    description="Serviço de detecção (YOLOv8n) e embeddings visuais (SigLIP 768d) para pets.",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def _load_image(req: AnalyzeRequest) -> Image.Image:
    """Carrega a imagem a partir de Base64 ou URL pública."""
    # 1. Prioriza image_base64 enviado pelo Flutter
    if req.image_base64:
        try:
            image_data = base64.b64decode(req.image_base64)
            return Image.open(io.BytesIO(image_data)).convert("RGB")
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Falha ao decodificar image_base64: {e}")

    # 2. Se não houver Base64, busca via URL pública
    if req.image_url:
        try:
            resp = requests.get(req.image_url, timeout=10)
            if resp.status_code != 200:
                raise HTTPException(status_code=400, detail=f"Erro ao baixar imagem da URL (HTTP {resp.status_code})")
            return Image.open(io.BytesIO(resp.content)).convert("RGB")
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Falha ao carregar imagem da URL: {e}")

    raise HTTPException(status_code=400, detail="Nenhuma imagem fornecida (image_base64 ou image_url ausentes).")

@app.get("/health")
def health():
    return {
        "status": "online",
        "models_loaded": pipeline.is_loaded,
        "device": str(pipeline.device)
    }

@app.post("/analyze", response_model=AnalyzeResponse)
async def analyze(
    request_data: AnalyzeRequest,
    authorization: str = Header(None),
    apikey: str = Header(None)
):
    """
    Endpoint principal esperado pelo Flutter AiVisionService._callRemoteAiPipeline.
    Executa:
    1. Validação de formato da imagem.
    2. Detecção com YOLOv8n (cão / gato).
    3. Se não houver animal detectado: retorna detections=[] e embedding=null.
    4. Se houver animal: recorta (utilizando selected_box ou a detecção com maior confiança)
       e gera o embedding 768d com SigLIP.
    """
    logger.info(f"Requisição recebida para pet_type={request_data.pet_type}")

    # 1. Carregar imagem
    image = _load_image(request_data)

    # 2. Detecção com YOLOv8n
    t0 = time.time()
    detections = pipeline.detect_animals(image, expected_type=request_data.pet_type)
    yolo_time = time.time() - t0

    # Se nenhum animal foi detectado: retorna detecções vazias (Flutter interpreta como notDetected)
    if not detections:
        logger.info(f"Nenhum animal detectado ({yolo_time:.2f}s). Retornando vazio.")
        return AnalyzeResponse(detections=[], embedding=None)

    # 3. Determinar bounding box alvo para extração de embedding (seleção por espécie)
    pet_type = request_data.pet_type
    target_box: Optional[BoundingBox] = None

    if request_data.selected_box:
        # Valida a caixa informada pelo usuário: geometria, dimensões mínimas e
        # correspondência espacial com uma detecção da espécie solicitada (IoB >= 30%).
        validated = pipeline.validate_selected_box(
            request_data.selected_box, detections, pet_type
        )
        if validated:
            target_box = validated
            logger.info(f"Usando bounding box selecionada pelo usuário para '{pet_type}'.")
        else:
            # Caixa inválida ou fora de qualquer detecção da espécie: tenta fallback
            # automático para a melhor detecção da espécie solicitada.
            matching = [d for d in detections if d.label == pet_type]
            if matching:
                target_box = matching[0]
                logger.warning(
                    f"Bounding box selecionada rejeitada; usando melhor detecção automática de '{pet_type}'."
                )
            else:
                logger.warning(
                    f"Bounding box selecionada rejeitada e sem detecção de '{pet_type}'. "
                    "Retornando sem embedding."
                )
                return AnalyzeResponse(detections=detections, embedding=None)
    else:
        # Seleção automática: escolhe a melhor detecção da espécie solicitada.
        # Como detect_animals já ordena a espécie correta primeiro, basta filtrar.
        matching = [d for d in detections if d.label == pet_type]
        if not matching:
            logger.warning(
                f"Nenhuma detecção de '{pet_type}' encontrada "
                f"(detectados: {[d.label for d in detections]}). Retornando sem embedding."
            )
            return AnalyzeResponse(detections=detections, embedding=None)
        target_box = matching[0]
        logger.info(f"Usando detecção automática de '{pet_type}' com confiança={target_box.confidence:.3f}.")

    # 4. Recorte e inferência do SigLIP
    t1 = time.time()
    cropped_image = pipeline.crop_animal(image, target_box)
    embedding = pipeline.extract_embedding(cropped_image)
    siglip_time = time.time() - t1

    logger.info(
        f"Sucesso: {len(detections)} animal(is) detectado(s). "
        f"YOLO: {yolo_time:.2f}s, SigLIP: {siglip_time:.2f}s, Embedding dim: {len(embedding)}"
    )

    return AnalyzeResponse(
        detections=detections,
        embedding=embedding
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host=settings.HOST, port=settings.PORT, reload=False)
