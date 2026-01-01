# Kubernetes AI Stack Deployment

Bu dizin Amazon Arbitrage projesinin AI altyapısını Kubernetes'e deploy etmek için gerekli dosyaları içerir.

## Ön Gereksinimler

- Kubernetes cluster (1.25+)
- Helm 3.x
- Longhorn (StorageClass: `longhorn-xfs-strg1`)
- kubectl erişimi

## Dizin Yapısı

```
kubernetes/
├── namespace/          # Namespace tanımı
├── localai/            # LocalAI (Helm)
├── qdrant/             # Qdrant Vector DB (Helm)
├── anythingllm/        # AnythingLLM (Helm)
├── rag-anything/       # RAG-Anything (Custom Manifest)
├── colqwen2/           # ColQwen2 VLM (Custom Manifest) - Faz 2
├── deploy-all.sh       # Tek komutla tüm stack'i deploy et
└── README.md
```

## Hızlı Başlangıç

### 1. Namespace Oluştur
```bash
kubectl apply -f namespace/namespace.yaml
```

### 2. Tüm Bileşenleri Deploy Et
```bash
./deploy-all.sh
```

### Veya Tek Tek Deploy

```bash
# LocalAI (Helm)
cd localai && ./install.sh

# Qdrant (Helm)
cd qdrant && ./install.sh

# AnythingLLM (Helm)
cd anythingllm && ./install.sh

# RAG-Anything (Custom)
kubectl apply -f rag-anything/
```

## Bileşenler

| Bileşen | Tip | Port | Açıklama |
|---------|-----|------|----------|
| LocalAI | Helm | 8080 | OpenAI-compatible LLM |
| Qdrant | Helm | 6333, 6334 | Vector Database |
| AnythingLLM | Helm | 3001 | RAG UI & Debug |
| RAG-Anything | Manifest | 8000 | Multi-modal RAG API |
| ColQwen2 | Manifest | 8001 | Visual Embedding (Faz 2) |

## Storage

Tüm PVC'ler `longhorn-xfs-strg1` StorageClass kullanır:

| Bileşen | PVC | Boyut |
|---------|-----|-------|
| LocalAI | localai-models | 50Gi |
| Qdrant | qdrant-storage | 20Gi |
| AnythingLLM | anythingllm-storage | 10Gi |
| RAG-Anything | rag-anything-data | 10Gi |

## Servis Erişimi

Cluster içi erişim:
```
http://localai.ai-stack.svc.cluster.local:8080
http://qdrant.ai-stack.svc.cluster.local:6333
http://anythingllm.ai-stack.svc.cluster.local:3001
http://rag-anything.ai-stack.svc.cluster.local:8000
```

## Kaynak Gereksinimleri

| Bileşen | CPU Request | Memory Request | GPU |
|---------|-------------|----------------|-----|
| LocalAI | 2 | 4Gi | Opsiyonel |
| Qdrant | 500m | 1Gi | - |
| AnythingLLM | 500m | 1Gi | - |
| RAG-Anything | 1 | 2Gi | - |
| ColQwen2 | 2 | 8Gi | Önerilen |

## Troubleshooting

```bash
# Pod durumlarını kontrol et
kubectl get pods -n ai-stack

# Logları görüntüle
kubectl logs -n ai-stack -l app=localai
kubectl logs -n ai-stack -l app=qdrant

# Servis erişimini test et
kubectl run curl --image=curlimages/curl -it --rm -- \
  curl http://localai.ai-stack.svc.cluster.local:8080/v1/models
```
