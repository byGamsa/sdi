# 25. Ein Web-Zertifikat erstellen

Originale Aufgabenstellung: [Lecture Notes](https://freedocs.mi.hdm-stuttgart.de/sdi_cloudProvider_certs.html#sdi_cloudProvider_certs_qanda_createCert)

In dieser Übung geht es darum, mithilfe von Terraform ein SSL/TLS-Zertifikat von Let's Encrypt automatisiert signieren zu lassen und lokal abzuspeichern (für die Haupt-Domain und alle Sub-Domains). Dies ist eine Erweiterung zur Aufgabe 21, bei der das Zertifikat noch manuell über das CLI (Command Line Interface) direkt auf dem Server bezogen wurde.

## Architektur-Komponenten

| Komponente                   | Beschreibung                                        |
| ---------------------------- | --------------------------------------------------- |
| **Zertifizierung**           | ACME Provider (Let's Encrypt), RSA & ED25519 Keys   |
| **DNS**                      | DNS-Challenge mittels RFC2136                       |
| **Netzwerk/Sicherheit**      | Firewall Rules für HTTPS (Port 443)                 |

## Codebasis

Diese Aufgabe baut auf der Infrastruktur aus [Aufgabe 24](/exercises/24-creating-a-fixed-number-of-servers) auf.

## Übungsschritte

### Provider konfigurieren

Zuerst konfigurieren wir den Provider mit der von Let's Encrypt bereitgestellten URL. Der `acme`-Provider muss zusätzlich in die `provider.tf` eingefügt werden.
::: warning

- Es ist wichtig die Staging-URL zu benutzen, statt der Production-URL, da es strenge Rate-Limits gibt.
- Bei acme ist es wichtig, eine Version zu benutzen, die neuer als `v2.23.2` ist. Wir benutzen die neuste Version.
  :::

::: code-group

```hcl [provider.tf]
provider "acme" { // [!code ++:3]
  server_url = "https://acme-staging-v02.api.letsencrypt.org/directory"
}

provider "hcloud" {
  token = var.hcloud_token
}

terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
    acme = {  // [!code ++:3]
            source  = "vancluever/acme"
        }
  }
  required_version = ">= 0.13"
}
```

:::

Im nächsten Schritt wird ein neuer RSA-Privatschlüssel angelegt, mit dem wir uns anschließend bei Let's Encrypt registrieren. Zudem muss eine neue Variable mit dem Namen email angelegt werden, hier kann eine Email eingetragen werden, auf die man Zugriff hat.

::: code-group

```hcl [main.tf]
resource "tls_private_key" "host_key" {
  algorithm = "ED25519"
  count = var.serverCount
}

resource "tls_private_key" "acme_reg" { // [!code ++:3]
  algorithm = "RSA"
}

resource "acme_registration" "reg" { // [!code ++:4]
  account_key_pem = tls_private_key.acme_reg.private_key_pem
  email_address   = var.email
}

```

```hcl [variables.tf]
variable "email" { // [!code ++:4]
  description = "Email address for Let's Encrypt registration"
  type        = string
}
```

:::

Nach der Registrierung des Accounts wird das eigentliche Zertifikat über den Provider Let's Encrypt angefragt. Über die Attribute `common_name` und `subject_alternative_names` stellen wir sicher, dass das Zertifikat sowohl für alle Subdomains als auch für die Hauptdomain selbst gültig ist. Danach wird eine DNS-Challenge ausgeführt, um das Zertifikat automatisch zu beantragen.

::: code-group

```hcl [main.tf]
resource "acme_certificate" "wildcard_cert" {  // [!code ++:17]
  account_key_pem = acme_registration.reg.account_key_pem
  common_name     = "*.${var.dnsZone}"
  subject_alternative_names = [
    var.dnsZone,
  ]

  dns_challenge {
    provider = "rfc2136"
    config = {
      RFC2136_NAMESERVER     = "ns1.sdi.hdm-stuttgart.cloud"
      RFC2136_TSIG_ALGORITHM = "hmac-sha512"
      RFC2136_TSIG_KEY       = "g1.key."
      RFC2136_TSIG_SECRET    = var.dns_secret
    }
  }
}
```

:::
Damit wir das generierte Zertifikat später auf unserem Webserver nutzen können, müssen die Daten in physischen Dateien abgelegt werden. Dafür nutzen wir die Terraform-Ressource local_file, welche die Dateien automatisch in dem Unterordner `gen/` speichert. Dabei brauchen wir ein privates File, in dem unser private Key abgelegt wird, der nicht an die Öffentlichkeit gelangen darf. Nur mit ihm kann der Server die Anfragen, die mit dem Public Certificate verschlüsselt wurden, wieder entschlüsseln. Das zweite File ist für unser Zertifikat gedacht, direkt mit dem Zertifikat von Let's Encrypt.

::: warning
Solange der Ordner `gen` den private Key enthält, darf er nicht in Git hochgeladen werden!
:::

::: code-group

```hcl [main.tf]
resource "local_file" "certificate_pem" { // [!code ++:9]
  content  = "${acme_certificate.wildcard_cert.certificate_pem}${acme_certificate.wildcard_cert.issuer_pem}"
  filename = "gen/certificate.pem"
}

resource "local_file" "private_key_pem" {
  content  = acme_certificate.wildcard_cert.private_key_pem
  filename = "gen/private.pem"
}
```

:::

Jetzt müsste die Konfiguration bereits abgeschlossen sein, da allerdings unsere Firewall aktuell nur Port 22 und Port 80 durchlässt, sollten wir noch Port 443 öffnen, um `https` zuzulassen.
::: code-group

```hcl [main.tf]
resource "hcloud_firewall" "fw" {
  name = "firewall-2"
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  rule { // [!code ++:6]
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}
```

:::

Nach dem applien kann in dem `gen/` Ordner überprüft werden, ob beide Files erfolgreich erstellt wurden. Außerdem kann folgender Befehl im Terminal ausgeführt werden:

```bash
openssl x509 -in gen/certificate.pem -text -noout
```

Hier kann man den Issuer überprüfen und überprüfen, ob die Domains richtig gesetzt wurden. So sollte der korrekte Issuer in etwa aussehen:

```
Issuer: C = US, O = (STAGING) Let's Encrypt, CN = (STAGING) Tenuous Tomato R13
```
