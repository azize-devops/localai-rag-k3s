#!/bin/bash
# Deploy All AI Stack Components
# Usage: ./deploy-all.sh [--phase1-only] [--include-phase2]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="ai-stack"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
PHASE1_ONLY=false
INCLUDE_PHASE2=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --phase1-only)
      PHASE1_ONLY=true
      shift
      ;;
    --include-phase2)
      INCLUDE_PHASE2=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: ./deploy-all.sh [--phase1-only] [--include-phase2]"
      exit 1
      ;;
  esac
done

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  AI Stack Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found${NC}"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo -e "${RED}Error: helm not found${NC}"
    exit 1
fi

# Check cluster connection
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites OK${NC}"
echo ""

# Create namespace
echo -e "${YELLOW}Creating namespace...${NC}"
kubectl apply -f "$SCRIPT_DIR/namespace/namespace.yaml"
echo -e "${GREEN}✓ Namespace created${NC}"
echo ""

# ===== FAZ 1: Core AI Stack =====
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  FAZ 1: Core AI Stack${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 1. Qdrant (Vector DB - needed first)
echo -e "${YELLOW}[1/4] Deploying Qdrant...${NC}"
cd "$SCRIPT_DIR/qdrant"
chmod +x install.sh
./install.sh
echo -e "${GREEN}✓ Qdrant deployed${NC}"
echo ""

# 2. LocalAI (LLM Engine)
echo -e "${YELLOW}[2/4] Deploying LocalAI...${NC}"
cd "$SCRIPT_DIR/localai"
chmod +x install.sh
./install.sh
echo -e "${GREEN}✓ LocalAI deployed${NC}"
echo ""

# 3. AnythingLLM (UI)
echo -e "${YELLOW}[3/4] Deploying AnythingLLM...${NC}"
cd "$SCRIPT_DIR/anythingllm"
chmod +x install.sh
./install.sh
echo -e "${GREEN}✓ AnythingLLM deployed${NC}"
echo ""

# 4. RAG-Anything (Custom)
echo -e "${YELLOW}[4/4] Deploying RAG-Anything...${NC}"
kubectl apply -k "$SCRIPT_DIR/rag-anything/"
echo -e "${GREEN}✓ RAG-Anything deployed${NC}"
echo ""

# ===== FAZ 2: Visual Embedding (Optional) =====
if [ "$INCLUDE_PHASE2" = true ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  FAZ 2: Visual Embedding${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    # Check for GPU node
    GPU_NODES=$(kubectl get nodes -l gpu=true -o name 2>/dev/null | wc -l)
    if [ "$GPU_NODES" -eq 0 ]; then
        echo -e "${YELLOW}Warning: No GPU nodes found (label: gpu=true)${NC}"
        echo -e "${YELLOW}ColQwen2 requires GPU. Skipping...${NC}"
    else
        echo -e "${YELLOW}[1/1] Deploying ColQwen2...${NC}"
        kubectl apply -k "$SCRIPT_DIR/colqwen2/"
        echo -e "${GREEN}✓ ColQwen2 deployed${NC}"
    fi
    echo ""
fi

# ===== Verification =====
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${YELLOW}Waiting for pods to be ready...${NC}"
sleep 10

echo ""
echo -e "${YELLOW}Pod Status:${NC}"
kubectl get pods -n $NAMESPACE

echo ""
echo -e "${YELLOW}Services:${NC}"
kubectl get svc -n $NAMESPACE

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Endpoints${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "LocalAI:      http://localai.$NAMESPACE.svc.cluster.local:8080"
echo "Qdrant:       http://qdrant.$NAMESPACE.svc.cluster.local:6333"
echo "AnythingLLM:  http://anythingllm.$NAMESPACE.svc.cluster.local:3001"
echo "RAG-Anything: http://rag-anything.$NAMESPACE.svc.cluster.local:8000"
if [ "$INCLUDE_PHASE2" = true ]; then
    echo "ColQwen2:     http://colqwen2.$NAMESPACE.svc.cluster.local:8001"
fi
echo ""
echo -e "${GREEN}Port forward for local access:${NC}"
echo "  kubectl port-forward -n $NAMESPACE svc/anythingllm 3001:3001"
echo ""
