terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"

  default_tags {
    tags = {
      Owner     = "p250825"
      Project   = "aws-static-pipeline"
      ManagedBy = "terraform"
    }
  }
}
