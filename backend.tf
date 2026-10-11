
terraform {
  backend "s3" {
    bucket = "giwasda-s3"
    key    = "infrastructure/terraform.tfstate"
    region = "eu-north-1"
  }
}

