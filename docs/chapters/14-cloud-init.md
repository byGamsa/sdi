# Automatic Nginx Installation with Terraform
This documentation describes the implementation of an automated Nginx installation using Terraform and Cloud-Init.

## Solution Overview
The solution uses Terraform in combination with Cloud-Init to fully automate a Debian server setup. Not only is Nginx installed, but security measures and system configurations are also implemented.

## Architecture
### Components

1. Terraform Configuration - Defines the infrastructure
2. Cloud-Init Template - Configures the server after boot
3. Firewall Rules - Secures the server
4. SSH Key Management - Enables secure access