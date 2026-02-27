# 23. Host mit DNS-Einträgen erstellen

Originale Aufgabenstellung: [Lecture Notes](https://freedocs.mi.hdm-stuttgart.de/sdiDnsProjectNameServer.html#sdi_cloudProvider_dns_quanda_hostAndDns)

In dieser Übung wird ein vollständiger Server mit passenden DNS-Einträgen erstellt und die SSH-Wrapper so angepasst, dass sie den DNS-Namen statt der IP-Adresse verwenden. Das macht die gesamte Konfiguration robuster.

## Architektur-Komponenten

| Komponente | Beschreibung |
|---|---|
| **DNS Provider** | Erstellt A-Records und CNAME-Aliase für den Server |
| **SSH-Wrapper mit DNS** | `ssh.sh` und `scp.sh` verwenden DNS-Namen statt IP-Adressen |
| **Known Hosts mit FQDN** | `known_hosts`-File verwendet den FQDN statt der IP |
| **TLS Key** | Generiert SSH Host Key für den Server |
| **Dynamische Server-IP** | A-Records verwenden die tatsächliche IP des erstellten Servers |

## Codebasis

Diese Aufgabe baut auf dem Code von [Aufgabe 16](/exercises/16-solving-the-known-hosts-quirk) (SSH Known Hosts) und [Aufgabe 22](/exercises/22-creating-dns-records) (DNS Records) auf. Der Code beider Aufgaben wird zusammengeführt.

## Übungsschritte

### 1. Code beider Aufgaben zusammenführen

Zunächst nehmen wir als Basiscode den Code aus Aufgabe 16. Dabei fügen wir sowohl den DNS-Code aus der `main.tf` der Aufgabe 22 hinzu, als auch die dort neu erstellten Variablen.

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

### 2. Server-IP durch dynamische Referenz ersetzen

Im nächsten Schritt passen wir den Code an die eigentliche Aufgabenstellung an. Die Variable `serverIp` ist überflüssig, da wir jetzt die echte IP des erstellten Servers verwenden.

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

### 3. SSH- und SCP-Skripte auf DNS-Namen umstellen

Als nächstes müssen die SSH- und SCP-Template-Dateien angepasst werden. Anstelle der IP-Adresse wird jetzt der DNS-Name (`${dnsName}`) als Verbindungsziel verwendet:

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

### 4. Übergabewerte anpassen

Zuletzt müssen die Übergabewerte für die generierten Dateien angepasst werden. Dabei wird statt der IP der `serverName` und die `dnsZone` übergeben.

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

### 5. Ergebnisse kontrollieren

Abschließend kann man alles ausführen und die Ergebnisse überprüfen. Die generierten Dateien sollten jetzt den DNS-Namen statt der IP enthalten:

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

Zusätzlich können die generierten Skripte ausgeführt werden, um die Funktionalität zu prüfen. Außerdem kann die DNS-Konfiguration über den Zone Transfer verifiziert werden:

```bash
dig @ns1.hdm-stuttgart.cloud -y "hmac-sha512:"$HMAC -t AXFR g1.sdi.hdm-stuttgart.cloud
```