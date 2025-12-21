#!/bin/bash

# usage
# Deploy dev
# ./deploy.sh dev

# # Plan only (no apply)
# ./deploy.sh dev plan

# # Destroy environment
# ./deploy.sh dev destroy

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Help message
usage() {
    echo "Usage: ./deploy.sh <environment> [action]"
    echo ""
    echo "Environments:"
    echo "  bootstrap    - Deploy state bucket (run first)"
    echo "  dev          - Deploy dev environment"
    echo "  staging      - Deploy staging environment"
    echo "  prod         - Deploy prod environment"
    echo ""
    echo "Actions (optional):"
    echo "  plan         - Run terraform plan only"
    echo "  apply        - Run terraform apply (default)"
    echo "  destroy      - Run terraform destroy"
    echo ""
    echo "Examples:"
    echo "  ./deploy.sh bootstrap"
    echo "  ./deploy.sh dev"
    echo "  ./deploy.sh dev plan"
    echo "  ./deploy.sh prod apply"
    exit 1
}

# Check arguments
if [ -z "$1" ]; then
    usage
fi

ENV=$1
ACTION=${2:-apply}  # Default to apply

# Validate environment
case $ENV in
    bootstrap|dev|staging|prod)
        echo -e "${GREEN}Environment: ${ENV}${NC}"
        ;;
    *)
        echo -e "${RED}Error: Invalid environment '${ENV}'${NC}"
        usage
        ;;
esac

# Validate action
case $ACTION in
    plan|apply|destroy)
        echo -e "${GREEN}Action: ${ACTION}${NC}"
        ;;
    *)
        echo -e "${RED}Error: Invalid action '${ACTION}'${NC}"
        usage
        ;;
esac

# Set directory based on environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$ENV" == "bootstrap" ]; then
    DEPLOY_DIR="${SCRIPT_DIR}/bootstrap"
else
    DEPLOY_DIR="${SCRIPT_DIR}/environments/${ENV}"
fi

# Check directory exists
if [ ! -d "$DEPLOY_DIR" ]; then
    echo -e "${RED}Error: Directory not found: ${DEPLOY_DIR}${NC}"
    exit 1
fi

# Navigate to directory
cd "$DEPLOY_DIR"
echo -e "${YELLOW}Working directory: $(pwd)${NC}"

# Initialize Terraform
echo -e "${GREEN}Initializing Terraform...${NC}"
terraform init

# Run action
case $ACTION in
    plan)
        echo -e "${GREEN}Running terraform plan...${NC}"
        terraform init
        terraform plan
        ;;
    apply)
        echo -e "${GREEN}Running terraform plan...${NC}"
        terraform plan -out=tfplan

        echo -e "${YELLOW}Review the plan above. Continue with apply? (y/n)${NC}"
        read -r CONFIRM

        if [ "$CONFIRM" == "y" ]; then
            echo -e "${GREEN}Running terraform apply...${NC}"
            terraform apply tfplan
            rm -f tfplan
        else
            echo -e "${RED}Apply cancelled.${NC}"
            rm -f tfplan
            exit 0
        fi
        ;;
    destroy)
        echo -e "${RED}WARNING: This will destroy all resources in ${ENV}!${NC}"
        echo -e "${YELLOW}Type 'y' to confirm:${NC}"
        read -r CONFIRM

        if [ "$CONFIRM" == "y" ]; then
            terraform destroy
        else
            echo -e "${RED}Destroy cancelled.${NC}"
            exit 0
        fi
        ;;
esac

echo -e "${GREEN}Done!${NC}"
