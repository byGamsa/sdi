# 24. Created a fixed number of servers

Diese Aufgabe baut auf der Basis von Aufgabe 23 auf.

Hier geht es darum, mehrere Server zu konfigurieren, wobei die Anzahl der Server in einer Variablen gespeichert werden.

Dabei sollen die Server außerdem auch eigene ssh-host key pairs und eigene ``bin/ssh`` und ``gen/known_hosts`` files besitzen

### Erstellen einer neuen Variable ``serverCount``

Hier wird eine neue Variable ``serverCount`` deklariert und initialisiert

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

### Anwendung der neuen Variablen und Implementierung im bestehenden Code

Um die Aufgabe zu lösen, müssen wir den Code von einer statischen Konfiguration in eine dynamische Konfiguration umwandeln, was wir durch das hinzufügen von ``count``-Variablen umsetzen.

Zudem wird der Output angepasst, indem man den Output aller Server (mit ``[*]``) ausgibt.

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

Da wir den Code von der vorherigen Aufgabe genommen haben, bekommen wir noch eine Fehlermeldung, da die Aliase und die Apex-Domain nicht mehr richig weitergeleitet wird. Hier setzen wir sie nicht mehr auf ``workhouse.g1.sdi.hdm-stuttgart.cloud.``, sondern auf den ersten Server der erstellt wird, also auf ``work-1.g1.sdi.hdm-stuttgart.cloud.``:

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

Jetzt können wir das Ganze applien und alles sollte korrekt erstellt werden, der Output sollte ungefähr so aussehen:
```
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

Zudem können die generierten ssh-Files ausgeführt werden, um zu überprüfen, ob hier alles korrekt geklappt hat.

Außerdem kann erneut der Befehl von Aufgabe 22 und Aufgabe 23 ausgeführt werden:

```bash
dig @ns1.hdm-stuttgart.cloud -y "hmac-sha512:"$HMAC -t AXFR g1.sdi.hdm-stuttgart.cloud
```

Sollte alles korrekt geklappt haben, sollte die Ausgabe ungefährt so aussehen:
```
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