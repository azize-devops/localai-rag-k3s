"""
RAG-Anything Configuration
Connects to LocalAI (LLM) and Qdrant (vectors) in Kubernetes
"""
import os
from dataclasses import dataclass
from typing import Optional


@dataclass
class Config:
    # LocalAI connection (OpenAI-compatible API)
    localai_url: str = os.getenv("LOCALAI_URL", "http://localai:8080/v1")
    localai_api_key: str = os.getenv("LOCALAI_API_KEY", "not-needed")

    # LLM model names (as configured in LocalAI)
    llm_model: str = os.getenv("LLM_MODEL", "llama3")
    vision_model: str = os.getenv("VISION_MODEL", "llava")
    embedding_model: str = os.getenv("EMBEDDING_MODEL", "all-minilm-l6-v2")
    embedding_dim: int = int(os.getenv("EMBEDDING_DIM", "384"))

    # Qdrant connection
    qdrant_url: str = os.getenv("QDRANT_URL", "http://qdrant:6333")
    qdrant_api_key: Optional[str] = os.getenv("QDRANT_API_KEY")

    # Working directories
    working_dir: str = os.getenv("WORKING_DIR", "/data/rag")
    documents_dir: str = os.getenv("DOCUMENTS_DIR", "/data/documents")
    cache_dir: str = os.getenv("CACHE_DIR", "/data/cache")

    # RAG-Anything settings
    parser: str = os.getenv("PARSER", "mineru")  # mineru or docling
    enable_image_processing: bool = os.getenv("ENABLE_IMAGE_PROCESSING", "true").lower() == "true"
    enable_table_processing: bool = os.getenv("ENABLE_TABLE_PROCESSING", "true").lower() == "true"
    enable_equation_processing: bool = os.getenv("ENABLE_EQUATION_PROCESSING", "true").lower() == "true"

    # Logging
    log_level: str = os.getenv("LOG_LEVEL", "INFO")


config = Config()
