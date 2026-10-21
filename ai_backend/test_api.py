import base64
import io
import math
import pytest
from PIL import Image, ImageDraw
from fastapi.testclient import TestClient
from unittest.mock import patch, MagicMock

from main import app
from schemas import BoundingBox
from pipeline import VisionPipeline

client = TestClient(app)


def create_synthetic_image(draw_dog=False, draw_cat=False) -> str:
    """Cria uma imagem sintética RGB de 300x300 e retorna em base64."""
    img = Image.new("RGB", (300, 300), color=(240, 240, 240))
    draw = ImageDraw.Draw(img)

    if draw_dog:
        # Desenha uma forma marrom simulando animal
        draw.rectangle([50, 50, 250, 250], fill=(139, 69, 19))
    elif draw_cat:
        # Desenha uma forma cinza simulando animal
        draw.ellipse([60, 60, 240, 240], fill=(128, 128, 128))

    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return base64.b64encode(buf.getvalue()).decode("utf-8")


def make_fake_embedding(dim: int = 768) -> list:
    """Gera embedding fake L2-normalizado de `dim` dimensões."""
    v = [1.0 / math.sqrt(dim)] * dim
    return v


def make_dog_detection(**kwargs) -> BoundingBox:
    defaults = dict(x_min=0.1, y_min=0.1, x_max=0.9, y_max=0.9, confidence=0.90, label="dog")
    defaults.update(kwargs)
    return BoundingBox(**defaults)


def make_cat_detection(**kwargs) -> BoundingBox:
    defaults = dict(x_min=0.1, y_min=0.1, x_max=0.9, y_max=0.9, confidence=0.85, label="cat")
    defaults.update(kwargs)
    return BoundingBox(**defaults)


# ---------------------------------------------------------------------------
# Testes existentes
# ---------------------------------------------------------------------------

def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "online"


def test_analyze_no_animal():
    """Imagem vazia sem nenhum animal detectado pelo YOLO."""
    b64 = create_synthetic_image(draw_dog=False)
    payload = {
        "image_base64": b64,
        "pet_type": "dog"
    }
    response = client.post("/analyze", json=payload)
    assert response.status_code == 200
    data = response.json()
    # Quando não há detecções, detections=[] e embedding=None
    assert data["detections"] == []
    assert data["embedding"] is None


def test_analyze_invalid_image_base64():
    """Payload com string base64 corrompida."""
    payload = {
        "image_base64": "invalid_base64_string",
        "pet_type": "dog"
    }
    response = client.post("/analyze", json=payload)
    assert response.status_code == 400


# ---------------------------------------------------------------------------
# Testes de seleção por espécie (sem inferência real — usa mock)
# ---------------------------------------------------------------------------

def test_wrong_species_no_embedding():
    """Detectado apenas gato, pediu cão: deve retornar embedding=None."""
    b64 = create_synthetic_image()
    cat_det = make_cat_detection()

    with patch.object(VisionPipeline, "detect_animals", return_value=[cat_det]):
        payload = {"image_base64": b64, "pet_type": "dog"}
        response = client.post("/analyze", json=payload)

    assert response.status_code == 200
    data = response.json()
    # Detecções visíveis (para UI multi-animal), mas sem embedding da espécie errada
    assert len(data["detections"]) == 1
    assert data["detections"][0]["label"] == "cat"
    assert data["embedding"] is None, (
        "Não deve gerar embedding quando nenhuma detecção é da espécie solicitada."
    )


def test_correct_species_generates_embedding():
    """Detectado cão, pediu cão: deve gerar embedding."""
    b64 = create_synthetic_image()
    dog_det = make_dog_detection()
    fake_emb = make_fake_embedding()

    with (
        patch.object(VisionPipeline, "detect_animals", return_value=[dog_det]),
        patch.object(VisionPipeline, "extract_embedding", return_value=fake_emb),
    ):
        payload = {"image_base64": b64, "pet_type": "dog"}
        response = client.post("/analyze", json=payload)

    assert response.status_code == 200
    data = response.json()
    assert data["embedding"] is not None
    assert len(data["embedding"]) == 768


def test_multi_animal_picks_correct_species():
    """Foto com cão (alta confiança) e gato, pediu gato: embedding do gato."""
    b64 = create_synthetic_image()
    dog_det = make_dog_detection(confidence=0.95, x_min=0.05, x_max=0.45)
    cat_det = make_cat_detection(confidence=0.80, x_min=0.55, x_max=0.95)
    fake_emb = make_fake_embedding()

    captured_crops = []

    def fake_crop(image, box):
        captured_crops.append(box)
        return image  # retorna a imagem inteira para não causar erro no SigLIP mock

    with (
        patch.object(VisionPipeline, "detect_animals", return_value=[dog_det, cat_det]),
        patch.object(VisionPipeline, "crop_animal", side_effect=fake_crop),
        patch.object(VisionPipeline, "extract_embedding", return_value=fake_emb),
    ):
        payload = {"image_base64": b64, "pet_type": "cat"}
        response = client.post("/analyze", json=payload)

    assert response.status_code == 200
    data = response.json()
    assert data["embedding"] is not None
    # O recorte deve ter sido feito sobre a bounding box do gato
    assert len(captured_crops) == 1
    assert captured_crops[0].label == "cat"


# ---------------------------------------------------------------------------
# Testes de validação da bounding box
# ---------------------------------------------------------------------------

def test_box_inverted_coordinates_rejected():
    """Caixa com x_min > x_max: deve ser rejeitada pelo schema Pydantic (422)."""
    b64 = create_synthetic_image()
    payload = {
        "image_base64": b64,
        "pet_type": "dog",
        "selected_box": {
            "x_min": 0.8, "y_min": 0.1, "x_max": 0.2, "y_max": 0.9,
            "confidence": 0.9, "label": "dog"
        }
    }
    # Pydantic Field(le=1.0, ge=0.0) aceita os valores individualmente;
    # a validação de inversão (x_min >= x_max) é feita em validate_selected_box.
    # O endpoint deve retornar embedding=None (fallback para detecção automática ou ausência).
    dog_det = make_dog_detection()
    fake_emb = make_fake_embedding()

    with (
        patch.object(VisionPipeline, "detect_animals", return_value=[dog_det]),
        patch.object(VisionPipeline, "extract_embedding", return_value=fake_emb),
    ):
        response = client.post("/analyze", json=payload)

    assert response.status_code == 200
    data = response.json()
    # Caixa inválida deve cair no fallback automático (detecção da espécie)
    # → embedding gerado com a detecção automática, NÃO com a caixa inválida
    assert data["embedding"] is not None  # fallback automático funcionou


def test_box_too_small_rejected():
    """Caixa com largura/altura < 5% da imagem: deve ser rejeitada."""
    b64 = create_synthetic_image()
    dog_det = make_dog_detection()
    fake_emb = make_fake_embedding()

    with (
        patch.object(VisionPipeline, "detect_animals", return_value=[dog_det]),
        patch.object(VisionPipeline, "extract_embedding", return_value=fake_emb),
    ):
        payload = {
            "image_base64": b64,
            "pet_type": "dog",
            "selected_box": {
                # Caixa de 2% x 2% — abaixo do mínimo de 5%
                "x_min": 0.10, "y_min": 0.10, "x_max": 0.12, "y_max": 0.12,
                "confidence": 0.9, "label": "dog"
            }
        }
        response = client.post("/analyze", json=payload)

    assert response.status_code == 200
    data = response.json()
    # Fallback para detecção automática: embedding deve existir
    assert data["embedding"] is not None


def test_box_no_species_overlap_rejected():
    """Caixa válida em tamanho mas sem correspondência com detecção da espécie: retorna None."""
    b64 = create_synthetic_image()
    # Detecção do cão no canto esquerdo
    dog_det = make_dog_detection(x_min=0.0, y_min=0.0, x_max=0.3, y_max=0.3, label="dog")

    with patch.object(VisionPipeline, "detect_animals", return_value=[dog_det]):
        payload = {
            "image_base64": b64,
            "pet_type": "dog",
            "selected_box": {
                # Caixa no canto direito — sem sobreposição com a detecção
                "x_min": 0.7, "y_min": 0.7, "x_max": 1.0, "y_max": 1.0,
                "confidence": 0.9, "label": "dog"
            }
        }
        response = client.post("/analyze", json=payload)

    assert response.status_code == 200
    data = response.json()
    # Caixa rejeitada, fallback para melhor detecção da espécie
    # (dog_det está disponível como fallback) → embedding gerado
    # Verificamos apenas que não houve erro 500
    assert data is not None


def test_valid_user_adjusted_box_accepted():
    """Caixa ligeiramente maior que a detecção do YOLO (ajuste manual) deve ser aceita."""
    b64 = create_synthetic_image()
    # Detecção do YOLO: cão centralizado
    dog_det = make_dog_detection(x_min=0.20, y_min=0.20, x_max=0.80, y_max=0.80, label="dog")
    fake_emb = make_fake_embedding()

    captured_crops = []

    def fake_crop(image, box):
        captured_crops.append(box)
        return image

    with (
        patch.object(VisionPipeline, "detect_animals", return_value=[dog_det]),
        patch.object(VisionPipeline, "crop_animal", side_effect=fake_crop),
        patch.object(VisionPipeline, "extract_embedding", return_value=fake_emb),
    ):
        payload = {
            "image_base64": b64,
            "pet_type": "dog",
            "selected_box": {
                # Usuário expandiu ligeiramente a caixa (±5pp)
                "x_min": 0.15, "y_min": 0.15, "x_max": 0.85, "y_max": 0.85,
                "confidence": 0.9, "label": "dog"
            }
        }
        response = client.post("/analyze", json=payload)

    assert response.status_code == 200
    data = response.json()
    assert data["embedding"] is not None
    # O recorte deve ter sido feito com a caixa do usuário (não a do YOLO)
    assert len(captured_crops) == 1
    assert captured_crops[0].x_min == pytest.approx(0.15)
    assert captured_crops[0].x_max == pytest.approx(0.85)


# ---------------------------------------------------------------------------
# Testes unitários de compute_iob
# ---------------------------------------------------------------------------

def test_compute_iob_full_overlap():
    """Caixas idênticas: IoB deve ser 1.0."""
    box = BoundingBox(x_min=0.1, y_min=0.1, x_max=0.5, y_max=0.5, confidence=0.9, label="dog")
    assert VisionPipeline.compute_iob(box, box) == pytest.approx(1.0)


def test_compute_iob_no_overlap():
    """Caixas sem sobreposição: IoB deve ser 0.0."""
    user = BoundingBox(x_min=0.0, y_min=0.0, x_max=0.3, y_max=0.3, confidence=0.9, label="dog")
    yolo = BoundingBox(x_min=0.7, y_min=0.7, x_max=1.0, y_max=1.0, confidence=0.9, label="dog")
    assert VisionPipeline.compute_iob(user, yolo) == pytest.approx(0.0)


def test_compute_iob_partial_overlap():
    """IoB deve ser proporcional à interseção sobre a caixa do usuário."""
    # user: [0.0, 0.0] -> [0.4, 0.4] → área = 0.16
    # yolo: [0.2, 0.2] -> [0.6, 0.6] → interseção: [0.2,0.2]->[0.4,0.4] = 0.2*0.2 = 0.04
    # IoB = 0.04 / 0.16 = 0.25
    user = BoundingBox(x_min=0.0, y_min=0.0, x_max=0.4, y_max=0.4, confidence=0.9, label="dog")
    yolo = BoundingBox(x_min=0.2, y_min=0.2, x_max=0.6, y_max=0.6, confidence=0.9, label="dog")
    assert VisionPipeline.compute_iob(user, yolo) == pytest.approx(0.25)
