# ColQwen2 Visual Embedding Service

**Faz 2 - Sprint 21-23**

ColQwen2 görsel doküman embedding servisi. Keepa grafikleri ve ürün görsellerini analiz etmek için kullanılır.

## Model Bilgisi

| Model | HuggingFace | VRAM | Latency |
|-------|-------------|------|---------|
| ColQwen2 | [vidore/colqwen2-v1.0](https://huggingface.co/vidore/colqwen2-v1.0) | 8GB (FP16) | ~45ms |
| ColQwen2 INT8 | Quantized | 4GB | ~60ms |

## Ön Gereksinimler

- **GPU Node**: En az 8GB VRAM (RTX 3070+, A4000+)
- **NVIDIA Driver**: 525.60+
- **nvidia-device-plugin**: Kubernetes'te kurulu

## Kurulum

### 1. GPU Node Labeling
```bash
kubectl label nodes <gpu-node-name> gpu=true nvidia.com/gpu=present
```

### 2. Docker Image Build
```bash
cd docker
docker build -t colqwen2:latest .
docker tag colqwen2:latest your-registry/colqwen2:latest
docker push your-registry/colqwen2:latest
```

### 3. Kustomization Güncelle
```yaml
# kustomization.yaml
images:
  - name: colqwen2
    newName: your-registry/colqwen2
    newTag: latest
```

### 4. Deploy
```bash
kubectl apply -k .
```

## API Endpoints

```
POST /embed
  Body: {"image": "base64_encoded_image"}
  Response: {"embedding": [0.1, 0.2, ...], "dim": 128}

POST /embed_batch
  Body: {"images": ["base64_1", "base64_2"]}
  Response: {"embeddings": [[...], [...]], "count": 2}

GET /health
  Response: {"status": "healthy", "gpu_available": true, "model_loaded": true}
```

## Qdrant Entegrasyonu

ColQwen2 embeddingleri için ayrı collection:
```
Collection: visual_embeddings
Dimension: 128 (ColQwen2 default)
Distance: Cosine
```

## Kaynak Gereksinimleri

| Resource | Request | Limit |
|----------|---------|-------|
| CPU | 2 | 4 |
| Memory | 8Gi | 16Gi |
| GPU | 1 | 1 |

## Troubleshooting

```bash
# GPU durumu
kubectl exec -n ai-stack deploy/colqwen2 -- nvidia-smi

# Model yüklenme durumu
kubectl logs -n ai-stack -l app=colqwen2 --tail=100

# Health check
kubectl run curl --image=curlimages/curl -it --rm -n ai-stack -- \
  curl http://colqwen2:8001/health
```
