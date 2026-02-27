# Terraform und DNS

Das Domain Name System (DNS) übersetzt Domainnamen in IP-Adressen. In Kombination mit Terraform lassen sich DNS-Einträge automatisiert erstellen und verwalten, sodass Server direkt über lesbare Namen erreichbar sind.

## DNS Grundlagen

### Wie funktioniert DNS?

1. Du gibst einen Domainnamen im Browser ein (z.B. `example.com`)
2. Dein Computer fragt einen DNS-Resolver (z.B. von deinem ISP)
3. Der Resolver fragt Root-, TLD- und autoritative DNS-Server
4. Die IP-Adresse wird zurückgegeben und die Verbindung hergestellt

### Wichtige Record-Typen

| Record | Beschreibung                      | Beispiel                         |
| ------ | --------------------------------- | -------------------------------- |
| A      | Domain → IPv4-Adresse             | `workhorse.g3.sdi... → 1.2.3.4`  |
| AAAA   | Domain → IPv6-Adresse             | `workhorse.g3.sdi... → 2a01:...` |
| CNAME  | Alias auf eine andere Domain      | `www → workhorse.g3.sdi...`      |
| MX     | Mailserver für eine Domain        | `mail.example.com`               |
| TXT    | Beliebiger Text (SPF, DKIM)       | `v=spf1 ...`                     |
| NS     | Autoritativer Nameserver          | `ns1.example.com`                |
| SOA    | Administrative Zone-Informationen | -                                |
| PTR    | Reverse DNS (IP → Name)           | `1.2.3.4 → workhorse...`         |

### Wichtige Begriffe

- **Zone**: Ein Abschnitt des DNS-Namensraums, verwaltet von einer Organisation
- **TTL (Time To Live)**: Wie lange ein DNS-Eintrag gecacht wird
- **Propagation**: Zeit bis DNS-Änderungen weltweit sichtbar sind
- **FQDN**: Fully Qualified Domain Name (z.B. `workhorse.g3.sdi.hdm-stuttgart.cloud`)

## DNS-Abfragen mit dig

```bash
# A-Record abfragen
dig example.com A

# Bestimmten Nameserver fragen
dig @ns1.hdm-stuttgart.cloud example.com

# Alle Records anzeigen
dig example.com ANY

# Kurzform
dig +short example.com

# DNS-Auflösungspfad verfolgen
dig +trace example.com

# Reverse DNS
dig -x 1.2.3.4
```

## DNS Zone Transfer

Alle Einträge einer Zone anzeigen (AXFR):

```bash
# HMAC Key exportieren
export HMAC="hmac-sha512:g10.key:<DEIN_SECRET_KEY>"

# Zone Transfer durchführen
dig @ns1.hdm-stuttgart.cloud -y $HMAC -t AXFR g10.sdi.hdm-stuttgart.cloud
```

## Manuelle DNS-Verwaltung mit nsupdate

DNS-Einträge können manuell mit `nsupdate` erstellt und gelöscht werden:

### Eintrag hinzufügen

```bash
nsupdate -y $HMAC
server ns1.hdm-stuttgart.cloud
update add www.g10.sdi.hdm-stuttgart.cloud 10 A <SERVER_IP>
send
quit
```

### Eintrag löschen

```bash
nsupdate -y $HMAC
server ns1.hdm-stuttgart.cloud
update delete www.g10.sdi.hdm-stuttgart.cloud A
send
quit
```

::: tip
Um einen Eintrag zu ändern, muss der alte zuerst gelöscht und dann der neue hinzugefügt werden.
:::

## DNS mit Terraform verwalten

### DNS Provider konfigurieren

```hcl
terraform {
  required_providers {
    dns = {
      source = "hashicorp/dns"
    }
  }
}

provider "dns" {
  update {
    server        = "ns1.hdm-stuttgart.cloud"
    key_name      = "g10.key."
    key_algorithm = "hmac-sha512"
    key_secret    = var.dns_secret
  }
}
```

### A-Records erstellen

Ein A-Record verknüpft einen Domainnamen mit einer IPv4-Adresse:

```hcl
resource "dns_a_record_set" "server_a" {
  zone      = "${var.dns_zone}."
  name      = var.server_name
  addresses = [var.server_ip]
  ttl       = 10
}

# Root-Domain A-Record (ohne Subdomain)
resource "dns_a_record_set" "server_a_root" {
  zone      = "${var.dns_zone}."
  addresses = [var.server_ip]
  ttl       = 10
}
```

::: warning Trailing Dot
Die Zone muss immer mit einem Punkt enden (z.B. `"g3.sdi.hdm-stuttgart.cloud."`). Das ist DNS-Standard für einen FQDN.
:::

### CNAME-Records (Aliase) erstellen

CNAME-Records verweisen auf einen anderen Domainnamen:

```hcl
resource "dns_cname_record" "server_aliases" {
  count = length(var.server_aliases)
  zone  = "${var.dns_zone}."
  name  = var.server_aliases[count.index]
  cname = "${var.server_name}.${var.dns_zone}."
  ttl   = 10

  depends_on = [dns_a_record_set.server_a]
}
```

### Variablen mit Validation

Validierungsregeln verhindern fehlerhafte Konfigurationen:

```hcl
variable "dns_zone" {
  description = "DNS Zone"
  type        = string
  nullable    = false
}

variable "server_name" {
  description = "Server-Name (Canonical Name)"
  type        = string
  nullable    = false
}

variable "server_aliases" {
  description = "CNAME Aliase"
  type        = list(string)
  default     = []

  validation {
    condition = (
      length(distinct(var.server_aliases)) == length(var.server_aliases) &&
      !contains(var.server_aliases, var.server_name)
    )
    error_message = "Aliase müssen eindeutig sein und dürfen nicht dem server_name entsprechen."
  }
}

variable "dns_secret" {
  description = "DNS HMAC-SHA512 Key Secret"
  type        = string
  sensitive   = true
}
```

Die Validierung prüft:

- Keine doppelten Alias-Namen (`distinct`)
- Kein Alias darf den Server-Namen haben (`contains`)

### Konfigurationsdatei (tfvars)

```hcl
# config.auto.tfvars
server_ip      = "1.2.3.4"
dns_zone       = "g3.sdi.hdm-stuttgart.cloud"
server_name    = "workhorse"
server_aliases = ["www", "mail"]
```

## Server mit DNS-Einträgen kombinieren

Terraform kann Server erstellen und automatisch die passenden DNS-Einträge anlegen:

```hcl
resource "hcloud_server" "debian_server" {
  name        = "debian-server"
  image       = "debian-12"
  server_type = "cx22"
}

resource "dns_a_record_set" "server_a" {
  zone      = "${var.dns_zone}."
  name      = var.server_name
  addresses = [hcloud_server.debian_server.ipv4_address]
  ttl       = 10
}

resource "dns_cname_record" "server_aliases" {
  count = length(var.server_aliases)
  zone  = "${var.dns_zone}."
  name  = var.server_aliases[count.index]
  cname = "${var.server_name}.${var.dns_zone}."
  ttl   = 10

  depends_on = [dns_a_record_set.server_a]
}
```

Dadurch sind die Server direkt nach `terraform apply` über ihren DNS-Namen erreichbar (z.B. `workhorse.g3.sdi.hdm-stuttgart.cloud`).

## DNS Cache leeren

Nach DNS-Änderungen muss der lokale Cache geleert werden:

```bash
# Windows
ipconfig /flushdns

# Linux
sudo systemd-resolve --flush-caches

# macOS
dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

## Weiterführende Links

- [Terraform DNS Provider](https://registry.terraform.io/providers/hashicorp/dns/latest/docs)
- [BIND9 Dokumentation](https://bind9.readthedocs.io/)
- [DNS Update Protocol (RFC 2136)](https://datatracker.ietf.org/doc/html/rfc2136)
- [Lecture Notes: Terraform und DNS](https://freedocs.mi.hdm-stuttgart.de/sdiDnsProjectNameServer.html)
