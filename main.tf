#------------------------------------------------------------------------------
# Root Module - Orchestrates EKS and HyperPod modules
#------------------------------------------------------------------------------
data "aws_region" "current" {}


module "ec2_eks" {
  source = "./ec2_eks"
  
  resource_name_prefix   = var.resource_name_prefix
  vpc_cidr              = var.vpc_cidr

  availability_zone_ids = var.availability_zone_ids
  kubernetes_version    = var.kubernetes_version
}

module "hp_eks" {
  source = "./hp_eks"

  resource_name_prefix   = var.resource_name_prefix
  vpc_id = module.ec2_eks.vpc_id
  availability_zones_ids = var.availability_zone_ids
  hyperpod_availability_zone = var.hyperpod_availability_zone
  hyperpod_subnet_cidr = var.hyperpod_subnet_cidr
  hyperpod_security_group_ids = module.ec2_eks.security_group_ids
  natgw_ids = module.ec2_eks.natgw_ids
  
  eks_cluster_name = module.ec2_eks.cluster_name
  eks_cluster_endpoint = module.ec2_eks.cluster_endpoint
  eks_cluster_arn = module.ec2_eks.cluster_arn
  eks_cluster_ca_data = module.ec2_eks.cluster_ca_data
      
  hyperpod_cluster_name = "${module.ec2_eks.cluster_name}-ml"
  hyperpod_helm_repo_url = var.hyperpod_helm_repo_url
  hyperpod_lifecycle_script_url = var.hyperpod_lifecycle_script_url
  hyperpod_node_recovery = var.hyperpod_node_recovery
  hyperpod_instance_groups = var.hyperpod_instance_groups

}
