# 22. Creating DNS records

In dieser Aufgabe werden wir...
- Alle Ressourcen der vorherigen Aufgaben entfernen und eine minimale Konfiguration mit einem A-record erstellen
- Zwei Aliase hinzufügen
- Hart-gecodete Strings entfernen und Variablen daraus erstellen
- Validations für die Variablen erstellen.

### Voraussetzungen
- Man besitzt bereits ein DNS-Secret
- Alle Ressourcen der vorherigen Aufgabe sollten gelöscht sein. Man sollte drei neue Files erstellen, ``main.tf``, ``variable.tf`` und ``secrets.auto.tfvars``
- Die Variable HMAC sollte exportiert sein. Sollte dies nicht passiert sein, muss das noch gemacht werden:
```bash
export HMAC="g1.key:CCqK..."
```

### Erstellung einer minimalen Konfiguration eines A-records für die Basisdomain und die ``workhouse``-Subdomain

Hierzu sollte man zuerst die Variable dns_secret definieren und sie initialisieren
::: code-group
```hcl [variable.tf]
variable "dns_secret" { // [!code ++:5]
  description = "Secret für DNS"
  type        = string
  nullable    = false
}
```
```hcl [secrets.auto.tfvars]
dns_secret="CCqK..." // [!code ++]
```
:::

Anschließend sollte man eine minimale Konfiguration in der ``main.tf`` vornehmen, um dort den DNS Record für die Basisdomain und die Subdomain zu erstellen. Eine ähnliche Konfiguration wurde bereits in der letzten Aufgabe verwendet.
::: code-group
```hcl [main.tf]
provider "dns" { // [!code ++:30]
  update {
    server        = "ns1.sdi.hdm-stuttgart.cloud"
    key_name      = "g1.key."
    key_algorithm = "hmac-sha512"
    key_secret    = var.dns_secret
  }
}

resource "dns_a_record_set" "workhorse" {
  name = "workhorse"
  zone = "g1.sdi.hdm-stuttgart.cloud."
  ttl = 10
  addresses = ["1.2.3.4"]
}

resource "null_resource" "dns_root" {
  triggers = {
    server_ip = "1.2.3.4"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "server ns1.sdi.hdm-stuttgart.cloud
      update delete g1.sdi.hdm-stuttgart.cloud. A
      update add g1.sdi.hdm-stuttgart.cloud. 10 A "1.2.3.4"
      send" | nsupdate -y "hmac-sha512:g1.key:${var.dns_secret}"
    EOT
  }
}
```
:::

Anschließend kann der Code ausgeführt werden.

```bash
terraform init
terraform plan
terraform apply
```

Um abschließend zu testen, ob alles korrekt ausgeführt wurde, kann es folgendermaßen getestet werden:
```bash
dig @ns1.hdm-stuttgart.cloud -y "hmac-sha512:"$HMAC -t AXFR g1.sdi.hdm-stuttgart.cloud
```

### Hinzufügen der Aliase

Um Aliase hinzuzufügen, erstellen wir einen ``dns_cname_record``
::: code-group
```hcl [main.tf]
resource "dns_cname_record" "aliases" { // [!code ++:8]
  count = length(["www", "mail"])

  name  = ["www", "mail"][count.index]
  zone  = "g1.sdi.hdm-stuttgart.cloud."
  ttl   = 10
  cname = "workhorse.g1.sdi.hdm-stuttgart.cloud."
}
```
:::

Dies kann erneut ausgeführt werden. Anschließend kann wieder getestet werden, ob soweit alles geklappt hat.
```bash
dig @ns1.hdm-stuttgart.cloud -y "hmac-sha512:"$HMAC -t AXFR g1.sdi.hdm-stuttgart.cloud
```
Sollten folgende Zeilen angezeigt werden, sollte soweit alles gepasst haben:
```
mail.g1.sdi.hdm-stuttgart.cloud. 10 IN  CNAME   workhorse.g1.sdi.hdm-stuttgart.cloud.
www.g1.sdi.hdm-stuttgart.cloud. 10 IN   CNAME   workhorse.g1.sdi.hdm-stuttgart.cloud.
```

### Entfernung aller Hard-gecodeter Strings, Erstellung von Variablen
Da wird bisher mit wenigen Variablen gearbeitet haben, definieren wir sie und ersetzen die Strings damit.
Wir erstellen dafür ein neues File mit dem Namen ``config.auto.tfvars``, in der die Variablen initialisiert werden.
::: code-group
```hcl [variable.tf]
variable "dns_secret" {
  description = "Secret für DNS"
  type        = string
  nullable    = false
}

variable "dnsZone" { // [!code ++:30]
  description = "Die Basis-Domain / Zone"
  type        = string
  nullable    = false
}

variable "serverName" {
  description = "Canonical Name des Servers"
  type        = string
  nullable    = false
}

variable "serverIp" {
  description = "IP-Adresse des Servers"
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
}
```
```hcl [config.auto.tfvars]
serverIp="1.2.3.4" // [!code ++:5]
dnsZone="g1.sdi.hdm-stuttgart.cloud"
serverName="workhorse"
serverAliases=["www", "mail"]
groupName="g1"
```
:::

Anschließend müssen die Variablen noch richtig in die `main.tf` eingesetzt werden.
::: code-group
```hcl [main.tf]
provider "dns" {
  update {
    server        = "ns1.sdi.hdm-stuttgart.cloud"
    key_name      = "${var.groupName}.key." // [!code ++]
    key_algorithm = "hmac-sha512"
    key_secret    = var.dns_secret
  }
}

resource "dns_a_record_set" "workhorse" {
  name = var.serverName // [!code ++]
  zone = "${var.dnsZone}." // [!code ++]
  ttl = 10
  addresses = [var.serverIp] // [!code ++]
}

resource "null_resource" "dns_root" {
  triggers = {
    server_ip = var.serverIp // [!code ++]
  }

  provisioner "local-exec" {
    command = <<-EOT // [!code ++:5]
      echo "server ns1.sdi.hdm-stuttgart.cloud 
      update delete ${var.dnsZone}. A 
      update add ${var.dnsZone}. 10 A ${var.serverIp} 
      send" | nsupdate -y "hmac-sha512:${var.groupName}.key:${var.dns_secret}" 
    EOT
  }
}

resource "dns_cname_record" "aliases" {
  count = length(var.serverAliases) // [!code ++]
  name  = var.serverAliases[count.index] // [!code ++]
  zone  = "${var.dnsZone}." // [!code ++]
  ttl   = 10
  cname = "${var.serverName}.${var.dnsZone}." // [!code ++]
}
```
:::

Sollte alles korrekt implementiert worden sein, können die Änderungen erneut applied und getestet werden.

### Validierungen für die Variablen erstellen.
Zuletzt müssen noch passende Validierungen erstellt werden, sodass es nicht zu konflikten kommen kann. Dabei werden drei wichtige Valierungen überprüft:
- Gibt es bei den Aliasen Duplikate?
- Ist ein CNAME-Record = @?
- Überschneidet sich der Server-Name mit einem der Alias-Namen?

Hierfür müssen nochmal die ``main.tf`` und die ``variable.tf`` bearbeitet werden:
::: code-group
```hcl [main.tf]
resource "dns_cname_record" "aliases" {
  count = length(var.serverAliases)
  name  = var.serverAliases[count.index]
  zone  = "${var.dnsZone}."
  ttl   = 10
  cname = "${var.serverName}.${var.dnsZone}."
  lifecycle { // [!code ++:6]
    precondition {
      condition     = !contains(var.serverAliases, var.serverName)
      error_message = "Der Server-Name darf nicht gleichzeitig als Alias (CNAME) definiert sein."
    }
  }
}
```
```hcl [variable.tf]
variable "serverAliases" {
  description = "Liste der Alias-Namen"
  type        = list(string)
  default     = ["www", "mail"]
  nullable    = false
  
  validation { // [!code ++:9]
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

Anschließend kann erneut alles applied und getestet werden.
```bash
dig @ns1.hdm-stuttgart.cloud -y "hmac-sha512:"$HMAC -t AXFR g1.sdi.hdm-stuttgart.cloud
```
Falls alles erfolgreich geklappt hat. Sollte der Output ungefähr so aussehen:
```
g1.sdi.hdm-stuttgart.cloud. 600 IN      SOA     ns1.hdm-stuttgart.cloud. goik\@hdm-stuttgart.de. 54 604800 86400 2419200 604800
g1.sdi.hdm-stuttgart.cloud. 10  IN      A       1.2.3.4
g1.sdi.hdm-stuttgart.cloud. 600 IN      NS      ns1.hdm-stuttgart.cloud.
mail.g1.sdi.hdm-stuttgart.cloud. 10 IN  CNAME   workhorse.g1.sdi.hdm-stuttgart.cloud.
test.g1.sdi.hdm-stuttgart.cloud. 10 IN  A       1.2.3.4
workhorse.g1.sdi.hdm-stuttgart.cloud. 10 IN A   1.2.3.4
www.g1.sdi.hdm-stuttgart.cloud. 10 IN   CNAME   workhorse.g1.sdi.hdm-stuttgart.cloud.
g1.sdi.hdm-stuttgart.cloud. 600 IN      SOA     ns1.hdm-stuttgart.cloud. goik\@hdm-stuttgart.de. 54 604800 86400 2419200 604800
```