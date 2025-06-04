variable "resource_name_prefix" {
  description = "Prefix for resource names"
  type        = string
}


variable "availability_zones_ids" {
  description = "List of availability zone IDs"
  type        = list(string)
}

variable "hyperpod_availability_zone" {
  description = "Availability zone ID for HyperPod subnet"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID from EKS module"
  type        = string
}

variable "hyperpod_security_group_ids" {
  description = "Security group ID from EKS module"
  type        = list(string)
}


variable "natgw_ids" {
  description = "NAT Gateway IDs from EKS module"
  type        = list(string)
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string  
}

variable eks_cluster_arn {
  description = "ARN of the EKS cluster"
  type        = string
}

variable eks_cluster_ca_data {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  type        = string
  sensitive   = true
}

variable eks_cluster_endpoint {
  description = "Endpoint of the EKS cluster"
  type        = string
}


variable "hyperpod_cluster_name" {
  description = "Name for HyperPod cluster"
  type        = string
}

variable "hyperpod_subnet_cidr" {
  description = "CIDR block for HyperPod subnet"
  type        = string
}

variable "hyperpod_helm_repo_url" {
  description = "The URL of the Helm repo containing the HyperPod Helm chart"
  type        = string
}

variable "hyperpod_lifecycle_script_url" {
  description = "URL for lifecycle script"
  type        = string
}

variable "hyperpod_node_recovery" {
  description = "Node recovery mode"
  type        = string
  default     = "Automatic"
}

variable "hyperpod_instance_groups" {
  description = "Map of instance group configurations"
  type = map(object({
    instance_type       = string
    instance_count      = number
    ebs_volume_size    = number
    threads_per_core   = number
    enable_stress_check = bool
    enable_connectivity_check = bool
    lifecycle_script    = string
  }))
}