# ╔══════════════════════════════════════════════════════════════╗
# ║  iam.tf — IAM roles and policies for EKS                  ║
# ║                                                            ║
# ║  WHAT IS IAM?                                              ║
# ║  IAM (Identity & Access Management) controls WHO can do    ║
# ║  WHAT in AWS. Every AWS service needs permission.          ║
# ║                                                            ║
# ║  KEY CONCEPT: "Assume Role"                                ║
# ║  A role is like a badge. When EKS "assumes" a role, it     ║
# ║  gets the permissions attached to that role. The "assume   ║
# ║  role policy" says WHO is allowed to wear the badge.       ║
# ║                                                            ║
# ║  We create 3 roles:                                        ║
# ║  1. EKS Cluster Role  — the control plane's permissions   ║
# ║  2. Node Group Role   — worker nodes' permissions         ║
# ║  3. LB Controller Role (IRSA) — for AWS Load Balancer     ║
# ╚══════════════════════════════════════════════════════════════╝

# ══════════════════════════════════════════════
# 1. EKS CLUSTER ROLE
# ══════════════════════════════════════════════
# The EKS control plane needs this role to:
# - Manage networking (ENIs, security groups)
# - Write logs to CloudWatch
# - Manage the Kubernetes API server

# "Trust policy" — says "the EKS service is allowed to assume this role"
data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "${var.project_name}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json

  tags = {
    Name = "${var.project_name}-eks-cluster-role"
  }
}

# Attach AWS-managed policies (pre-built permission sets from AWS)
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ══════════════════════════════════════════════
# 2. NODE GROUP ROLE
# ══════════════════════════════════════════════
# Worker nodes (EC2 instances) need permissions to:
# - Join the EKS cluster
# - Pull images from ECR
# - Get assigned IPs (CNI plugin)

data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_node" {
  name               = "${var.project_name}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json

  tags = {
    Name = "${var.project_name}-eks-node-role"
  }
}

# AmazonEKSWorkerNodePolicy — lets nodes register with EKS
resource "aws_iam_role_policy_attachment" "eks_node_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# AmazonEKS_CNI_Policy — lets the VPC CNI plugin assign pod IPs
resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# AmazonEC2ContainerRegistryReadOnly — lets nodes pull images from ECR
resource "aws_iam_role_policy_attachment" "eks_ecr_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ══════════════════════════════════════════════
# 3. OIDC PROVIDER (for IRSA)
# ══════════════════════════════════════════════
# IRSA = IAM Roles for Service Accounts
#
# WHAT IS IRSA?
# Normally, ALL pods on a node share the node's IAM permissions.
# IRSA lets you give INDIVIDUAL pods their own IAM role.
# This is the "least privilege" principle.
#
# HOW?
# EKS has an OIDC identity provider. When a pod has a ServiceAccount
# annotated with a role ARN, AWS trusts that the pod IS that role.
#
# This block creates the trust relationship between EKS and IAM.

# Get the TLS certificate for the OIDC provider URL
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# Register the EKS OIDC provider with IAM
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Name = "${var.project_name}-eks-oidc"
  }
}

# ══════════════════════════════════════════════
# 4. AWS LOAD BALANCER CONTROLLER ROLE (IRSA)
# ══════════════════════════════════════════════
# The AWS Load Balancer Controller is a Kubernetes controller
# that creates ALBs when you create Ingress resources.
# It needs IAM permissions to create/manage ALBs, Target Groups, etc.
#
# This is a great example of IRSA:
# Only the LB controller pod gets these permissions, not all pods.

# Trust policy: "the LB controller's ServiceAccount can assume this role"
data "aws_iam_policy_document" "lb_controller_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lb_controller" {
  name               = "${var.project_name}-lb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_assume_role.json

  tags = {
    Name = "${var.project_name}-lb-controller-role"
  }
}

# The LB controller needs a LOT of permissions (create ALB, manage SGs, etc.)
# AWS provides an official policy JSON for this. We create a custom policy from it.
resource "aws_iam_policy" "lb_controller" {
  name        = "${var.project_name}-lb-controller-policy"
  description = "IAM policy for AWS Load Balancer Controller"

  # This policy is maintained by AWS. Full list of permissions:
  # https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
  policy = file("${path.module}/policies/lb-controller-policy.json")
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

# ══════════════════════════════════════════════
# 5. EBS CSI DRIVER ROLE (IRSA)
# ══════════════════════════════════════════════
# The EBS CSI driver lets Kubernetes create EBS volumes
# for PersistentVolumeClaims (used by MongoDB).
# It needs IAM permissions to create/attach/delete EBS volumes.

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.project_name}-ebs-csi-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json

  tags = {
    Name = "${var.project_name}-ebs-csi-role"
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
