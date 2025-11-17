# 14. Automatic Nginx installation
This documentation describes the implementation of an automated Nginx installation using Terraform and Cloud-Init.

## Solution Overview
The solution uses Terraform in combination with Cloud-Init to fully automate a Debian server setup. Not only is Nginx installed, but security measures and system configurations are also implemented.

## Architecture
### Components

1. Terraform Configuration - Defines the infrastructure
2. Cloud-Init Template - Configures the server after boot
3. Firewall Rules - Secures the server
4. SSH Key Management - Enables secure access

## Implementation

Für folgende Aufgabe verwenden wir die Codebasis welche in Aufgabe 13 bereits aufgesetzt wurde

### 1. Creating the Initialization Script

Zu allererst muss eine Bash Datei mit beispielsweise dem Namen init.sh erstellt werde, welche die nötigen Commands enthält

::: code-group
```bash [init.sh]
#!/bin/bash

# System aktualisieren
apt update && apt upgrade -y

# Nginx installieren
apt install -y nginx

# Nginx Service managen
systemctl start nginx
systemctl enable nginx
```
:::

### 2. Configuring the Server Resource

Als nächstes muss die Server Ressource "hcloud_server" in der main.tf Datei wie folgt angepasst werden, damit diese unsere zuvor erstellte init.sh ausführt. Dafür verwenden wir das user_data Attribut

```hcl [main.tf]
resource "hcloud_server" "web_server" {
  name         = "hello"
  image        =  "debian-13"
  server_type  =  "cx23"
  firewall_ids = [hcloud_firewall.sshFw.id]
  ssh_keys     = [hcloud_ssh_key.loginUser.id]
  user_data    = file("init.sh") // [!code ++]
}
```

### 3. Granting SSH Access

Um auf die Nginx Webseite zugreifen zu können muss eine neue Firewallregel aufgestellt werden welche den Port 80 zulässt. Dafür erstellen wir eine neue Ressource hcloud_firewall

```hcl
resource "hcloud_firewall" "httpFw" {
  name = "firewall-2"
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}
```

Diese Firewall Ressource muss anschließend in der Server Ressource referenziert werden, dafür tauschen wir die alte Defintion für das Attribut firewall_ids mit unserer neuen Firewall Ressource aus.

```hcl
  resource "hcloud_server" "helloServer" {
  name         = "hello"
  image        =  "debian-13"
  server_type  =  "cx23"
  firewall_ids = [hcloud_firewall.sshFw.id] // [!code --]
  firewall_ids = [hcloud_firewall.httpFw.id] // [!code ++]
  ssh_keys     = [hcloud_ssh_key.loginUser.id]
  user_data    = file("init.sh")
}
```

## Verification

Nach dem wir erfolgreich deployed haben lässt sich das Ergebnis verifizieren in dem wir folgenden Befehl ausführen.

```bash
  curl http://$(terraform output -raw ip_addr)
```

Als Resultat solltest du den HTML Quellcode der Nginx Website sehen

```html
  <!DOCTYPE html>
  <html>
  <head>
  <title>Welcome to nginx!</title>
  <style>
  html { color-scheme: light dark; }
  body { width: 35em; margin: 0 auto;
  font-family: Tahoma, Verdana, Arial, sans-serif; }
  </style>
  </head>
  <body>
  <h1>Welcome to nginx!</h1>
  <p>If you see this page, the nginx web server is successfully installed and
  working. Further configuration is required.</p>

  <p>For online documentation and support please refer to
  <a href="http://nginx.org/">nginx.org</a>.<br/>
  Commercial support is available at
  <a href="http://nginx.com/">nginx.com</a>.</p>
 
  <p><em>Thank you for using nginx.</em></p>
  </body>
  </html>
```