terraform {
  backend "s3" {
    bucket       = "p250825-tf-state"
    key          = "site/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
