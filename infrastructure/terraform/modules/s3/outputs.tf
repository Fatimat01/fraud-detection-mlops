# infrastructure/terraform/modules/s3/outputs.tf

output "bucket_ids" {
  description = "S3 bucket IDs"
  value       = { for k, v in aws_s3_bucket.buckets : k => v.id }
}

output "bucket_arns" {
  description = "S3 bucket ARNs"
  value       = { for k, v in aws_s3_bucket.buckets : k => v.arn }
}
