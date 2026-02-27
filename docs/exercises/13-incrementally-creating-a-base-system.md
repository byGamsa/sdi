# 13. Incrementally creating a base system

## 1. Install Terraform

Before you begin, you need to install Terraform. Follow the official installation guide for your operating system on the [Terraform website](https://developer.hashicorp.com/terraform/downloads).

## 2. Get a Hetzner Cloud API Token

To allow Terraform to interact with your Hetzner Cloud account, you need to generate an API token.

1. Go to the [Hetzner Cloud Console](https://console.hetzner.cloud/) and log in.
2. Select your project.
3. Navigate to "Security" -> "API Tokens".
4. Click "Generate API Token".
5. Enter a descriptive name for the token and click "Generate API Token".
6. Copy the generated token's value immediately. This token is only shown once and cannot be retrieved later. Store it securely, for example, in a password manager.


## 3. We create a minimal Terraform configuration:
::: info
This basic configuration will create a minimal server without security features. You'll enhance it in later sections.
:::
<details>
<summary>show file </summary>

::: code-group

```hcl [main.tf]
terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
  }
  required_version = ">= 0.13"
}
# Configure the Hetzner Cloud API token
provider "hcloud" {
  token = "YOUR_API_TOKEN"
}

# Create a server
resource "hcloud_server" "helloServer" {
  name         = "hello"
  image        =  "debian-13"
  server_type  =  "cx23"
}
```

:::
</details>

## 4. Outsource the API Key in another file
- Create a new file named variables.tf in the same directory:
::: code-group
```hcl [variables.tf]
variable "hcloud_token" {
  description = "Hetzner Cloud API token (can be supplied via environment variable TF_VAR_hcloud_token)"
  nullable = false
  type        = string
  sensitive   = true
}

```
:::

- Create a new file named provider.tf in the same directory:
::: code-group
```hcl [provider.tf]
provider "hcloud" {
  token = var.hcloud_token
}

terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
  }
  required_version = ">= 0.13"
}
```
:::
- Create a file named secret.auto.tfvars in the same directory:
::: code-group
```hcl [secret.auto.tfvars]
hcloud_token="YOUR_API_TOKEN"
```
:::

## 5. Add a Firewall
- Add the following code block into the main.tf and add the firewall id into the hcloud_server code block:
::: code-group
```hcl [main.tf]
resource "hcloud_server" "helloServer" {
  name         = "hello"
  image        =  "debian-13"
  server_type  =  "cx23"
  firewall_ids = [hcloud_firewall.sshFw.id] // [!code ++]
}

resource "hcloud_firewall" "sshFw" { // [!code ++]
  name = "firewall-1" // [!code ++]
  rule { // [!code ++]
    direction = "in" // [!code ++]
    protocol  = "tcp" // [!code ++]
    port      = "22" // [!code ++]
    source_ips = ["0.0.0.0/0", "::/0"] // [!code ++]
  } // [!code ++]
} // [!code ++]
```
:::

## Adding SSH-keys
- Create a second variable in variable.tf
::: code-group
```hcl [variable.tf]
variable "hcloud_token" {
  description = "Hetzner Cloud API token (can be supplied via environment variable TF_VAR_hcloud_token)"
  nullable = false
  type        = string
  sensitive   = true
}

variable "ssh_login_public_key" { // [!code ++]
  description = ""  // [!code ++]
  nullable = false // [!code ++]
  type = string // [!code ++]
  sensitive = true // [!code ++]
} // [!code ++]
```
:::
- Set the new variable in secrets.auto.tfvars
::: code-group
```hcl [secrets.auto.tfvars]
hcloud_token="YOUR_API_TOKEN"
ssh_login_public_key="YOUR_PUBLIC_SSK_KEY" // [!code ++]
```
:::
- Add a resource block for every ssh-key you want to add to main.tf and add the loginUser-key-id into the hcloud_server code block:
::: code-group
```hcl [main.tf]
resource "hcloud_server" "helloServer" {
  name         = "hello"
  image        =  "debian-13"
  server_type  =  "cx23"
  firewall_ids = [hcloud_firewall.sshFw.id]
  ssh_keys     = [hcloud_ssh_key.loginUser.id] // [!code ++]
}

resource "hcloud_firewall" "sshFw" {
  name = "firewall-1"
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_ssh_key" "loginUser" { // [!code ++]
  name       = "my_ssh_key" // [!code ++]
  public_key = var.ssh_login_public_key // [!code ++]
} // [!code ++]
```
:::

## Terraform output
- Create a new file output.tf in the same directory
::: code-group
```hcl [output.tf]
output "ip_addr" {
  value       = hcloud_server.helloServer.ipv4_address
  description = "The server's IPv4 address"
}

output "datacenter" {
  value       = hcloud_server.helloServer.datacenter
  description = "The server's datacenter"
}
```
:::

- Now you get the correct output after running "terraform apply"