# Solving the `~/.ssh/known_hosts` quirk
Diese Dokumentation beschreibt die Implementierung von Hilfsskripten, um die Nachricht: ` WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!` zu vermeiden

Dazu müssen wir zu Beginn zwei Skripte im Ordner `tpl` erstellen. 

::: code-group
```bash [ssh.sh]
#!/usr/bin/env bash

GEN_DIR=$(dirname "$0")/../gen

ssh -o UserKnownHostsFile="$GEN_DIR/known_hosts" ${devopsUsername}@${ip} "$@"
```
```bash [scp.sh]
#!/usr/bin/env bash

GEN_DIR=$(dirname "$0")/../gen

if [ $# -lt 2 ]; then
   echo usage: .../bin/scp ${devopsUsername}@${ip} ...
else
   scp -o UserKnownHostsFile="$GEN_DIR/known_hosts" $@
fi
```
:::

Jetzt muss ein Schlüssel erstellt werden, auf den wir zugreifen können. Zudem muss ein eigenes known_hosts File erstellt werden, in das direkt der User, die IP und der zugehörige Public-Key eingetragen wird. Dieses soll im Ordner `gen` stehen.

::: code-group
```hcl [main.tf]
resource "tls_private_key" "host_key" { // [!code ++]
  algorithm = "ED25519" // [!code ++]
} // [!code ++]

resource "local_file" "known_hosts" { // [!code ++]
  content = join(" " // [!code ++]
    ,[ hcloud_server.helloServer.ipv4_address // [!code ++]
    , tls_private_key.host_key.public_key_openssh ] // [!code ++]
  ) // [!code ++]
  filename        = "gen/known_hosts" // [!code ++]
  file_permission = "644"// [!code ++]
} // [!code ++]

```
:::

Außerdem müssen wir aus den Templates ausführbare Files generieren. Diese sollen in den Ordner `bin` landen. Wir fügen dazu diesen Code ein (der Username wurde ebenfalls als Variable ausgelagert, muss man in diesem Fall ebenfalls anpassen):

::: code-group
```hcl [main.tf]
resource "local_file" "ssh_script" { //[!code ++]
  content = templatefile("${path.module}/tpl/ssh.sh", {// [!code ++]
    devopsUsername = var.loginUser, //[!code ++]
    ip = hcloud_server.helloServer.ipv4_address //[!code ++]
  }) //[!code ++]
  filename        = "bin/ssh" //[!code ++]
  file_permission = "755"//[!code ++]
}//[!code ++]

resource "local_file" "scp_script" { //[!code ++]
  content = templatefile("${path.module}/tpl/scp.sh", { //[!code ++]
    devopsUsername = var.loginUser, //[!code ++]
    ip = hcloud_server.helloServer.ipv4_address //[!code ++]
  }) // [!code ++]
  filename        = "bin/scp" //[!code ++]
  file_permission = "755" //[!code ++]
} //[!code ++]
```
:::

Zuletzt muss der private-key der `userData.yml` hinzugefügt werden, sodass der Server den Key erhält.
::: code-group
```hcl [main.tf]
resource "local_file" "user_data" {
  content = templatefile("tpl/userData.yml", {
    loginUser = var.loginUser
    sshKey    = chomp(file("~/.ssh/id_ed25519.pub"))
    tls_private_key = indent(4, tls_private_key.host_key.private_key_openssh) //[!code ++]
  })
  
  filename = "gen/userData.yml"
}
```
```yaml [tpl/userData.yaml]
#cloud-config
package_update: true
package_upgrade: true

packages:
  - nginx

ssh_pwauth: false
disable_root: true

ssh_keys:  //[!code ++]
  ed25519_private: |  //[!code ++]
    ${tls_private_key}   
    
ssh_pwauth: false

runcmd:
  - systemctl restart ssh
  - systemctl start nginx
  - systemctl enable nginx

users:
  - name: ${loginUser}
    groups: sudo
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    shell: /bin/bash
    ssh_authorized_keys:
      - ${sshKey}
```
:::

Wenn jetzt nach `terraform apply` die Files erstellt wurden, kann man `./bin/ssh` ausführen. Das Problem sollte somit behoben sein.

Zudem kann das andere File ausgeführt werden, um Files zu kopieren. Ein Beispielaufruf des Files sollte so aussehen (IP, Name, Pfade müssen angepasst werden): `./bin/scp test.txt  devops@65.21.251.129:/home/devops`