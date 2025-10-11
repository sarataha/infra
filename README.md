# PawaPay Infrastructure

Production-grade AWS infrastructure for the ConfigMirror Kubernetes operator, built with Terraform and Terragrunt. This repository demonstrates enterprise-level infrastructure as code practices including remote state management, DRY configuration, and comprehensive security controls.

## Architecture Overview

This infrastructure deploys a complete EKS-based platform with the following components:

- **VPC**: Multi-AZ network with public/private subnets, NAT gateways, and proper routing
- **EKS**: Kubernetes 1.34 cluster with managed node groups and comprehensive logging
- **RDS**: Multi-AZ PostgreSQL 17.6 database with automated backups and encryption
- **ECR**: Private container registry for storing operator images
- **IAM**: Least-privilege roles and policies for EKS cluster and node groups

### Network Architecture

```
VPC (10.0.0.0/16)
├── AZ us-east-1a
│   ├── Public Subnet (10.0.1.0/24)  - NAT Gateway, Load Balancers
│   └── Private Subnet (10.0.10.0/24) - EKS Nodes, RDS
└── AZ us-east-1b
    ├── Public Subnet (10.0.2.0/24)  - NAT Gateway (HA)
    └── Private Subnet (10.0.20.0/24) - EKS Nodes, RDS (Multi-AZ)
```

## Directory Structure

```
pawapay-infra/
├── terragrunt.hcl                 # Root Terragrunt config with remote state
├── modules/                       # Reusable Terraform modules
│   ├── vpc/                       # VPC, subnets, NAT, routing
│   ├── iam/                       # IAM roles and policies
│   ├── ecr/                       # Container registry
│   ├── rds/                       # PostgreSQL database
│   └── eks/                       # EKS cluster and node groups
├── environments/
│   └── dev/
│       ├── terragrunt.hcl         # Environment-level configuration
│       ├── vpc/terragrunt.hcl     # VPC deployment config
│       ├── iam/terragrunt.hcl     # IAM deployment config
│       ├── ecr/terragrunt.hcl     # ECR deployment config
│       ├── rds/terragrunt.hcl     # RDS deployment config
│       └── eks/terragrunt.hcl     # EKS deployment config
└── .github/
    └── workflows/
        └── terraform-ci.yml       # CI/CD pipeline
```

## Prerequisites

### Required Tools

- **AWS CLI**: `>= 2.0`
- **Terraform**: `>= 1.0` (tested with 1.10.4)
- **Terragrunt**: `>= 0.72.7`
- **kubectl**: `>= 1.34` (matching EKS version)

### Installation

#### macOS (Homebrew)
```bash
# Install Terraform
brew install terraform

# Install Terragrunt
brew install terragrunt

# Install AWS CLI
brew install awscli

# Install kubectl
brew install kubectl
```

#### Linux
```bash
# Install Terraform
wget https://releases.hashicorp.com/terraform/1.10.4/terraform_1.10.4_linux_amd64.zip
unzip terraform_1.10.4_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Install Terragrunt
wget https://github.com/gruntwork-io/terragrunt/releases/download/v0.72.7/terragrunt_linux_amd64
chmod +x terragrunt_linux_amd64
sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install kubectl
curl -LO "https://dl.k8s.io/release/v1.34.0/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

### Verify Installation
```bash
terraform --version  # Should be >= 1.0
terragrunt --version # Should be >= 0.72.7
aws --version        # Should be >= 2.0
kubectl version --client # Should be >= 1.34
```

## AWS Configuration

### 1. AWS Credentials Setup

#### Option A: AWS CLI Configuration (Recommended for local development)
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region: us-east-1
# Default output format: json
```

#### Option B: Environment Variables
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

#### Option C: AWS SSO (Recommended for enterprise)
```bash
aws configure sso
aws sso login --profile your-profile
export AWS_PROFILE=your-profile
```

### 2. Verify AWS Access
```bash
aws sts get-caller-identity
```

You should see output with your AWS Account ID and IAM user/role information.

### 3. Required AWS Permissions

Your IAM user/role needs the following permissions:
- EC2 (VPC, Subnets, NAT, Security Groups)
- EKS (Cluster, Node Groups)
- RDS (Database Instances, Subnet Groups)
- ECR (Repositories)
- IAM (Roles, Policies)
- S3 (State bucket)
- DynamoDB (Lock table)
- CloudWatch (Logs)
- Secrets Manager (RDS credentials)

For production, use a custom IAM policy with least-privilege access. For development/testing, `AdministratorAccess` can be used.

## Configuration

### Environment Variables

Before deploying, customize the configuration in `environments/dev/terragrunt.hcl`:

#### Required Changes

1. **Public Access CIDR** - Restrict EKS API access to your IP:
   ```bash
   # Find your public IP
   curl ifconfig.me

   # Update in environments/dev/terragrunt.hcl
   public_access_cidrs = ["YOUR_IP/32"]  # Replace with your IP
   ```

2. **Project Name** (optional):
   ```hcl
   project_name = "your-project-name"  # Default: pawapay
   ```

#### Optional Customizations

```hcl
# Node instance types (t3.small recommended minimum)
node_instance_types = ["t3.small"]  # Upgrade to t3.medium for production

# Node group sizing
desired_node_count = 2  # Number of nodes to maintain
min_node_count     = 1  # Minimum for autoscaling
max_node_count     = 4  # Maximum for autoscaling

# Kubernetes version
kubernetes_version = "1.34"  # Latest supported EKS version

# Database settings
db_name = "configmirror"  # PostgreSQL database name
```

## Deployment

### Step 1: Initialize Backend Infrastructure

First, create the S3 bucket and DynamoDB table for Terraform state:

```bash
# Set your AWS Account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create S3 bucket for state
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

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name pawapay-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1
```

### Step 2: Deploy Infrastructure

#### Option A: Deploy All Modules at Once (Recommended for first deployment)
```bash
cd environments/dev

# Initialize all modules
terragrunt run-all init

# Plan all changes
terragrunt run-all plan

# Apply all changes (requires confirmation for each module)
terragrunt run-all apply
```

#### Option B: Deploy Modules Individually (More control)
```bash
cd environments/dev

# 1. Deploy VPC
cd vpc
terragrunt init
terragrunt plan
terragrunt apply
cd ..

# 2. Deploy IAM
cd iam
terragrunt init
terragrunt plan
terragrunt apply
cd ..

# 3. Deploy ECR (parallel with RDS)
cd ecr
terragrunt init
terragrunt plan
terragrunt apply
cd ..

# 4. Deploy RDS (parallel with ECR)
cd rds
terragrunt init
terragrunt plan
terragrunt apply
cd ..

# 5. Deploy EKS (after all dependencies)
cd eks
terragrunt init
terragrunt plan
terragrunt apply
cd ..
```

### Step 3: Verify Deployment

```bash
# Check EKS cluster
aws eks describe-cluster --name pawapay-eks-dev --region us-east-1

# Configure kubectl
aws eks update-kubeconfig --name pawapay-eks-dev --region us-east-1

# Verify nodes
kubectl get nodes

# Check RDS instance
aws rds describe-db-instances --region us-east-1 | grep pawapay

# Check ECR repository
aws ecr describe-repositories --region us-east-1 | grep configmirror
```

## Infrastructure Outputs

After deployment, Terragrunt will output important values:

```bash
# Get all outputs
cd environments/dev
terragrunt run-all output

# Get specific outputs
cd vpc && terragrunt output vpc_id
cd ../eks && terragrunt output cluster_endpoint
cd ../rds && terragrunt output db_instance_endpoint
cd ../ecr && terragrunt output repository_url
```

### Important Outputs

- **VPC ID**: Used for networking configurations
- **EKS Cluster Endpoint**: Kubernetes API server URL
- **RDS Endpoint**: Database connection string
- **ECR Repository URL**: For pushing container images
- **RDS Secret ARN**: Secrets Manager ARN containing database credentials

## Accessing Resources

### Kubernetes Cluster

```bash
# Configure kubectl
aws eks update-kubeconfig --name pawapay-eks-dev --region us-east-1

# Verify connection
kubectl cluster-info
kubectl get nodes
kubectl get namespaces
```

### RDS Database

```bash
# Get database credentials from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id pawapay-rds-credentials \
  --region us-east-1 \
  --query SecretString \
  --output text | jq -r

# Connect via psql (requires VPN or bastion host)
psql -h <rds-endpoint> -U postgres -d configmirror
```

### ECR Repository

```bash
# Authenticate Docker to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com

# Build and push image
docker build -t configmirror-operator:latest .
docker tag configmirror-operator:latest <ecr-repository-url>:latest
docker push <ecr-repository-url>:latest
```

## CI/CD Pipeline

This repository includes a GitHub Actions workflow for automated validation and deployment:

### Features

- Terraform formatting validation
- Module validation and linting (TFLint)
- Security scanning (Checkov)
- Automated plan on pull requests
- Automated apply on merge to main (with approval)

### Setup GitHub Actions

1. **Configure GitHub Secrets**:
   - Go to repository Settings > Secrets and variables > Actions
   - Add: `AWS_ACCESS_KEY_ID`
   - Add: `AWS_SECRET_ACCESS_KEY`

2. **Enable Workflow**:
   - Uncomment AWS credential sections in `.github/workflows/terraform-ci.yml`
   - Uncomment plan/apply steps

3. **Configure Environment Protection**:
   - Go to Settings > Environments
   - Create `dev` environment
   - Enable required reviewers for apply jobs

## State Management

### Remote State

This project uses S3 for state storage with DynamoDB for locking:

- **S3 Bucket**: `pawapay-terraform-state-<account-id>`
- **DynamoDB Table**: `pawapay-terraform-locks`
- **Encryption**: AES256 encryption at rest
- **Versioning**: Enabled for state history

### State Commands

```bash
# List state resources
terragrunt state list

# Show specific resource
terragrunt state show <resource-address>

# Pull current state
terragrunt state pull

# Remove resource from state (dangerous!)
terragrunt state rm <resource-address>
```

### State Locking

Terragrunt automatically handles state locking via DynamoDB. If a lock gets stuck:

```bash
# Check DynamoDB for locks
aws dynamodb scan --table-name pawapay-terraform-locks --region us-east-1

# Force unlock (use with caution!)
terragrunt force-unlock <lock-id>
```

## Troubleshooting

### Common Issues

#### 1. "Error: error configuring S3 Backend: bucket does not exist"

**Solution**: Create the S3 bucket and DynamoDB table (see Step 1 of Deployment)

#### 2. "Error: error creating EKS Cluster: InvalidParameterException"

**Solution**: Ensure IAM roles exist and have correct trust policies:
```bash
cd environments/dev/iam
terragrunt apply
```

#### 3. "Error: failed to create RDS instance: DBSubnetGroupNotFoundFault"

**Solution**: Ensure VPC and subnets are created:
```bash
cd environments/dev/vpc
terragrunt apply
```

#### 4. EKS nodes not joining cluster

**Solution**: Check node IAM role has required policies:
```bash
# Verify node role policies
aws iam list-attached-role-policies --role-name <node-role-name>

# Check node group status
aws eks describe-nodegroup --cluster-name pawapay-eks-dev --nodegroup-name <nodegroup-name>
```

#### 5. "Unable to connect to the server: dial tcp: lookup"

**Solution**: Update kubeconfig and verify API access:
```bash
aws eks update-kubeconfig --name pawapay-eks-dev --region us-east-1
kubectl cluster-info
```

### Debug Commands

```bash
# Enable Terragrunt debug logging
export TERRAGRUNT_DEBUG=1
terragrunt plan

# Enable Terraform debug logging
export TF_LOG=DEBUG
terraform plan

# Check AWS CLI connectivity
aws sts get-caller-identity
aws eks list-clusters --region us-east-1
```

## Cost Optimization

### Estimated Monthly Costs (us-east-1)

- **EKS Cluster**: ~$73/month (control plane)
- **EC2 Instances**: ~$30/month (2x t3.small nodes)
- **NAT Gateways**: ~$65/month (2x Multi-AZ)
- **RDS**: ~$26/month (db.t3.micro Multi-AZ)
- **Data Transfer**: Variable
- **Total**: ~$194/month

### Cost Reduction Options

#### For Development:
```hcl
# Single AZ deployment
availability_zones = ["us-east-1a"]

# Single NAT gateway
# (requires VPC module modification)

# RDS Single-AZ
multi_az = false

# Smaller nodes
node_instance_types = ["t3.micro"]  # Not recommended for production
desired_node_count  = 1

# Estimated savings: ~$100/month (~$94/month total)
```

#### For Production:
- Use Reserved Instances for predictable workloads (save ~40%)
- Use Savings Plans for compute (save ~30-50%)
- Enable EKS Fargate for batch workloads
- Use S3 Intelligent-Tiering for state storage
- Implement auto-scaling based on metrics

## Security Best Practices

### Current Implementation

- All resources tagged with environment and project
- RDS encryption at rest (enabled by default)
- RDS credentials stored in AWS Secrets Manager
- Private subnets for EKS nodes and RDS
- Security groups with least-privilege access
- EKS control plane logging enabled
- IAM roles with minimum required permissions
- S3 state encryption and versioning
- DynamoDB state locking

### Recommended Enhancements

1. **Network Security**:
   - Restrict `public_access_cidrs` to specific IPs
   - Implement VPN or AWS Client VPN for database access
   - Enable VPC Flow Logs for network monitoring

2. **EKS Security**:
   - Enable pod security standards
   - Implement network policies (Calico/Cilium)
   - Use AWS IAM Roles for Service Accounts (IRSA)
   - Enable audit logging

3. **Database Security**:
   - Rotate RDS credentials regularly
   - Enable automated backups (already enabled)
   - Implement read replicas for DR
   - Use IAM database authentication

4. **State Security**:
   - Enable S3 bucket logging
   - Use S3 Object Lock for compliance
   - Implement cross-region replication for DR

5. **Access Control**:
   - Implement AWS Organizations for multi-account
   - Use AWS SSO for centralized authentication
   - Enable CloudTrail for audit logging
   - Implement GuardDuty for threat detection

## Maintenance

### Updates

#### Update Terraform/Terragrunt
```bash
# Check current versions
terraform --version
terragrunt --version

# Update via Homebrew (macOS)
brew upgrade terraform
brew upgrade terragrunt
```

#### Update Kubernetes Version
```bash
# Update in environments/dev/terragrunt.hcl
kubernetes_version = "1.35"  # When available

# Apply changes
cd environments/dev/eks
terragrunt plan
terragrunt apply
```

#### Update Module Dependencies
```bash
# Update provider versions in terragrunt.hcl
required_providers {
  aws = {
    source  = "hashicorp/aws"
    version = "~> 6.0"  # Update version constraint
  }
}

# Re-initialize
cd environments/dev
terragrunt run-all init -upgrade
```

### Backup and Recovery

#### State Backup
```bash
# S3 versioning is enabled, but you can also:
aws s3 sync s3://pawapay-terraform-state-<account-id> ./state-backup/
```

#### Resource Backup
```bash
# EKS resources
kubectl get all --all-namespaces -o yaml > eks-backup.yaml

# RDS snapshots (automatic, but can trigger manual)
aws rds create-db-snapshot \
  --db-instance-identifier pawapay-rds \
  --db-snapshot-identifier pawapay-manual-backup-$(date +%Y%m%d)
```

## Cleanup

### Complete Teardown

```bash
cd environments/dev

# Destroy all resources (in reverse dependency order)
terragrunt run-all destroy

# Or destroy individually:
cd eks && terragrunt destroy && cd ..
cd rds && terragrunt destroy && cd ..
cd ecr && terragrunt destroy && cd ..
cd iam && terragrunt destroy && cd ..
cd vpc && terragrunt destroy && cd ..
```

### Cleanup State Infrastructure

```bash
# Get account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Delete S3 bucket (after removing all objects)
aws s3 rm s3://pawapay-terraform-state-${AWS_ACCOUNT_ID} --recursive
aws s3api delete-bucket --bucket pawapay-terraform-state-${AWS_ACCOUNT_ID} --region us-east-1

# Delete DynamoDB table
aws dynamodb delete-table --table-name pawapay-terraform-locks --region us-east-1
```

## Contributing

### Development Workflow

1. Create feature branch: `git checkout -b feature/new-module`
2. Make changes to modules or configurations
3. Format code: `terraform fmt -recursive modules/`
4. Validate: `cd modules/<module> && terraform init -backend=false && terraform validate`
5. Test locally: `cd environments/dev/<module> && terragrunt plan`
6. Commit and push: `git commit -m "Add new module" && git push`
7. Create pull request for review

### Module Development

When creating new modules:
1. Follow the structure in existing modules
2. Include README.md with inputs/outputs documentation
3. Add proper variable validation
4. Include examples in comments
5. Use consistent naming conventions
6. Add appropriate tags support

## Support and Documentation

### Additional Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [Terragrunt Documentation](https://terragrunt.gruntwork.io/docs/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [AWS RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)

### Module Documentation

Each module has detailed documentation:
- [VPC Module](modules/vpc/README.md)
- [IAM Module](modules/iam/README.md)
- [ECR Module](modules/ecr/README.md)
- [RDS Module](modules/rds/README.md)
- [EKS Module](modules/eks/README.md)

## License

This infrastructure code is maintained for the PawaPay ConfigMirror project.

---

**Built with Terraform + Terragrunt | Production-Ready | Enterprise-Grade**
