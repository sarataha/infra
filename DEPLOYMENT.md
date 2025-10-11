# Deployment Guide

Complete step-by-step guide to deploy the PawaPay infrastructure using Terragrunt.

## Prerequisites Check

Before starting, verify you have all required tools installed:

```bash
# Check Terraform
terraform --version
# Expected: Terraform v1.0 or higher

# Check Terragrunt
terragrunt --version
# Expected: terragrunt version v0.72.7 or higher

# Check AWS CLI
aws --version
# Expected: aws-cli/2.x or higher

# Check AWS credentials
aws sts get-caller-identity
# Should return your AWS account ID and user/role
```

## Step 1: Configure AWS Access

Choose one of the following methods:

### Option A: AWS CLI Configuration (Recommended)
```bash
aws configure
# AWS Access Key ID: [Enter your access key]
# AWS Secret Access Key: [Enter your secret key]
# Default region name: us-east-1
# Default output format: json
```

### Option B: Environment Variables
```bash
export AWS_ACCESS_KEY_ID="your-access-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
export AWS_DEFAULT_REGION="us-east-1"
```

### Verify Access
```bash
aws sts get-caller-identity
```

You should see output with your account ID, user ID, and ARN.

## Step 2: Configure Infrastructure

### Update Environment Configuration

Edit `environments/dev/terragrunt.hcl` and update the following:

#### REQUIRED: Update Public Access CIDR

```bash
# Find your public IP address
curl ifconfig.me
# Example output: 203.0.113.42

# Edit environments/dev/terragrunt.hcl
# Change this line:
public_access_cidrs = ["0.0.0.0/0"]  # WARNING: Open to all

# To this (replace with YOUR IP):
public_access_cidrs = ["203.0.113.42/32"]  # Only your IP
```

#### OPTIONAL: Customize Other Settings

```hcl
# Project name (affects resource naming)
project_name = "pawapay"  # Change if needed

# Node instance types (cost vs performance tradeoff)
node_instance_types = ["t3.small"]  # Minimum: t3.micro, Recommended: t3.small, Production: t3.medium

# Node group sizing
desired_node_count = 2  # Normal operation
min_node_count     = 1  # Scale down minimum
max_node_count     = 4  # Scale up maximum

# Kubernetes version
kubernetes_version = "1.34"  # Keep current unless upgrading

# Database name
db_name = "configmirror"  # Application database name
```

## Step 3: Initialize Backend

The backend (S3 bucket and DynamoDB table) stores Terraform state remotely.

### Option A: Automated Setup (Recommended)

```bash
# Run the setup script
cd /Users/sara/pawapay/pawapay-infra
./scripts/setup-backend.sh
```

The script will:
- Create S3 bucket with versioning and encryption
- Create DynamoDB table for state locking
- Configure proper security settings
- Display configuration details

### Option B: Manual Setup

```bash
# Get your AWS Account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create S3 bucket
aws s3api create-bucket \
  --bucket pawapay-terraform-state-${AWS_ACCOUNT_ID} \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket pawapay-terraform-state-${AWS_ACCOUNT_ID} \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket pawapay-terraform-state-${AWS_ACCOUNT_ID} \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket pawapay-terraform-state-${AWS_ACCOUNT_ID} \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create DynamoDB table
aws dynamodb create-table \
  --table-name pawapay-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1
```

## Step 4: Deploy Infrastructure

### Option A: Deploy All at Once (Recommended for First Deployment)

```bash
cd /Users/sara/pawapay/pawapay-infra/environments/dev

# Initialize all modules
terragrunt run-all init

# Review what will be created
terragrunt run-all plan

# Review the plan output carefully!
# Verify:
# - Resource counts are reasonable
# - No unexpected deletions
# - Configuration matches your requirements

# Deploy all infrastructure
terragrunt run-all apply
# Type 'yes' when prompted for each module
```

**Deployment Time**: ~15-20 minutes total
- VPC: ~2 minutes
- IAM: ~1 minute
- ECR: ~1 minute
- RDS: ~10-15 minutes (Multi-AZ database creation)
- EKS: ~10-12 minutes (cluster creation)

### Option B: Deploy Modules Individually (More Control)

This approach gives you fine-grained control and is useful for troubleshooting.

#### 1. Deploy VPC
```bash
cd /Users/sara/pawapay/pawapay-infra/environments/dev/vpc
terragrunt init
terragrunt plan
terragrunt apply  # Type 'yes' to confirm
```

#### 2. Deploy IAM
```bash
cd ../iam
terragrunt init
terragrunt plan
terragrunt apply
```

#### 3. Deploy ECR
```bash
cd ../ecr
terragrunt init
terragrunt plan
terragrunt apply
```

#### 4. Deploy RDS
```bash
cd ../rds
terragrunt init
terragrunt plan
terragrunt apply
# This takes 10-15 minutes for Multi-AZ deployment
```

#### 5. Deploy EKS
```bash
cd ../eks
terragrunt init
terragrunt plan
terragrunt apply
# This takes 10-12 minutes for cluster creation
```

## Step 5: Verify Deployment

### Check Infrastructure Resources

```bash
# Check all outputs
cd /Users/sara/pawapay/pawapay-infra/environments/dev
terragrunt run-all output

# Or check specific modules
cd vpc && terragrunt output
cd ../eks && terragrunt output
cd ../rds && terragrunt output
cd ../ecr && terragrunt output
```

### Verify AWS Resources

```bash
# Check VPC
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=pawapay"

# Check EKS cluster
aws eks describe-cluster --name pawapay-eks-dev --region us-east-1

# Check RDS instance
aws rds describe-db-instances --db-instance-identifier pawapay-rds-dev

# Check ECR repository
aws ecr describe-repositories --repository-names configmirror-operator
```

## Step 6: Configure kubectl for EKS

```bash
# Update kubeconfig
aws eks update-kubeconfig --name pawapay-eks-dev --region us-east-1

# Verify cluster access
kubectl cluster-info

# Check nodes are ready
kubectl get nodes
# Should show 2 nodes in Ready state (or your configured desired_node_count)

# Check system pods
kubectl get pods --all-namespaces
# All pods should be Running or Completed
```

## Step 7: Access Resources

### Get Database Credentials

```bash
# Retrieve credentials from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id pawapay-rds-credentials \
  --region us-east-1 \
  --query SecretString \
  --output text | jq -r

# Save to environment variables
export DB_HOST=$(aws secretsmanager get-secret-value --secret-id pawapay-rds-credentials --query SecretString --output text | jq -r .host)
export DB_USER=$(aws secretsmanager get-secret-value --secret-id pawapay-rds-credentials --query SecretString --output text | jq -r .username)
export DB_PASS=$(aws secretsmanager get-secret-value --secret-id pawapay-rds-credentials --query SecretString --output text | jq -r .password)
export DB_NAME=$(aws secretsmanager get-secret-value --secret-id pawapay-rds-credentials --query SecretString --output text | jq -r .dbname)

echo "Database Endpoint: $DB_HOST"
```

### Get ECR Repository URL

```bash
# Get repository URL
aws ecr describe-repositories \
  --repository-names configmirror-operator \
  --query 'repositories[0].repositoryUri' \
  --output text

# Authenticate Docker to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com
```

## Troubleshooting

### Issue: "Error: error configuring S3 Backend: bucket does not exist"

**Cause**: Backend infrastructure not created
**Solution**: Run the backend setup script (Step 3)

```bash
./scripts/setup-backend.sh
```

### Issue: "Error: Error creating EKS Cluster: InvalidParameterException"

**Cause**: IAM roles don't exist or incorrect
**Solution**: Deploy IAM module first

```bash
cd environments/dev/iam
terragrunt apply
```

### Issue: Nodes not joining EKS cluster

**Cause**: IAM role missing policies or security group issues
**Solution**: Check IAM policies and security groups

```bash
# Verify node role has required policies
aws iam list-attached-role-policies --role-name pawapay-eks-node-role-dev

# Should have:
# - AmazonEKSWorkerNodePolicy
# - AmazonEKS_CNI_Policy
# - AmazonEC2ContainerRegistryReadOnly

# Check node group status
aws eks describe-nodegroup \
  --cluster-name pawapay-eks-dev \
  --nodegroup-name pawapay-eks-dev-node-group
```

### Issue: "Access Denied" when running kubectl commands

**Cause**: kubeconfig not configured or IAM permissions issue
**Solution**: Update kubeconfig and verify AWS credentials

```bash
# Update kubeconfig
aws eks update-kubeconfig --name pawapay-eks-dev --region us-east-1

# Verify AWS identity
aws sts get-caller-identity

# Check cluster endpoint
kubectl cluster-info
```

### Issue: High costs

**Solution**: Check running resources and consider cost optimization

```bash
# List EC2 instances (EKS nodes)
aws ec2 describe-instances --filters "Name=tag:Project,Values=pawapay" --query 'Reservations[].Instances[].InstanceType'

# Check NAT Gateways (expensive!)
aws ec2 describe-nat-gateways --filter "Name=tag:Project,Values=pawapay"

# Consider:
# - Reduce node count to 1 for dev
# - Use t3.micro instead of t3.small
# - Single AZ deployment (remove one NAT gateway)
# - RDS single-AZ instead of Multi-AZ
```

## Cost Breakdown

### Current Configuration (Development)
- EKS Control Plane: $73/month
- EC2 Nodes (2x t3.small): $30/month
- NAT Gateways (2x Multi-AZ): $65/month
- RDS (db.t3.micro Multi-AZ): $26/month
- Data Transfer: ~$5-10/month
- **Total: ~$194-199/month**

### Cost-Optimized Development
```hcl
# In environments/dev/terragrunt.hcl
availability_zones   = ["us-east-1a"]           # Single AZ
node_instance_types  = ["t3.micro"]             # Smaller instances
desired_node_count   = 1                        # Single node
# In environments/dev/rds/terragrunt.hcl
multi_az = false                                # Single AZ RDS
```

**Optimized Total: ~$94/month**

## Next Steps

After successful deployment:

1. **Deploy Application**: Use ECR repository to push container images
2. **Configure Monitoring**: Set up CloudWatch dashboards and alarms
3. **Implement Backup Strategy**: Configure additional RDS snapshots
4. **Security Hardening**: Review security groups and IAM policies
5. **Set Up CI/CD**: Configure GitHub Actions for automated deployments
6. **Documentation**: Update with your specific application details

## Cleanup (DANGER!)

To destroy all infrastructure:

```bash
cd /Users/sara/pawapay/pawapay-infra/environments/dev

# Destroy all resources (WARNING: This deletes everything!)
terragrunt run-all destroy
# Type 'yes' for each module when prompted

# Or destroy individually in reverse order
cd eks && terragrunt destroy && cd ..
cd rds && terragrunt destroy && cd ..
cd ecr && terragrunt destroy && cd ..
cd iam && terragrunt destroy && cd ..
cd vpc && terragrunt destroy && cd ..
```

**Note**: Set `skip_final_snapshot = false` in RDS module before destroying in production to save a final database backup!

## Support

For issues or questions:
1. Check module README files in `modules/*/README.md`
2. Review AWS CloudWatch logs
3. Check Terraform/Terragrunt debug output
4. Consult AWS documentation

---

**Remember**: This is production-grade infrastructure. Always review plans before applying!
