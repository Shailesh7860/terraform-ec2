# AWS Infrastructure Pipeline

A production-ready Terraform and Jenkins CI/CD pipeline for automating AWS infrastructure deployment. This project provisions a complete AWS VPC with public/private subnets, EC2 instances, and security groups in the AWS Mumbai region (ap-south-1).

## 📋 Overview

This repository contains Infrastructure as Code (IaC) using Terraform to automate the provisioning and management of AWS resources. A Jenkins pipeline handles automated deployment, state management, and infrastructure lifecycle operations.

### What Gets Deployed

- **VPC**: Virtual Private Cloud with CIDR block `10.0.0.0/16`
- **Public Subnet**: `10.0.1.0/24` - for internet-facing resources
- **Private Subnet**: `10.0.2.0/24` - for internal resources
- **EC2 Instances**: Compute instances in both subnets
- **Security Groups**: Network access control
- **Internet Gateway & NAT**: Network connectivity
- **Route Tables**: Traffic routing rules

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│          AWS VPC (10.0.0.0/16)              │
├─────────────────────────────────────────────┤
│  Public Subnet (10.0.1.0/24)                │
│  ├─ Internet Gateway                        │
│  └─ EC2 Instance (Public)                   │
├─────────────────────────────────────────────┤
│  Private Subnet (10.0.2.0/24)               │
│  └─ EC2 Instance (Private)                  │
└─────────────────────────────────────────────┘
```

## 📦 Prerequisites

### Local Development
- **Terraform**: >= 1.5.0
- **AWS CLI**: v2 (latest)
- **AWS Account**: With appropriate permissions
- **AWS Credentials**: Configured locally (`~/.aws/credentials`)

### Jenkins Pipeline
- **Jenkins**: With Terraform plugin installed
- **Terraform Plugin**: terraform-1.5 configured in Jenkins
- **AWS Credentials**: Configured in Jenkins (ID: `Tony`)
- **Git Access**: Ability to clone from GitHub

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/Shailesh7860/terraform-ec2.git
cd terraform-ec2
```

### 2. Configure AWS Credentials
```bash
# Option 1: Using AWS CLI
aws configure

# Option 2: Set environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-south-1"
```

### 3. Initialize Terraform
```bash
cd prod
terraform init
```

### 4. Plan Infrastructure
```bash
terraform plan
```

### 5. Apply Configuration
```bash
terraform apply
```

## ⚙️ Configuration

### Key Variables

Edit `prod/terraform.tfvars` to customize:

```hcl
aws_region          = "ap-south-1"        # AWS region
vpc_cidr            = "10.0.0.0/16"       # VPC CIDR block
public_subnet_cidr  = "10.0.1.0/24"       # Public subnet
private_subnet_cidr = "10.0.2.0/24"       # Private subnet
ami_id              = "ami-0b1ed96948adabcd9"  # Ubuntu AMI
instance_type       = "t3.micro"           # EC2 instance type
tags_name           = "Terraform-github"   # Resource naming prefix
```

### State Management

Terraform state is stored in S3 (remote backend):
- **Bucket**: `terraform-github-tf-state`
- **Key**: `terraform/prod/terraform.tfstate`
- **Region**: `ap-south-1`
- **Locking**: Enabled via DynamoDB

## 📁 Project Structure

```
terraform-ec2/
├── Jenkinsfile              # Jenkins pipeline definition
├── README.md                # This file
├── steps.txt                # Setup/testing steps reference
└── prod/                    # Production environment
    ├── main.tf              # Core infrastructure resources
    ├── variable.tf          # Variable definitions
    ├── backend.tf           # S3 backend configuration
    └── terraform.tfvars     # Variable values
```

## 🔄 Jenkins Pipeline

The `Jenkinsfile` automates the deployment process:

**Pipeline Stages:**
1. **Checkout** - Clone repository
2. **Terraform Init** - Initialize working directory
3. **Terraform Plan** - Preview infrastructure changes
4. **Terraform Apply** - Deploy infrastructure
5. **State Backup** - Backup state files (optional)

**Configuration:**
- Region: `ap-south-1`
- Jenkins Credentials: `Tony` (AWS)
- Automation Settings: Concurrent builds disabled for stability

## 🔑 SSH Key Generation

**⚠️ Important Security Note:**

This project **auto-generates SSH keys during infrastructure build** via Terraform. While convenient for development and learning purposes, this approach is **NOT suitable for production**:

### Current Approach (Project Level)
- Keys are generated automatically by Terraform
- Stored in the Terraform state file
- Convenient for quick prototyping

### Production-Level Considerations
- ✅ Use **AWS Systems Manager Session Manager** instead of SSH keys
- ✅ Store keys in **AWS Secrets Manager** or **HashiCorp Vault**
- ✅ Implement **key rotation policies**
- ✅ Use **IAM roles** instead of embedding credentials
- ✅ Enable **MFA** for all access
- ✅ Implement **audit logging** via CloudTrail

### For Testing with Generated Keys
```bash
# Keys are output after terraform apply
terraform output -raw private_key > ~/.ssh/terraform-key.pem
chmod 600 ~/.ssh/terraform-key.pem

# Connect to instance
ssh -i ~/.ssh/terraform-key.pem ec2-user@<instance-ip>
```

## 📊 Useful Commands

### Terraform Commands
```bash
cd prod

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive

# Show current state
terraform show

# Output values
terraform output

# Destroy all resources
terraform destroy
```

### AWS CLI Commands
```bash
# List instances
aws ec2 describe-instances --region ap-south-1

# Check VPC
aws ec2 describe-vpcs --region ap-south-1

# View security groups
aws ec2 describe-security-groups --region ap-south-1
```

## 📝 Outputs

After successful deployment, view outputs with:

```bash
terraform output
```

Common outputs include:
- VPC ID
- Subnet IDs
- EC2 Instance IPs
- Security Group IDs

## 🧹 Cleanup

To destroy all infrastructure and avoid unnecessary AWS charges:

```bash
cd prod
terraform destroy

# Confirm by typing 'yes'
```

## 🐛 Troubleshooting

### Error: "terraform.tfstate" not found
```bash
# Re-initialize Terraform
terraform init -reconfigure
```

### Error: AWS credentials not found
```bash
# Verify credentials are configured
aws sts get-caller-identity

# Or set environment variables
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
```

### State Lock Issues
```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

## 🔐 Security Best Practices

- ✅ Keep `terraform.tfstate` and credentials out of version control
- ✅ Use S3 backend with encryption enabled
- ✅ Enable S3 bucket versioning for state recovery
- ✅ Implement IAM policies for least privilege access
- ✅ Regularly audit AWS resources and permissions
- ✅ Enable VPC Flow Logs for monitoring
- ✅ Use security groups restrictively

## 📚 Additional Resources

- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)
- [Jenkins Terraform Plugin](https://plugins.jenkins.io/terraform/)
- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)

## 👤 Author

**Shailesh7860**

## 📄 License

This project is open source and available under the MIT License.

## 💬 Support

For issues, questions, or contributions, please open an issue on GitHub.

---

**Last Updated**: 2026-09-01
**Terraform Version**: >= 1.5.0
**AWS Provider Version**: ~> 5.0
