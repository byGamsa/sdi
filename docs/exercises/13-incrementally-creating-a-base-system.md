# 13. Schrittweise ein Basissystem aufbauen

Originale Aufgabenstellung: [Lecture Notes](https://freedocs.mi.hdm-stuttgart.de/sdi_cloudProvider_terra.html#sdi_cloudProvider_terra_qandaBasicSystem)

In dieser Übung wird eine grundlegende Cloud-Infrastruktur mit Terraform auf Hetzner Cloud aufgebaut. Ausgehend von einem einzelnen minimalen Server wird die Konfiguration schrittweise um Sicherheitsfeatures wie Firewalls und SSH-Keys erweitert, bis ein produktionsnahes Setup entsteht.

## Codebasis

Diese Übung ist der **Ausgangspunkt** des Kurses und baut auf keiner vorherigen Aufgabe auf. Hier wird das Terraform-Projekt von Grund auf erstellt.

## Übungsschritte

### 1. Terraform installieren

Bevor wir beginnen, muss Terraform auf dem lokalen Rechner installiert werden.
Folge der offiziellen Installationsanleitung für dein Betriebssystem auf der [Terraform Website](https://developer.hashicorp.com/terraform/downloads).

::: tip
Nach der Installation kannst du die korrekte Einrichtung mit `terraform version` überprüfen.
:::

### 2. Hetzner Cloud API Token erstellen

Um Terraform mit deinem Hetzner Cloud Account zu verbinden, wird ein API Token benötigt. Dieser Token erlaubt es Terraform, Ressourcen in deinem Hetzner Cloud Projekt zu erstellen, zu ändern und zu löschen.

1. Gehe zur [Hetzner Cloud Console](https://console.hetzner.cloud/) und melde dich an.
2. Wähle dein Projekt aus.
3. Navigiere zu **„Security"** → **„API Tokens"**.
4. Klicke auf **„Generate API Token"**.
5. Vergib einen aussagekräftigen Namen und klicke auf **„Generate API Token"**.
6. Kopiere den generierten Token sofort. Er wird nur einmal angezeigt und kann nicht erneut abgerufen werden.

::: warning Sicherheitshinweis
Der Token gewährt vollen Zugriff auf dein Hetzner Cloud Projekt. Speichere ihn sicher, z.B. in einem Passwort-Manager, und teile ihn niemals öffentlich (z.B. in Git-Repositories).
:::

### 3. Minimale Terraform-Konfiguration erstellen

Zuerst erstellen wir eine einfache `main.tf` Datei, die einen einzelnen Debian-Server bei Hetzner Cloud erzeugt. Diese Konfiguration enthält den Provider-Block (welcher Cloud-Anbieter verwendet wird) und einen Ressourcen-Block (was erstellt werden soll).

::: info
Diese Basiskonfiguration erstellt einen minimalen Server ohne Sicherheitsfeatures. Der API Token steht hier noch direkt im Code, wird aber im nächsten Schritt verbessert.
:::

::: code-group

```hcl [main.tf]
terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
  }
  required_version = ">= 0.13"
}
# Configure the Hetzner Cloud API token
provider "hcloud" {
  token = "YOUR_API_TOKEN"
}

# Create a server
resource "hcloud_server" "helloServer" {
  name         = "hello"
  image        =  "debian-13"
  server_type  =  "cx23"
}
```

:::

### 4. API Key in eine separate Datei auslagern

In der bisherigen Konfiguration steht der API Token direkt im Code. Das ist ein Sicherheitsrisiko, insbesondere wenn der Code in einem Git-Repository versioniert wird. Deshalb lagern wir den Token in separate Dateien aus und nutzen Terraform-Variablen.

Erstelle zuerst eine `variables.tf` Datei, die die Variable deklariert:

::: code-group

```hcl [variables.tf]
variable "hcloud_token" {
  description = "Hetzner Cloud API token (can be supplied via environment variable TF_VAR_hcloud_token)"
  nullable = false
  type        = string
  sensitive   = true
}

```

:::

Erstelle dann eine `provider.tf` Datei, die den Provider so konfiguriert, dass er die Variable verwendet:

::: code-group

```hcl [provider.tf]
provider "hcloud" {
  token = var.hcloud_token
}

terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
  }
  required_version = ">= 0.13"
}
```

:::

Erstelle abschließend eine `secret.auto.tfvars` Datei, die den tatsächlichen Token-Wert enthält. Dateien mit der Endung `.auto.tfvars` werden von Terraform automatisch geladen:

::: code-group

```hcl [secret.auto.tfvars]
hcloud_token="YOUR_API_TOKEN"
```

:::

::: warning Sicherheitshinweis
Die Datei `secret.auto.tfvars` enthält sensible Daten und sollte unbedingt in die `.gitignore` eingetragen werden, damit sie nicht ins Repository committed wird.
:::

### 5. Firewall hinzufügen

Ohne Firewall ist der Server über alle Ports aus dem Internet erreichbar. Wir erstellen eine Firewall-Ressource, die nur eingehenden SSH-Verkehr (Port 22) erlaubt, und referenzieren sie in der Server-Ressource.

Füge folgende Blöcke in die `main.tf` ein:

::: code-group

```hcl [main.tf]
resource "hcloud_server" "helloServer" {
  name         = "hello"
  image        =  "debian-13"
  server_type  =  "cx23"
  firewall_ids = [hcloud_firewall.sshFw.id] // [!code ++]
}

resource "hcloud_firewall" "sshFw" { // [!code ++]
  name = "firewall-1" // [!code ++]
  rule { // [!code ++]
    direction = "in" // [!code ++]
    protocol  = "tcp" // [!code ++]
    port      = "22" // [!code ++]
    source_ips = ["0.0.0.0/0", "::/0"] // [!code ++]
  } // [!code ++]
} // [!code ++]
```

:::

### 6. SSH-Keys hinzufügen

Anstelle von passwortbasiertem Login verwenden wir SSH-Keys für eine sichere Authentifizierung. Dafür wird eine neue Variable für den öffentlichen SSH-Schlüssel angelegt und eine `hcloud_ssh_key` Ressource erstellt.

Erstelle eine zweite Variable in `variable.tf`:

::: code-group

```hcl [variable.tf]
variable "hcloud_token" {
  description = "Hetzner Cloud API token (can be supplied via environment variable TF_VAR_hcloud_token)"
  nullable = false
  type        = string
  sensitive   = true
}

variable "ssh_login_public_key" { // [!code ++]
  description = ""  // [!code ++]
  nullable = false // [!code ++]
  type = string // [!code ++]
  sensitive = true // [!code ++]
} // [!code ++]
```

:::

Setze den Wert der Variable in der Secrets-Datei:

::: code-group

```hcl [secrets.auto.tfvars]
hcloud_token="YOUR_API_TOKEN"
ssh_login_public_key="YOUR_PUBLIC_SSK_KEY" // [!code ++]
```

:::

Füge eine SSH-Key-Ressource hinzu und referenziere sie im Server-Block. Dadurch wird der öffentliche Schlüssel automatisch auf dem Server hinterlegt:

::: code-group

```hcl [main.tf]
resource "hcloud_server" "helloServer" {
  name         = "hello"
  image        =  "debian-13"
  server_type  =  "cx23"
  firewall_ids = [hcloud_firewall.sshFw.id]
  ssh_keys     = [hcloud_ssh_key.loginUser.id] // [!code ++]
}

resource "hcloud_firewall" "sshFw" {
  name = "firewall-1"
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_ssh_key" "loginUser" { // [!code ++]
  name       = "my_ssh_key" // [!code ++]
  public_key = var.ssh_login_public_key // [!code ++]
} // [!code ++]
```

:::

### 7. Terraform Output definieren

Outputs sind ein nützliches Feature von Terraform, um nach `terraform apply` wichtige Informationen über die erstellten Ressourcen anzuzeigen. In unserem Fall wollen wir die IP-Adresse und das Datacenter des Servers sehen, damit wir uns direkt per SSH verbinden können.

Erstelle eine neue Datei `output.tf`:

::: code-group

```hcl [output.tf]
output "ip_addr" {
  value       = hcloud_server.helloServer.ipv4_address
  description = "The server's IPv4 address"
}

output "datacenter" {
  value       = hcloud_server.helloServer.datacenter
  description = "The server's datacenter"
}
```

:::

Nach `terraform apply` werden die Server-IP und das Datacenter direkt im Terminal ausgegeben.
