# Terraform — AWS EKS Infrastructure

This directory contains the Infrastructure-as-Code (IaC) for deploying the NET4255 platform on AWS EKS.

## Architecture

```
┌──────────────────────── AWS Region (us-east-1) ─────────────────────────┐
│                                                                         │
│  ┌────────────────────── VPC 10.0.0.0/16 ──────────────────────────┐   │
│  │                                                                  │   │
│  │  Public Subnets              Private Subnets                     │   │
│  │  ┌──────────┐               ┌──────────────────────────────┐    │   │
│  │  │ 10.0.1.0 │  NAT GW ──▷  │ 10.0.10.0  │  10.0.20.0    │    │   │
│  │  │ 10.0.2.0 │               │  EKS Nodes  │  EKS Nodes    │    │   │
│  │  │   ALB    │               │  MongoDB    │  Flask Pods   │    │   │
│  │  └──────────┘               └──────────────────────────────┘    │   │
│  │        ▲                                                         │   │
│  │        │ Internet Gateway                                        │   │
│  └────────┼─────────────────────────────────────────────────────────┘   │
│           │                                                             │
│  ┌────────┴────┐   ┌──────────┐   ┌──────────┐   ┌─────────────────┐  │
│  │ EKS Cluster │   │   ECR    │   │ EBS CSI  │   │ LB Controller   │  │
│  │ (managed)   │   │ Registry │   │ (PVCs)   │   │ (IRSA)          │  │
│  └─────────────┘   └──────────┘   └──────────┘   └─────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- AWS credentials configured: `aws configure`

## Quick Start

```bash
# 1. Copy and edit the variables file
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# 2. Initialize Terraform (downloads providers)
terraform init

# 3. Preview what will be created
terraform plan

# 4. Create the infrastructure (~15 minutes)
terraform apply

# 5. Configure kubectl
$(terraform output -raw configure_kubectl)

# 6. Verify cluster access
kubectl get nodes
```

## Files

| File | Purpose |
|------|---------|
| `main.tf` | Provider config, backend (local state) |
| `variables.tf` | All configurable inputs |
| `vpc.tf` | VPC, subnets, IGW, NAT GW, route tables |
| `eks.tf` | EKS cluster, managed node group, add-ons |
| `ecr.tf` | ECR repository + lifecycle policy |
| `iam.tf` | IAM roles: cluster, nodes, IRSA (LB, EBS) |
| `outputs.tf` | Cluster endpoint, ECR URL, helper commands |
| `policies/` | AWS-managed IAM policy JSONs |

## Estimated Costs (dev)

| Resource | ~Monthly Cost |
|----------|--------------|
| EKS control plane | $73 |
| 2x t3.medium nodes | $60 |
| NAT Gateway | $32 + data |
| EBS volumes (3x 1Gi MongoDB) | < $1 |
| **Total** | **~$166/mo** |

> Tip: To save costs, scale to 0 nodes when not in use:
> `aws eks update-nodegroup-config --cluster-name net4255-cluster --nodegroup-name net4255-nodes --scaling-config minSize=0,maxSize=4,desiredSize=0`

## Tear Down

```bash
# Destroy everything (careful!)
terraform destroy
```
