import os
from pydantic import BaseModel
from dotenv import load_dotenv

load_dotenv()

class Settings(BaseModel):
    HOST: str = os.getenv("HOST", "127.0.0.1")
    PORT: int = int(os.getenv("PORT", "8000"))
    YOLO_MODEL_NAME: str = os.getenv("YOLO_MODEL_NAME", "yolov8n.pt")
    SIGLIP_MODEL_NAME: str = os.getenv("SIGLIP_MODEL_NAME", "google/siglip-base-patch16-224")
    CONFIDENCE_THRESHOLD: float = float(os.getenv("CONFIDENCE_THRESHOLD", "0.25"))
    DEVICE: str = os.getenv("DEVICE", "cpu")

settings = Settings()
