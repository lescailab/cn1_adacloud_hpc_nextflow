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
 application_credential_id     = "69bec527844c48b887d7f9bc163f88da"
 application_credential_secret = "ozx3baorn23n0tSR-0-KfJvvwYuSuSfvNvJ017CSWXMDIWV-ilFW5D_OE9BUTr_eg1Vv01NhhFQS0p1hqwHjqw"
 #cacert_file                   = data.http.ada_cloud_ca_certificate.response_body
}
