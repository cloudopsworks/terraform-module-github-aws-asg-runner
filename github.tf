terraform {
  required_providers {
    time = {
      source  = "hashicorp/time"
      version = "0.13.1"
    }
  }
}
##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

resource "random_string" "this" {
  length  = 64
  special = true
  upper   = true
  numeric = true
  lower   = true

  lifecycle {
    replace_triggered_by = [
      time_rotating.this
    ]
  }
}

resource "time_rotating" "this" {
  rotation_days = 90
}

locals {
  secretb64 = base64encode(random_string.this.result)
}
resource "github_actions_runner_group" "this" {
  name                       = "aws-runners"
  visibility                 = "all"
  allows_public_repositories = true
}

resource "github_organization_webhook" "this" {
  configuration {
    url          = aws_lambda_function_url.this.function_url
    content_type = "application/json"
    insecure_ssl = false
    secret       = local.secretb64
    active       = true
  }
}