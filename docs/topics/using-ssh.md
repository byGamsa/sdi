# SSH verwenden

SSH (Secure Shell) ist ein Netzwerkprotokoll für die verschlüsselte Kommunikation zwischen zwei Rechnern. Es wird vor allem für den sicheren Fernzugriff auf Server verwendet und ist das wichtigste Werkzeug in der täglichen Arbeit mit Cloud-Infrastruktur.

## Grundlagen

### Verbindung herstellen

Die einfachste Form einer SSH-Verbindung nutzt Benutzername und Passwort:

```bash
ssh root@DEINE_SERVER_IP
```

Beim ersten Verbindungsaufbau prüft SSH die Identität des Servers anhand seines Host Keys. SSH speichert diesen in `~/.ssh/known_hosts`, um bei zukünftigen Verbindungen sicherzustellen, dass man sich mit dem richtigen Server verbindet.

### Passwort vs. SSH-Keys

Passwortbasierte Logins sind anfällig für Brute-Force-Angriffe. Die sicherere Alternative ist die Authentifizierung mit einem Public/Private Key Pair.

## SSH Key Pair erstellen

Ein SSH Key Pair besteht aus zwei Dateien:

- **Private Key** (`~/.ssh/id_ed25519`): geheim halten, niemals teilen
- **Public Key** (`~/.ssh/id_ed25519.pub`): kann frei weitergegeben werden (z.B. an Server, GitHub, GitLab)

Der Private Key kann nicht aus dem Public Key abgeleitet werden.

### Key generieren

```bash
ssh-keygen -t ed25519 -C "deine@email.de"
```

Dabei wird man nach einem Speicherort (Standard: `~/.ssh/id_ed25519`) und einer **Passphrase** gefragt.

::: tip Passphrase
Eine gute Passphrase sollte mindestens 15-20 Zeichen lang sein und Groß-/Kleinbuchstaben, Zahlen und Sonderzeichen enthalten. Sie schützt den Private Key, falls jemand Zugriff auf die Datei erhält.
:::

### Key auf den Server kopieren

Um sich per Key am Server anzumelden, muss der Public Key dort hinterlegt werden:

```bash
ssh-copy-id root@DEINE_SERVER_IP
```

Alternativ auf dem Server manuell den Inhalt von `~/.ssh/id_ed25519.pub` in `~/.ssh/authorized_keys` einfügen.

Danach kann man sich ohne Passwort verbinden:

```bash
ssh root@DEINE_SERVER_IP
```

### Keys überprüfen

```bash
# Vorhandene Keys auflisten
ls ~/.ssh/id_ed25519*

# Fingerprint anzeigen
ssh-keygen -l -f ~/.ssh/id_ed25519.pub
```

## SSH Agent

### Das Problem: Ständige Passphrase-Eingabe

Mit Passphrase-geschützten Keys muss man bei jeder SSH-Verbindung die Passphrase erneut eingeben. Bei mehreren Verbindungen pro Session wird das schnell lästig:

```bash
ssh root@server1    # Passphrase eingeben
ssh root@server2    # Passphrase erneut eingeben
```

### Die Lösung: ssh-agent

Der `ssh-agent` ist ein Hintergrundprozess, der Private Keys im Arbeitsspeicher cached. Man gibt die Passphrase nur einmal pro Session ein:

```bash
# Agent starten (falls nicht automatisch aktiv)
eval $(ssh-agent)

# Key zum Agent hinzufügen
ssh-add ~/.ssh/id_ed25519
# Passphrase wird einmalig abgefragt

# Geladene Keys anzeigen
ssh-add -l
```

Danach funktionieren alle SSH-Verbindungen ohne erneute Passphrase-Eingabe:

```bash
ssh root@server1    # Keine Passphrase nötig
ssh root@server2    # Keine Passphrase nötig
```

::: tip
Prüfe, ob der ssh-agent läuft:

```bash
printenv | grep SSH_AUTH_SOCK
```

Wenn eine Ausgabe wie `SSH_AUTH_SOCK=/run/user/.../ssh` erscheint, ist der Agent aktiv.
:::

## Agent Forwarding

### Das Problem: Zugriff von entfernten Servern

Man ist per SSH auf Server A eingeloggt und möchte von dort aus per SSH auf Server B zugreifen, ohne den Private Key auf Server A ablegen zu müssen:

```text
Lokal → Server A → Server B
                    ✗ Kein Zugriff (kein Key auf Server A)
```

### Die Lösung

Agent Forwarding leitet die Authentifizierung über den lokalen ssh-agent weiter:

```bash
# Mit Agent Forwarding verbinden
ssh -A root@SERVER_A

# Von Server A aus weiter zu Server B (nutzt lokalen Agent)
ssh root@SERVER_B    # Funktioniert!
```

Die `-A` Flag aktiviert das Forwarding. Man kann dies auch dauerhaft in der SSH Config setzen:

```ssh
Host server_a
    HostName DEINE_SERVER_IP
    User root
    ForwardAgent yes
```

::: warning Sicherheitshinweis
Agent Forwarding sollte nur bei vertrauenswürdigen Servern aktiviert werden. Ein kompromittierter Zwischenhost könnte den weitergeleiteten Agent missbrauchen.
:::

## SSH Config

Die Datei `~/.ssh/config` ermöglicht es, häufig genutzte Verbindungen als Shortcuts zu definieren:

```ssh
Host meinserver
    HostName 95.216.187.60
    User root
    Port 22
    IdentityFile ~/.ssh/id_ed25519

Host gitlab
    HostName gitlab.mi.hdm-stuttgart.de
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes

Host interner-server
    HostName 10.0.5.10
    ProxyJump meinserver
```

Danach reicht:

```bash
ssh meinserver        # statt ssh root@95.216.187.60
ssh interner-server   # springt automatisch über meinserver
```

## Port Forwarding (SSH Tunnel)

Port Forwarding ermöglicht es, Dienste auf einem entfernten Server über einen SSH-Tunnel lokal zugänglich zu machen, auch wenn diese Dienste durch eine Firewall blockiert sind.

### Local Port Forwarding

```bash
ssh -L 2000:localhost:80 root@DEINE_SERVER_IP
```

Dieser Befehl leitet den Port 80 des Remote-Servers auf den lokalen Port 2000 weiter. Man kann danach im Browser `http://localhost:2000` öffnen und den Nginx-Server sehen, obwohl Port 80 in der Firewall gesperrt ist.

**Syntax**: `ssh -L LOKAL:ZIEL:REMOTE user@host`

### Anwendungsbeispiele

- Zugriff auf eine Datenbank hinter einer Firewall
- Testen von Webservern ohne offene Ports
- Sicherer Zugriff auf Admin-Panels

## X11 Forwarding

X11 Forwarding ermöglicht es, grafische Anwendungen auf einem Remote-Server auszuführen und das Fenster lokal anzuzeigen.

### Voraussetzungen

- Auf dem Server muss `xauth` installiert sein: `apt install xauth`
- Lokal muss ein X11 Server laufen (Linux: Standard, macOS: XQuartz)

### Verbindung mit X11 Forwarding

```bash
ssh -Y root@DEINE_SERVER_IP
```

Auf dem Server kann man dann z.B. einen Browser starten:

```bash
apt install firefox-esr
firefox-esr &
```

Das Firefox-Fenster erscheint auf dem lokalen Desktop, obwohl der Browser auf dem Server läuft.

## Dateitransfer

### SCP (Secure Copy)

```bash
# Datei zum Server kopieren
scp datei.txt root@SERVER:/pfad/

# Datei vom Server herunterladen
scp root@SERVER:/pfad/datei.txt ./

# Verzeichnis rekursiv kopieren
scp -r verzeichnis/ root@SERVER:/pfad/
```

### Rsync über SSH

`rsync` ist effizienter als `scp`, da nur geänderte Dateien übertragen werden:

```bash
rsync -avz -e ssh ./lokaler_ordner/ root@SERVER:/remote/pfad/
```

## Weiterführende Links

- [Lecture Notes: Public/Private Key Pair](https://freedocs.mi.hdm-stuttgart.de/sdiSshBase.html)
- [Lecture Notes: SSH Agent](https://freedocs.mi.hdm-stuttgart.de/sdiSshAgent.html)
- [Lecture Notes: Agent Forwarding](https://freedocs.mi.hdm-stuttgart.de/sdiSshAgentForwarding.html)
- [Lecture Notes: Port Forwarding](https://freedocs.mi.hdm-stuttgart.de/sdiSshPortForward.html)
- [Lecture Notes: X11 Forwarding](https://freedocs.mi.hdm-stuttgart.de/sdiSshX11Forward.html)
- [Lecture Notes: Datentransfer mit rsync](https://freedocs.mi.hdm-stuttgart.de/sshDataTransfer.html)
