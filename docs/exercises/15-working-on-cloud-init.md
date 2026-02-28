# 15. Cloud-Init erweitern

Originale Aufgabenstellung: [Lecture Notes](https://freedocs.mi.hdm-stuttgart.de/sdi_cloudProvider_cloudInit.html#sdi_cloudProvider_cloudInit_qanda_gettingStarted)

In dieser Übung wird die bestehende Server-Konfiguration schrittweise zu einer robusten Cloud-Init-basierten Lösung ausgebaut. Anstelle eines einfachen Shell-Scripts wird ein flexibles YAML-Template eingeführt, das über Terraform-Variablen gesteuert wird. Damit lassen sich Benutzerverwaltung, SSH-Sicherheit und Paketinstallation deklarativ und wiederholbar konfigurieren.

## Codebasis

Diese Aufgabe baut auf der Infrastruktur aus [Aufgabe 14](/exercises/14-cloud-init) auf. Der dort erstellte Server mit Nginx-Init-Script wird hier auf ein flexibles Cloud-Init Template umgestellt.

## Übungsschritte

### 1. Firewall um SSH-Zugriff erweitern

In der vorherigen Aufgabe haben wir nur eine HTTP-Firewall (Port 80) verwendet. Für die Verwaltung des Servers benötigen wir aber auch SSH-Zugriff (Port 22). Deshalb erstellen wir eine kombinierte Firewall, die beide Ports erlaubt.

Dafür wird die bisherige Firewall-Ressource umbenannt und um eine zweite Regel erweitert:

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

Da die Firewall-Ressource umbenannt wurde (von `httpFw` zu `fw`), muss auch die Referenz in der Server-Ressource aktualisiert werden:

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

### 2. Von Shell-Script auf Cloud-Init Template umsteigen

Die bisherige Lösung nutzte eine einfache Bash-Datei:

```hcl
user_data = file("init.sh")
```

Diese Methode hat mehrere Nachteile:

- **Keine Variablen**: Alle Werte müssen hartcodiert werden
- **Schwer erweiterbar**: Komplexe Konfigurationen werden schnell unübersichtlich
- **Nicht deklarativ**: Shell-Scripts sind imperativ, Cloud-Init ist deklarativ

Stattdessen verwenden wir ein Cloud-Init YAML-Template, das über `templatefile()` dynamisch erzeugt wird. Diese Terraform-Funktion ersetzt Platzhalter (`${variable}`) im Template durch die übergebenen Werte.

Erstelle eine Vorlage unter `tpl/userData.yml` und passe die `main.tf` entsprechend an:

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

Die `local_file` Ressource rendert das Template und schreibt das Ergebnis nach `gen/userData.yml`. Das hat den Vorteil, dass man die generierte Datei inspizieren und debuggen kann.

### Überprüfung

Nach `terraform apply` kann das Setup mit folgenden Befehlen überprüft werden:

| Befehl                      | Erwartetes Ergebnis                         |
| --------------------------- | ------------------------------------------- |
| `ssh root@<SERVER_IP>`      | Zugriff sollte **verweigert** werden        |
| `ssh -v devops@<SERVER_IP>` | SSH-Zugriff als `devops` Benutzer           |
| `journalctl -f`             | Cloud-Init Logs anzeigen                    |
| `apt list --upgradable`     | Sollte leer sein (alle Updates installiert) |
| `systemctl status nginx`    | Nginx sollte aktiv sein                     |

### 3. Cloud-Init Konfiguration erweitern

Die Cloud-Init Konfiguration kann beliebig erweitert werden. Im Folgenden fügen wir drei nützliche Erweiterungen hinzu:

#### 3.1 System-Upgrade sicherstellen

Die Provider-Abbilder von Hetzner führen kein vollständiges Upgrade aus. Über Cloud-Init können wir sicherstellen, dass alle Pakete beim ersten Boot aktualisiert werden:

```hcl
package_update: true
package_upgrade: true
```

#### 3.2 Fail2Ban installieren

Fail2Ban schützt den Server vor SSH-Bruteforce-Angriffen, indem es IP-Adressen nach mehreren fehlgeschlagenen Login-Versuchen automatisch sperrt:

```hcl
packages:
  - fail2ban// [!code ++]
```

#### 3.3 Plocate installieren

Plocate ermöglicht eine schnelle Dateisuche auf dem Server. Nach der Installation muss die Datenbank einmalig aufgebaut werden:

```hcl
packages:
  - plocate// [!code ++]
runcmd:
  - updatedb// [!code ++]
```
