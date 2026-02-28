# 18. Modul für SSH Host Key Handling

Originale Aufgabenstellung: [Lecture Notes](https://freedocs.mi.hdm-stuttgart.de/sdi_cloudProvider_modules.html#sdi_cloudProvider_modules_qanda_moduleFileGen)

In dieser Übung wird die SSH-Host-Key-Logik aus [Aufgabe 16](/exercises/16-solving-the-known-hosts-quirk) in ein wiederverwendbares Terraform-Modul `SshKnownHosts` ausgelagert. Das Modul generiert die SSH- und SCP-Wrapper-Skripte sowie die `known_hosts`-Datei automatisch.

## Codebasis

Diese Aufgabe baut auf der Infrastruktur aus [Aufgabe 17](/exercises/17-generating-host-meta-data) auf. Die Modulstruktur mit dem `modules` Ordner wurde dort bereits eingeführt.

## Übungsschritte

### 1. Modulstruktur erstellen

Wie in der letzten Aufgabe verwenden wir erneut den `modules` Ordner, in welchem wir das neue Modul `ssh-known-hosts` erstellen. Die Struktur enthält die Modul-Logik und die Template-Dateien:

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

### 2. Modul-Templates erstellen

Das Modul verwendet die aus Aufgabe 16 bekannten SSH- und SCP-Wrapper-Skripte. Die Platzhalter `${user}` und `${host}` werden durch `templatefile()` mit den tatsächlichen Werten ersetzt, wenn das Modul aufgerufen wird:

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

### 3. Modul implementieren

#### 3.1 Variablen (`variables.tf`)

Definiere die Eingangsvariablen des Moduls.

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

#### 3.2 Hauptdatei (`main.tf`)

Der `locals` Block implementiert eine Fallback-Logik: Wenn ein Hostname angegeben ist, wird dieser verwendet. Ansonsten wird auf die IPv4-Adresse zurückgegriffen.

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

Damit liegen nach `terraform apply` drei generierte Dateien im Projekt:

| Datei                    | Beschreibung                                  |
| ------------------------ | --------------------------------------------- |
| `bin/ssh_<host>`         | SSH-Wrapper für den spezifischen Server       |
| `bin/scp_<host>`         | SCP-Wrapper für den spezifischen Server       |
| `gen/known_hosts_<host>` | Known-Hosts-Datei für den spezifischen Server |

### 4. Submodul im Parent-Projekt einbinden

Nach dem Aufbau des Moduls kann es in der Terraform-Konfiguration des Hauptprojekts wie folgt eingebunden werden:

```sh
module "ssh_wrapper" { # [!code ++:7]
  source      = "../modules/ssh-wrapper"
  login_user  = var.login_user
  ipv4Address = hcloud_server.debian_server.ipv4_address
  public_key  = file("~/.ssh/id_ed25519.pub")
}
```

::: info
Vergiss nicht, `terraform init` nach dem Hinzufügen des Moduls auszuführen.
:::
