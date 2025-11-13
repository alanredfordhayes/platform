#!/bin/bash

# Argo CD Minikube Installation/Uninstallation Script
# Handles both fresh installations and updates to existing installations
# Can be run multiple times safely (idempotent)

set -o pipefail

# Default action is install
ACTION="${1:-install}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
MANIFEST_URL="${MANIFEST_URL:-https://raw.githubusercontent.com/argoproj/argo-cd/master/manifests/install.yaml}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

print_warning() {
    echo -e "${BLUE}⚠${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [install|uninstall|status] [options]

Commands:
  install     Install or update Argo CD (default)
  uninstall   Remove Argo CD completely
  status      Show current Argo CD status

Options:
  -n, --namespace NAMESPACE    Kubernetes namespace (default: argocd)
  -h, --help                   Show this help message

Environment Variables:
  ARGOCD_NAMESPACE             Kubernetes namespace (default: argocd)
  MANIFEST_URL                 Argo CD manifest URL

Examples:
  $0                    # Install Argo CD
  $0 install            # Install Argo CD
  $0 uninstall          # Uninstall Argo CD
  $0 status             # Show status
  $0 -n my-namespace    # Install in custom namespace

EOF
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command_exists minikube; then
        print_error "minikube is not installed. Please install minikube first."
        return 1
    fi
    
    if ! command_exists kubectl; then
        print_error "kubectl is not installed. Please install kubectl first."
        return 1
    fi
    
    print_success "Prerequisites check passed"
    return 0
}

# Function to ensure minikube is running
ensure_minikube_running() {
    print_info "Checking minikube status..."
    if ! minikube status > /dev/null 2>&1; then
        print_warning "Minikube is not running. Starting minikube..."
        if minikube start; then
            print_success "Minikube started"
        else
            print_error "Failed to start minikube"
            return 1
        fi
    else
        print_success "Minikube is running"
    fi
    return 0
}

# Function to ensure kubectl context is set to minikube
ensure_minikube_context() {
    print_info "Verifying kubectl context..."
    CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")
    if [ -z "$CURRENT_CONTEXT" ]; then
        print_error "No kubectl context found"
        return 1
    fi
    
    if [[ "$CURRENT_CONTEXT" != *"minikube"* ]]; then
        print_warning "Current context is not minikube: $CURRENT_CONTEXT"
        print_info "Switching to minikube context..."
        if kubectl config use-context minikube >/dev/null 2>&1; then
            print_success "Switched to minikube context"
        else
            print_error "Failed to switch to minikube context"
            return 1
        fi
    else
        print_success "Using minikube context: $CURRENT_CONTEXT"
    fi
    return 0
}

# Function to wait for a resource with timeout
wait_for_resource() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3
    local timeout=${4:-300}
    local condition=${5:-condition=available}
    
    print_info "Waiting for $resource_type/$resource_name to be ready (timeout: ${timeout}s)..."
    if kubectl wait --for=$condition --timeout=${timeout}s $resource_type/$resource_name -n $namespace >/dev/null 2>&1; then
        print_success "$resource_type/$resource_name is ready"
        return 0
    else
        print_warning "$resource_type/$resource_name not ready within timeout"
        return 1
    fi
}

# Function to clean up duplicate or stuck pods
cleanup_duplicate_pods() {
    local namespace=$1
    print_info "Checking for duplicate or stuck pods..."
    
    # Get pods in error states
    local error_pods=$(kubectl get pods -n $namespace -o jsonpath='{range .items[?(@.status.phase!="Running" && @.status.phase!="Succeeded")]}{.metadata.name}{"\n"}{end}' 2>/dev/null)
    
    if [ -n "$error_pods" ]; then
        print_warning "Found pods in error states. Attempting to restart deployments/statefulsets..."
        
        # Restart all deployments
        for deployment in $(kubectl get deployments -n $namespace -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
            print_info "Restarting deployment: $deployment"
            kubectl rollout restart deployment/$deployment -n $namespace >/dev/null 2>&1 || true
        done
        
        # Restart statefulsets
        for statefulset in $(kubectl get statefulsets -n $namespace -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
            print_info "Restarting statefulset: $statefulset"
            kubectl rollout restart statefulset/$statefulset -n $namespace >/dev/null 2>&1 || true
        done
        
        # Wait a bit for restarts to initiate
        sleep 5
    fi
}

# Function to install Argo CD
install_argocd() {
    echo "🚀 Argo CD Minikube Installation"
    echo "=================================="
    echo ""
    
    # Check prerequisites
    if ! check_prerequisites; then
        return 1
    fi
    
    # Ensure minikube is running
    if ! ensure_minikube_running; then
        return 1
    fi
    
    # Ensure kubectl context
    if ! ensure_minikube_context; then
        return 1
    fi
    
    # Check for existing Argo CD installation
    print_info "Checking for existing Argo CD installation..."
    ARGOCD_EXISTS=false
    if kubectl get namespace "$ARGOCD_NAMESPACE" > /dev/null 2>&1; then
        if kubectl get deployments -n "$ARGOCD_NAMESPACE" > /dev/null 2>&1 || kubectl get statefulsets -n "$ARGOCD_NAMESPACE" > /dev/null 2>&1; then
            ARGOCD_EXISTS=true
            print_warning "Argo CD appears to be already installed in the $ARGOCD_NAMESPACE namespace"
            print_info "This script will update the existing installation"
        else
            print_info "Namespace '$ARGOCD_NAMESPACE' exists but no deployments found"
        fi
    else
        print_info "No existing Argo CD installation found"
    fi
    
    # Create namespace if it doesn't exist
    if ! kubectl get namespace "$ARGOCD_NAMESPACE" > /dev/null 2>&1; then
        print_info "Creating $ARGOCD_NAMESPACE namespace..."
        if kubectl create namespace "$ARGOCD_NAMESPACE"; then
            print_success "Namespace '$ARGOCD_NAMESPACE' created"
        else
            print_error "Failed to create namespace"
            return 1
        fi
    else
        print_success "Namespace '$ARGOCD_NAMESPACE' already exists"
    fi
    
    # Clean up any duplicate or stuck pods if Argo CD exists
    if [ "$ARGOCD_EXISTS" = true ]; then
        cleanup_duplicate_pods "$ARGOCD_NAMESPACE"
    fi
    
    # Apply Argo CD manifest
    print_info "Downloading and applying Argo CD installation manifest..."
    if kubectl apply -n "$ARGOCD_NAMESPACE" -f "$MANIFEST_URL"; then
        print_success "Argo CD manifest applied"
    else
        print_error "Failed to apply Argo CD manifest"
        return 1
    fi
    
    # Wait for deployments and statefulsets individually
    print_info "Waiting for Argo CD components to be ready (this may take several minutes)..."
    
    # Get list of deployments
    DEPLOYMENTS=$(kubectl get deployments -n "$ARGOCD_NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    DEPLOYMENT_COUNT=0
    DEPLOYMENT_SUCCESS=0
    
    if [ -n "$DEPLOYMENTS" ]; then
        for deployment in $DEPLOYMENTS; do
            DEPLOYMENT_COUNT=$((DEPLOYMENT_COUNT + 1))
            if wait_for_resource "deployment" "$deployment" "$ARGOCD_NAMESPACE" 600; then
                DEPLOYMENT_SUCCESS=$((DEPLOYMENT_SUCCESS + 1))
            fi
        done
    fi
    
    # Get list of statefulsets
    STATEFULSETS=$(kubectl get statefulsets -n "$ARGOCD_NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    STATEFULSET_COUNT=0
    STATEFULSET_SUCCESS=0
    
    if [ -n "$STATEFULSETS" ]; then
        for statefulset in $STATEFULSETS; do
            STATEFULSET_COUNT=$((STATEFULSET_COUNT + 1))
            if wait_for_resource "statefulset" "$statefulset" "$ARGOCD_NAMESPACE" 600; then
                STATEFULSET_SUCCESS=$((STATEFULSET_SUCCESS + 1))
            fi
        done
    fi
    
    # Summary of readiness
    echo ""
    print_info "Readiness Summary:"
    echo "  Deployments: $DEPLOYMENT_SUCCESS/$DEPLOYMENT_COUNT ready"
    echo "  Statefulsets: $STATEFULSET_SUCCESS/$STATEFULSET_COUNT ready"
    
    # Check for pod issues
    print_info "Checking pod status..."
    POD_STATUS=$(kubectl get pods -n "$ARGOCD_NAMESPACE" --no-headers 2>/dev/null | awk '{print $3}' | sort | uniq -c)
    
    if echo "$POD_STATUS" | grep -q "CrashLoopBackOff\|Error\|Pending"; then
        print_warning "Some pods are in error states. Checking details..."
        kubectl get pods -n "$ARGOCD_NAMESPACE" | grep -E "CrashLoopBackOff|Error|Pending" || true
        
        echo ""
        print_info "To diagnose issues, check pod logs:"
        echo "  kubectl logs <pod-name> -n $ARGOCD_NAMESPACE"
        echo ""
        print_info "Common issues:"
        echo "  - Port conflicts: Delete old pods or restart deployments"
        echo "  - Resource constraints: Check minikube resources"
        echo "  - Image pull errors: Check network connectivity"
    else
        print_success "All pods appear to be running or completed"
    fi
    
    # Get admin password
    print_info "Retrieving initial admin password..."
    ADMIN_PASSWORD=""
    MAX_RETRIES=5
    RETRY_COUNT=0
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        ADMIN_PASSWORD=$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null)
        
        if [ -n "$ADMIN_PASSWORD" ] && [ "$ADMIN_PASSWORD" != "null" ]; then
            break
        fi
        
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            print_info "Password secret not ready yet, waiting 10 seconds... (attempt $RETRY_COUNT/$MAX_RETRIES)"
            sleep 10
        fi
    done
    
    # Display results
    echo ""
    echo "=========================================="
    if [ -n "$ADMIN_PASSWORD" ] && [ "$ADMIN_PASSWORD" != "null" ]; then
        echo "📋 Argo CD Installation Complete!"
        echo "=========================================="
        echo ""
        echo "Admin Username: admin"
        echo "Admin Password: $ADMIN_PASSWORD"
        echo ""
        echo "To access Argo CD UI:"
        echo "  1. Run: kubectl port-forward svc/argocd-server -n $ARGOCD_NAMESPACE 8080:443"
        echo "  2. Open: https://localhost:8080"
        echo "  3. Login with username 'admin' and the password above"
        echo ""
        print_success "Installation completed successfully!"
    else
        echo "⚠️  Argo CD Installation Status"
        echo "=========================================="
        echo ""
        print_warning "Could not retrieve admin password automatically."
        echo ""
        echo "The secret may not be ready yet. Try running:"
        echo "  kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
        echo ""
        print_info "Installation may still be in progress. Check pod status below."
    fi
    
    # Show current status
    echo ""
    print_info "Current Argo CD pod status:"
    kubectl get pods -n "$ARGOCD_NAMESPACE" 2>/dev/null || print_error "Failed to get pod status"
    
    echo ""
    print_info "Current Argo CD service status:"
    kubectl get svc -n "$ARGOCD_NAMESPACE" 2>/dev/null || print_error "Failed to get service status"
    
    echo ""
    print_info "Useful commands:"
    echo "  Check pods:        kubectl get pods -n $ARGOCD_NAMESPACE"
    echo "  Check services:    kubectl get svc -n $ARGOCD_NAMESPACE"
    echo "  Check logs:        kubectl logs <pod-name> -n $ARGOCD_NAMESPACE"
    echo "  Port forward:      kubectl port-forward svc/argocd-server -n $ARGOCD_NAMESPACE 8080:443"
    echo "  Get admin password: kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
    
    echo ""
    print_info "Script execution completed!"
    return 0
}

# Function to uninstall Argo CD
uninstall_argocd() {
    echo "🗑️  Argo CD Minikube Uninstallation"
    echo "==================================="
    echo ""
    
    # Check prerequisites
    if ! check_prerequisites; then
        return 1
    fi
    
    # Check if namespace exists
    if ! kubectl get namespace "$ARGOCD_NAMESPACE" > /dev/null 2>&1; then
        print_warning "Namespace '$ARGOCD_NAMESPACE' does not exist. Argo CD may not be installed."
        return 0
    fi
    
    # Check if Argo CD is installed
    if ! kubectl get deployments -n "$ARGOCD_NAMESPACE" > /dev/null 2>&1 && ! kubectl get statefulsets -n "$ARGOCD_NAMESPACE" > /dev/null 2>&1; then
        print_warning "No Argo CD deployments or statefulsets found in namespace '$ARGOCD_NAMESPACE'"
        read -p "Do you want to delete the namespace anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Uninstallation cancelled"
            return 0
        fi
    else
        print_warning "This will delete all Argo CD resources in the '$ARGOCD_NAMESPACE' namespace"
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Uninstallation cancelled"
            return 0
        fi
    fi
    
    print_info "Deleting Argo CD resources..."
    
    # Delete using the manifest (this will remove all resources defined in the manifest)
    print_info "Removing resources from manifest..."
    if kubectl delete -n "$ARGOCD_NAMESPACE" -f "$MANIFEST_URL" >/dev/null 2>&1; then
        print_success "Resources from manifest deleted"
    else
        print_warning "Some resources from manifest may not exist (this is okay)"
    fi
    
    # Delete any remaining CRDs (they may not be in the manifest)
    print_info "Removing CustomResourceDefinitions..."
    kubectl delete crd applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io 2>/dev/null || true
    
    # Delete any remaining cluster resources
    print_info "Removing cluster-level resources..."
    kubectl delete clusterrole,clusterrolebinding -l app.kubernetes.io/part-of=argocd 2>/dev/null || true
    
    # Wait for resources to be deleted
    print_info "Waiting for resources to be deleted..."
    sleep 5
    
    # Check if namespace is empty (except for finalizers)
    print_info "Checking if namespace can be deleted..."
    
    # Force delete any remaining pods with finalizers
    PODS=$(kubectl get pods -n "$ARGOCD_NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    if [ -n "$PODS" ]; then
        print_info "Force deleting remaining pods..."
        for pod in $PODS; do
            kubectl delete pod "$pod" -n "$ARGOCD_NAMESPACE" --force --grace-period=0 2>/dev/null || true
        done
    fi
    
    # Delete the namespace
    print_info "Deleting namespace '$ARGOCD_NAMESPACE'..."
    if kubectl delete namespace "$ARGOCD_NAMESPACE" --timeout=60s 2>/dev/null; then
        print_success "Namespace '$ARGOCD_NAMESPACE' deleted"
    else
        print_warning "Namespace deletion may still be in progress (finalizers may delay deletion)"
        print_info "You can check status with: kubectl get namespace $ARGOCD_NAMESPACE"
    fi
    
    echo ""
    echo "=========================================="
    echo "🗑️  Argo CD Uninstallation Complete!"
    echo "=========================================="
    echo ""
    print_success "Argo CD has been removed from your cluster"
    echo ""
    print_info "Note: Some cluster-level resources (CRDs, ClusterRoles) may still exist."
    echo "To remove them completely, run:"
    echo "  kubectl delete crd applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io"
    echo "  kubectl delete clusterrole,clusterrolebinding -l app.kubernetes.io/part-of=argocd"
    echo ""
    
    return 0
}

# Function to show Argo CD status
show_status() {
    echo "📊 Argo CD Status"
    echo "================"
    echo ""
    
    # Check if namespace exists
    if ! kubectl get namespace "$ARGOCD_NAMESPACE" > /dev/null 2>&1; then
        print_warning "Namespace '$ARGOCD_NAMESPACE' does not exist. Argo CD is not installed."
        return 0
    fi
    
    print_info "Namespace: $ARGOCD_NAMESPACE"
    echo ""
    
    # Show deployments
    print_info "Deployments:"
    kubectl get deployments -n "$ARGOCD_NAMESPACE" 2>/dev/null || print_warning "No deployments found"
    echo ""
    
    # Show statefulsets
    print_info "StatefulSets:"
    kubectl get statefulsets -n "$ARGOCD_NAMESPACE" 2>/dev/null || print_warning "No statefulsets found"
    echo ""
    
    # Show pods
    print_info "Pods:"
    kubectl get pods -n "$ARGOCD_NAMESPACE" 2>/dev/null || print_warning "No pods found"
    echo ""
    
    # Show services
    print_info "Services:"
    kubectl get svc -n "$ARGOCD_NAMESPACE" 2>/dev/null || print_warning "No services found"
    echo ""
    
    # Try to get admin password
    ADMIN_PASSWORD=$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null)
    if [ -n "$ADMIN_PASSWORD" ] && [ "$ADMIN_PASSWORD" != "null" ]; then
        print_info "Admin Credentials:"
        echo "  Username: admin"
        echo "  Password: $ADMIN_PASSWORD"
        echo ""
    fi
    
    return 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        install|uninstall|status)
            ACTION="$1"
            shift
            ;;
        -n|--namespace)
            ARGOCD_NAMESPACE="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Execute the requested action
case "$ACTION" in
    install)
        install_argocd
        exit $?
        ;;
    uninstall)
        uninstall_argocd
        exit $?
        ;;
    status)
        show_status
        exit $?
        ;;
    *)
        print_error "Unknown action: $ACTION"
        show_usage
        exit 1
        ;;
esac
