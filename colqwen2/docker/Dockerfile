# ColQwen2 Docker Image
# Visual Document Embedding Service
# Model: vidore/colqwen2-v1.0

FROM nvidia/cuda:12.1-runtime-ubuntu22.04

LABEL maintainer="Amazon Arbitrage Project"
LABEL description="ColQwen2 Visual Embedding API"
LABEL phase="2"

# Install Python
RUN apt-get update && apt-get install -y \
    python3.11 \
    python3.11-pip \
    python3.11-venv \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/bin/python3.11 /usr/bin/python

WORKDIR /app

# Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Application
COPY server.py .

# Create directories
RUN mkdir -p /models/huggingface /models/transformers

# Non-root user
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app /models
USER appuser

EXPOSE 8001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8001/health || exit 1

CMD ["python", "server.py"]
