# Creating a host with corresponding DNS entries

Diese Aufgabe baut auf dem bestehenden Code der Aufgabe 16 (Solving the known host quirk) und der Aufgabe 22 (Creating DNS records) auf.

Dabei geht es darum, den Server-DNS-Name (``workhorse.g1.sdi.hdm-stuttgart.cloud``) statt der IP im ``ssh``, ``scp`` und ``known-hosts`` File zu benutzen.

### Zusammensetzung des Codes der beiden Aufgaben

Zunächst nehmen wir als Basiscode den Code aus Aufgabe 16. Dabei fügen wir sowohl den Code aus der ``main.tf`` der Aufgabe 22 hinzu, als auch die neu erstellten Variablen.

::: code-group
```hcl [main.tf]
resource "local_file" "ssh_script" { 
  content = templatefile("${path.module}/tpl/ssh.sh", {
    devopsUsername = var.loginUser,
    dnsName = "${var.serverName}.${var.dnsZone}"
  })
  filename        = "bin/ssh"
  file_permission = "755"
}

resource "local_file" "scp_script" { 
  content = templatefile("${path.module}/tpl/scp.sh", {
    devopsUsername = var.loginUser,
    dnsName = "${var.serverName}.${var.dnsZone}"
  })
  filename        = "bin/scp"
  file_permission = "755"
}

provider "dns" { // [!code ++:44]
  update {
    server        = "ns1.sdi.hdm-stuttgart.cloud"
    key_name      = "${var.groupName}.key."
    key_algorithm = "hmac-sha512"
    key_secret    = var.dns_secret
  }
}

resource "dns_a_record_set" "workhorse" {
  name = var.serverName
  zone = "${var.dnsZone}."
  ttl = 10
  addresses = ${var.serverIp}
}

resource "null_resource" "dns_root" {
  triggers = {
    server_ip = ${var.serverIp}
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "server ns1.sdi.hdm-stuttgart.cloud
      update delete ${var.dnsZone}. A
      update add ${var.dnsZone}. 10 A ${var.serverIp}
      send" | nsupdate -y "hmac-sha512:${var.groupName}.key:${var.dns_secret}"
    EOT
  }
}

resource "dns_cname_record" "aliases" {
  count = length(var.serverAliases)
  name  = var.serverAliases[count.index]
  zone  = "${var.dnsZone}."
  ttl   = 10
  cname = "${var.serverName}.${var.dnsZone}."
  lifecycle {
    precondition {
      condition     = !contains(var.serverAliases, var.serverName)
      error_message = "Der Server-Name darf nicht gleichzeitig als Alias (CNAME) definiert sein."
    }
  }
}
```
```hcl [variable.tf]
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

variable "dns_secret" {  // [!code ++:46]
  description = "Secret für DNS"
  type        = string
  nullable    = false
}

variable "dnsZone" {
  description = "Die Basis-Domain / Zone"
  type        = string
  nullable    = false
}

variable "serverIp" {
  description = "IP-Adresse des Servers"
  type        = string
  nullable    = false
}

variable "serverName" {
  description = "Canonical Name des Servers"
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
```
:::

Im nächsten Schritt passen wir den Code an unsere Aufgabenstellung an. Somit ist die Variable ``serverIp`` überflüssig und wir verwenden stattdessen die IP des erstellten Servers. 

::: code-group
```hcl [variable.tf]
variable "dnsZone" {
  description = "Die Basis-Domain / Zone"
  type        = string
  nullable    = false
}

variable "serverIp" {  // [!code --:5]
  description = "IP-Adresse des Servers"
  type        = string
  nullable    = false
}

variable "serverName" {
  description = "Canonical Name des Servers"
  type        = string
  nullable    = false
}

```
```hcl [main.tf]
resource "dns_a_record_set" "workhorse" {
  name = var.serverName
  zone = "${var.dnsZone}."
  ttl = 10
  addresses = [hcloud_server.helloServer.ipv4_address] // [!code ++]
}

resource "null_resource" "dns_root" {
  triggers = {
    server_ip = hcloud_server.helloServer.ipv4_address // [!code ++]
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "server ns1.sdi.hdm-stuttgart.cloud
      update delete ${var.dnsZone}. A
      update add ${var.dnsZone}. 10 A ${hcloud_server.helloServer.ipv4_address} // [!code ++]
      send" | nsupdate -y "hmac-sha512:${var.groupName}.key:${var.dns_secret}"
    EOT
  }
}
```
:::

### Anpassung des ``ssh`` und ``scp`` Files

Als nächstes müssen die ssh und scp Files angepasst werden, indem man die IP mit dem DNS-Namen austauscht.

::: code-group
```bash [tpl/ssh.sh]
#!/usr/bin/env bash

GEN_DIR=$(dirname "$0")/../gen

ssh -o UserKnownHostsFile="$GEN_DIR/known_hosts" ${devopsUsername}@${dnsName} "$@" # // [!code ++]
```
```bash [tpl/scp.sh]
#!/usr/bin/env bash

GEN_DIR=$(dirname "$0")/../gen

if [ $# -lt 2 ]; then
   echo usage: .../bin/scp ${devopsUsername}@${dnsName} ... # // [!code ++]
else
   scp -o UserKnownHostsFile="$GEN_DIR/known_hosts" $@
fi
```
:::

### Änderung der Übergabewerte

Zuletzt müssen die Übergabewerte für die Files angepasst werden. Dabei wird statt der IP, der ``serverName`` und die ``dnsZone`` übergeben.
::: code-group
```hcl [main.tf]
resource "local_file" "known_hosts" { 
  content = "${var.serverName}.${var.dnsZone} ${tls_private_key.host_key.public_key_openssh}" // [!code ++]
  filename        = "gen/known_hosts"
  file_permission = "644"
}

resource "local_file" "ssh_script" { 
  content = templatefile("${path.module}/tpl/ssh.sh", {
    devopsUsername = var.loginUser,
    dnsName = "${var.serverName}.${var.dnsZone}" // [!code ++]
  })
  filename        = "bin/ssh"
  file_permission = "755"
}

resource "local_file" "scp_script" { 
  content = templatefile("${path.module}/tpl/scp.sh", {
    devopsUsername = var.loginUser,
    dnsName = "${var.serverName}.${var.dnsZone}" // [!code ++]
  })
  filename        = "bin/scp"
  file_permission = "755"
}
```
:::

### Ergebnisse kontrollieren

Abschließend kann man alles ausführen und die Ergebnisse überprüfen. 
Dabei sollten die generierten Files folgt aussehen, falls alles erfolgreich geklappt hat:
::: code-group
``` [gen/known_hosts]
workhorse.g1.sdi.hdm-stuttgart.cloud ssh-ed25519 AAAAC....

```
```bash [bin/ssh]
#!/usr/bin/env bash

GEN_DIR=$(dirname "$0")/../gen

ssh -o UserKnownHostsFile="$GEN_DIR/known_hosts" devops@workhorse.g1.sdi.hdm-stuttgart.cloud "$@"
```
```bash [bin/scp]
#!/usr/bin/env bash

GEN_DIR=$(dirname "$0")/../gen

if [ $# -lt 2 ]; then
   echo usage: .../bin/scp devops@workhorse.g1.sdi.hdm-stuttgart.cloud ...
else
   scp -o UserKnownHostsFile="$GEN_DIR/known_hosts" $@
fi
```
:::

Zusätzlich können die Files augeführt werden, um auf erfolgreiche Funktionalität zu prüfen. Außerdem kann der Befehl der vorherigen Aufgaben zur zusätzlichen Prüfung ebenfalls ausgeführt werden.
```bash
dig @ns1.hdm-stuttgart.cloud -y "hmac-sha512:"$HMAC -t AXFR g1.sdi.hdm-stuttgart.cloud
```