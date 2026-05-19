variable "project_name" {
  default = "pixel-monitor"
}

variable "aws_region" {
  default = "us-east-1"
}

# network
variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  default = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "is_production" {
  description = "whether to deploy production resources (like RDS)"
  type        = bool
  default     = false
}

# RDS PostgreSQL -----
variable "db" {
  description = "RDS PostgreSQL configuration"
  type = object({
    name                  = optional(string, "pixeldb") # db name
    username              = optional(string, "appuser")
    instance_class        = optional(string, "db.t4g.micro")
    allocated_storage     = optional(number, 20)
    max_allocated_storage = optional(number, 100)
    engine_version        = optional(string, "17.9")
    backup_retention_days = optional(number, 7)
  })
  default = {}
}

# API Container
variable "api_container" {
  description = "API container configuration"
  type = object({
    name  = optional(string, "api")
    image = optional(string, "802838070254.dkr.ecr.us-east-1.amazonaws.com/pixel-monitor:v4")
    port  = optional(number, 8000)
  })
  default = {}
}

# ECS -----
variable "ecs" {
  description = "ECS configuration"
  type = object({
    desired_count = optional(number, 2)
    cpu           = optional(number, 256) # 0.25 vCPU
    memory        = optional(number, 512) # 0.5 GB
  })
  default = {}
}

variable "AWS_STORAGE_BUCKET_NAME" {
  description = "S3 bucket name for storage"
  type        = string
  default     = "pixel-monitor-storage-bucket"
}

variable "allowed_hosts" {
  description = "Comma-separated list of allowed hosts for Django"
  type        = string
  # for testing, allow all hosts.
  # In production, this should be set to the ALB DNS name or a domain name pointing to it.
  # default = "*"

  default     = "pixel-monitor-default-alb-537414936.us-east-1.elb.amazonaws.com"

}