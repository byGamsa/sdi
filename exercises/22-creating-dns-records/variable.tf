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

variable "serverIp" {
  description = "IP-Adresse des Servers"
  type        = string
  nullable    = false
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