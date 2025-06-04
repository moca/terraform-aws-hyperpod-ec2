output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.hyperpod_bucket.bucket
}

output "hyperpod_cluster_name" {
  description = "Name of the HyperPod cluster"
  value       = awscc_sagemaker_cluster.hyperpod_cluster.cluster_name
}


