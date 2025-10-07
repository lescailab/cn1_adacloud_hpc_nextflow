terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
  }
}

#--------------------------------------------
# Configure the OpenStack Provider
# provider "openstack" {}

# Without parameters it looks first at the environment variables, then at the default paths.
# See the official website for more info https://docs.openstack.org/python-openstackclient/pike/configuration/index.html#clouds-yaml

#--------------------------------------------
# Configure the OpenStack Provider credentials @Vault

#data "http" "ada_cloud_ca_certificate" {
#  url = "https://docs.hpc.cineca.it/_downloads/55d62992c2566aca1ea72b1603547c6a/adacloud.ca.chain"
#}

provider "openstack" {
 auth_url                      = "https://adacloud.hpc.cineca.it:5000"
 region                        = "RegionOne"
 application_credential_id     = "xxxx"
 application_credential_secret = "oxxxw"
 #cacert_file                   = data.http.ada_cloud_ca_certificate.response_body
}
