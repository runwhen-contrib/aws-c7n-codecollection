provider "aws" {
  region = "us-west-2" # Replace with your desired region
}

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }
  required_version = ">= 1.0"
}