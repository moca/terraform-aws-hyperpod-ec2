# EKS Cluster Outputs
output "eks_cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = module.ec2_eks.cluster_arn
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.ec2_eks.cluster_name
}

output "hyperpod_cluster_name" {
  description = "Name of the HyperPod cluster"
  value       = module.hp_eks.hyperpod_cluster_name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = module.hp_eks.s3_bucket_name
}

# Region Output
output "aws_region" {
  description = "AWS region"
  value       = data.aws_region.current.name
}



