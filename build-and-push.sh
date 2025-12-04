#!/bin/bash
# Build and Push Docker Images to Docker Hub
# Multi-platform build: Mac (arm64) → Ubuntu/Kubernetes (amd64)
#
# Usage: ./build-and-push.sh [--rag-only] [--colqwen2-only] [--all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_REGISTRY="burhandocker2021"

# Target platform for Kubernetes (Ubuntu x86_64)
TARGET_PLATFORM="linux/amd64"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse arguments
BUILD_RAG=false
BUILD_COLQWEN2=false

if [ $# -eq 0 ] || [ "$1" == "--all" ]; then
    BUILD_RAG=true
    BUILD_COLQWEN2=true
elif [ "$1" == "--rag-only" ]; then
    BUILD_RAG=true
elif [ "$1" == "--colqwen2-only" ]; then
    BUILD_COLQWEN2=true
else
    echo "Usage: ./build-and-push.sh [--rag-only] [--colqwen2-only] [--all]"
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Docker Build & Push (Multi-Platform)${NC}"
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

# Build RAG-Anything
if [ "$BUILD_RAG" = true ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Building RAG-Anything (${TARGET_PLATFORM})${NC}"
    echo -e "${GREEN}========================================${NC}"

    RAG_DIR="$SCRIPT_DIR/rag-anything/docker"

    if [ ! -d "$RAG_DIR" ]; then
        echo -e "${RED}Error: RAG-Anything docker directory not found${NC}"
        echo "Expected: $RAG_DIR"
        exit 1
    fi

    cd "$RAG_DIR"

    # Version tag
    VERSION=$(date +%Y%m%d-%H%M%S)

    # Build and push with buildx (multi-platform)
    echo -e "${YELLOW}Building and pushing image...${NC}"
    docker buildx build \
        --platform ${TARGET_PLATFORM} \
        --tag ${DOCKER_REGISTRY}/rag-anything:latest \
        --tag ${DOCKER_REGISTRY}/rag-anything:${VERSION} \
        --push \
        .

    echo -e "${GREEN}✓ RAG-Anything pushed successfully${NC}"
    echo "  - ${DOCKER_REGISTRY}/rag-anything:latest"
    echo "  - ${DOCKER_REGISTRY}/rag-anything:${VERSION}"
    echo ""
fi

# Build ColQwen2
if [ "$BUILD_COLQWEN2" = true ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Building ColQwen2 (${TARGET_PLATFORM})${NC}"
    echo -e "${GREEN}========================================${NC}"

    COLQWEN2_DIR="$SCRIPT_DIR/colqwen2/docker"

    if [ ! -d "$COLQWEN2_DIR" ]; then
        echo -e "${RED}Error: ColQwen2 docker directory not found${NC}"
        echo "Expected: $COLQWEN2_DIR"
        exit 1
    fi

    cd "$COLQWEN2_DIR"

    # Version tag
    VERSION=$(date +%Y%m%d-%H%M%S)

    # Build and push with buildx (multi-platform)
    echo -e "${YELLOW}Building and pushing image...${NC}"
    docker buildx build \
        --platform ${TARGET_PLATFORM} \
        --tag ${DOCKER_REGISTRY}/colqwen2:latest \
        --tag ${DOCKER_REGISTRY}/colqwen2:${VERSION} \
        --push \
        .

    echo -e "${GREEN}✓ ColQwen2 pushed successfully${NC}"
    echo "  - ${DOCKER_REGISTRY}/colqwen2:latest"
    echo "  - ${DOCKER_REGISTRY}/colqwen2:${VERSION}"
    echo ""
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Build & Push Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Platform: ${TARGET_PLATFORM} (Ubuntu/Kubernetes compatible)${NC}"
echo ""
echo "Images are now available on Docker Hub:"
if [ "$BUILD_RAG" = true ]; then
    echo "  - docker pull ${DOCKER_REGISTRY}/rag-anything:latest"
fi
if [ "$BUILD_COLQWEN2" = true ]; then
    echo "  - docker pull ${DOCKER_REGISTRY}/colqwen2:latest"
fi
echo ""
