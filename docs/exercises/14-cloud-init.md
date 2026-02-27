# 14. Automatische Nginx-Installation

Originale Aufgabenstellung: [Lecture Notes](https://freedocs.mi.hdm-stuttgart.de/sdi_cloudProvider_cloudInit.html#sdi_cloudProvider_cloudInit_qanda_NginxByBash)

In dieser Übung wird ein Webserver (Nginx) automatisch bei der Servererstellung installiert. Anstatt den Server manuell nach der Erstellung zu konfigurieren, nutzen wir Cloud-Init, ein Initialisierungstool, das beim ersten Bootvorgang ein Shell-Script ausführt und so den Server vollautomatisch einrichtet.

## Architektur-Komponenten

| Komponente                        | Beschreibung                                                      |
| --------------------------------- | ----------------------------------------------------------------- |
| **Terraform Konfiguration**       | Definiert die Infrastruktur und übergibt das Init-Script          |
| **Cloud-Init Script (`init.sh`)** | Shell-Script, das beim ersten Boot Nginx installiert und startet  |
| **HTTP Firewall**                 | Neue Firewallregel für Port 80, damit die Webseite erreichbar ist |
| **SSH Key Management**            | Ermöglicht sicheren Zugriff auf den Server                        |

## Codebasis

Diese Aufgabe baut auf der Infrastruktur aus [Aufgabe 13](/exercises/13-incrementally-creating-a-base-system) auf. Der dort erstellte Server mit Firewall und SSH-Key wird hier um Cloud-Init erweitert.

## Übungsschritte

### 1. Initialisierungsskript erstellen

Der erste Schritt ist die Erstellung eines Bash-Scripts, das die nötigen Befehle für die Nginx-Installation enthält. Dieses Script wird später beim ersten Serverstart automatisch ausgeführt.

Erstelle eine Datei `init.sh` im Projektverzeichnis:

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

### 2. Server-Ressource anpassen

Als nächstes muss die Server-Ressource `hcloud_server` in der `main.tf` Datei angepasst werden. Über das `user_data` Attribut wird das zuvor erstellte Init-Script an den Server übergeben. Hetzner Cloud übergibt den Inhalt dieses Feldes an Cloud-Init, das es beim ersten Boot ausführt.

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

Die Terraform-Funktion `file("init.sh")` liest den Inhalt der Datei und übergibt ihn als String an die Ressource.

::: info
Cloud-Init wird nur beim **ersten Start** des Servers ausgeführt. Wenn du Änderungen am Script vornimmst, musst du den Server zerstören und neu erstellen (`terraform destroy` + `terraform apply`), damit die Änderungen wirksam werden.
:::

### 3. HTTP-Zugriff per Firewall erlauben

Der Nginx Webserver lauscht standardmäßig auf Port 80 (HTTP). Da unsere bestehende Firewall nur Port 22 (SSH) erlaubt, müssen wir eine neue Firewallregel für HTTP-Verkehr erstellen. Ohne diese Regel wäre die Webseite von außen nicht erreichbar.

Erstelle eine neue Firewall-Ressource:

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

Diese Firewall-Ressource muss anschließend in der Server-Ressource referenziert werden. Dafür tauschen wir die alte Definition für das Attribut `firewall_ids` mit unserer neuen Firewall-Ressource aus:

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

### 4. Ergebnis überprüfen

Nach dem erfolgreichen Deploy mit `terraform apply` lässt sich das Ergebnis verifizieren. Der folgende Befehl fragt die IP-Adresse über Terraform ab und sendet einen HTTP-Request an den Webserver:

```bash
  curl http://$(terraform output -raw ip_addr)
```

Als Resultat sollte der HTML-Quellcode der Nginx-Willkommensseite erscheinen:

```html
<!DOCTYPE html>
<html>
  <head>
    <title>Welcome to nginx!</title>
    <style>
      html {
        color-scheme: light dark;
      }
      body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
      }
    </style>
  </head>
  <body>
    <h1>Welcome to nginx!</h1>
    <p>
      If you see this page, the nginx web server is successfully installed and working. Further
      configuration is required.
    </p>

    <p>
      For online documentation and support please refer to
      <a href="http://nginx.org/">nginx.org</a>.<br />
      Commercial support is available at
      <a href="http://nginx.com/">nginx.com</a>.
    </p>

    <p><em>Thank you for using nginx.</em></p>
  </body>
</html>
```
