# Plans the shared variable schema against terraform.tfvars.
# The root module cannot host this test: import blocks crash tofu test.
terraform {
  required_version = ">= 1.12.0"
}
