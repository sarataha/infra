#!/bin/bash
# Setup Terraform Backend (S3 + DynamoDB)
# This script creates the required infrastructure for Terraform remote state

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Terraform Backend Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Get AWS Account ID
echo -e "${YELLOW}Getting AWS Account ID...${NC}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)

if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}Error: Unable to get AWS Account ID. Please check your AWS credentials.${NC}"
    exit 1
fi

echo -e "${GREEN}AWS Account ID: ${AWS_ACCOUNT_ID}${NC}"
echo ""

# Configuration
PROJECT_NAME="pawapay"
AWS_REGION="${AWS_REGION:-us-east-1}"
BUCKET_NAME="${PROJECT_NAME}-terraform-state-${AWS_ACCOUNT_ID}"
DYNAMODB_TABLE="${PROJECT_NAME}-terraform-locks"

echo -e "${YELLOW}Configuration:${NC}"
echo "  Project: ${PROJECT_NAME}"
echo "  Region: ${AWS_REGION}"
echo "  S3 Bucket: ${BUCKET_NAME}"
echo "  DynamoDB Table: ${DYNAMODB_TABLE}"
echo ""

# Confirm before proceeding
read -p "Proceed with backend setup? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Setup cancelled.${NC}"
    exit 0
fi

# Create S3 bucket
echo -e "${YELLOW}Creating S3 bucket for Terraform state...${NC}"
if ! aws s3api head-bucket --bucket "${BUCKET_NAME}" >/dev/null 2>&1; then
    aws s3api create-bucket \
        --bucket "${BUCKET_NAME}" \
        --region "${AWS_REGION}" \
        --create-bucket-configuration LocationConstraint="${AWS_REGION}" 2>/dev/null || \
    aws s3api create-bucket \
        --bucket "${BUCKET_NAME}" \
        --region "${AWS_REGION}" 2>/dev/null
    echo -e "${GREEN}✓ S3 bucket created${NC}"
else
    echo -e "${GREEN}✓ S3 bucket already exists${NC}"
fi

# Enable versioning
echo -e "${YELLOW}Enabling versioning on S3 bucket...${NC}"
aws s3api put-bucket-versioning \
    --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled
echo -e "${GREEN}✓ Versioning enabled${NC}"

# Enable encryption
echo -e "${YELLOW}Enabling encryption on S3 bucket...${NC}"
aws s3api put-bucket-encryption \
    --bucket "${BUCKET_NAME}" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'
echo -e "${GREEN}✓ Encryption enabled${NC}"

# Block public access
echo -e "${YELLOW}Blocking public access to S3 bucket...${NC}"
aws s3api put-public-access-block \
    --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
echo -e "${GREEN}✓ Public access blocked${NC}"

# Add bucket tags
echo -e "${YELLOW}Adding tags to S3 bucket...${NC}"
aws s3api put-bucket-tagging \
    --bucket "${BUCKET_NAME}" \
    --tagging "TagSet=[{Key=Name,Value=Terraform State Bucket},{Key=Project,Value=${PROJECT_NAME}},{Key=ManagedBy,Value=script}]"
echo -e "${GREEN}✓ Tags added${NC}"

# Create DynamoDB table
echo -e "${YELLOW}Creating DynamoDB table for state locking...${NC}"
if ! aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${AWS_REGION}" >/dev/null 2>&1; then
    aws dynamodb create-table \
        --table-name "${DYNAMODB_TABLE}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region "${AWS_REGION}" \
        --tags Key=Name,Value="Terraform Lock Table" Key=Project,Value="${PROJECT_NAME}" Key=ManagedBy,Value=script \
        > /dev/null

    echo -e "${YELLOW}Waiting for DynamoDB table to be active...${NC}"
    aws dynamodb wait table-exists --table-name "${DYNAMODB_TABLE}" --region "${AWS_REGION}"
    echo -e "${GREEN}✓ DynamoDB table created${NC}"
else
    echo -e "${GREEN}✓ DynamoDB table already exists${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Backend Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review configuration in environments/dev/terragrunt.hcl"
echo "  2. Update public_access_cidrs with your IP address"
echo "  3. Run: cd environments/dev && terragrunt run-all init"
echo "  4. Run: terragrunt run-all plan"
echo "  5. Run: terragrunt run-all apply"
echo ""
echo -e "${YELLOW}Backend Details:${NC}"
echo "  S3 Bucket: ${BUCKET_NAME}"
echo "  DynamoDB Table: ${DYNAMODB_TABLE}"
echo "  Region: ${AWS_REGION}"
echo ""
