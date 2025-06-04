#------------------------------------------------------------------------------
# Data Sources
#------------------------------------------------------------------------------

data "aws_region" "current" {}

# Get AZ data from IDs
data "aws_availability_zones" "available" {
  filter {
    name   = "zone-id"
    values = var.availability_zone_ids
  }
}

locals {
  eks_cluster_name = "${var.resource_name_prefix}-eks"
  azs             = data.aws_availability_zones.available.names
}

#------------------------------------------------------------------------------
# VPC Module for vanilla EKS
#------------------------------------------------------------------------------

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.resource_name_prefix}-vpc"
  cidr = var.vpc_cidr

  azs = data.aws_availability_zones.available.names
  
  # Only create subnets from primary CIDR for EKS
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 52)]
  
  # EKS-specific subnet tagging
  public_subnet_tags = {
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "shared"
    "kubernetes.io/role/elb"                          = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"               = "1"
  }

  enable_nat_gateway     = true
  one_nat_gateway_per_az = true
  enable_vpn_gateway     = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Project = var.resource_name_prefix
  }
}

#------------------------------------------------------------------------------
# Security Group
#------------------------------------------------------------------------------

resource "aws_security_group" "main_sg" {
  name        = "${var.resource_name_prefix}-security-group"
  description = "Security group for HyperPod cluster"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow all traffic within the security group"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.resource_name_prefix}-security-group"
  }
}

#------------------------------------------------------------------------------
# EKS Cluster Module
#------------------------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.eks_cluster_name
  cluster_version = var.kubernetes_version

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  enable_cluster_creator_admin_permissions = true

  cluster_security_group_additional_rules = {
    allow_all_internal = {
      description = "Allow all traffic within the security group"
      protocol    = "-1"
      from_port  = 0
      to_port    = 0
      type       = "ingress"
      self       = true
    }
  }

  eks_managed_node_groups = {
    default = {
      name            = "${var.resource_name_prefix}-ng"
      use_name_prefix = true
      vpc_security_group_ids = [aws_security_group.main_sg.id]
      subnet_ids = module.vpc.private_subnets
      ami_type       = "BOTTLEROCKET_x86_64"      

      min_size     = 1
      max_size     = 1
      desired_size = 1

      instance_types = ["m6i.2xlarge"]
      capacity_type  = "ON_DEMAND"

      labels = {
        Environment = "default"
      }

      tags = {
        Name = "${var.resource_name_prefix}-node-group"
      }
    }
  }

  tags = {
    Project = var.resource_name_prefix
  }
}
