# 17. Generating host meta data
Diese Dokumentation beschreibt, wie du ein wiederverwendbares Terraform-Submodul HostMetaData erstellst, das einen hcloud-Server anlegt und eine JSON-Datei mit Hostmetadaten (IPv4, IPv6, Location) erzeugt.

## Solution Overview
...

## Architecture
### Components

1. Terraform Configuration - Defines the infrastructure
2. Cloud-Init Template - Configures the server after boot
3. Firewall Rules - Secures the server
4. SSH Key Management - Enables secure access

## Implementation

Für folgende Aufgabe verwenden wir die Codebasis welche in Aufgabe 15 bereits aufgesetzt wurde

### 1. Submodul HostMetaData erstellen

Zuerst müssen die Files neu organisiert werden. Dafür erstellen wir einen neuen `modules` Ordner, welcher das neue Modul HostMetaData enthält. Dieses ist wie folgt aufgebaut

```sh
.
├── 17-generating-host-meta-data/
│   ├── main.tf
│   ├── variables.tf
│   └── providers.tf
│   └── ...
└── modules/  # [!code ++:7]
    └── host-meta-data/
        ├── main.tf
        ├── variables.tf
        └── tpl/ 
            └── hostdata.json
```

Im nächsten Schritt befüllen wir die neu erstellten Dateien im Modul `host-meta-data`

1.1 Tpl/hostdata.json 

Dies ist die Template-Datei, die mit templatefile() gerendert wird.

```hcl
{
  "network": {
    "ipv4": "${ip4}",
    "ipv6": "${ip6}"
  },
  "location": "${location}"
}
```

1.2 variables.tf

Definiere die Eingangsvariablen, die das Modul benötigt

```hcl
variable "location" {
  type     = string
  nullable = false
}

variable "ipv4Address" {
  type     = string
  nullable = false
}
variable "ipv6Address" {
  type     = string
  nullable = false
}

variable "name" {
  type     = string
  nullable = false
}
```

1.3 main.tf 

Hier werden der Server erstellt und die JSON-Datei gerendert und geschrieben.

```hcl
resource "local_file" "host_data" {
  content = templatefile("${path.module}/tpl/hostData.json", {
    ip4      = var.ipv4Address
    ip6      = var.ipv6Address
    location = var.location
  })
  filename = "gen/${var.name}.json"
}
```

### 1. SubModule einbinden

Jetzt wo du das Modul erfolgreich aufgebaut hast, muss dieser nur noch in der `main.tf` des Exercize Ordners eingebunden werden. Erweitere diese dafür um folgendes:

```sh
module "host_metadata" { # [!code ++:7]
  source      = "../modules/host-meta-data"
  name        = hcloud_server.debian_server.name
  location    = hcloud_server.debian_server.location
  ipv4Address = hcloud_server.debian_server.ipv4_address
  ipv6Address = hcloud_server.debian_server.ipv6_address
}
```

Nach erfolgreicher Ausführung erzeugt das Submodul in deinem Parent-Verzeichnis die Datei `Gen/debian_server.json`.

### Erwartetes Ergebnis (debian-server.json)

```sh
{
  "network": {
    "ipv4": "46.62.215.100",
    "ipv6": "2a01:4f9:c013:70f9::1"
  },
  "location": "hel1"
}
```