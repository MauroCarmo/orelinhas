from typing import List, Optional
from pydantic import BaseModel, Field

class BoundingBox(BaseModel):
    x_min: float = Field(..., ge=0.0, le=1.0)
    y_min: float = Field(..., ge=0.0, le=1.0)
    x_max: float = Field(..., ge=0.0, le=1.0)
    y_max: float = Field(..., ge=0.0, le=1.0)
    confidence: float = Field(..., ge=0.0, le=1.0)
    label: str

class AnalyzeRequest(BaseModel):
    image_url: Optional[str] = None
    pet_type: str  # "dog", "cat", etc.
    selected_box: Optional[BoundingBox] = None
    image_base64: Optional[str] = None

class AnalyzeResponse(BaseModel):
    detections: List[BoundingBox] = []
    embedding: Optional[List[float]] = None
