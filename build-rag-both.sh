#!/bin/bash
# Build and Push RAG-Anything Docker Images (Both PyPI and GitHub versions)
# Multi-platform build: Mac (arm64) → Ubuntu/Kubernetes (amd64)
#
# Usage: ./build-rag-both.sh
#
# Creates two images:
#   - burhandocker2021/rag-anything:pypi    (stable, from PyPI)
#   - burhandocker2021/rag-anything:github  (latest, from GitHub)
#   - burhandocker2021/rag-anything:latest  (alias for github)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_REGISTRY="burhandocker2021"
RAG_DIR="$SCRIPT_DIR/rag-anything/docker"

# Target platform for Kubernetes (Ubuntu x86_64)
TARGET_PLATFORM="linux/amd64"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  RAG-Anything Build (PyPI + GitHub)${NC}"
echo -e "${GREEN}  Registry: ${DOCKER_REGISTRY}${NC}"
echo -e "${GREEN}  Target: ${TARGET_PLATFORM}${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check Docker login
echo -e "${YELLOW}Checking Docker login...${NC}"
if ! docker info 2>/dev/null | grep -q "Username"; then
    echo -e "${YELLOW}Please login to Docker Hub first:${NC}"
    docker login
fi
echo -e "${GREEN}✓ Docker ready${NC}"
echo ""

# Setup buildx for multi-platform builds
echo -e "${YELLOW}Setting up Docker Buildx...${NC}"
if ! docker buildx inspect multiplatform-builder 2>/dev/null; then
    docker buildx create --name multiplatform-builder --use
else
    docker buildx use multiplatform-builder
fi
docker buildx inspect --bootstrap
echo -e "${GREEN}✓ Buildx ready${NC}"
echo ""

# Verify directory exists
if [ ! -d "$RAG_DIR" ]; then
    echo -e "${RED}Error: RAG-Anything docker directory not found${NC}"
    echo "Expected: $RAG_DIR"
    exit 1
fi

cd "$RAG_DIR"

# Version tag
VERSION=$(date +%Y%m%d-%H%M%S)

# ============================================
# Build PyPI Version
# ============================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Building RAG-Anything (PyPI)${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "${YELLOW}Building and pushing PyPI version...${NC}"
docker buildx build \
    --platform ${TARGET_PLATFORM} \
    --file Dockerfile.pypi \
    --tag ${DOCKER_REGISTRY}/rag-anything:pypi \
    --tag ${DOCKER_REGISTRY}/rag-anything:pypi-${VERSION} \
    --progress=plain \
    --push \
    .

echo -e "${GREEN}✓ PyPI version pushed${NC}"
echo "  - ${DOCKER_REGISTRY}/rag-anything:pypi"
echo "  - ${DOCKER_REGISTRY}/rag-anything:pypi-${VERSION}"
echo ""

# ============================================
# Build GitHub Version
# ============================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Building RAG-Anything (GitHub)${NC}"
echo -e "${BLUE}========================================${NC}"

echo -e "${YELLOW}Building and pushing GitHub version...${NC}"
docker buildx build \
    --platform ${TARGET_PLATFORM} \
    --file Dockerfile.github \
    --tag ${DOCKER_REGISTRY}/rag-anything:github \
    --tag ${DOCKER_REGISTRY}/rag-anything:github-${VERSION} \
    --tag ${DOCKER_REGISTRY}/rag-anything:latest \
    --progress=plain \
    --push \
    .

echo -e "${GREEN}✓ GitHub version pushed${NC}"
echo "  - ${DOCKER_REGISTRY}/rag-anything:github"
echo "  - ${DOCKER_REGISTRY}/rag-anything:github-${VERSION}"
echo "  - ${DOCKER_REGISTRY}/rag-anything:latest"
echo ""

# ============================================
# Summary
# ============================================
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Build Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Available images:${NC}"
echo ""
echo -e "${BLUE}PyPI Version (Stable):${NC}"
echo "  docker pull ${DOCKER_REGISTRY}/rag-anything:pypi"
echo ""
echo -e "${BLUE}GitHub Version (Latest):${NC}"
echo "  docker pull ${DOCKER_REGISTRY}/rag-anything:github"
echo "  docker pull ${DOCKER_REGISTRY}/rag-anything:latest"
echo ""
echo -e "${YELLOW}Usage in Kubernetes:${NC}"
echo "  PyPI:   image: ${DOCKER_REGISTRY}/rag-anything:pypi"
echo "  GitHub: image: ${DOCKER_REGISTRY}/rag-anything:github"
echo ""
echo -e "${YELLOW}Recommendation:${NC}"
echo "  - Production: Use :pypi (stable, tested releases)"
echo "  - Development: Use :github (latest features)"
echo ""
