variable "hcloud_token" {
  description = "Hetzner Cloud API token (can be supplied via environment variable TF_VAR_hcloud_token)"
  nullable = false
  type        = string
  sensitive   = true
}

variable "ssh_login_public_key" {
  description = ""
  nullable = false
  type = string
  sensitive = true
}

variable "loginUser" {
  description = "Der Benutzername für den Login (z.B. devops)"
  nullable = false
  type = string
  sensitive = true
}