output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "security_group_ids" {
  description = "ID of the main security group"
  value       = [aws_security_group.main_sg.id, module.eks.node_security_group_id] 
}

output "natgw_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.vpc.natgw_ids
}

output "availability_zones_ids" {
  description = "Available zones data"
  value       = data.aws_availability_zones.available
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint  # or aws_eks_cluster.this.endpoint
}

output "cluster_ca_data" {
  description = "EKS cluster certificate authority data"
  value       = module.eks.cluster_certificate_authority_data
}
