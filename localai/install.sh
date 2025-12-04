#!/bin/bash
# LocalAI Helm Installation Script
# Helm Chart: cowboysysop/local-ai
# Image: localai/localai (Docker Hub - official)

set -e

NAMESPACE="ai-stack"
RELEASE_NAME="localai"
CHART_REPO="cowboysysop"
CHART_NAME="local-ai"

echo "=== LocalAI Helm Installation ==="
echo "Image: localai/localai:latest-gpu-nvidia-cuda-12"
echo ""

# Namespace kontrolü
kubectl get namespace $NAMESPACE >/dev/null 2>&1 || \
  kubectl create namespace $NAMESPACE

# Helm repo ekle
echo "Adding Helm repo..."
helm repo add $CHART_REPO https://cowboysysop.github.io/charts/ 2>/dev/null || true
helm repo update

# Mevcut kurulumu kontrol et
if helm status $RELEASE_NAME -n $NAMESPACE >/dev/null 2>&1; then
  echo "Upgrading existing installation..."
  helm upgrade $RELEASE_NAME $CHART_REPO/$CHART_NAME \
    -n $NAMESPACE \
    -f values.yaml \
    --wait --timeout 15m
else
  echo "Installing LocalAI..."
  helm install $RELEASE_NAME $CHART_REPO/$CHART_NAME \
    -n $NAMESPACE \
    -f values.yaml \
    --wait --timeout 15m
fi

echo ""
echo "=== Installation Complete ==="
echo "Service: localai.$NAMESPACE.svc.cluster.local:8080"
echo ""
echo "Test with:"
echo "  kubectl run curl --image=curlimages/curl -it --rm -n $NAMESPACE -- \\"
echo "    curl http://localai:8080/v1/models"
echo ""
echo "Note: First startup may take a few minutes while models are downloaded."
