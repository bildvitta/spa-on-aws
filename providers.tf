terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }

    github = {
      source = "integrations/github"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "github" {
  owner = var.github_owner
}
