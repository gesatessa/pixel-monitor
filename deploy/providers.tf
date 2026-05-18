terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket               = "pixel-monitor-tf-state-file-bucket"
    region               = "us-east-1"
    encrypt              = false
    use_lockfile         = true
    workspace_key_prefix = "environ"
    key                  = "deploy/tf.tfstate"
    # s3://pixel-monitor-tf-state-file-bucket/deploy/tf.tfstate
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = terraform.workspace
      ProjectName = var.project_name
    }
  }
}
