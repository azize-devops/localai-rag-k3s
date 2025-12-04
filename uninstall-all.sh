#!/bin/bash
# Uninstall AI Stack Components
# Usage:
#   ./uninstall-all.sh                    # Interactive menu
#   ./uninstall-all.sh --all              # Uninstall all components
#   ./uninstall-all.sh --all --include-pvc # Uninstall all + delete PVCs
#   ./uninstall-all.sh localai            # Uninstall specific component
#   ./uninstall-all.sh localai anythingllm # Uninstall multiple components
#
# Components: localai, qdrant, anythingllm, rag-anything, colqwen2

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="ai-stack"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Available components
COMPONENTS=("localai" "qdrant" "anythingllm" "rag-anything" "colqwen2")

# Parse arguments
INCLUDE_PVC=false
UNINSTALL_ALL=false
SELECTED_COMPONENTS=()
FORCE=false

show_help() {
    echo -e "${CYAN}AI Stack Uninstall Script${NC}"
    echo ""
    echo "Usage:"
    echo "  ./uninstall-all.sh                       # Interactive menu"
    echo "  ./uninstall-all.sh --all                 # Uninstall all components"
    echo "  ./uninstall-all.sh --all --include-pvc   # Uninstall all + delete PVCs"
    echo "  ./uninstall-all.sh localai               # Uninstall specific component"
    echo "  ./uninstall-all.sh localai anythingllm   # Uninstall multiple components"
    echo "  ./uninstall-all.sh --force localai       # Skip confirmation"
    echo ""
    echo "Components:"
    echo "  localai       - LocalAI LLM server (Helm)"
    echo "  qdrant        - Qdrant vector database (Helm)"
    echo "  anythingllm   - AnythingLLM RAG UI (Helm)"
    echo "  rag-anything  - RAG-Anything wrapper (Kustomize)"
    echo "  colqwen2      - ColQwen2 visual retrieval (Kustomize)"
    echo ""
    echo "Options:"
    echo "  --all          Uninstall all components"
    echo "  --include-pvc  Also delete PVCs (data will be lost!)"
    echo "  --force, -f    Skip confirmation prompt"
    echo "  --help, -h     Show this help"
}

# Function to uninstall a component
uninstall_component() {
    local component=$1
    local include_pvc=$2

    case $component in
        localai)
            echo -e "${YELLOW}Removing LocalAI...${NC}"
            helm uninstall localai -n $NAMESPACE 2>/dev/null || echo "  LocalAI not installed"
            if [ "$include_pvc" = true ]; then
                kubectl delete pvc -l app.kubernetes.io/name=local-ai -n $NAMESPACE 2>/dev/null || true
                kubectl delete pvc localai-models -n $NAMESPACE 2>/dev/null || true
            fi
            echo -e "${GREEN}  LocalAI removed${NC}"
            ;;
        qdrant)
            echo -e "${YELLOW}Removing Qdrant...${NC}"
            helm uninstall qdrant -n $NAMESPACE 2>/dev/null || echo "  Qdrant not installed"
            if [ "$include_pvc" = true ]; then
                kubectl delete pvc -l app.kubernetes.io/name=qdrant -n $NAMESPACE 2>/dev/null || true
            fi
            echo -e "${GREEN}  Qdrant removed${NC}"
            ;;
        anythingllm)
            echo -e "${YELLOW}Removing AnythingLLM...${NC}"
            helm uninstall anythingllm -n $NAMESPACE 2>/dev/null || echo "  AnythingLLM not installed"
            # Clean up all possible secrets
            kubectl delete secret anythingllm-secrets -n $NAMESPACE 2>/dev/null || true
            kubectl delete secret -l app.kubernetes.io/name=anything-llm -n $NAMESPACE 2>/dev/null || true
            kubectl delete secret -l app.kubernetes.io/instance=anythingllm -n $NAMESPACE 2>/dev/null || true
            if [ "$include_pvc" = true ]; then
                # Clean up all possible PVC names
                kubectl delete pvc -l app.kubernetes.io/name=anything-llm -n $NAMESPACE 2>/dev/null || true
                kubectl delete pvc -l app.kubernetes.io/instance=anythingllm -n $NAMESPACE 2>/dev/null || true
                kubectl delete pvc anythingllm-storage -n $NAMESPACE 2>/dev/null || true
                kubectl delete pvc server-storage -n $NAMESPACE 2>/dev/null || true
            fi
            echo -e "${GREEN}  AnythingLLM removed${NC}"
            ;;
        rag-anything)
            echo -e "${YELLOW}Removing RAG-Anything...${NC}"
            kubectl delete -k "$SCRIPT_DIR/rag-anything/" 2>/dev/null || echo "  RAG-Anything not installed"
            echo -e "${GREEN}  RAG-Anything removed${NC}"
            ;;
        colqwen2)
            echo -e "${YELLOW}Removing ColQwen2...${NC}"
            kubectl delete -k "$SCRIPT_DIR/colqwen2/" 2>/dev/null || echo "  ColQwen2 not installed"
            if [ "$include_pvc" = true ]; then
                kubectl delete pvc -l app=colqwen2 -n $NAMESPACE 2>/dev/null || true
            fi
            echo -e "${GREEN}  ColQwen2 removed${NC}"
            ;;
        *)
            echo -e "${RED}Unknown component: $component${NC}"
            return 1
            ;;
    esac
}

# Interactive menu
show_menu() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  AI Stack Uninstall Menu${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Select component(s) to uninstall:${NC}"
    echo ""
    echo "  1) localai       - LocalAI LLM server"
    echo "  2) qdrant        - Qdrant vector database"
    echo "  3) anythingllm   - AnythingLLM RAG UI"
    echo "  4) rag-anything  - RAG-Anything wrapper"
    echo "  5) colqwen2      - ColQwen2 visual retrieval"
    echo ""
    echo "  a) ALL           - Uninstall everything"
    echo "  q) QUIT          - Exit without changes"
    echo ""
    echo -e "${YELLOW}Enter choice(s) separated by space (e.g., '1 3' or 'a'):${NC}"
    read -r choices

    if [[ "$choices" == "q" || "$choices" == "Q" ]]; then
        echo "Aborted."
        exit 0
    fi

    if [[ "$choices" == "a" || "$choices" == "A" ]]; then
        SELECTED_COMPONENTS=("${COMPONENTS[@]}")
    else
        for choice in $choices; do
            case $choice in
                1) SELECTED_COMPONENTS+=("localai") ;;
                2) SELECTED_COMPONENTS+=("qdrant") ;;
                3) SELECTED_COMPONENTS+=("anythingllm") ;;
                4) SELECTED_COMPONENTS+=("rag-anything") ;;
                5) SELECTED_COMPONENTS+=("colqwen2") ;;
                *) echo -e "${RED}Invalid choice: $choice${NC}" ;;
            esac
        done
    fi

    if [ ${#SELECTED_COMPONENTS[@]} -eq 0 ]; then
        echo -e "${RED}No valid components selected.${NC}"
        exit 1
    fi

    # Ask about PVC
    echo ""
    echo -e "${YELLOW}Also delete PVCs (persistent data)? (y/N)${NC}"
    read -r pvc_choice
    if [[ "$pvc_choice" =~ ^[Yy]$ ]]; then
        INCLUDE_PVC=true
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            UNINSTALL_ALL=true
            shift
            ;;
        --include-pvc)
            INCLUDE_PVC=true
            shift
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            # Check if it's a valid component
            valid=false
            for comp in "${COMPONENTS[@]}"; do
                if [[ "$1" == "$comp" ]]; then
                    SELECTED_COMPONENTS+=("$1")
                    valid=true
                    break
                fi
            done
            if [ "$valid" = false ]; then
                echo -e "${RED}Unknown option or component: $1${NC}"
                echo ""
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Determine what to uninstall
if [ "$UNINSTALL_ALL" = true ]; then
    SELECTED_COMPONENTS=("${COMPONENTS[@]}")
elif [ ${#SELECTED_COMPONENTS[@]} -eq 0 ]; then
    # No arguments - show interactive menu
    show_menu
fi

# Show what will be uninstalled
echo ""
echo -e "${RED}========================================${NC}"
echo -e "${RED}  AI Stack Uninstall${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo -e "${YELLOW}Components to uninstall:${NC}"
for comp in "${SELECTED_COMPONENTS[@]}"; do
    echo "  - $comp"
done
if [ "$INCLUDE_PVC" = true ]; then
    echo ""
    echo -e "${RED}WARNING: PVCs will be deleted (data loss!)${NC}"
fi
echo ""

# Confirmation
if [ "$FORCE" = false ]; then
    read -p "Are you sure you want to proceed? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

echo ""

# Uninstall selected components
for comp in "${SELECTED_COMPONENTS[@]}"; do
    uninstall_component "$comp" "$INCLUDE_PVC"
done

# Clean up any remaining PVCs if --include-pvc and --all
if [ "$INCLUDE_PVC" = true ] && [ "$UNINSTALL_ALL" = true ]; then
    echo ""
    echo -e "${YELLOW}Cleaning up any remaining PVCs...${NC}"
    kubectl delete pvc --all -n $NAMESPACE 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Uninstall Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check remaining resources
echo -e "${YELLOW}Remaining resources in namespace:${NC}"
kubectl get all -n $NAMESPACE 2>/dev/null || echo "Namespace empty or not found"
echo ""
kubectl get pvc -n $NAMESPACE 2>/dev/null || echo "No PVCs found"
