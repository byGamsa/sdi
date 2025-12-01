# 15. Working on Cloud-init
This documentation describes the implementation of an incrementally build robust server configuration using Cloud-Init.

## Solution Overview
...

## Architecture
### Components

1. Terraform Configuration - Defines the infrastructure
2. Cloud-Init Template - Configures the server after boot
3. Firewall Rules - Secures the server
4. SSH Key Management - Enables secure access

## Implementation

Für folgende Aufgabe verwenden wir die Codebasis welche in Aufgabe 14 bereits aufgesetzt wurde

### 1. Creating a Simple Web Server

Zu allererst muss die aktuelle firewall configuration erweitert werden damit diese inbound traffic für port 22 zulässt

```hcl
resource "hcloud_firewall" "fw" { // [!code ++]
resource "hcloud_firewall" "httpFw" { // [!code --]
  name = "firewall-2" 
  rule { 
    direction = "in" 
    protocol  = "tcp" 
    port      = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  } // [!code ++]
  rule { // [!code ++]
    direction = "in" // [!code ++]
    protocol  = "tcp" // [!code ++]
    port      = "22" // [!code ++]
    source_ips = ["0.0.0.0/0", "::/0"] // [!code ++]
  } // [!code ++]
}
```

Diese Firewall Ressource muss anschließend in der Server Ressource referenziert werden, dafür tauschen wir die alte Defintion für das Attribut firewall_ids mit unserer neuen Firewall Ressource aus.

```hcl
  resource "hcloud_server" "helloServer" {
  name         = "hello"
  image        =  "debian-13"
  server_type  =  "cx23"
  firewall_ids = [hcloud_firewall.sshFw.id] // [!code --]
  firewall_ids = [hcloud_firewall.fw.id] // [!code ++]
  ssh_keys     = [hcloud_ssh_key.loginUser.id]
  user_data    = file("init.sh")
}
```

### 2. Modify our current Cloud-init configuration

Die bisherige Lösung nutzte eine einfache Datei:

```hcl
user_data = file("init.sh")
```

Diese Methode ist unflexibel, schwer zu erweitern und lässt keine Variablen zu.Stattdessen soll ein Cloud-Init YAML Template verwendet werden, das über templatefile() dynamisch erzeugt wird.

Wir erstellen zunächst eine Vorlage unter tpl/userData.yml. Sie enthält Cloud-Init Anweisungen und Variablen, die Terraform füllt. Außerdem 

::: code-group
```hcl [main.tf]
resource "hcloud_server" "helloServer" {
  name         = "hello"
  image        =  "debian-13"
  server_type  =  "cx23"
  firewall_ids = [hcloud_firewall.fw.id]
  ssh_keys     = [hcloud_ssh_key.loginUser.id]
  user_data    = file("init.sh") // [!code --]
  user_data    = local_file.user_data.content // [!code ++]
}

resource "local_file" "user_data" { // [!code ++]
  content = templatefile("tpl/userData.yml", { // [!code ++]
    loginUser = "devops" // [!code ++]
    sshKey    = chomp(file("~/.ssh/id_rsa.pub")) // [!code ++]
  }) // [!code ++]
  filename = "gen/userData.yml" // [!code ++]
} // [!code ++]
```


```yaml [tpl/userData.yml]
#cloud-config

package_update: true
package_upgrade: true

# Nginx installieren und starten
packages:
  - nginx

runcmd:
  - systemctl start nginx
  - systemctl enable nginx

ssh_pwauth: false           # Passwort-Login deaktivieren
disable_root: true          # Root-Login deaktivieren

users:
  - name: ${loginUser}
    groups: sudo
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    shell: /bin/bash
    ssh_authorized_keys:
      - ${sshKey}

package_update: true
package_upgrade: true
``` 
::: 

This complete `userData.yml` configuration includes:

- **User Management**: Creates a new user with sudo privileges and SSH key access
- **SSH Security**: Disables password authentication and root login
- **Package Management**: Updates and upgrades all packages
- **Web Server**: Installs and configures Nginx with a custom welcome page 

You can verify the setup by checking:

- `ssh root@95.217.154.104` - for prohibited root access
- `ssh -v devops@95.217.154.104` - for ssh access to another user
- `journalctl -f` - for logs
- `apt list --upgradable` - should be empty after updates
- `systemctl status nginx` - for Nginx status

### 3. Extend Cloud-init configuration

#### 3.1 System-Upgrade sicherstellen

Provider-Abbilder führen kein vollständiges Upgrade aus.Cloud-Init übernimmt dies mit:

package_update: true
package_upgrade: true

#### 3.2 Fail2Ban installieren

Schutz vor SSH-Bruteforce-Angriffen:

packages:
  - fail2ban

#### 3.3 Plocate installieren

Schnelle Dateisuche:

packages:
  - plocate
runcmd:
  - updatedb

Die Finale template Datei sollte also aussehen wie folgt:

