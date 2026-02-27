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

variable "dns_secret" {
  description = "Secret für DNS"
  type        = string
  nullable    = false
}

variable "dnsZone" {
  description = "Die Basis-Domain / Zone"
  type        = string
  nullable    = false
}

variable "serverName" {
  description = "Canonical Name des Servers"
  type        = string
  nullable    = false
}

variable "serverCount" { 
  description = "The number of servers to create"
  type        = number
  default     = 2
}

variable "groupName" {
  description = "Gruppennummer"
  type        = string
  nullable    = false
}

variable "serverAliases" {
  description = "Liste der Alias-Namen"
  type        = list(string)
  default     = ["www", "mail"]
  nullable    = false
  
  validation {
    condition     = length(var.serverAliases) == length(distinct(var.serverAliases))
    error_message = "Die Liste 'serverAliases' darf keine doppelten Einträge enthalten."
  }

  validation {
    condition     = !contains(var.serverAliases, "@")
    error_message = "Ein CNAME-Record darf nicht '@' (Zone Apex) sein, da dies mit SOA/NS-Records kollidiert."
  }
}

variable "email" { 
  description = "Email address for Let's Encrypt registration"
  type        = string
}