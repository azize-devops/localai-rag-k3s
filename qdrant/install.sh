#!/bin/bash
# Qdrant Helm Installation Script
# Helm Chart: qdrant/qdrant

set -e

NAMESPACE="ai-stack"
RELEASE_NAME="qdrant"
CHART_REPO="qdrant"
CHART_NAME="qdrant"

echo "=== Qdrant Helm Installation ==="

# Namespace kontrolü
kubectl get namespace $NAMESPACE >/dev/null 2>&1 || \
  kubectl create namespace $NAMESPACE

# Helm repo ekle
echo "Adding Helm repo..."
helm repo add $CHART_REPO https://qdrant.github.io/qdrant-helm 2>/dev/null || true
helm repo update

# Mevcut kurulumu kontrol et
if helm status $RELEASE_NAME -n $NAMESPACE >/dev/null 2>&1; then
  echo "Upgrading existing installation..."
  helm upgrade $RELEASE_NAME $CHART_REPO/$CHART_NAME \
    -n $NAMESPACE \
    -f values.yaml \
    --wait
else
  echo "Installing Qdrant..."
  helm install $RELEASE_NAME $CHART_REPO/$CHART_NAME \
    -n $NAMESPACE \
    -f values.yaml \
    --wait
fi

echo ""
echo "=== Installation Complete ==="
echo "HTTP: qdrant.$NAMESPACE.svc.cluster.local:6333"
echo "gRPC: qdrant.$NAMESPACE.svc.cluster.local:6334"
echo ""
echo "Test with:"
echo "  kubectl run curl --image=curlimages/curl -it --rm -n $NAMESPACE -- \\"
echo "    curl http://qdrant:6333/collections"
