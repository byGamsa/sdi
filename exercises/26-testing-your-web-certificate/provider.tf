provider "hcloud" {
  token = var.hcloud_token
}

provider "acme" { 
  server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
}

terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
    acme = {
            source  = "vancluever/acme"
        }
  }
  required_version = ">= 0.13"
}