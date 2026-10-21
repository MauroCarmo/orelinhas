import io
import time
import logging
from typing import List, Tuple, Optional
import numpy as np
from PIL import Image
import torch
from transformers import AutoProcessor, AutoModel
from ultralytics import YOLO

from config import settings
from schemas import BoundingBox

logger = logging.getLogger("vision_pipeline")

# COCO classes for animals: 15: cat, 16: dog, 17: horse, 18: sheep, 19: cow, 20: elephant, 21: bear, 22: zebra, 23: giraffe
PET_CLASS_MAP = {
    15: "cat",
    16: "dog",
}

class VisionPipeline:
    def __init__(self):
        self.device = torch.device(settings.DEVICE)
        self.yolo_model: Optional[YOLO] = None
        self.siglip_model = None
        self.siglip_processor = None
        self.is_loaded = False

    def load_models(self):
        """Carrega os modelos uma única vez na inicialização."""
        if self.is_loaded:
            return

        t0 = time.time()
        logger.info(f"Carregando YOLOv8n ({settings.YOLO_MODEL_NAME}) em {self.device}...")
        self.yolo_model = YOLO(settings.YOLO_MODEL_NAME)

        logger.info(f"Carregando SigLIP ({settings.SIGLIP_MODEL_NAME}) em {self.device}...")
        self.siglip_processor = AutoProcessor.from_pretrained(settings.SIGLIP_MODEL_NAME)
        self.siglip_model = AutoModel.from_pretrained(settings.SIGLIP_MODEL_NAME).to(self.device)
        self.siglip_model.eval()

        self.is_loaded = True
        elapsed = time.time() - t0
        logger.info(f"Modelos carregados com sucesso em {elapsed:.2f}s")

    def detect_animals(self, image: Image.Image, expected_type: str) -> List[BoundingBox]:
        """Executa YOLOv8n e retorna bounding boxes normalizadas (0.0 a 1.0).

        Detecta cães e gatos (multi-animal). A lista resultante é ordenada com as
        detecções da espécie solicitada (expected_type) primeiro, e dentro de cada
        grupo pela confiança decrescente. Isso permite que o chamador escolha a
        melhor detecção compatível sem precisar refiltrar a lista.
        """
        if not self.is_loaded:
            self.load_models()

        w, h = image.size
        results = self.yolo_model(image, conf=settings.CONFIDENCE_THRESHOLD, verbose=False)

        boxes: List[BoundingBox] = []
        for result in results:
            for box in result.boxes:
                cls_id = int(box.cls[0].item())
                conf = float(box.conf[0].item())

                label = PET_CLASS_MAP.get(cls_id, None)
                if not label:
                    continue

                # Coordenadas em pixels -> normalizadas [0.0, 1.0]
                xyxy = box.xyxy[0].tolist()
                x_min = max(0.0, min(1.0, xyxy[0] / w))
                y_min = max(0.0, min(1.0, xyxy[1] / h))
                x_max = max(0.0, min(1.0, xyxy[2] / w))
                y_max = max(0.0, min(1.0, xyxy[3] / h))

                boxes.append(
                    BoundingBox(
                        x_min=round(x_min, 4),
                        y_min=round(y_min, 4),
                        x_max=round(x_max, 4),
                        y_max=round(y_max, 4),
                        confidence=round(conf, 4),
                        label=label,
                    )
                )

        # Ordena: espécie solicitada primeiro, depois por confiança decrescente.
        # Detecções de outra espécie ficam no final (visíveis para multi-animal).
        boxes.sort(key=lambda b: (b.label != expected_type, -b.confidence))
        return boxes

    # ------------------------------------------------------------------
    # Validação da bounding box selecionada pelo usuário
    # ------------------------------------------------------------------

    @staticmethod
    def compute_iob(box_user: BoundingBox, box_yolo: BoundingBox) -> float:
        """Calcula o IoB (Intersection over selected Box).

        Mede qual proporção da caixa do usuário está coberta pela detecção do YOLO.
        Valor em [0.0, 1.0]. Valores próximos de 1.0 indicam correspondência total.

        Usamos IoB (em vez de IoU) porque o usuário pode ajustar a caixa para ser
        ligeiramente maior do que a detecção automática e ainda assim ser válida.
        """
        ix_min = max(box_user.x_min, box_yolo.x_min)
        iy_min = max(box_user.y_min, box_yolo.y_min)
        ix_max = min(box_user.x_max, box_yolo.x_max)
        iy_max = min(box_user.y_max, box_yolo.y_max)

        inter_w = max(0.0, ix_max - ix_min)
        inter_h = max(0.0, iy_max - iy_min)
        intersection = inter_w * inter_h

        user_area = (box_user.x_max - box_user.x_min) * (box_user.y_max - box_user.y_min)
        if user_area <= 0.0:
            return 0.0

        return intersection / user_area

    def validate_selected_box(
        self,
        selected_box: BoundingBox,
        detections: List[BoundingBox],
        expected_type: str,
        min_size: float = 0.05,
        min_iob: float = 0.30,
    ) -> Optional[BoundingBox]:
        """Valida a bounding box selecionada pelo usuário.

        Regras (por ordem de aplicação):
        1. Sanidade geométrica: x_min < x_max, y_min < y_max.
        2. Dimensões mínimas: largura e altura >= min_size (padrão: 5% da imagem).
        3. Correspondência espacial: existe pelo menos uma detecção da espécie
           solicitada (expected_type) com IoB >= min_iob (padrão: 30%).

        O limiar de 30% é generoso o suficiente para aceitar ajustes manuais
        legítimos do usuário, mas rejeita caixas deslocadas para regiões sem animal.

        Retorna:
            A própria selected_box se válida (a seleção do usuário é preservada).
            None se alguma regra for violada.
        """
        # 1. Sanidade geométrica
        if selected_box.x_min >= selected_box.x_max or selected_box.y_min >= selected_box.y_max:
            logger.warning(
                "Bounding box inválida (coordenadas invertidas): "
                f"x=[{selected_box.x_min}, {selected_box.x_max}] "
                f"y=[{selected_box.y_min}, {selected_box.y_max}]"
            )
            return None

        # 2. Dimensões mínimas
        width = selected_box.x_max - selected_box.x_min
        height = selected_box.y_max - selected_box.y_min
        if width < min_size or height < min_size:
            logger.warning(
                f"Bounding box muito pequena: {width:.4f}w x {height:.4f}h "
                f"(mínimo: {min_size})"
            )
            return None

        # 3. Correspondência espacial com detecção da espécie solicitada
        species_detections = [d for d in detections if d.label == expected_type]
        if not species_detections:
            logger.warning(
                f"Nenhuma detecção de '{expected_type}' para validar a bounding box selecionada."
            )
            return None

        best_iob = max(self.compute_iob(selected_box, d) for d in species_detections)
        if best_iob < min_iob:
            logger.warning(
                f"Bounding box selecionada sem correspondência com detecção de '{expected_type}': "
                f"IoB máximo={best_iob:.3f} (limiar={min_iob})"
            )
            return None

        logger.info(
            f"Bounding box selecionada validada para '{expected_type}' com IoB={best_iob:.3f}"
        )
        return selected_box

    def crop_animal(self, image: Image.Image, box: BoundingBox) -> Image.Image:
        """Recorta a região do animal a partir de uma bounding box normalizada."""
        w, h = image.size
        left = int(box.x_min * w)
        top = int(box.y_min * h)
        right = int(box.x_max * w)
        bottom = int(box.y_max * h)

        # Garante dimensões mínimas válidas
        if right <= left:
            right = min(w, left + 10)
        if bottom <= top:
            bottom = min(h, top + 10)

        return image.crop((left, top, right, bottom))

    def extract_embedding(self, image: Image.Image) -> List[float]:
        """Extrai embedding visual real do SigLIP com exatamente 768 dimensões e normalização L2."""
        if not self.is_loaded:
            self.load_models()

        inputs = self.siglip_processor(images=image, return_tensors="pt")
        inputs = {k: v.to(self.device) for k, v in inputs.items()}

        with torch.no_grad():
            vision_outputs = self.siglip_model.vision_model(**inputs)
            # pooler_output do SigLIP vision_model produz tensor de [batch_size, 768]
            pooled = vision_outputs.pooler_output
            
            # Normalização L2
            norm = torch.norm(pooled, p=2, dim=-1, keepdim=True)
            normalized = pooled / (norm + 1e-8)
            embedding_vector = normalized.squeeze(0).cpu().tolist()

        if len(embedding_vector) != 768:
            raise ValueError(f"Dimensão incorreta do embedding SigLIP: {len(embedding_vector)}, esperado 768.")

        return embedding_vector

pipeline = VisionPipeline()
