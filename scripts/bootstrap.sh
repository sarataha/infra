#!/bin/bash
# Setup Bootstrap Infrastructure
# This script creates:
# 1. S3 bucket for Terraform state
# 2. DynamoDB table for state locking
# 3. GitHub OIDC provider for CI/CD
# 4. IAM role for Terraform CI/CD

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Bootstrap Infrastructure Setup${NC}"
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
GITHUB_ORG="${GITHUB_ORG:-sarataha}"
GITHUB_REPO="${GITHUB_REPO:-pawapay-infra}"
IAM_ROLE_NAME="github-actions-terraform"

echo -e "${YELLOW}Configuration:${NC}"
echo "  Project: ${PROJECT_NAME}"
echo "  Region: ${AWS_REGION}"
echo "  S3 Bucket: ${BUCKET_NAME}"
echo "  DynamoDB Table: ${DYNAMODB_TABLE}"
echo "  GitHub Org: ${GITHUB_ORG}"
echo "  GitHub Repo: ${GITHUB_REPO}"
echo "  IAM Role: ${IAM_ROLE_NAME}"
echo ""

# Confirm before proceeding
read -p "Proceed with bootstrap setup? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Setup cancelled.${NC}"
    exit 0
fi
echo ""

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
echo -e "${GREEN}  Part 2: GitHub OIDC & IAM Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Create GitHub OIDC provider
echo -e "${YELLOW}Setting up GitHub OIDC provider...${NC}"
OIDC_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "${OIDC_ARN}" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ GitHub OIDC provider already exists${NC}"
else
    aws iam create-open-id-connect-provider \
        --url "https://token.actions.githubusercontent.com" \
        --client-id-list "sts.amazonaws.com" \
        --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1" "1c58a3a8518e8759bf075b76b750d4f2df264fcd" \
        --tags Key=Name,Value="GitHub Actions OIDC" Key=Project,Value="${PROJECT_NAME}" Key=ManagedBy,Value=script \
        > /dev/null
    echo -e "${GREEN}✓ GitHub OIDC provider created${NC}"
fi

# Create IAM role for Terraform CI/CD
echo -e "${YELLOW}Creating IAM role for Terraform CI/CD...${NC}"

# Create trust policy
TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF
)

if aws iam get-role --role-name "${IAM_ROLE_NAME}" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ IAM role already exists${NC}"
else
    ROLE_ARN=$(aws iam create-role \
        --role-name "${IAM_ROLE_NAME}" \
        --assume-role-policy-document "${TRUST_POLICY}" \
        --tags Key=Name,Value="GitHub Actions Terraform" Key=Project,Value="${PROJECT_NAME}" Key=ManagedBy,Value=script \
        --query 'Role.Arn' \
        --output text)
    echo -e "${GREEN}✓ IAM role created: ${ROLE_ARN}${NC}"
fi

# Create customer-managed IAM policy for Terraform
echo -e "${YELLOW}Creating IAM policy for Terraform...${NC}"

# Get script directory to find policy file
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
POLICY_FILE="${SCRIPT_DIR}/terraform-iam-policy.json"

# Read policy file and replace placeholders
POLICY_DOCUMENT=$(cat "${POLICY_FILE}" | \
  sed "s/BUCKET_NAME_PLACEHOLDER/${BUCKET_NAME}/g" | \
  sed "s/REGION_PLACEHOLDER/${AWS_REGION}/g" | \
  sed "s/ACCOUNT_ID_PLACEHOLDER/${AWS_ACCOUNT_ID}/g" | \
  sed "s/DYNAMODB_TABLE_PLACEHOLDER/${DYNAMODB_TABLE}/g")

POLICY_NAME="TerraformExecutionPolicy"
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"

# Create the policy if it doesn't exist
if aws iam get-policy --policy-arn "${POLICY_ARN}" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ IAM policy already exists${NC}"
else
    aws iam create-policy \
        --policy-name "${POLICY_NAME}" \
        --policy-document "${POLICY_DOCUMENT}" \
        --description "Least-privilege permissions for Terraform to manage EKS, VPC, RDS, and ECR infrastructure" \
        --tags Key=Name,Value="Terraform Execution Policy" Key=Project,Value="${PROJECT_NAME}" Key=ManagedBy,Value=script \
        > /dev/null
    echo -e "${GREEN}✓ IAM policy created: ${POLICY_ARN}${NC}"
fi

# Attach policy to role
echo -e "${YELLOW}Attaching policy to IAM role...${NC}"
if aws iam list-attached-role-policies --role-name "${IAM_ROLE_NAME}" | grep -q "${POLICY_ARN}"; then
    echo -e "${GREEN}✓ Policy already attached to role${NC}"
else
    aws iam attach-role-policy \
        --role-name "${IAM_ROLE_NAME}" \
        --policy-arn "${POLICY_ARN}"
    echo -e "${GREEN}✓ Policy attached to role${NC}"
fi

# Get final role ARN
FINAL_ROLE_ARN=$(aws iam get-role --role-name "${IAM_ROLE_NAME}" --query 'Role.Arn' --output text)

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Part 3: Local Development IAM User${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

LOCAL_USER_NAME="terraform-local-dev"

# Create IAM user for local development
echo -e "${YELLOW}Creating IAM user for local Terraform development...${NC}"

if aws iam get-user --user-name "${LOCAL_USER_NAME}" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ IAM user already exists${NC}"
    USER_EXISTS=true
else
    aws iam create-user \
        --user-name "${LOCAL_USER_NAME}" \
        --tags Key=Name,Value="Terraform Local Dev" Key=Project,Value="${PROJECT_NAME}" Key=ManagedBy,Value=script \
        > /dev/null
    echo -e "${GREEN}✓ IAM user created${NC}"
    USER_EXISTS=false
fi

# Attach the same managed policy to local user
echo -e "${YELLOW}Attaching policy to local user...${NC}"

if aws iam list-attached-user-policies --user-name "${LOCAL_USER_NAME}" | grep -q "${POLICY_ARN}"; then
    echo -e "${GREEN}✓ Policy already attached to user${NC}"
else
    aws iam attach-user-policy \
        --user-name "${LOCAL_USER_NAME}" \
        --policy-arn "${POLICY_ARN}"
    echo -e "${GREEN}✓ Policy attached to user${NC}"
fi

# Create access keys if user is new
if [ "$USER_EXISTS" = false ]; then
    echo -e "${YELLOW}Creating access keys for local development...${NC}"
    ACCESS_KEY_OUTPUT=$(aws iam create-access-key --user-name "${LOCAL_USER_NAME}" --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text)
    ACCESS_KEY_ID=$(echo "$ACCESS_KEY_OUTPUT" | awk '{print $1}')
    SECRET_ACCESS_KEY=$(echo "$ACCESS_KEY_OUTPUT" | awk '{print $2}')
    echo -e "${GREEN}✓ Access keys created${NC}"
else
    echo -e "${YELLOW}⚠ User already exists - skipping access key creation${NC}"
    echo -e "${YELLOW}  If you need new keys, delete old ones in AWS console first${NC}"
    ACCESS_KEY_ID="<existing-keys-not-shown>"
    SECRET_ACCESS_KEY="<existing-keys-not-shown>"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Bootstrap Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Backend Details:${NC}"
echo "  S3 Bucket: ${BUCKET_NAME}"
echo "  DynamoDB Table: ${DYNAMODB_TABLE}"
echo "  Region: ${AWS_REGION}"
echo ""
echo -e "${YELLOW}CI/CD IAM Details:${NC}"
echo "  OIDC Provider: ${OIDC_ARN}"
echo "  CI Role: ${IAM_ROLE_NAME}"
echo "  Role ARN: ${FINAL_ROLE_ARN}"
echo ""
echo -e "${YELLOW}Local Development IAM Details:${NC}"
echo "  User: ${LOCAL_USER_NAME}"
if [ "$USER_EXISTS" = false ]; then
    echo "  Access Key ID: ${ACCESS_KEY_ID}"
    echo "  Secret Access Key: ${SECRET_ACCESS_KEY}"
    echo ""
    echo -e "${RED}⚠️  IMPORTANT: Save these credentials securely!${NC}"
    echo -e "${RED}⚠️  They will not be shown again!${NC}"
else
    echo "  (User already existed - keys not generated)"
fi
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "  1. Configure local AWS credentials:"
if [ "$USER_EXISTS" = false ]; then
    echo "     aws configure --profile terraform-dev"
    echo "     AWS Access Key ID: ${ACCESS_KEY_ID}"
    echo "     AWS Secret Access Key: ${SECRET_ACCESS_KEY}"
    echo "     Default region: ${AWS_REGION}"
else
    echo "     (Use existing credentials for ${LOCAL_USER_NAME})"
fi
echo ""
echo "  2. Add this secret to GitHub repo '${GITHUB_REPO}':"
echo "     AWS_ROLE_ARN=${FINAL_ROLE_ARN}"
echo ""
echo "  3. Review configuration in environments/dev/terragrunt.hcl"
echo "  4. Update public_access_cidrs with your IP address"
echo "  5. Run: export AWS_PROFILE=terraform-dev"
echo "  6. Run: cd environments/dev && terragrunt run-all init"
echo "  7. Run: terragrunt run-all plan"
echo "  8. Run: terragrunt run-all apply"
echo ""
