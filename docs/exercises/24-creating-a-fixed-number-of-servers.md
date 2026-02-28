# 24. Feste Anzahl an Servern erstellen

Originale Aufgabenstellung: [Lecture Notes](https://freedocs.mi.hdm-stuttgart.de/sdiDnsProjectNameServer.html#sdi_cloudProvider_loops_qanda_multiServerGen)

In dieser Übung wird die bestehende Konfiguration dynamisch gemacht, sodass eine variable Anzahl an Servern über eine einzige Variable gesteuert wird. Jeder Server erhält seinen eigenen SSH Host Key, eigene Wrapper-Skripte (`bin/ssh`, `bin/scp`), eine individuelle `known_hosts`-Datei und einen eigenen DNS A-Record.

## Architektur-Komponenten

| Komponente                   | Beschreibung                                                                  |
| ---------------------------- | ----------------------------------------------------------------------------- |
| **`count` Meta-Argument**    | Erstellt mehrere Instanzen jeder Ressource basierend auf `serverCount`        |
| **Dynamische Namensvergabe** | Server werden durchnummeriert (`work-1`, `work-2`, ...)                       |
| **Individuelle SSH-Keys**    | Jeder Server erhält ein eigenes ED25519-Schlüsselpaar                         |
| **Individuelle Skripte**     | Pro Server ein eigenes `bin/ssh` und `gen/known_hosts` im eigenen Unterordner |
| **DNS A-Records**            | Jeder Server bekommt einen eigenen A-Record                                   |
| **Splat-Expression `[*]`**   | Gibt die Attribute aller Instanzen als Liste aus                              |

## Codebasis

Diese Aufgabe baut auf der Infrastruktur aus [Aufgabe 23](/exercises/23-creating-host-with-corresponding-dns-entries) auf. Der dort erstellte Code wird so erweitert, dass er mit einer variablen Anzahl an Servern funktioniert.

## Übungsschritte

### 1. Variable `serverCount` erstellen

Deklariere eine neue Variable `serverCount`, die die Anzahl der zu erstellenden Server bestimmt. In der `config.auto.tfvars` wird der Wert gesetzt:

::: code-group

```hcl [variable.tf]
variable "serverName" {
  description = "Canonical Name des Servers"
  type        = string
  nullable    = false
}

variable "serverCount" { // [!code ++:5]
  description = "The number of servers to create"
  type        = number
  default     = 2
}

variable "groupName" {
  description = "Gruppennummer"
  type        = string
  nullable    = false
}

```

```hcl [config.auto.tfvars]
dnsZone="g1.sdi.hdm-stuttgart.cloud"
serverName="work"
serverAliases=["www", "mail"]
groupName="g1"
loginUser="devops"
serverCount="2" // [!code ++]
```

:::

### 2. Dynamische Konfiguration implementieren

Um die Aufgabe zu lösen, wird der Code von einer statischen in eine dynamische Konfiguration umgewandelt. Das geschieht durch das Hinzufügen von `count` zu allen relevanten Ressourcen. Über `count.index` wird auf den aktuellen Index zugegriffen, und mit `[count.index]` wird auf die jeweilige Instanz referenziert.

Zudem wird der Output angepasst, indem die Expression `[*]` verwendet wird, um die Daten aller Server auszugeben:

::: code-group

```hcl [main.tf]
resource "tls_private_key" "host_key" {
  algorithm = "ED25519"
  count = var.serverCount // [!code ++]
}

resource "hcloud_server" "helloServer" {
  count        = var.serverCount // [!code ++]
  name         = "${var.serverName}-${count.index + 1}" // [!code ++]
  image        =  "debian-13"
  server_type  =  "cx23"
  firewall_ids = [hcloud_firewall.fw.id]
  ssh_keys     = [hcloud_ssh_key.loginUser.id]
  user_data    = local_file.user_data[count.index].content // [!code ++]
}

resource "local_file" "user_data" {
  count = var.serverCount // [!code ++]
  content = templatefile("tpl/userData.yml", {
    loginUser = var.loginUser
    sshKey    = chomp(file("~/.ssh/id_ed25519.pub"))
    tls_private_key = indent(4, tls_private_key.host_key[count.index].private_key_openssh) // [!code ++]
  })
  filename = "${var.serverName}-${count.index+1}/gen/userData.yml" // [!code ++]
}

resource "local_file" "known_hosts" {
  count = var.serverCount  // [!code ++]
  content = "${var.serverName}-${count.index + 1}.${var.dnsZone} ${tls_private_key.host_key[count.index].public_key_openssh}"  // [!code ++]
  filename        = "${var.serverName}-${count.index + 1}/gen/known_hosts"  // [!code ++]
  file_permission = "644"
}

resource "local_file" "ssh_script" {
  count = var.serverCount  // [!code ++]
  content = templatefile("${path.module}/tpl/ssh.sh", {
    devopsUsername = var.loginUser,
    dnsName = "${var.serverName}-${count.index + 1}.${var.dnsZone}"  // [!code ++]
  })
  filename        = "${var.serverName}-${count.index + 1}/bin/ssh"  // [!code ++]
  file_permission = "755"
}

resource "local_file" "scp_script" {
  count = var.serverCount  // [!code ++]
  content = templatefile("${path.module}/tpl/scp.sh", {
    devopsUsername = var.loginUser,
    dnsName = "${var.serverName}-${count.index + 1}.${var.dnsZone}"  // [!code ++]
  })
  filename        = "${var.serverName}-${count.index + 1}/bin/scp"  // [!code ++]
  file_permission = "755"
}

resource "dns_a_record_set" "workhorse" {
  count = var.serverCount // [!code ++]
  name = "${var.serverName}-${count.index+1}" // [!code ++]
  zone = "${var.dnsZone}."
  ttl = 10
  addresses = [hcloud_server.helloServer[count.index].ipv4_address] // [!code ++]
}
```

```hcl [output.tf]
output "ip_addr" {
  value       = hcloud_server.helloServer[*].ipv4_address // [!code ++]
  description = "The server's IPv4 address"
}

output "datacenter" {
  value       = hcloud_server.helloServer[*].datacenter // [!code ++]
  description = "The server's datacenter"
}
```

:::

### 3. Aliase und Apex-Domain anpassen

Da wir den Code von der vorherigen Aufgabe übernommen haben, gibt es eine Fehlermeldung: Die Aliase und die Apex-Domain verweisen noch auf den alten Server-Namen (`workhorse`). Da der Name jetzt durchnummeriert ist, müssen die CNAME-Aliase und die Root-Domain auf den **ersten Server** (`work-1`) zeigen:

::: code-group

```hcl [main.tf]
resource "null_resource" "dns_root" {
  triggers = {
    server_ip = hcloud_server.helloServer[0].ipv4_address // [!code ++]
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "server ns1.sdi.hdm-stuttgart.cloud
      update delete ${var.dnsZone}. A
      update add ${var.dnsZone}. 10 A ${hcloud_server.helloServer[0].ipv4_address} // [!code ++]
      send" | nsupdate -y "hmac-sha512:${var.groupName}.key:${var.dns_secret}"
    EOT
  }
}

resource "dns_cname_record" "aliases" {
  count = length(var.serverAliases)
  name  = var.serverAliases[count.index]
  zone  = "${var.dnsZone}."
  ttl   = 10
  cname = "${var.serverName}-1.${var.dnsZone}." // [!code ++]
  lifecycle {
    precondition {
      condition     = !contains(var.serverAliases, var.serverName)
      error_message = "Der Server-Name darf nicht gleichzeitig als Alias (CNAME) definiert sein."
    }
  }
}

```

:::

### 4. Ergebnis überprüfen

Nach Apply sollte der Output die IP-Adressen und Datacenter beider Server auflisten:

```text
Outputs:

datacenter = [
  "hel1-dc2",
  "hel1-dc2",
]
ip_addr = [
  "37.27.12.32",
  "37.27.200.65",
]
```

Teste die generierten SSH-Skripte für jeden Server:

```bash
./workhorse-1/bin/ssh
./workhorse-2/bin/ssh
```

Zudem kann der Befehl von Aufgabe 22 und Aufgabe 23 die korrekte Einrichtung bestätigen:

```bash
dig @ns1.hdm-stuttgart.cloud -y "hmac-sha512:"$HMAC -t AXFR g1.sdi.hdm-stuttgart.cloud
```

Sollte alles korrekt geklappt haben, sollte die Ausgabe ungefähr so aussehen:

```text
g1.sdi.hdm-stuttgart.cloud. 600 IN      SOA     ns1.hdm-stuttgart.cloud. goik\@hdm-stuttgart.de. 85 604800 86400 2419200 604800
g1.sdi.hdm-stuttgart.cloud. 10  IN      A       37.27.12.32
g1.sdi.hdm-stuttgart.cloud. 600 IN      NS      ns1.hdm-stuttgart.cloud.
mail.g1.sdi.hdm-stuttgart.cloud. 10 IN  CNAME   work-1.g1.sdi.hdm-stuttgart.cloud.
test.g1.sdi.hdm-stuttgart.cloud. 10 IN  A       1.2.3.4
work-1.g1.sdi.hdm-stuttgart.cloud. 10 IN A      37.27.12.32
work-2.g1.sdi.hdm-stuttgart.cloud. 10 IN A      37.27.200.65
www.g1.sdi.hdm-stuttgart.cloud. 10 IN   CNAME   work-1.g1.sdi.hdm-stuttgart.cloud.
g1.sdi.hdm-stuttgart.cloud. 600 IN      SOA     ns1.hdm-stuttgart.cloud. goik\@hdm-stuttgart.de. 85 604800 86400 2419200 604800
```

::: tip
Durch Ändern von `serverCount` in der `config.auto.tfvars` können beliebig viele Server erstellt oder entfernt werden. Terraform kümmert sich automatisch um das Erstellen/Löschen der jeweiligen Ressourcen.
:::
