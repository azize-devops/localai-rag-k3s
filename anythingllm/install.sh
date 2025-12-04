#!/bin/bash
# AnythingLLM Helm Installation Script
# Helm Chart: la-cc/anything-llm-helm-chart
# https://github.com/la-cc/anything-llm-helm-chart

set -e

NAMESPACE="ai-stack"
RELEASE_NAME="anythingllm"
CHART_REPO="anythingllm-repo"
CHART_NAME="anything-llm"

echo "=== AnythingLLM Helm Installation ==="

# Namespace kontrolü
kubectl get namespace $NAMESPACE >/dev/null 2>&1 || \
  kubectl create namespace $NAMESPACE

# Helm repo ekle (la-cc/anything-llm-helm-chart)
echo "Adding Helm repo..."
helm repo remove $CHART_REPO 2>/dev/null || true
helm repo add $CHART_REPO https://la-cc.github.io/anything-llm-helm-chart
helm repo update

# Chart'ı listele (debug)
echo "Available charts:"
helm search repo $CHART_REPO

# Mevcut kurulumu kontrol et
if helm status $RELEASE_NAME -n $NAMESPACE >/dev/null 2>&1; then
  echo "Upgrading existing installation..."
  helm upgrade $RELEASE_NAME $CHART_REPO/$CHART_NAME \
    -n $NAMESPACE \
    -f values.yaml \
    --wait --timeout 10m
else
  echo "Installing AnythingLLM..."
  helm install $RELEASE_NAME $CHART_REPO/$CHART_NAME \
    -n $NAMESPACE \
    -f values.yaml \
    --wait --timeout 10m
fi

echo ""
echo "=== Installation Complete ==="
echo "Service: anythingllm.$NAMESPACE.svc.cluster.local:3001"
echo ""
echo "Port forward for local access:"
echo "  kubectl port-forward -n $NAMESPACE svc/anythingllm 3001:3001"
echo "  Then open: http://localhost:3001"
