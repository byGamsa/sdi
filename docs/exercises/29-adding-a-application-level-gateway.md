# 29. Adding a application level gateway

Diese Aufgabe ist aufbauend auf Aufgabe 28

Diese Aufgabe soll die bereits in Aufgabe 28 erstellten Netzwerke um mehrere Punkte erweitern.
- Es soll eine ``hcloud_primary_ip`` für das Gateway erstellt werden
- Auf dem Gateway soll ein HTTP-Proxy installiert und konfiguriert werden
- Es soll ein Delay eingerichtet werden, sodass der interne Host erst startet, sobald der Proxy läuft
- Der interne Host soll das Gateway als Proxy benutzen und Packages installieren und updaten.

#### Erstellen einer ``hcloud_primary_ip`` für das Gateway
Als ersten Schritt erstellen wir eine ``hcloud_primary_ip`` und verknüpfen sie mit unserem Gateway-Host. Dabei muss darauf geachtet werden, dass die IP-Adresse und der Server im gleichen Netzwerk liegen. Aus diesem Grund legen wir zusätzlich eine neue Variable für die Location fest und ordnen sowohl der ``hcloud_primary_ip`` als auch dem Gateway zu.

::: code-group
```hcl [main.tf]
resource "hcloud_primary_ip" "gateway_ip" { // [!code ++:7]
  name          = "gateway-ip"
  location    = var.location
  type          = "ipv4"
  assignee_type = "server"
  auto_delete   = false 
}

resource "hcloud_server" "gateway" {
  name = "gateway"
  image        =  "debian-13"
  server_type  =  "cx23"
  location   = var.location // [!code ++]
  firewall_ids = [hcloud_firewall.fw.id]
  ssh_keys     = [hcloud_ssh_key.loginUser.id]
  user_data    = local_file.user_data.content
  public_net {
    ipv4 = hcloud_primary_ip.gateway_ip.id // [!code ++]
    ipv6_enabled = true
  }
  network {
    network_id = hcloud_network.privateNet.id 
    ip         = "10.0.1.10"
  }
}
```
```hcl [variable.tf]
variable "loginUser" { // [!code ++:6]
  description = "Standort des Rechenzentrums"
  type = string
  sensitive = true
  default = "nbg1-dc3" # Nürnberg
}
```
:::

#### Installation und Konfiguration eines HTTP-Proxys (``apt-cacher-ng``) auf dem Gateway-Host

In diesem Schritt muss unsere ``tpl/userData.yml`` in zwei separate Dateien aufgeteilt werden, da der Gateway-Server Packete aus dem Internet installieren muss, während der interne Server das noch gar nicht kann. Wenn beide dieselbe Datei nutzen, stürzt der interne Server beim Booten höchstwahrscheinlich ab.

Zuerst wird die Datei ``tpl/userData.yml`` dupliziert und in ``tpl/gateway.yml`` und ``tpl/intern.yml`` umbenannt. Die Anpassung muss dementsprechend auch in der ``main.tf`` erfolgen. Anschließend passen wir die ``tpl/gateway.yml`` Datei an, indem `apt-cacher-ng` installiert und konfiguriert wird. Die ``tpl/intern.yml`` kann vorerst gleich bleiben.

::: code-group
```hcl [main.tf]
resource "hcloud_server" "gateway" {
  name = "gateway"
  image        =  "debian-13"
  server_type  =  "cx23"
  firewall_ids = [hcloud_firewall.fw.id]
  ssh_keys     = [hcloud_ssh_key.loginUser.id]
  user_data    = local_file.gateway_data.content // [!code ++]
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
  user_data    = local_file.intern_data.content // [!code ++]
  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
  network {
    network_id = hcloud_network.privateNet.id
    ip         = "10.0.1.20"
  }
}

resource "local_file" "gateway_data" { // [!code ++:9]
  content = templatefile("tpl/gateway.yml", {
    tls_private_key = indent(4, tls_private_key.host_key.private_key_openssh)
    loginUser = var.loginUser
    sshKey    = chomp(file("~/.ssh/id_ed25519.pub"))
    dnsDomainName = var.privateSubnet.dnsDomainName
  })
  filename = "gen/gateway.yml"
}

resource "local_file" "intern_data" { // [!code ++:9]
  content = templatefile("tpl/intern.yml", {
    tls_private_key = indent(4, tls_private_key.host_key.private_key_openssh)
    loginUser = var.loginUser
    sshKey    = chomp(file("~/.ssh/id_ed25519.pub"))
    dnsDomainName = var.privateSubnet.dnsDomainName
  })
  filename = "gen/intern.yml"
}
```
```yml [tpl/gateway.yml]
#cloud-config
package_update: true // [!code ++:2]
package_upgrade: true

packages: // [!code ++:2]
  - apt-cacher-ng

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
  - path: /etc/apt-cacher-ng/zz_local.conf // [!code ++:4]
    content: |
      BindAddress: 10.0.1.10 # Proxy ist nur über diese IP erreichbar, sodass nur der interne Server ihn erreichen kann
      Port: 3142

runcmd:
  # Host Key wurde geschrieben -> SSH neu starten, damit er aktiv wird
  - systemctl restart ssh
  - systemctl restart apt-cacher-ng // [!code ++]
users:
  - name: ${loginUser}
    groups: sudo
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    shell: /bin/bash
    ssh_authorized_keys:
      - ${sshKey}
```
:::

#### Delay einrichten, sodass der interne Host erst startet, sobald der Proxy läuft

Dies ist besonders wichtig, da der interne Host sonst versuchen würde Packages zu installieren, aber noch gar kein Zugriff auf das Internet haben würde.

Dazu erstellen wir erstmal ein Bash-Skript ``tpl/waitForAptProxy.sh``. Diese Ressourcen werden dann in der `main.tf` angelegt und an den internen Server gegeben.
::: warning
Hier wird vorausgesetzt, dass der ssh-agent aktiviert und der private key darin geladen ist. Falls nicht, helfen dazu folgende Befehle:
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

ssh-add -l # prüfen, ob alles richtig funktioniert
```
:::
::: code-group
```bash [tpl/waitForAptProxy.sh]
#!/bin/bash
echo "Waiting for apt-cacher-ng on ${interface}:3142 ..." #// [!code ++:7]
while ! nc -z ${interface} 3142; do
  sleep 8
  echo "apt-cacher-ng not yet ready ..."
done

echo "apt-cacher-ng service ready"
```
```hcl [main.tf]
resource "local_file" "waitForAptProxy" { // [!code ++:22]
  content = templatefile("tpl/waitForAptProxy.sh", {
    interface = "10.0.1.10"
  })
  filename        = "gen/waitForAptProxy.sh"
  file_permission = "0755"
}

resource "null_resource" "waitForProxy" {
  depends_on = [hcloud_server.gateway]

  connection {
    type  = "ssh"
    user  = var.loginUser
    agent = true
    host  = hcloud_server.gateway.ipv4_address
  }

  provisioner "remote-exec" {
    script = local_file.waitForAptProxy.filename
  }
}
```
```hcl [main.tf]
resource "hcloud_server" "intern" {
  name = "intern"
  image        =  "debian-13"
  server_type  =  "cx23"
  ssh_keys     = [hcloud_ssh_key.loginUser.id]
  user_data    = local_file.intern_data.content
  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
  network {
    network_id = hcloud_network.privateNet.id
    ip         = "10.0.1.20"
  }
  depends_on = [
    hcloud_network_subnet.privateSubnet
    null_resource.waitForProxy // [!code ++]
  ] 
}
```
:::
#### Interner Host soll Gateway als Proxy benutzen und Packages installieren und updaten.

In dieser Aufgabe müssen wir die ``tpl/intern.yml`` anpassen. Es müssen Packet-Updates aktiviert werden und mehrere Packete installiert werden. Außerdem müssen wir alle Downloads über das Gateway umleiten.

::: code-group
```yml [tpl/intern.yml]
#cloud-config
package_update: true #// [!code ++:2]
package_upgrade: true

apt: // [!code ++:2]
  proxy: http://10.0.1.10:3142

packages: // [!code ++:4]
  - htop
  - tree
  - curl

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

users:
  - name: ${loginUser}
    groups: sudo
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    shell: /bin/bash
    ssh_authorized_keys:
      - ${sshKey}
```
:::

#### Testen der Funktionsfähigkeit

Um die Funktionsfähigkeit der Konfiguration sicher zu testen, gibt es mehrere Möglichkeiten. In erster Linie können wir schon direkt nach dem Ausführen von ``terraform apply`` in den Logs überprüfen, ob der interne Server wartet, bis ``apt-cacher-ng`` bereit ist. Dabei ist es wichtig, dass `hcloud_server.intern: Creating...` erst ausgeführt wird, nachdem die Meldung `null_resource.waitForProxy (remote-exec): apt-cacher-ng service ready` bereits aufgetaucht ist. Sollten die Logs wie folgt aussehen, ist es ein sehr gutes Zeichen, dass alles geklappt hat.
```
ull_resource.waitForProxy (remote-exec): apt-cacher-ng not yet ready ...
null_resource.waitForProxy: Still creating... [00m50s elapsed]
null_resource.waitForProxy (remote-exec): apt-cacher-ng not yet ready ...
null_resource.waitForProxy (remote-exec): Connection to 10.0.1.10 3142 port [tcp/*] succeeded!
null_resource.waitForProxy (remote-exec): apt-cacher-ng service ready
null_resource.waitForProxy: Creation complete after 53s [id=877343464653383018]
hcloud_server.intern: Creating...
hcloud_server.intern: Still creating... [00m10s elapsed]
hcloud_server.intern: Still creating... [00m20s elapsed]
```

Um zu überprüfen, ob die feste IP wirklich geklappt hat, können wir uns in die Hetzner Console im Browser einloggen. Hier muss man links auf "Server" drücken und oben im Reiter muss "Primäre IPs" ausgewählt werden. Sollte hier eine IPV4-Adresse mit dem Namen `gateway-ip` existieren, der dem Server `gateway` zugewiesen ist, scheint alles korrekt geklappt zu haben.

Weiterhin können wir prüfen, ob der Proxy wirklich nur intern funktioniert. Dazu können wir in unserem Terminal von außen testen, den Proxy zu erreichen.
```bash
curl http://<Statische-IP-des-Gateways>:3142
```
Dieser Befehl muss fehlschlagen (z.B. Timeout oder "Connection refused"). Anschließend kann man sich auf dem Gateway einloggen (mit dem ``bin/ssh``-Skript). Hier kann folgender Befehl ausgeführt werden:
```bash
sudo ss -tulpn | grep 3142
```
Hier sollte `10.0.1.10:3142` als lokale Adresse angezeigt werden. 

Zuletzt sollte noch geprüft werden, ob der interne Server über den Proxy an das Internet kommt, um Pakete zu laden. Dafür loggen wir uns auf den internen Server ein:
```bash
ssh -J devops@<Statische-IP-des-Gateways> devops@10.0.1.20
```
Anschließend kann überprüft werden, ob die Packete erfolgreich installiert wurden (z.B. Eingabe von ``tree`` in die shell)`. Sollte sich die Anwendung öffnen, scheint auch diese Aufgabe korrekt gelöst worden zu sein.