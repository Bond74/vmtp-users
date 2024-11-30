provider "aws" {
    profile = "default"
    region = "eu-west-1"
}

# *******************************************
# Running resources module
# *******************************************

module "resources" {
  source = "./../../resources"

  aws_region = "eu-west-1"
  stage = "prod"
}