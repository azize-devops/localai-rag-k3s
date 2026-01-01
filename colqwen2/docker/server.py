"""
ColQwen2 Visual Embedding API Server
Faz 2 - Sprint 21

Model: vidore/colqwen2-v1.0
GitHub: https://github.com/illuin-tech/colpali
"""

import os
import io
import base64
import logging
from typing import List, Optional
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from PIL import Image
import torch

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


# Configuration
class Config:
    MODEL_NAME = os.getenv("MODEL_NAME", "vidore/colqwen2-v1.0")
    MODEL_CACHE_DIR = os.getenv("MODEL_CACHE_DIR", "/models")
    USE_QUANTIZATION = os.getenv("USE_QUANTIZATION", "false").lower() == "true"
    QUANTIZATION_TYPE = os.getenv("QUANTIZATION_TYPE", "int8")

    SERVER_HOST = os.getenv("SERVER_HOST", "0.0.0.0")
    SERVER_PORT = int(os.getenv("SERVER_PORT", "8001"))

    QDRANT_URL = os.getenv("QDRANT_URL", "http://qdrant:6333")
    QDRANT_COLLECTION = os.getenv("QDRANT_COLLECTION", "visual_embeddings")


# Request/Response models
class EmbedRequest(BaseModel):
    image: str  # Base64 encoded image


class EmbedBatchRequest(BaseModel):
    images: List[str]  # List of base64 encoded images


class EmbedResponse(BaseModel):
    embedding: List[float]
    dim: int


class EmbedBatchResponse(BaseModel):
    embeddings: List[List[float]]
    count: int
    dim: int


class HealthResponse(BaseModel):
    status: str
    gpu_available: bool
    model_loaded: bool
    model_name: str
    device: str


# Global model instance
model = None
processor = None
device = None


def load_model():
    """Load ColQwen2 model"""
    global model, processor, device

    try:
        from colpali_engine.models import ColQwen2, ColQwen2Processor

        # Determine device
        if torch.cuda.is_available():
            device = torch.device("cuda")
            logger.info(f"Using GPU: {torch.cuda.get_device_name(0)}")
        else:
            device = torch.device("cpu")
            logger.warning("GPU not available, using CPU (slow)")

        # Load model
        logger.info(f"Loading model: {Config.MODEL_NAME}")

        if Config.USE_QUANTIZATION:
            logger.info(f"Using {Config.QUANTIZATION_TYPE} quantization")
            # Quantized loading
            model = ColQwen2.from_pretrained(
                Config.MODEL_NAME,
                cache_dir=Config.MODEL_CACHE_DIR,
                torch_dtype=torch.float16,
                load_in_8bit=True if Config.QUANTIZATION_TYPE == "int8" else False,
                load_in_4bit=True if Config.QUANTIZATION_TYPE == "int4" else False,
                device_map="auto"
            )
        else:
            model = ColQwen2.from_pretrained(
                Config.MODEL_NAME,
                cache_dir=Config.MODEL_CACHE_DIR,
                torch_dtype=torch.float16,
            ).to(device)

        processor = ColQwen2Processor.from_pretrained(
            Config.MODEL_NAME,
            cache_dir=Config.MODEL_CACHE_DIR
        )

        model.eval()
        logger.info("Model loaded successfully")
        return True

    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        return False


def decode_image(base64_str: str) -> Image.Image:
    """Decode base64 image"""
    try:
        image_data = base64.b64decode(base64_str)
        image = Image.open(io.BytesIO(image_data))
        return image.convert("RGB")
    except Exception as e:
        raise ValueError(f"Invalid image data: {e}")


@torch.no_grad()
def embed_image(image: Image.Image) -> List[float]:
    """Generate embedding for a single image"""
    if model is None or processor is None:
        raise RuntimeError("Model not loaded")

    inputs = processor.process_images([image]).to(device)
    embeddings = model(**inputs)

    # ColQwen2 returns multi-vector embeddings, we pool them
    embedding = embeddings.mean(dim=1).squeeze().cpu().numpy().tolist()
    return embedding


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize model on startup"""
    success = load_model()
    if not success:
        logger.error("Failed to load model, running in degraded mode")
    yield
    logger.info("Shutting down ColQwen2 server")


app = FastAPI(
    title="ColQwen2 Visual Embedding API",
    description="Visual document embedding service using ColQwen2",
    version="1.0.0",
    lifespan=lifespan
)


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    gpu_available = torch.cuda.is_available()
    model_loaded = model is not None and processor is not None

    return HealthResponse(
        status="healthy" if model_loaded else "degraded",
        gpu_available=gpu_available,
        model_loaded=model_loaded,
        model_name=Config.MODEL_NAME,
        device=str(device) if device else "none"
    )


@app.post("/embed", response_model=EmbedResponse)
async def embed(request: EmbedRequest):
    """Generate embedding for a single image"""
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    try:
        image = decode_image(request.image)
        embedding = embed_image(image)

        return EmbedResponse(
            embedding=embedding,
            dim=len(embedding)
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Embedding failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/embed_batch", response_model=EmbedBatchResponse)
async def embed_batch(request: EmbedBatchRequest):
    """Generate embeddings for multiple images"""
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    try:
        embeddings = []
        for img_b64 in request.images:
            image = decode_image(img_b64)
            embedding = embed_image(image)
            embeddings.append(embedding)

        return EmbedBatchResponse(
            embeddings=embeddings,
            count=len(embeddings),
            dim=len(embeddings[0]) if embeddings else 0
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Batch embedding failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "ColQwen2 Visual Embedding API",
        "version": "1.0.0",
        "model": Config.MODEL_NAME,
        "phase": 2,
        "docs": "/docs"
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "server:app",
        host=Config.SERVER_HOST,
        port=Config.SERVER_PORT,
        reload=False,
        log_level="info"
    )
