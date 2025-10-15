#!/bin/bash
# Cleanup Bootstrap Infra
# This script destroys:
# 1. IAM user for local development
# 2. IAM role for Terraform CI/CD
# 3. GitHub OIDC provider
# 4. DynamoDB table for state locking
# 5. S3 bucket for Terraform state

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}========================================${NC}"
echo -e "${RED}  Bootstrap Infra Cleanup${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo -e "${YELLOW}WARNING: This will destroy all bootstrap infra!${NC}"
echo -e "${YELLOW}Make sure you have destroyed all Terraform-managed resources first!${NC}"
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
IAM_ROLE_NAME="github-actions-terraform"
LOCAL_USER_NAME="terraform-local-dev"
POLICY_NAME="TerraformExecutionPolicy"

echo -e "${YELLOW}Configuration:${NC}"
echo "  Project: ${PROJECT_NAME}"
echo "  Region: ${AWS_REGION}"
echo "  S3 Bucket: ${BUCKET_NAME}"
echo "  DynamoDB Table: ${DYNAMODB_TABLE}"
echo "  IAM Role: ${IAM_ROLE_NAME}"
echo "  IAM User: ${LOCAL_USER_NAME}"
echo "  IAM Policy: ${POLICY_NAME}"
echo ""

# Final confirmation
echo -e "${RED}WARNING: THIS ACTION CANNOT BE UNDONE${NC}"
echo ""
read -p "Type 'DELETE' to confirm destruction: " -r
echo
if [[ ! $REPLY == "DELETE" ]]; then
    echo -e "${YELLOW}Cleanup cancelled.${NC}"
    exit 0
fi
echo ""

# Delete IAM user access keys
echo -e "${YELLOW}Deleting IAM user access keys...${NC}"
if aws iam get-user --user-name "${LOCAL_USER_NAME}" >/dev/null 2>&1; then
    ACCESS_KEYS=$(aws iam list-access-keys --user-name "${LOCAL_USER_NAME}" --query 'AccessKeyMetadata[].AccessKeyId' --output text)
    for key in $ACCESS_KEYS; do
        aws iam delete-access-key --user-name "${LOCAL_USER_NAME}" --access-key-id "$key"
        echo -e "${GREEN}Deleted access key: $key${NC}"
    done
else
    echo -e "${YELLOW}IAM user not found, skipping${NC}"
fi

# Detach policies from IAM user
echo -e "${YELLOW}Detaching policies from IAM user...${NC}"
if aws iam get-user --user-name "${LOCAL_USER_NAME}" >/dev/null 2>&1; then
    POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"
    if aws iam list-attached-user-policies --user-name "${LOCAL_USER_NAME}" | grep -q "${POLICY_ARN}"; then
        aws iam detach-user-policy --user-name "${LOCAL_USER_NAME}" --policy-arn "${POLICY_ARN}"
        echo -e "${GREEN}Policy detached from user${NC}"
    fi

    # Delete inline policies
    INLINE_POLICIES=$(aws iam list-user-policies --user-name "${LOCAL_USER_NAME}" --query 'PolicyNames' --output text)
    for policy in $INLINE_POLICIES; do
        aws iam delete-user-policy --user-name "${LOCAL_USER_NAME}" --policy-name "$policy"
        echo -e "${GREEN}Deleted inline policy: $policy${NC}"
    done
fi

# Delete IAM user
echo -e "${YELLOW}Deleting IAM user...${NC}"
if aws iam get-user --user-name "${LOCAL_USER_NAME}" >/dev/null 2>&1; then
    aws iam delete-user --user-name "${LOCAL_USER_NAME}"
    echo -e "${GREEN}IAM user deleted${NC}"
else
    echo -e "${YELLOW}IAM user already deleted${NC}"
fi

# Detach policies from IAM role
echo -e "${YELLOW}Detaching policies from IAM role...${NC}"
if aws iam get-role --role-name "${IAM_ROLE_NAME}" >/dev/null 2>&1; then
    POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"
    if aws iam list-attached-role-policies --role-name "${IAM_ROLE_NAME}" | grep -q "${POLICY_ARN}"; then
        aws iam detach-role-policy --role-name "${IAM_ROLE_NAME}" --policy-arn "${POLICY_ARN}"
        echo -e "${GREEN}Policy detached from role${NC}"
    fi

    # Delete inline policies
    INLINE_POLICIES=$(aws iam list-role-policies --role-name "${IAM_ROLE_NAME}" --query 'PolicyNames' --output text)
    for policy in $INLINE_POLICIES; do
        aws iam delete-role-policy --role-name "${IAM_ROLE_NAME}" --policy-name "$policy"
        echo -e "${GREEN}Deleted inline policy: $policy${NC}"
    done
fi

# Delete IAM role
echo -e "${YELLOW}Deleting IAM role...${NC}"
if aws iam get-role --role-name "${IAM_ROLE_NAME}" >/dev/null 2>&1; then
    aws iam delete-role --role-name "${IAM_ROLE_NAME}"
    echo -e "${GREEN}IAM role deleted${NC}"
else
    echo -e "${YELLOW}IAM role already deleted${NC}"
fi

# Delete IAM policy
echo -e "${YELLOW}Deleting IAM policy...${NC}"
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"
if aws iam get-policy --policy-arn "${POLICY_ARN}" >/dev/null 2>&1; then
    aws iam delete-policy --policy-arn "${POLICY_ARN}"
    echo -e "${GREEN}IAM policy deleted${NC}"
else
    echo -e "${YELLOW}IAM policy already deleted${NC}"
fi

# Delete GitHub OIDC provider
echo -e "${YELLOW}Deleting GitHub OIDC provider...${NC}"
OIDC_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "${OIDC_ARN}" >/dev/null 2>&1; then
    aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "${OIDC_ARN}"
    echo -e "${GREEN}GitHub OIDC provider deleted${NC}"
else
    echo -e "${YELLOW}GitHub OIDC provider already deleted${NC}"
fi

# Delete DynamoDB table
echo -e "${YELLOW}Deleting DynamoDB table...${NC}"
if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${AWS_REGION}" >/dev/null 2>&1; then
    aws dynamodb delete-table --table-name "${DYNAMODB_TABLE}" --region "${AWS_REGION}" >/dev/null
    echo -e "${YELLOW}Waiting for DynamoDB table deletion...${NC}"
    aws dynamodb wait table-not-exists --table-name "${DYNAMODB_TABLE}" --region "${AWS_REGION}"
    echo -e "${GREEN}DynamoDB table deleted${NC}"
else
    echo -e "${YELLOW}DynamoDB table already deleted${NC}"
fi

# Empty and delete S3 bucket
echo -e "${YELLOW}Emptying S3 bucket...${NC}"
if aws s3api head-bucket --bucket "${BUCKET_NAME}" >/dev/null 2>&1; then
    # Delete all objects and versions using AWS CLI
    aws s3 rm s3://"${BUCKET_NAME}" --recursive || true

    # Delete all versions
    aws s3api list-object-versions --bucket "${BUCKET_NAME}" --output json | \
    jq -r '.Versions[]? | .Key + " " + .VersionId' | \
    while read key versionId; do
        aws s3api delete-object --bucket "${BUCKET_NAME}" --key "$key" --version-id "$versionId" || true
    done

    # Delete all delete markers
    aws s3api list-object-versions --bucket "${BUCKET_NAME}" --output json | \
    jq -r '.DeleteMarkers[]? | .Key + " " + .VersionId' | \
    while read key versionId; do
        aws s3api delete-object --bucket "${BUCKET_NAME}" --key "$key" --version-id "$versionId" || true
    done

    echo -e "${GREEN}S3 bucket emptied${NC}"

    echo -e "${YELLOW}Deleting S3 bucket...${NC}"
    aws s3api delete-bucket --bucket "${BUCKET_NAME}" --region "${AWS_REGION}"
    echo -e "${GREEN}S3 bucket deleted${NC}"
else
    echo -e "${YELLOW}S3 bucket already deleted${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Cleanup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}All bootstrap infra has been destroyed.${NC}"
echo ""
