data "aws_region" "current" {}

# EKS cluster data for provider configuration

data "aws_eks_cluster_auth" "cluster" {
  name = var.eks_cluster_name
}


provider "helm" {
  kubernetes {
    host                   = var.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(var.eks_cluster_ca_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}
 

#------------------------------------------------------------------------------
# Create Subnet for HyperPod
#------------------------------------------------------------------------------

# Add secondary CIDR block separately for HyperPod only
resource "aws_vpc_ipv4_cidr_block_association" "hyperpod_cidr" {
  vpc_id     = var.vpc_id
  cidr_block = var.hyperpod_subnet_cidr
}

# Create HyperPod subnet manually from secondary CIDR
resource "aws_subnet" "hyperpod_subnet" {
  vpc_id            = var.vpc_id
  cidr_block        = var.hyperpod_subnet_cidr
  availability_zone_id = var.hyperpod_availability_zone
  
  tags = {
    Name = "${var.resource_name_prefix}-hyperpod-subnet"
  }
  
  depends_on = [aws_vpc_ipv4_cidr_block_association.hyperpod_cidr]
}

# Route table for HyperPod subnet
resource "aws_route_table" "hyperpod_rt" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    # Find the NAT gateway in the same AZ as the HyperPod subnet
    nat_gateway_id = var.natgw_ids[
      index(
        var.availability_zones_ids, 
        var.hyperpod_availability_zone
      )
    ]
  }

  tags = {
    Name = "${var.resource_name_prefix}-hyperpod-rt"
  }
}

# Associate route table with HyperPod subnet
resource "aws_route_table_association" "hyperpod_rt_association" {
  subnet_id      = aws_subnet.hyperpod_subnet.id
  route_table_id = aws_route_table.hyperpod_rt.id
}

# #------------------------------------------------------------------------------
# # S3 Bucket and Endpoint
# #------------------------------------------------------------------------------

resource "random_string" "suffix" {
  length  = 4
  special = false
  lower   = true
  upper   = false
}

resource "aws_s3_bucket" "hyperpod_bucket" {
  bucket = lower("${var.resource_name_prefix}-bucket-${data.aws_region.current.name}-${random_string.suffix.result}")

  tags = {
    Name = "${var.resource_name_prefix}-bucket"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_encryption" {
  bucket = aws_s3_bucket.hyperpod_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "hyperpod_bucket_access" {
  bucket = aws_s3_bucket.hyperpod_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# # S3 VPC Endpoint
resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.hyperpod_rt.id]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "*"
        Resource  = "*"
      }
    ]
  })

  tags = {
    Name = "${var.resource_name_prefix}-s3-endpoint"
  }
}

#------------------------------------------------------------------------------
# Lifecycle Script Upload to S3
#------------------------------------------------------------------------------

# Fetch script content directly from URL
data "http" "lifecycle_script" {
  url = var.hyperpod_lifecycle_script_url
}

# # Upload script to S3 directly from response body
resource "aws_s3_object" "lifecycle_script_upload" {
  bucket  = aws_s3_bucket.hyperpod_bucket.id
  key     = "on_create.sh"
  content = data.http.lifecycle_script.response_body
  content_type = "text/x-sh"
}

#------------------------------------------------------------------------------
# IAM Role for SageMaker
#------------------------------------------------------------------------------

resource "aws_iam_role" "sagemaker_execution_role" {
  name = "${var.resource_name_prefix}-hp-exec-role-${data.aws_region.current.name}"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sagemaker_managed_policy_attachment" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerClusterInstanceRolePolicy"
}

resource "aws_iam_role_policy_attachment" "sagemaker_eks_cni_policy_attachment" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_policy" "sagemaker_execution_policy" {
  name = "${var.resource_name_prefix}-ExecutionRolePolicy-${data.aws_region.current.name}"
  path = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:AssignPrivateIpAddresses",
          "ec2:CreateNetworkInterface",
          "ec2:CreateNetworkInterfacePermission",
          "ec2:DeleteNetworkInterface",
          "ec2:DeleteNetworkInterfacePermission",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeVpcs",
          "ec2:DescribeDhcpOptions",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DetachNetworkInterface",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:UnassignPrivateIpAddresses",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken",
          "ecr:GetDownloadUrlForLayer",
          "eks-auth:AssumeRoleForPodIdentity",
          "cloudwatch:DescribeAlarms"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = "arn:aws:ec2:*:*:network-interface/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject"
        ]
        Resource = [
          aws_s3_bucket.hyperpod_bucket.arn,
          "${aws_s3_bucket.hyperpod_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sagemaker_execution_policy_attachment" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = aws_iam_policy.sagemaker_execution_policy.arn
}


#------------------------------------------------------------------------------
# Install helm dependencies prior to HyperPod Installation
#------------------------------------------------------------------------------


resource "null_resource" "git_clone" {
  triggers = {
    helm_repo_url = var.hyperpod_helm_repo_url
    # Add a random trigger to force recreation
    random = uuid()
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Starting git clone operation..."
      echo "Cleaning up existing directory..."
      rm -rf /tmp/helm-repo
      echo "Creating fresh directory..."
      mkdir -p /tmp/helm-repo
      echo "Cloning from ${var.hyperpod_helm_repo_url}..."
      git clone ${var.hyperpod_helm_repo_url} /tmp/helm-repo
      echo "Contents of /tmp/helm-repo:"
      ls -la /tmp/helm-repo
      echo "Git clone complete"
    EOT
  }
}

resource "null_resource" "helm_dep_update" {
  triggers = {
    helm_repo_url = var.hyperpod_helm_repo_url
    git_clone = null_resource.git_clone.id
    # Add a random trigger to force recreation
    random = uuid()
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Starting helm dependency update..."
      echo "Checking for /tmp/helm-repo..."
      if [ ! -d "/tmp/helm-repo" ]; then
        echo "Error: /tmp/helm-repo directory does not exist"
        exit 1
      fi
      
      echo "Checking for chart directory..."
      if [ ! -d "/tmp/helm-repo/helm_chart/HyperPodHelmChart" ]; then
        echo "Error: Chart directory helm_chart/HyperPodHelmChart not found"
        echo "Contents of /tmp/helm-repo:"
        ls -la /tmp/helm-repo
        exit 1
      fi

      echo "Running helm dependency update..."
      helm dependency update /tmp/helm-repo/helm_chart/HyperPodHelmChart
      echo "Helm dependency update complete"
    EOT
  }

  depends_on = [null_resource.git_clone]
}


resource "helm_release" "hyperpod" {
  name       = "hyperpod-dependencies"
  chart      = "/tmp/helm-repo/helm_chart/HyperPodHelmChart"
  namespace  = "kube-system"

  depends_on = [
    null_resource.git_clone,
    null_resource.helm_dep_update,
  ]

  # Force recreation of the helm release when git repo changes
  lifecycle {
    replace_triggered_by = [
      null_resource.git_clone,
      null_resource.helm_dep_update

    ]
  }
}


#------------------------------------------------------------------------------
# SageMaker HyperPod Cluster
#------------------------------------------------------------------------------

resource "awscc_sagemaker_cluster" "hyperpod_cluster" {
  cluster_name = var.hyperpod_cluster_name
  
  instance_groups = [
    for key, group in var.hyperpod_instance_groups : {
      instance_group_name = key
      instance_count = group.instance_count
      instance_type = group.instance_type

      life_cycle_config = {
          on_create     = group.lifecycle_script
          source_s3_uri = "s3://${aws_s3_bucket.hyperpod_bucket.id}"
        }
      execution_role = aws_iam_role.sagemaker_execution_role.arn
      
      instance_group_settings = {
        lifecycle_management_settings = {
          max_parallelism = 100
        }
        threading_settings = {
          threads_per_core = group.threads_per_core
        }
      }

      enable_stress_check = group.enable_stress_check
      node_recovery = var.hyperpod_node_recovery
      
      instance_storage_configs = [{
          volume_size_in_gb = group.ebs_volume_size
          volume_type = "ebs"
      }]     
    }
  ]

  orchestrator = {
    eks = {
      cluster_arn = var.eks_cluster_arn
    }
  }

  vpc_config = {
    security_group_ids = var.hyperpod_security_group_ids
    subnets            = [aws_subnet.hyperpod_subnet.id]
  }
  
  depends_on = [
    aws_s3_object.lifecycle_script_upload,
    aws_iam_role_policy_attachment.sagemaker_execution_policy_attachment,
    helm_release.hyperpod
  ]
}
