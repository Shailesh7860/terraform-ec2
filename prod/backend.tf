# =====================================================================
# BLOCK 1: S3 BACKEND 
# =====================================================================
terraform {
  backend "s3" {
    bucket       = "terraform-github-tf-state"
    key          = "terraform/prod/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
  }
}