# 28. Ein Subnetz erstellen

Originale Aufgabenstellung: [Lecture Notes](https://freedocs.mi.hdm-stuttgart.de/sdi_cloudProvider_networks.html#sdi_cloudProvider_networks_qanda_simpleSubnet)

In dieser Übung geht es darum:

- Ein privates Netzwerk und ein privates Subnetz zu erstellen.
- Ein Gateway einzurichten, das zwei Netzwerkschnittstellen besitzt: eine zum privaten Subnetz und eine zum Internet (über SSH erreichbar).
- Einen internen Host aufzusetzen, der ausschließlich mit dem privaten Subnetz verbunden ist. Er ist vom Internet isoliert, hat keinen Internetzugang und ist nur vom Gateway-Host aus erreichbar.
- Lokale DNS-Namen festzulegen, die auf den beiden Hosts verwendet werden.

## Codebasis

Da diese Aufgabe mit dem Erstellen von privaten Netzwerken ein komplett neues Szenario einführt, baut sie nicht direkt auf den vorherigen Übungen auf. Dennoch werden grundlegende Teile der bestehenden Konfiguration übernommen (siehe Dokumentation unten).

## Übungsschritte

### Erstellung der Dateien zu Beginn der Aufgabe

::: warning
Zu beachten ist, dass der `tpl/`- Ordner mit zugehörigen Inhalt und die output.tf mit Inhalt gleich bleibt
:::

Mit folgenden Konfigurationen starten wir in die Aufgabe:
::: code-group

```hcl [main.tf]
resource "tls_private_key" "host_key" {
  algorithm = "ED25519"
}

resource "local_file" "user_data" {
  content = templatefile("tpl/userData.yml", {
    tls_private_key = indent(4, tls_private_key.host_key.private_key_openssh)
    loginUser = var.loginUser
    sshKey    = chomp(file("~/.ssh/id_ed25519.pub"))
  })
  filename = "gen/userData.yml"
}

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
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_ssh_key" "loginUser" {
  name       = "my_ssh_key_joel"
  public_key = var.ssh_login_public_key
}

resource "local_file" "known_hosts" {
  content = join(" "
    ,[ hcloud_server # todo
    , tls_private_key.host_key.public_key_openssh ]
  )
  filename        = "gen/known_hosts"
  file_permission = "644"
}

resource "local_file" "ssh_script" {
  content = templatefile("${path.module}/tpl/ssh.sh", {
    devopsUsername = var.loginUser,
    ip =
  })
  filename        = "bin/ssh"
  file_permission = "755"
}

resource "local_file" "scp_script" {
  content = templatefile("${path.module}/tpl/scp.sh", {
    devopsUsername = var.loginUser,
    ip =
  })
  filename        = "bin/scp"
  file_permission = "755"
}
```

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

```hcl [variable.tf]
variable "hcloud_token" {
  description = "Hetzner Cloud API token (can be supplied via environment variable TF_VAR_hcloud_token)"
  nullable = false
  type        = string
  sensitive   = true
}

variable "ssh_login_public_key" {
  description = ""
  nullable = false
  type = string
  sensitive = true
}

variable "loginUser" {
  description = "Der Benutzername für den Login (z.B. devops)"
  nullable = false
  type = string
  sensitive = true
}
```

:::

#### Erstellung eines privaten Netzwerks und eines privaten Subnetzwerks

Zuerst erweitern wir unsere main.tf, um ein privates Netzwerk (10.0.0.0/8) und ein Subnetz (10.0.1.0/24) zu erstellen.
::: code-group

```hcl [main.tf]
resource "hcloud_network" "privateNet" { // [!code ++:11]
  name     = "Private Network"
  ip_range = "10.0.0.0/8"
}

resource "hcloud_network_subnet" "privateSubnet" {
  network_id   = hcloud_network.privateNet.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}
```

:::

#### Erstellung des Gateway-Hosts mit zwei Netzwerkschnittstellen

::: code-group

```hcl [main.tf]
resource "hcloud_server" "gateway" { // [!code ++:16]
  name = "gateway"
  image        =  "debian-13"
  server_type  =  "cx23"
  firewall_ids = [hcloud_firewall.fw.id]
  ssh_keys     = [hcloud_ssh_key.loginUser.id]
  user_data    = local_file.user_data.content
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
  network {
    network_id = hcloud_network.privateNet.id
    ip         = "10.0.1.10"
  }
}
```

:::

#### Erstellung des internen Host, der vom Internet komplett isoliert ist

Hier muss darauf geachtet werden, dass `ipv4_enabled` und `ipv6_enabled` beide als `false` gesetzt werden.

::: code-group

```hcl [main.tf]
resource "hcloud_server" "intern" { // [!code ++:15]
  name = "intern"
  image        =  "debian-13"
  server_type  =  "cx23"
  ssh_keys     = [hcloud_ssh_key.loginUser.id]
  user_data    = local_file.user_data.content
  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
  network {
    network_id = hcloud_network.privateNet.id
    ip         = "10.0.1.20"
  }
}
```

:::

#### Verteilung interner DNS Namen

Um die Verteilung interner DNS Namen zu ermöglichen, muss zunächst die `tpl/userData.yml` Datei angepasst werden.

::: code-block

```yml [tpl/userData-yml]
#cloud-config
package_update: true
package_upgrade: true

packages:
  - nginx

ssh_pwauth: false
disable_root: true

ssh_keys:
  ed25519_private: |
    ${tls_private_key}

write_files: // [!code ++:8]
  - path: /etc/cloud/templates/hosts.debian.tmpl
    content: |
      127.0.1.1 {{fqdn}} {{hostname}}
      127.0.0.1 localhost

      10.0.1.10 gateway.intern.g1.sdi.hdm-stuttgart.cloud gateway
      10.0.1.20 intern.intern.g1.sdi.hdm-stuttgart.cloud intern

runcmd:
  # Host Key wurde geschrieben -> SSH neu starten, damit er aktiv wird
  - systemctl restart ssh
  - systemctl enable nginx
  - systemctl restart nginx

users:
  - name: ${loginUser}
    groups: sudo
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    shell: /bin/bash
    ssh_authorized_keys:
      - ${sshKey}
```

:::

Zuletzt können wir für die bessere Typisierung unser privates Subnetz als Variable definieren (wie in der Aufgabenstellung als Beispiel gegeben)
::: code-group

```hcl [variable.tf]
variable "privateSubnet" { // [!code ++:10]
  type = object({
    dnsDomainName = string
    ipAndNetmask  = string
  })
  default = {
    dnsDomainName = "intern.g1.sdi.hdm-stuttgart.cloud"
    ipAndNetmask  = "10.0.1.0/24"
  }
}
```

:::

Diese Variable kann ebenfalls im Code angewandt werden.
::: code-group

```hcl [main.tf]
resource "hcloud_network_subnet" "privateSubnet" {
  network_id   = hcloud_network.privateNet.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = var.privateSubnet.ipAndNetmask // [!code ++]
}

resource "hcloud_server" "gateway" {
  name = "gateway"
  image        =  "debian-13"
  server_type  =  "cx23"
  firewall_ids = [hcloud_firewall.fw.id]
  ssh_keys     = [hcloud_ssh_key.loginUser.id]
  user_data    = local_file.user_data.content
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
  network {
    network_id = hcloud_network.privateNet.id
    ip         = "10.0.1.10"
  }
}

resource "hcloud_server" "intern" {
  name = "intern"
  image        =  "debian-13"
  server_type  =  "cx23"
  ssh_keys     = [hcloud_ssh_key.loginUser.id]
  user_data    = local_file.user_data.content
  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
  network {
    network_id = hcloud_network.privateNet.id
    ip         = "10.0.1.20"
  }
}

resource "local_file" "user_data" {
  content = templatefile("tpl/userData.yml", {
    tls_private_key = indent(4, tls_private_key.host_key.private_key_openssh)
    loginUser = var.loginUser
    sshKey    = chomp(file("~/.ssh/id_ed25519.pub"))
    dnsDomainName = var.privateSubnet.dnsDomainName // [!code ++]
  })
  filename = "${var.serverName}/gen/userData.yml"
}
```

```yml [tpl/userData.yml]
write_files:
  - path: /etc/cloud/templates/hosts.debian.tmpl
    content: |
      127.0.1.1 {{fqdn}} {{hostname}}
      127.0.0.1 localhost

      10.0.1.10 gateway.${dnsDomainName} gateway // [!code ++]
      10.0.1.20 intern.${dnsDomainName} intern // [!code ++]
```

:::

Zuletzt ist es noch wichtig, das Package `nginx` aus und package updates unserer Cloud-init-Datei zu entfernen. Erstens brauchen wir hier einen Webserver nicht zwingend, zweitens ist diese Datei sowohl an das Gateway-Host, als auch an den internen Host gebunden. Da der interne Host jedoch kein Internet hat, würde die Ausführung der Datei hier fehlschlagen.

Als zusätzliche Maßnahme ist es sinnvoll, einen `depends_on`- Block an beide Server hinzuzufügen, sodass der Server nicht gestartet werden kann, solange die Subnetzmaske nicht erfolgreich erstellt wurde.

::: code-group

```yml [tpl/userData.yml]
#cloud-config
package_update: true #// [!code --:2]
package_upgrade: true

packages: // [!code --:2]
  - nginx

ssh_pwauth: false
disable_root: true

ssh_keys:
  ed25519_private: |
    ${tls_private_key}

write_files:
  - path: /etc/cloud/templates/hosts.debian.tmpl
    content: |
      127.0.1.1 {{fqdn}} {{hostname}}
      127.0.0.1 localhost

      10.0.1.10 gateway.${dnsDomainName} gateway
      10.0.1.20 intern.${dnsDomainName} intern

runcmd:
  # Host Key wurde geschrieben -> SSH neu starten, damit er aktiv wird
  - systemctl restart ssh
  - systemctl enable nginx #// [!code --:2]
  - systemctl restart nginx

users:
  - name: ${loginUser}
    groups: sudo
    sudo: 'ALL=(ALL) NOPASSWD:ALL'
    shell: /bin/bash
    ssh_authorized_keys:
      - ${sshKey}
```

```hcl [main.tf]
resource "hcloud_server" "gateway" {
  name = "gateway"
  image        =  "debian-13"
  server_type  =  "cx23"
  firewall_ids = [hcloud_firewall.fw.id]
  ssh_keys     = [hcloud_ssh_key.loginUser.id]
  user_data    = local_file.user_data.content
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
  network {
    network_id = hcloud_network.privateNet.id
    ip         = "10.0.1.10"
  }
  depends_on = [          // [!code ++:3]
    hcloud_network_subnet.privateSubnet
  ]
}

resource "hcloud_server" "intern" {
  name = "intern"
  image        =  "debian-13"
  server_type  =  "cx23"
  ssh_keys     = [hcloud_ssh_key.loginUser.id]
  user_data    = local_file.user_data.content
  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
  network {
    network_id = hcloud_network.privateNet.id
    ip         = "10.0.1.20"
  }
  depends_on = [          // [!code ++:3]
    hcloud_network_subnet.privateSubnet
  ]
}

```

:::

Zuletzt müssen noch alle Variablen der ssh-files, scp-files und known-hosts files an den Gateway-Server angepasst werden.
::: code-group

```hcl [main.tf]
resource "local_file" "known_hosts" {
  content = join(" "
    ,[ hcloud_server.gateway.ipv4_address // [!code ++]
    , tls_private_key.host_key.public_key_openssh ]
  )
  filename        = "gen/known_hosts"
  file_permission = "644"
}

resource "local_file" "ssh_script" {
  content = templatefile("${path.module}/tpl/ssh.sh", {
    devopsUsername = var.loginUser,
    ip = hcloud_server.gateway.ipv4_address //[!code ++]
  })
  filename        = "bin/ssh"
  file_permission = "755"
}

resource "local_file" "scp_script" {
  content = templatefile("${path.module}/tpl/scp.sh", {
    devopsUsername = var.loginUser,
    ip = hcloud_server.gateway.ipv4_address // [!code ++]
  })
  filename        = "bin/scp"
  file_permission = "755"
}
```

```bash [ssh.sh]
#!/usr/bin/env bash

GEN_DIR=$(dirname "$0")/../gen

ssh -o UserKnownHostsFile="$GEN_DIR/known_hosts" ${devopsUsername}@${ip} "$@"  #// [!code ++]
```

```bash [scp.sh]
#!/usr/bin/env bash

GEN_DIR=$(dirname "$0")/../gen

if [ $# -lt 2 ]; then
   echo usage: .../bin/scp ${devopsUsername}@${ip} ... #// [!code ++]
else
   scp -o UserKnownHostsFile="$GEN_DIR/known_hosts" $@
fi
```

:::

Um zu prüfen, ob alles richtig funktioniert hat, kann man sich zuerst mithilfe des erstellten `bin/ssh`-Files im Gateway einloggen. Anschließend können folgende Befehle ausgeführt werden, um zu überprüfen, ob die internen DNS Namen richtig erstellt wurden und ob das Internet erreichbar ist.

```bash
ping -c 3 intern
ping -c 3 1.1.1.1
```

Da man nicht einfach so auf den internen Host Zugriff hat, empfiehlt es sich einen der beiden unteren Befehle einzugeben, um Zugriff auf den internen Host zu bekommen:
::: code-group

```bash [erster Befehl]
ssh -A devops@$(gatewayIp)
# nach erfolgreichem Login:
ssh devops@intern
```

```bash [zweiter Befehl]
ssh -J devops@$(gatewayIp) devops@10.0.1.20
```

:::
Nach erfolgreichem Login können hier ebenfalls ähnliche Befehle ausgeführt werden. Hier sollte allerdings der ping in das Internet scheitern.

```bash
ping -c 3 gateway
ping -c 3 1.1.1.1
```
