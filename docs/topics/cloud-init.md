# Cloud-init

[Cloud-init](https://cloudinit.readthedocs.io/en/latest/) ist ein Industriestandard zur automatischen Initialisierung von Cloud-Instanzen beim ersten Start. Es ermöglicht, Server direkt bei der Erstellung zu konfigurieren: Pakete installieren, Benutzer anlegen, Dateien erstellen und Befehle ausführen.

## Was ist Cloud-init?

Wenn ein Cloud-Server erstellt wird, ist er zunächst nur ein nacktes Betriebssystem. Cloud-init wird beim ersten Boot automatisch ausgeführt und konfiguriert den Server anhand von sogenannten **User Data**, die bei der Erstellung mitgegeben werden.

### Typische Aufgaben

- Pakete installieren und aktualisieren
- Benutzer und Gruppen anlegen
- SSH-Keys hinterlegen
- Dateien erstellen oder bearbeiten
- Befehle ausführen
- SSH-Server konfigurieren
- Volumes mounten

## User Data Formate

Cloud-init akzeptiert verschiedene Formate als User Data. Die zwei wichtigsten:

### 1. Shell-Script

Ein einfaches Shell-Script, das beim ersten Boot ausgeführt wird:

```bash
#!/bin/bash
apt update && apt upgrade -y
apt install -y nginx
systemctl start nginx
systemctl enable nginx
```

### 2. Cloud-Config (YAML)

Das Format `#cloud-config` ist der bevorzugte Ansatz und bietet deutlich mehr Möglichkeiten:

```yaml
#cloud-config
package_update: true
package_upgrade: true

packages:
  - nginx
  - fail2ban

runcmd:
  - systemctl enable nginx
  - systemctl start nginx
```

::: tip
`#cloud-config` muss immer die erste Zeile der Datei sein.
:::

## Cloud-Config Module

Cloud-init stellt verschiedene Module bereit, die jeweils eine bestimmte Konfigurationsaufgabe übernehmen.

### packages

Pakete installieren:

```yaml
package_update: true
package_upgrade: true
package_reboot_if_required: true

packages:
  - nginx
  - fail2ban
  - git
```

- `package_update`: Führt `apt update` aus
- `package_upgrade`: Führt `apt upgrade` aus
- `package_reboot_if_required`: Neustart falls nötig (z.B. nach Kernel-Update)

### users

Benutzer anlegen und SSH-Keys hinterlegen:

```yaml
users:
  - name: devops
    groups: [sudo]
    shell: /bin/bash
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3... user@example.com
```

### write_files

Dateien auf dem Server erstellen:

```yaml
write_files:
  - path: /etc/motd
    permissions: "0644"
    content: |
      Willkommen auf diesem Server!
      Konfiguriert mit Cloud-init.
```

### runcmd

Beliebige Befehle am Ende des Boot-Prozesses ausführen:

```yaml
runcmd:
  - systemctl enable nginx
  - systemctl start nginx
  - echo "Setup abgeschlossen" > /var/log/setup.log
```

### ssh_keys

SSH Host Keys des Servers setzen:

```yaml
ssh_keys:
  ed25519_private: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    ...
    -----END OPENSSH PRIVATE KEY-----
```

### ssh_pwauth

Passwort-Authentifizierung für SSH deaktivieren:

```yaml
ssh_pwauth: false
```

## Integration mit Terraform

Cloud-init wird in Terraform über das `user_data` Attribut an den Server übergeben.

### Mit Shell-Script

```hcl
resource "hcloud_server" "web" {
  name        = "web-server"
  image       = "debian-12"
  server_type = "cx22"
  user_data   = file("init.sh")
}
```

### Mit Cloud-Config

```hcl
resource "hcloud_server" "web" {
  name        = "web-server"
  image       = "debian-12"
  server_type = "cx22"
  user_data   = file("cloud-init.yml")
}
```

### Mit Template-Variablen

Terraform kann Variablen in Cloud-Config-Templates einsetzen:

```hcl
resource "hcloud_server" "web" {
  name        = "web-server"
  image       = "debian-12"
  server_type = "cx22"
  user_data   = templatefile("tpl/userData.yml", {
    login_user = var.login_user
    public_key = var.ssh_public_key
  })
}
```

```yaml
#cloud-config
users:
  - name: ${login_user}
    groups: [sudo]
    shell: /bin/bash
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    ssh_authorized_keys:
      - ${public_key}
```

::: warning Wichtig
Änderungen an `user_data` erfordern eine Neuerstellung des Servers (`terraform destroy` + `terraform apply`), da Cloud-init nur beim ersten Boot ausgeführt wird.
:::

## Boot-Phasen

Cloud-init durchläuft mehrere Phasen beim Start:

1. **Network**: Netzwerkkonfiguration
2. **Config**: Hauptkonfiguration (Benutzer, Pakete, Dateien)
3. **Final**: Abschlussbefehle (`runcmd`)

Die Reihenfolge ist wichtig: z.B. muss das Netzwerk verfügbar sein, bevor Pakete heruntergeladen werden.

## Debugging und Troubleshooting

### Log-Dateien

Cloud-init protokolliert alle Aktionen. Die wichtigsten Logs:

```bash
# Hauptlog
cat /var/log/cloud-init.log

# Ausgabe der Befehle
cat /var/log/cloud-init-output.log
```

### Konfiguration validieren

```bash
# User Data auf dem Server prüfen
cloud-init schema --config-file /var/lib/cloud/instance/user-data.txt

# System-Konfiguration validieren
cloud-init schema --system --annotate
```

### Häufige Fehlerquellen

- **YAML-Syntax Fehler**: Einrückung muss konsistent sein (Leerzeichen, keine Tabs)
- **Falsche Paketnamen**: Paketnamen variieren je nach Distribution
- **Netzwerkprobleme**: Pakete können nicht installiert werden, wenn kein Netzwerk verfügbar ist
- **SSH-Key Format**: Keys müssen im korrekten Format vorliegen
- **Berechtigungen**: Verzeichnisse müssen existieren, bevor Dateien geschrieben werden

## Weiterführende Links

- [Cloud-init Dokumentation](https://cloudinit.readthedocs.io/en/latest/)
- [Cloud-init Module Referenz](https://cloudinit.readthedocs.io/en/latest/reference/modules.html)
- [Debugging Cloud-init](https://cloudinit.readthedocs.io/en/latest/howto/debugging.html)
- [Lecture Notes: Cloud-init](https://freedocs.mi.hdm-stuttgart.de/sdi_cloudProvider_cloudInit.html)
