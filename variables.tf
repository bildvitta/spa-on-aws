variable "name" {
  type = string
}

variable "area" {
  type = string
}

variable "domain" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "aws_route53_zone_id" {
  type = string
}

variable "github_owner" {
  type = string
}

variable "github_repository" {
  type = string
}

variable "environments" {
  type = list(string)
}
