variable "project_name" {
  default = "pixel-monitor"
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