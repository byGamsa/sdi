# Hetzner Cloud GUI

[Hetzner Cloud](https://www.hetzner.com/cloud/) ist ein deutscher Cloud-Anbieter, der virtuelle Server (VPS), Volumes, Firewalls und weitere Cloud-Dienste anbietet. In diesem Kurs nutzen wir die Hetzner Cloud Console, um Server zu erstellen und zu verwalten.

## Account erstellen

1. Registriere dich unter [https://accounts.hetzner.com/signUp](https://accounts.hetzner.com/signUp).
2. Schließe den Verifizierungsprozess ab (ID-Verifizierung und Zahlungsmethode können erforderlich sein).
3. Aktiviere die Zwei-Faktor-Authentifizierung (2FA) für erhöhte Sicherheit.

::: tip Tipp für HdM-Studierende
Im Rahmen der Vorlesung werden Hetzner-Projekte durch den Dozenten bereitgestellt. Nutze nur die zugewiesenen Projekte, damit keine privaten Kosten entstehen.
:::

## Projekt erstellen

Nach dem Login in der [Hetzner Cloud Console](https://console.hetzner.cloud/):

1. Klicke auf **„Neues Projekt"** oder wähle ein bestehendes Projekt aus.
2. Vergib einen aussagekräftigen Namen (z.B. `sdi-uebungen`).

## Firewall konfigurieren

Bevor du einen Server erstellst, solltest du eine Firewall anlegen, um den Zugriff abzusichern.

1. Navigiere im linken Menü zu **Firewalls**.
2. Klicke auf **„Firewall erstellen"**.
3. Konfiguriere die Firewall:
   - **Name**: z.B. `ssh-access`
   - **Inbound Rule**: SSH-Zugriff erlauben

| IP-Version | Protokoll | Port |
|---|---|---|
| Any IPv4 / Any IPv6 | TCP | 22 |

4. Klicke auf **„Firewall erstellen"**.

## Server erstellen

1. Navigiere im linken Menü zu **Server** und klicke auf **„Server hinzufügen"**.
2. Konfiguriere den Server:
   - **Location**: Helsinki oder Frankfurt (je nach Verfügbarkeit).
   - **Image**: **Debian 12** (empfohlen, da root-Zugang per Passwort standardmäßig erlaubt ist).
   - **Typ**: Shared vCPU / x86 (Intel/AMD). **CX22** oder **CPX11** sind für die Übungen ausreichend.
   - **Firewall**: Wähle die zuvor erstellte Firewall aus.
   - **Name**: Vergib einen beschreibenden Namen.
3. Klicke auf **„Erstellen & Kaufen"**.

::: warning Hinweis zu Ubuntu
Bei Ubuntu ist der passwortbasierte root-Zugang standardmäßig deaktiviert (`PermitRootLogin prohibit-password` in `/etc/ssh/sshd_config`). Nutze bevorzugt **Debian**, um dieses Problem zu vermeiden.
:::

Nach der Erstellung erhältst du eine E-Mail mit dem root-Passwort für den Server. Du kannst das Passwort auch jederzeit in der Cloud Console zurücksetzen.

## Server erreichen

### Per Ping testen

Kopiere die IP-Adresse deines Servers aus der Cloud Console und teste die Erreichbarkeit:

```bash
ping DEINE_SERVER_IP
```

### Per SSH verbinden

Verbinde dich mit dem root-Passwort aus der E-Mail:

```bash
ssh root@DEINE_SERVER_IP
```

Beim ersten Verbindungsaufbau erscheint folgende Meldung:

```
The authenticity of host '95.216.187.60 (95.216.187.60)' can't be established.
ED25519 key fingerprint is SHA256:vMMi2lkyhu0BPeqfncLzDRo6a1Ae8TtyVETebvh2ZwU.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

Diese Meldung bedeutet:
- SSH überprüft die Identität des Servers anhand seines öffentlichen Fingerprints.
- Da du dich zum ersten Mal verbindest, ist der Host Key noch nicht in `~/.ssh/known_hosts` gespeichert.
- Tippe **`yes`**, um den Schlüssel zu akzeptieren und die Verbindung herzustellen.


## Passwort zurücksetzen

Falls du dein root-Passwort vergessen hast:

1. Klicke auf deinen Server in der Serverliste.
2. Navigiere zum Reiter **„Rescue"**.
3. Klicke auf **„Root-Passwort zurücksetzen"** und kopiere das generierte Passwort.

## Server löschen und neu erstellen

Server können jederzeit gelöscht und neu erstellt werden. Das ist bei Cloud-Servern üblich und wird in den Übungen häufig gemacht.

::: warning SSH Host Key Warnung
Wenn du einen Server löschst und mit derselben IP-Adresse neu erstellst, wirst du eine **Host Key Warnung** sehen, da der neue Server einen anderen Fingerprint hat. Löse das Problem mit:

```bash
ssh-keygen -R DEINE_SERVER_IP
```

Danach kannst du dich wieder normal per SSH verbinden.
:::

## Weiterführende Links

- [Hetzner Docs: Server erstellen](https://docs.hetzner.com/cloud/servers/getting-started/creating-a-server)
- [Hetzner Docs: Mit Server verbinden](https://docs.hetzner.com/cloud/servers/getting-started/connecting-to-the-server)
- [Hetzner Docs: Firewall erstellen](https://docs.hetzner.com/cloud/firewalls/getting-started/creating-a-firewall)
- [Lecture Notes: Hetzner Cloud GUI](https://freedocs.mi.hdm-stuttgart.de/sdi_cloudProvider_webAdminGui.html)
