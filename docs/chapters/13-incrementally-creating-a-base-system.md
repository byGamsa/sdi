# 13. Incrementally creating a base system

## 1. Install Terraform

Before you begin, you need to install Terraform. Follow the official installation guide for your operating system on the [Terraform website](https://developer.hashicorp.com/terraform/downloads).


### 1 Firstly, we create a minimal Terraform configuration:
<details>
<summary>show code </summary>

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
```

:::
</details>