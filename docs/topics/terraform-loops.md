# Terraform Loops

Terraform bietet verschiedene Mechanismen, um Ressourcen mehrfach zu erstellen, ohne den gleichen Code wiederholen zu müssen. Damit lassen sich z.B. mehrere Server, DNS-Einträge oder Firewall-Regeln mit einer einzigen Ressourcen-Definition erzeugen.

## count

Das `count` Meta-Argument ist der einfachste Weg, eine Ressource mehrfach zu erstellen. Es gibt an, wie viele Instanzen erstellt werden sollen.

### Grundlegende Verwendung

```hcl
resource "hcloud_server" "server" {
  count       = 3
  name        = "web-${count.index}"
  image       = "debian-12"
  server_type = "cx22"
}
```

Terraform erstellt drei Server mit den Namen `web-0`, `web-1` und `web-2`. Der Index beginnt immer bei 0.

### Auf Instanzen zugreifen

Ressourcen mit `count` werden als Liste referenziert:

```hcl
# Einzelne Instanz
output "first_server_ip" {
  value = hcloud_server.server[0].ipv4_address
}

# Alle Instanzen
output "all_server_ips" {
  value = hcloud_server.server[*].ipv4_address
}
```

### Praxisbeispiel: Server mit DNS-Einträgen

```hcl
resource "hcloud_server" "server" {
  count       = 10
  name        = "www-${count.index}"
  image       = "debian-12"
  server_type = "cx22"
  user_data   = local_file.user_data[count.index].content
}

resource "dns_a_record_set" "dnsRecordSet" {
  count     = 10
  zone      = "g3.sdi.hdm-stuttgart.cloud."
  name      = hcloud_server.server[count.index].name
  addresses = [hcloud_server.server[count.index].ipv4_address]
}
```

### count mit Variablen

Die Anzahl kann über eine Variable gesteuert werden:

```hcl
variable "server_count" {
  description = "Anzahl der Server"
  type        = number
  default     = 3
}

resource "hcloud_server" "server" {
  count       = var.server_count
  name        = "web-${count.index}"
  image       = "debian-12"
  server_type = "cx22"
}
```

### Bedingtes Erstellen mit count

`count` kann auch als Bedingung verwendet werden, um eine Ressource optional zu erstellen:

```hcl
variable "create_firewall" {
  type    = bool
  default = true
}

resource "hcloud_firewall" "ssh" {
  count = var.create_firewall ? 1 : 0
  name  = "ssh-firewall"
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}
```

## for_each

`for_each` erstellt eine Instanz pro Element in einer Map oder einem Set. Im Gegensatz zu `count` werden Ressourcen über Keys statt über Indizes identifiziert.

### Mit einer Map

```hcl
variable "servers" {
  type = map(object({
    server_type = string
    image       = string
  }))
  default = {
    "web" = {
      server_type = "cx22"
      image       = "debian-12"
    }
    "db" = {
      server_type = "cx32"
      image       = "debian-12"
    }
  }
}

resource "hcloud_server" "server" {
  for_each    = var.servers
  name        = each.key
  server_type = each.value.server_type
  image       = each.value.image
}
```

### Mit einem Set

```hcl
variable "server_names" {
  type    = set(string)
  default = ["web", "api", "db"]
}

resource "hcloud_server" "server" {
  for_each    = var.server_names
  name        = each.key
  image       = "debian-12"
  server_type = "cx22"
}
```

### Auf Instanzen zugreifen

```hcl
# Einzelne Instanz über den Key
output "web_server_ip" {
  value = hcloud_server.server["web"].ipv4_address
}

# Alle IPs als Map
output "all_ips" {
  value = { for k, v in hcloud_server.server : k => v.ipv4_address }
}
```

## for-Ausdruck

Der `for`-Ausdruck erzeugt Listen oder Maps aus bestehenden Datenstrukturen:

```hcl
# Liste erzeugen
output "server_names" {
  value = [for s in hcloud_server.server : s.name]
}

# Map erzeugen
output "server_ips" {
  value = { for s in hcloud_server.server : s.name => s.ipv4_address }
}

# Mit Bedingung filtern
output "large_servers" {
  value = [for s in hcloud_server.server : s.name if s.server_type == "cx32"]
}
```

## count vs. for_each

| Eigenschaft | count | for_each |
|---|---|---|
| Identifikation | Index (0, 1, 2...) | Key (Name) |
| Reihenfolge wichtig | Ja | Nein |
| Element entfernen | Verschiebt Indizes | Nur betroffene Ressource |
| Eingabe | Zahl | Map oder Set |

::: tip Wann was verwenden?
- **count**: Wenn man eine bestimmte Anzahl identischer Ressourcen braucht
- **for_each**: Wenn jede Ressource unterschiedliche Konfigurationen hat oder wenn Ressourcen stabil referenziert werden sollen
:::

## Weiterführende Links

- [Terraform: count Meta-Argument](https://developer.hashicorp.com/terraform/language/meta-arguments/count)
- [Terraform: for_each Meta-Argument](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each)
- [Terraform: for Expressions](https://developer.hashicorp.com/terraform/language/expressions/for)
- [Lecture Notes: Terraform Loops](https://freedocs.mi.hdm-stuttgart.de/sdi_cloudProvider_loops.html)
