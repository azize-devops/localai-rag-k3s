"""
RAG-Anything FastAPI Server
Wraps RAG-Anything library with REST API for Kubernetes deployment
Connects to LocalAI for LLM and embedding functions

GitHub: https://github.com/HKUDS/RAG-Anything
"""
import asyncio
import logging
import os
import shutil
import uuid
from datetime import datetime
from pathlib import Path
from typing import Optional, List
from contextlib import asynccontextmanager

from fastapi import FastAPI, File, UploadFile, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import httpx
from openai import AsyncOpenAI

from config import config

# Setup logging
logging.basicConfig(
    level=getattr(logging, config.log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


# ============ Pydantic Models ============

class QueryRequest(BaseModel):
    query: str
    mode: str = "hybrid"  # naive, local, global, hybrid
    multimodal: bool = False
    top_k: int = 5


class QueryResponse(BaseModel):
    answer: str
    sources: List[dict] = []
    mode: str
    processing_time: float


class InsertRequest(BaseModel):
    content: str
    metadata: Optional[dict] = None
    doc_id: Optional[str] = None


class DocumentStatus(BaseModel):
    document_id: str
    filename: str
    status: str  # pending, processing, completed, failed
    progress: float
    error: Optional[str] = None
    created_at: str


class HealthResponse(BaseModel):
    status: str
    localai_connected: bool
    qdrant_connected: bool
    rag_initialized: bool
    documents_processed: int


# Global state
rag_instance = None
processing_status = {}


# ============ LLM Functions for RAG-Anything ============

async def llm_model_func(prompt: str, **kwargs) -> str:
    """LLM function using LocalAI (OpenAI-compatible)"""
    client = AsyncOpenAI(
        base_url=config.localai_url,
        api_key=config.localai_api_key
    )

    try:
        response = await client.chat.completions.create(
            model=config.llm_model,
            messages=[{"role": "user", "content": prompt}],
            temperature=kwargs.get("temperature", 0.7),
            max_tokens=kwargs.get("max_tokens", 2048)
        )
        return response.choices[0].message.content
    except Exception as e:
        logger.error(f"LLM error: {e}")
        raise


async def vision_model_func(prompt: str, images: List[str] = None, **kwargs) -> str:
    """Vision model function using LocalAI"""
    client = AsyncOpenAI(
        base_url=config.localai_url,
        api_key=config.localai_api_key
    )

    try:
        messages = [{"role": "user", "content": prompt}]

        # If images provided, add them to the message (for vision models)
        if images:
            content = [{"type": "text", "text": prompt}]
            for img in images:
                content.append({
                    "type": "image_url",
                    "image_url": {"url": f"data:image/jpeg;base64,{img}"}
                })
            messages = [{"role": "user", "content": content}]

        response = await client.chat.completions.create(
            model=config.vision_model,
            messages=messages,
            max_tokens=kwargs.get("max_tokens", 1024)
        )
        return response.choices[0].message.content
    except Exception as e:
        logger.error(f"Vision model error: {e}")
        # Fallback to text-only LLM
        return await llm_model_func(prompt, **kwargs)


async def embedding_func(texts: List[str]) -> List[List[float]]:
    """Embedding function using LocalAI"""
    client = AsyncOpenAI(
        base_url=config.localai_url,
        api_key=config.localai_api_key
    )

    try:
        embeddings = []
        batch_size = 32

        for i in range(0, len(texts), batch_size):
            batch = texts[i:i + batch_size]
            response = await client.embeddings.create(
                model=config.embedding_model,
                input=batch
            )
            embeddings.extend([e.embedding for e in response.data])

        return embeddings
    except Exception as e:
        logger.error(f"Embedding error: {e}")
        raise


# ============ RAG Initialization ============

async def initialize_rag():
    """Initialize RAG-Anything instance"""
    global rag_instance

    if rag_instance is not None:
        return

    logger.info("Initializing RAG-Anything...")

    try:
        from raganything import RAGAnything, RAGAnythingConfig

        # Create working directory
        Path(config.working_dir).mkdir(parents=True, exist_ok=True)

        # RAG-Anything configuration
        rag_config = RAGAnythingConfig(
            working_dir=config.working_dir,
            parser=config.parser,
            enable_image_processing=config.enable_image_processing,
            enable_table_processing=config.enable_table_processing,
            enable_equation_processing=config.enable_equation_processing,
        )

        # Initialize RAG-Anything with our LLM functions
        rag_instance = RAGAnything(
            config=rag_config,
            llm_model_func=llm_model_func,
            vision_model_func=vision_model_func,
            embedding_func=embedding_func,
            embedding_dim=config.embedding_dim
        )

        logger.info("RAG-Anything initialized successfully")

    except ImportError as e:
        logger.warning(f"RAG-Anything not available: {e}")
        rag_instance = None
    except Exception as e:
        logger.error(f"Failed to initialize RAG-Anything: {e}")
        rag_instance = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize on startup"""
    await initialize_rag()
    yield
    logger.info("Shutting down RAG-Anything server")


# FastAPI app
app = FastAPI(
    title="RAG-Anything API",
    description="Multimodal RAG API for document processing and querying",
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


# ============ API Endpoints ============

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    localai_ok = False
    qdrant_ok = False

    # Check LocalAI
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(f"{config.localai_url.replace('/v1', '')}/readyz")
            localai_ok = resp.status_code == 200
    except:
        pass

    # Check Qdrant
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(f"{config.qdrant_url}/collections")
            qdrant_ok = resp.status_code == 200
    except:
        pass

    return HealthResponse(
        status="healthy" if rag_instance else "initializing",
        localai_connected=localai_ok,
        qdrant_connected=qdrant_ok,
        rag_initialized=rag_instance is not None,
        documents_processed=len(processing_status)
    )


@app.post("/documents/upload")
async def upload_document(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...)
):
    """Upload and process a document"""
    if rag_instance is None:
        raise HTTPException(status_code=503, detail="RAG not initialized")

    # Generate document ID
    doc_id = str(uuid.uuid4())

    # Save file
    doc_dir = Path(config.documents_dir) / doc_id
    doc_dir.mkdir(parents=True, exist_ok=True)
    file_path = doc_dir / file.filename

    with open(file_path, "wb") as f:
        content = await file.read()
        f.write(content)

    # Track status
    processing_status[doc_id] = DocumentStatus(
        document_id=doc_id,
        filename=file.filename,
        status="pending",
        progress=0.0,
        created_at=datetime.utcnow().isoformat()
    )

    # Process in background
    background_tasks.add_task(process_document, doc_id, str(file_path))

    return {"document_id": doc_id, "status": "processing"}


async def process_document(doc_id: str, file_path: str):
    """Background task to process document"""
    try:
        processing_status[doc_id].status = "processing"
        processing_status[doc_id].progress = 0.1

        # Process with RAG-Anything
        output_dir = Path(config.working_dir) / doc_id
        output_dir.mkdir(parents=True, exist_ok=True)

        await rag_instance.process_document_complete(
            file_path=file_path,
            output_dir=str(output_dir)
        )

        processing_status[doc_id].status = "completed"
        processing_status[doc_id].progress = 1.0
        logger.info(f"Document {doc_id} processed successfully")

    except Exception as e:
        logger.error(f"Failed to process document {doc_id}: {e}")
        processing_status[doc_id].status = "failed"
        processing_status[doc_id].error = str(e)


@app.get("/documents/{doc_id}/status", response_model=DocumentStatus)
async def get_document_status(doc_id: str):
    """Get document processing status"""
    if doc_id not in processing_status:
        raise HTTPException(status_code=404, detail="Document not found")
    return processing_status[doc_id]


@app.get("/documents")
async def list_documents():
    """List all documents"""
    return {"documents": list(processing_status.values())}


@app.delete("/documents/{doc_id}")
async def delete_document(doc_id: str):
    """Delete a document and its data"""
    if doc_id not in processing_status:
        raise HTTPException(status_code=404, detail="Document not found")

    # Remove files
    doc_dir = Path(config.documents_dir) / doc_id
    if doc_dir.exists():
        shutil.rmtree(doc_dir)

    output_dir = Path(config.working_dir) / doc_id
    if output_dir.exists():
        shutil.rmtree(output_dir)

    del processing_status[doc_id]
    return {"status": "deleted"}


@app.post("/insert")
async def insert_content(request: InsertRequest):
    """Insert text content directly into RAG"""
    if rag_instance is None:
        raise HTTPException(status_code=503, detail="RAG not initialized")

    try:
        await rag_instance.ainsert(
            content=request.content,
            metadata=request.metadata or {},
            doc_id=request.doc_id
        )
        return {"status": "ok", "message": "Content inserted"}
    except Exception as e:
        logger.error(f"Insert failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/query", response_model=QueryResponse)
async def query(request: QueryRequest):
    """Query the RAG system"""
    if rag_instance is None:
        raise HTTPException(status_code=503, detail="RAG not initialized")

    start_time = datetime.utcnow()

    try:
        if request.multimodal:
            result = await rag_instance.aquery_with_multimodal(
                query=request.query,
                mode=request.mode
            )
        else:
            result = await rag_instance.aquery(
                query=request.query,
                mode=request.mode
            )

        processing_time = (datetime.utcnow() - start_time).total_seconds()

        return QueryResponse(
            answer=result if isinstance(result, str) else result.get("answer", str(result)),
            sources=[],
            mode=request.mode,
            processing_time=processing_time
        )

    except Exception as e:
        logger.error(f"Query error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/query/multimodal", response_model=QueryResponse)
async def query_multimodal(request: QueryRequest):
    """Query with multimodal support (tables, images, equations)"""
    request.multimodal = True
    return await query(request)


# ============ Amazon Arbitrage Specific Endpoints ============

class ProductAnalysisRequest(BaseModel):
    product_info: dict
    context_query: str = "Analyze this product for arbitrage opportunity"


@app.post("/analyze/product")
async def analyze_product(request: ProductAnalysisRequest):
    """
    Analyze a product using RAG context
    Useful for getting additional context from stored documents
    """
    if rag_instance is None:
        raise HTTPException(status_code=503, detail="RAG not initialized")

    # Build query with product context
    query_text = f"""
    {request.context_query}

    Product Information:
    - ASIN: {request.product_info.get('asin', 'N/A')}
    - Title: {request.product_info.get('title', 'N/A')}
    - Category: {request.product_info.get('category', 'N/A')}
    - Price US: {request.product_info.get('price_us', 'N/A')}
    - Price CA: {request.product_info.get('price_ca', 'N/A')}
    - BSR: {request.product_info.get('bsr', 'N/A')}

    Based on historical data and patterns, provide analysis.
    """

    try:
        result = await rag_instance.aquery(query=query_text, mode="hybrid")
        return {
            "analysis": result if isinstance(result, str) else result.get("answer", str(result)),
            "product_asin": request.product_info.get('asin')
        }
    except Exception as e:
        logger.error(f"Product analysis error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "RAG-Anything API",
        "version": "1.0.0",
        "docs": "/docs",
        "github": "https://github.com/HKUDS/RAG-Anything"
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
