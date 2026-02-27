# Terraform Module

Terraform Module sind eigenständige Pakete von Terraform-Konfigurationen, die zusammengehörende Ressourcen verwalten. Sie sind das wichtigste Mittel, um Terraform-Code zu organisieren, wiederzuverwenden und konsistent zu halten.

## Was sind Module?

Ein Modul ist im Grunde ein Verzeichnis mit `.tf`-Dateien. Jedes Terraform-Projekt ist selbst ein Modul, das sogenannte Root Module. Module, die von anderen Modulen aufgerufen werden, heißen Child Module.

### Vorteile von Modulen

- **Organisation**: Zusammengehörende Ressourcen gruppieren
- **Kapselung**: Komplexe Details hinter einem einfachen Interface verbergen
- **Wiederverwendbarkeit**: Gleiche Konfiguration in verschiedenen Projekten nutzen
- **Konsistenz**: Ressourcen werden immer nach dem gleichen Muster erstellt

## Modul-Struktur

Ein typisches Modul besteht aus drei Dateien:

```
modules/
└── mein-modul/
    ├── main.tf          # Ressourcen-Definitionen
    ├── variables.tf     # Input-Variablen
    └── outputs.tf       # Output-Werte
```

### variables.tf - Eingabeparameter

Variablen definieren die Schnittstelle des Moduls:

```hcl
variable "name" {
  description = "Name des Servers"
  type        = string
  nullable    = false
}

variable "server_type" {
  description = "Server-Typ"
  type        = string
  default     = "cx22"
}

variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}
```

### main.tf - Ressourcen

Die eigentliche Logik des Moduls:

```hcl
resource "hcloud_server" "server" {
  name        = var.name
  image       = "debian-12"
  server_type = var.server_type
}

resource "local_file" "hostdata" {
  content = templatefile("${path.module}/tpl/hostdata.json", {
    ip4      = hcloud_server.server.ipv4_address
    ip6      = hcloud_server.server.ipv6_address
    location = hcloud_server.server.location
  })
  filename = "gen/${var.name}.json"
}
```

::: tip path.module
Innerhalb eines Moduls muss `${path.module}` verwendet werden, um auf Dateien im Modul-Verzeichnis zuzugreifen (z.B. Templates). Relative Pfade beziehen sich sonst auf das Root Module.
:::

### outputs.tf - Ausgabewerte

Outputs machen Werte des Moduls für das aufrufende Modul verfügbar:

```hcl
output "server_ip" {
  value       = hcloud_server.server.ipv4_address
  description = "IPv4-Adresse des Servers"
}

output "server_id" {
  value       = hcloud_server.server.id
  description = "ID des Servers"
}
```

## Module verwenden

### Lokale Module

Module aus dem lokalen Dateisystem einbinden:

```hcl
module "webserver" {
  source       = "../modules/mein-modul"
  name         = "web-server"
  server_type  = "cx22"
  hcloud_token = var.hcloud_token
}
```

Auf Outputs des Moduls zugreifen:

```hcl
output "server_ip" {
  value = module.webserver.server_ip
}
```

### Registry Module

Module aus der [Terraform Registry](https://registry.terraform.io/) nutzen:

```hcl
module "network" {
  source   = "hetznercloud/network/hcloud"
  version  = "~> 1.0"
  name     = "mein-netzwerk"
  ip_range = "10.0.0.0/16"
}
```

### Git Repository

Module direkt aus einem Git-Repository laden:

```hcl
module "webserver" {
  source = "git::https://github.com/team/terraform-modules.git//hcloud-server?ref=v1.2.0"
}
```

## Module Sources

Module können aus verschiedenen Quellen geladen werden:

| Quelle | Beispiel |
|---|---|
| Lokaler Pfad | `source = "./modules/server"` |
| Terraform Registry | `source = "hetznercloud/network/hcloud"` |
| GitHub | `source = "github.com/org/repo//module"` |
| Git | `source = "git::https://example.com/repo.git"` |
| HTTP URL | `source = "https://example.com/module.zip"` |

## Projektstruktur mit Modulen

Ein typisches Projekt mit Modulen sieht so aus:

```
.
├── exercise/
│   ├── main.tf
│   ├── variables.tf
│   ├── providers.tf
│   └── gen/
│       └── hostdata.json
└── modules/
    └── host-metadata/
        ├── main.tf
        ├── outputs.tf
        ├── variables.tf
        └── tpl/
            └── hostdata.json
```

Das Root Module unter `exercise/` ruft das Child Module `host-metadata` auf und übergibt die nötigen Variablen:

```hcl
# exercise/main.tf
module "server_with_metadata" {
  source       = "../modules/host-metadata"
  name         = "mein-server"
  hcloud_token = var.hcloud_token
}
```

## Modul-Management Befehle

```bash
# Module herunterladen und initialisieren
terraform init

# Module aktualisieren
terraform get

# Provider-Baum anzeigen
terraform providers

# Modul-Konfiguration validieren
terraform validate
```

::: tip
Nach dem Hinzufügen oder Ändern eines Moduls muss `terraform init` erneut ausgeführt werden, damit Terraform die Modul-Quellen herunterladen kann.
:::

## Weiterführende Links

- [Terraform Docs: Module](https://www.terraform.io/language/modules)
- [Terraform Docs: Module Sources](https://www.terraform.io/language/modules/sources)
- [Terraform Registry](https://registry.terraform.io/)
- [Lecture Notes: Terraform Modules](https://freedocs.mi.hdm-stuttgart.de/sdi_cloudProvider_modules.html)
