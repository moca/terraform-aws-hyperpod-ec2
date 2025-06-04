variable "resource_name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable aws_region {
  description = "AWS region for resource deployment"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.192.0.0/16"
}

variable "hyperpod_subnet_cidr" {
  description = "CIDR block for HyperPod subnet"
  type        = string
  default     = "10.1.0.0/16"  
}

variable "availability_zone_ids" {
  description = "List of availability zone IDs"
  type        = list(string)
}

variable "hyperpod_availability_zone" {
  description = "Availability zone ID for HyperPod subnet"
  type        = string
}


variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.31"
}

variable "hyperpod_node_recovery" {
  description = "Node recovery mode"
  type        = string
  default     = "Automatic"
}

variable "hyperpod_lifecycle_script_url" {
  description = "URL for lifecycle script"
  type        = string
  default = "https://raw.githubusercontent.com/aws-samples/awsome-distributed-training/main/1.architectures/7.sagemaker-hyperpod-eks/LifecycleScripts/base-config/on_create.sh"
}

variable "hyperpod_helm_repo_url" {
  description = "The URL of the Helm repo containing the HyperPod Helm chart"
  type        = string
  default     = "https://github.com/aws/sagemaker-hyperpod-cli.git"
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
