# 18. A module for ssh host key handling
Diese Aufgabe erweitert das bestehende Infrastruktur-Setup um ein neues wiederverwendbares Modul SshKnownHosts, welches SSH‑ und SCP‑Wrapper‑Skripte generiert.

## Solution Overview
...

## Architecture
### Components

1. Terraform Configuration - Defines the infrastructure
2. Cloud-Init Template - Configures the server after boot
3. Firewall Rules - Secures the server
4. SSH Key Management - Enables secure access

## Implementation

Für folgende Aufgabe verwenden wir die Codebasis welche in Aufgabe 17 bereits aufgesetzt wurde

### 1. Submodul für SSH Host Key Handling erstellen

Wie in der letzten Aufgabe verwenden wir erneut den `modules` Ordner, in welchem wir das neue Modul SshKnownHosts erstellen. Dieses ist wie folgt aufgebaut

```sh
.
├── 17-generating-host-meta-data/
│   ├── main.tf
│   ├── variables.tf
│   └── providers.tf
│   └── ...
└── modules/  
    └── host-meta-data/
    └── ssh-known-hosts/ # [!code ++:7]
        ├── main.tf
        ├── variables.tf
        └── tpl/ 
            ├── scp.sh
            └── ssh.sh
```

Im nächsten Schritt befüllen wir die neu erstellten Dateien im Modul `ssh-known-hosts`

### 2. Creating the Module Templates

Das Modul verwendet die in Aufgabe 16 erstellten ssh und scp Wrapper-Skripte. Die Platzhalter werden durch templatefile() ersetzt.

::: code-group

```sh [modules/ssh-wrapper/tpl/scp.sh]
#!/usr/bin/env bash

GEN_DIR=$(dirname "$0")/../gen

if [ $# -lt 2 ]; then
   echo usage: ./bin/scp <arguments>
else
   scp -o UserKnownHostsFile="$GEN_DIR/known_hosts" ${user}@${host} $@
fi
```

```sh [modules/ssh-wrapper/tpl/ssh.sh]
#!/usr/bin/env bash

GEN_DIR=$(dirname "$0")/../gen

ssh -o UserKnownHostsFile="$GEN_DIR/known_hosts" ${user}@${ip} "$@"
```

:::

### 3. Implementiere das restliche Modul

3.1 variables.tf

Definiere die Eingangsvariablen, die das Modul benötigt

```hcl
variable "login_user" {
  description = "The user to login to the server"
  type        = string
  nullable    = false
  default     = "root"
}

variable "public_key" {
  description = "The public key to use for the server"
  type        = string
  nullable    = false
}

variable "ipv4Address" {
  description = "The IPv4 address of the server"
  type        = string
  nullable    = true
  default     = null
}

variable "hostname" {
  description = "The hostname to connect to (alternative to ipv4Address)"
  type        = string
  nullable    = true
  default     = null
}
```

3.2 main.tf 

Hier werden der Server erstellt und die JSON-Datei gerendert und geschrieben.

```hcl
locals {
  target_host = var.hostname != null && var.hostname != "" ? var.hostname : var.ipv4Address
}

resource "local_file" "known_hosts" {
  content         = "${local.target_host} ${var.public_key}"
  filename        = "gen/known_hosts_${local.target_host}"
}

resource "local_file" "ssh_script" {
  content = templatefile("${path.module}/tpl/ssh.sh", {
    host = local.target_host
    user = var.login_user
  })
  filename        = "bin/ssh_${local.target_host}" 
}

resource "local_file" "scp_script" {
  content = templatefile("${path.module}/tpl/scp.sh", {
    host = local.target_host,
    user = var.login_user
  })
  filename        = "bin/scp_${local.target_host}" 
}
```

Damit liegen nach terraform apply drei generierte Dateien im Parent-Projekt:

- bin/ssh

- bin/scp

- gen/known_hosts

### 4. Submodul im Parent-Projekt einbinden

Nach dem Aufbau des Moduls kann es in der Terraform-Konfiguration wie folgt eingesetzt werden:

```sh
module "ssh_wrapper" { # [!code ++:7]
  source      = "../modules/ssh-wrapper"
  login_user  = var.login_user
  ipv4Address = hcloud_server.debian_server.ipv4_address
  public_key  = file("~/.ssh/id_ed25519.pub")
} 
```

Terraform generiert anschließend alle benötigten SSH-Hilfsdateien, sodass zukünftige Verbindungen automatisch den korrekten Host Key verwenden.