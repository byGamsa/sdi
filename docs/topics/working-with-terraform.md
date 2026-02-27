# Arbeiten mit Terraform

[Terraform](https://www.terraform.io/) ist ein Open-Source Infrastructure-as-Code (IaC) Tool von HashiCorp. Es ermöglicht es, Cloud-Infrastruktur deklarativ in Konfigurationsdateien zu beschreiben und automatisiert bereitzustellen.

## Was ist Terraform?

Terraform verfolgt einen deklarativen Ansatz: Man beschreibt den gewünschten Zustand der Infrastruktur, und Terraform berechnet automatisch, welche Schritte nötig sind, um diesen Zustand zu erreichen.

### Warum Terraform?

- **Deklarativ**: Man beschreibt _was_ man haben möchte, nicht _wie_ es erstellt wird
- **Provider-Ökosystem**: Unterstützt hunderte Cloud-Anbieter (AWS, Azure, GCP, Hetzner, etc.)
- **Reproduzierbar**: Gleiche Konfiguration ergibt immer das gleiche Ergebnis
- **Versionierbar**: Konfigurationsdateien können mit Git verwaltet werden
- **Planbar**: Vor jeder Änderung zeigt `terraform plan`, was genau passieren wird

### Use Cases

- Cloud-Server erstellen und konfigurieren
- Netzwerke, Firewalls und DNS-Einträge verwalten
- SSL-Zertifikate automatisch erstellen
- Multi-Server-Umgebungen mit einer Konfiguration verwalten
- Infrastruktur in CI/CD-Pipelines automatisch deployen

## Installation

### Linux (Debian/Ubuntu)

```bash
# Abhängigkeiten installieren
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common

# HashiCorp GPG Key installieren
wget -O- https://apt.releases.hashicorp.com/gpg | \
  gpg --dearmor | \
  sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

# Repository hinzufügen
echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

# Terraform installieren
sudo apt update && sudo apt-get install terraform
```

### macOS

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

### Windows

```powershell
choco install terraform
```

Alternativ: [Terraform Download-Seite](https://developer.hashicorp.com/terraform/downloads)

### Installation überprüfen

```bash
terraform -version
```

### Autocompletion (optional)

```bash
terraform -install-autocomplete
```

## Core Concepts

### HCL (HashiCorp Configuration Language)

Terraform-Konfigurationen werden in `.tf`-Dateien geschrieben und verwenden die HCL-Syntax. Typische Dateien in einem Terraform-Projekt:

| Datei              | Zweck                             |
| ------------------ | --------------------------------- |
| `main.tf`          | Hauptkonfiguration mit Ressourcen |
| `variables.tf`     | Variablen-Definitionen            |
| `outputs.tf`       | Ausgabewerte nach dem Apply       |
| `providers.tf`     | Provider-Konfiguration            |
| `terraform.tfvars` | Variablen-Werte                   |

### Provider

Provider sind Plugins, die Terraform mit Cloud-Anbietern verbinden. Für Hetzner Cloud:

```hcl
terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
  }
  required_version = ">= 0.13"
}

provider "hcloud" {
  token = var.hcloud_token
}
```

### Resources

Resources sind das wichtigste Element in Terraform. Jeder Resource-Block beschreibt ein Infrastruktur-Objekt:

```hcl
resource "hcloud_server" "debian_server" {
  name        = "debian-server"
  image       = "debian-12"
  server_type = "cx22"
}
```

Die Syntax ist `resource "TYP" "NAME" { ... }`. Der Typ bestimmt die Art der Ressource (z.B. `hcloud_server`), der Name ist ein interner Bezeichner.

### Variables

Variablen ermöglichen es, Konfigurationen flexibel und wiederverwendbar zu gestalten:

```hcl
variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  nullable    = false
  sensitive   = true
}

variable "server_type" {
  description = "Server-Typ"
  type        = string
  default     = "cx22"
}
```

Das `sensitive = true` Flag verhindert, dass der Wert in der Terraform-Ausgabe angezeigt wird.

### Outputs

Outputs geben nach dem Apply nützliche Informationen zurück:

```hcl
output "server_ip" {
  value       = hcloud_server.debian_server.ipv4_address
  description = "IP-Adresse des Servers"
}
```

## Terraform Workflow

Der Terraform-Workflow besteht aus drei Schritten:

### 1. Init

```bash
terraform init
```

Initialisiert das Arbeitsverzeichnis, lädt Provider-Plugins herunter und bereitet den State vor.

### 2. Plan

```bash
terraform plan
```

Zeigt eine Vorschau der geplanten Änderungen. Terraform vergleicht die Konfiguration mit dem aktuellen State und zeigt an, welche Ressourcen erstellt, geändert oder gelöscht werden.

### 3. Apply

```bash
terraform apply
```

Führt die geplanten Änderungen aus. Terraform fragt vor der Ausführung nach Bestätigung. Mit `-auto-approve` kann die Bestätigung übersprungen werden.

### Destroy

```bash
terraform destroy
```

Löscht alle in der Konfiguration definierten Ressourcen.

## Hetzner Cloud API Token

Um Terraform mit der Hetzner Cloud zu verwenden, benötigt man einen API Token:

1. In der [Hetzner Cloud Console](https://console.hetzner.cloud/) einloggen
2. Projekt auswählen
3. **Security** → **API Tokens** navigieren
4. **Generate API Token** klicken
5. Token sofort kopieren und sicher speichern (wird nur einmal angezeigt)

## Secrets Management

API Tokens und andere Geheimnisse sollten nie direkt in `.tf`-Dateien stehen. Stattdessen:

### Mit `.tfvars`-Datei

Erstelle eine `secret.auto.tfvars`:

```hcl
hcloud_token = "DEIN_API_TOKEN"
```

::: warning Wichtig
Füge `**/secret.auto.tfvars` zu deiner `.gitignore` hinzu, damit das Token nicht ins Repository gelangt!
:::

### Mit Umgebungsvariablen

```bash
# Linux/macOS
export TF_VAR_hcloud_token="DEIN_API_TOKEN"

# Windows PowerShell
$env:TF_VAR_hcloud_token="DEIN_API_TOKEN"
```

## State Management

Terraform speichert den aktuellen Zustand der Infrastruktur in einer State-Datei (`terraform.tfstate`). Diese Datei wird verwendet, um:

- Den aktuellen Zustand mit der gewünschten Konfiguration zu vergleichen
- Abhängigkeiten zwischen Ressourcen zu verwalten
- Änderungen effizient zu planen

::: warning
Die State-Datei kann sensible Daten enthalten. Auch sie gehört in die `.gitignore`.
:::

## Weiterführende Links

- [Terraform Dokumentation](https://developer.hashicorp.com/terraform/docs)
- [Terraform Core Workflow](https://developer.hashicorp.com/terraform/intro/core-workflow)
- [Hetzner Cloud Provider](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs)
- [Terraform Install Guide](https://developer.hashicorp.com/terraform/downloads)
- [Lecture Notes: Terraform](https://freedocs.mi.hdm-stuttgart.de/sdi_cloudProvider_terra.html)
