# 19. Partitionen und Mounting

Originale Aufgabenstellung: [Lecture Notes](https://freedocs.mi.hdm-stuttgart.de/sdi_cloudProvider_volume.html#sdi_cloudProvider_volume_qanda_ManualMount)

In dieser Übung wird ein externes Block-Storage-Volume an einen Server angebunden. Dabei werden die grundlegenden Linux-Konzepte zum Partitionieren, Formatieren und Einhängen von Dateisystemen manuell durchgeführt. Anschließend wird das Mounting persistent gemacht, sodass das Volume auch nach einem Server-Neustart automatisch wieder zur Verfügung steht.

## Architektur-Komponenten

| Komponente | Beschreibung |
|---|---|
| **Hetzner Volume** | 10 GB externer Block-Storage, unabhängig vom Server-Lebenszyklus |
| **Volume Attachment** | Terraform-Ressource zur Verknüpfung von Volume und Server |
| **Cloud-Init Workaround** | Löst den Automount-Bug über `udevadm trigger` |
| **fstab** | Linux-Konfigurationsdatei für persistentes Mounting nach Neustarts |

## Codebasis

Diese Aufgabe baut auf der Infrastruktur aus [Aufgabe 18](/exercises/18-a-module-for-ssh-host-key-handling) auf.

## Übungsschritte

### 1. Volume erstellen und anbinden

Zuerst definieren wir das Volume in Terraform und binden es an unseren Server. Der Parameter `automount = true` sorgt dafür, dass Hetzner das Volume automatisch formatiert und mountet. Zusätzlich erstellen wir einen Output, um die Volume-ID abfragen zu können:

::: code-group

```sh [main.tf] 
resource "hcloud_volume" "volume01" {
    name      = "volume1"
    size      = 10
    server_id = hcloud_server.debian_server.id
    automount = true
    format    = "xfs"
}

resource "hcloud_volume_attachment" "volume_attachment" { 
  volume_id = hcloud_volume.volume01.id
  server_id = hcloud_server.debian_server.id
}
```

```sh [output.tf] 
output "volume_id" {
    value       = hcloud_volume.volume01.id
    description = "The volume's id"
}
```

:::

::: details Der `automount` Bug und Workaround
Die Automount-Funktion von Hetzner kann gelegentlich fehlschlagen, sodass ein Volume beim ersten Systemstart nicht korrekt eingebunden wird. Eine bewährte Lösung ist es, Cloud-Init zu verwenden, um udev manuell auszulösen. Füge dafür folgendes zur `userData.yml` hinzu: 

```yml
runcmd: 
    // [!code ++:3]
  - udevadm trigger -c add -s block -p ID_VENDOR=HC --verbose -p ID_MODEL=Volume 
  - reboot # Ein Neustart ist meist notwendig, damit Automount greift 

```

Der Befehl `udevadm trigger` löst die udev-Regeln erneut aus, die für das Erkennen und Einbinden des Volumes zuständig sind. Der anschließende `reboot` stellt sicher, dass alle Systemd-Mount-Units korrekt geladen werden.
:::

### 2. Manuelles Partitionieren und Mounten

In den folgenden Schritten arbeiten wir direkt auf dem Server und lernen die grundlegenden Linux-Befehle für Volume-Management kennen.

#### 2.1 Ergebnisse überprüfen

Nach dem Neustart verschaffe dir mit `df -h` einen Überblick über die lokalen Dateisysteme, um das neu angebundene Volume zu identifizieren:

```bash
devops@debian-server:~$ df -h
Filesystem      Size  Used Avail Use% Mounted on
udev            1.9G     0  1.9G   0% /dev
tmpfs           383M  568K  383M   1% /run
/dev/sdb1        38G  1.5G   35G   5% /
tmpfs           1.9G     0  1.9G   0% /dev/shm
tmpfs           5.0M     0  5.0M   0% /run/lock
tmpfs           1.9G     0  1.9G   0% /tmp
tmpfs           1.0M     0  1.0M   0% /run/credentials/systemd-journald.service
/dev/sdb15      241M  146K  241M   1% /boot/efi
/dev/sda         10G  104M  9.9G   2% /mnt/HC_Volume_<VOLUME_ID>
tmpfs           1.0M     0  1.0M   0% /run/credentials/getty@tty1.service
tmpfs           1.0M     0  1.0M   0% /run/credentials/serial-getty@ttyS0.service
tmpfs           383M  8.0K  383M   1% /run/user/1000
```

Das Volume (`/dev/sda`) ist unter `/mnt/HC_Volume_<VOLUME_ID>` gemountet.

#### 2.2 Auto-mounted Volume unmounten

Bevor wir das Volume manuell partitionieren können, muss es zuerst unmountet werden:

```bash
sudo umount /mnt/HC_Volume_<VOLUME_ID>
```

::: warning
Stelle sicher, dass du dich nicht im Volume-Verzeichnis selbst befindest, da es sich sonst um ein „busy target" handelt und der Unmount fehlschlägt: `umount: /mnt/HC_Volume_104441845: target is busy.`
:::

#### 2.3 Volume partitionieren

Im folgenden Schritt teilen wir das Volume in zwei Partitionen. Verwende dafür den Befehl `sudo fdisk /dev/sdb`.

**Bestehende Datenpartition löschen:**

```bash
Command (m for help): d
Partition number (1,14,15, default 15): 1
Partition 1 has been deleted.
```

**Aktuelle Partitionstabelle prüfen** mit `p`:

```bash
Command (m for help): p

Disk /dev/sdb: 38.15 GiB, 80003072 sectors
Disklabel type: gpt
Device      Start    End      Sectors  Size Type
/dev/sdb14   2048     4095     2048    1M BIOS boot
/dev/sdb15   4096   503807   499712  244M EFI System
```

**Erste Partition erstellen** (~5 GiB):

```bash
Command (m for help): n
Partition number (1-13,16-128, default 1): ⏎
First sector (34-80003038, default 503808): ⏎
Last sector, +/-sectors or +/-size{K,M,G,T,P} (503808-80003038, default 80001023): +5G
```

**Zweite Partition erstellen** (Rest des Volumes):

```bash
Command (m for help): n
Partition number (2-13,16-128, default 2): ⏎
First sector (10989568-80003038, default 10989568): ⏎
Last sector, +/-sectors or +/-size{K,M,G,T,P} (10989568-80003038, default 80001023): ⏎
```

**Ergebnis prüfen:**

```bash
Command (m for help): p

Device     Boot    Start      End  Sectors Size Id Type
/dev/sdb1           2048 10487807 10485760   5G 83 Linux
/dev/sdb2       10487808 20971519 10483712   5G 83 Linux
```

::: tip
Vergiss nicht, die Änderungen mit `w` (write) zu speichern, bevor du `fdisk` beendest.
:::

#### 2.4 Dateisysteme erstellen

Nachdem wir das Volume in zwei Partitionen geteilt haben, erstellen wir auf jeder Partition ein anderes Dateisystem, um die Unterschiede kennenzulernen:

**Ext4-Dateisystem** auf der ersten Partition (das Standarddateisystem für die meisten Linux-Distributionen):

```bash
sudo mkfs -t ext4 /dev/sdb1
```

**XFS-Dateisystem** auf der zweiten Partition (ein leistungsstarkes Dateisystem für große Datenmengen):

```bash
sudo mkfs -t xfs /dev/sdb2
```

**Überprüfung** der erstellten Dateisysteme:

```bash
lsblk -f
```

#### 2.5 Mount-Verzeichnisse erstellen

Erstelle zwei Ordner, die als Mount-Punkte dienen:

```bash
sudo mkdir /disk1 /disk2
```

#### 2.6 Erste Partition mounten (nach Device-Name)

```bash
sudo mount /dev/sdb1 /disk1
```

#### 2.7 Zweite Partition mounten (nach UUID)

Die UUID ist eindeutig und ändert sich nicht, auch wenn sich die Device-Reihenfolge ändert. Das macht sie zur bevorzugten Methode:

```bash
UUID=$(sudo blkid -s UUID -o value /dev/sdb2)
sudo mount UUID=$UUID /disk2
```

#### 2.8 Unmount-Verhalten beobachten

Erstelle zunächst eine Datei in `/disk1` und unmounte dann die Partition:

```bash
sudo umount /disk1
```

**Ergebnis:** Alle erstellten Dateien im Ordner `disk1` verschwinden, da das Dateisystem nicht mehr eingehängt ist. Die Daten sind aber nicht verloren, sie werden wieder sichtbar, sobald die Partition erneut gemountet wird.

### 3. Dauerhaftes Mounting mit fstab

Bisheriges Mounting geht beim Neustart verloren. Damit die Partitionen persistent gemountet bleiben, müssen sie in der Datei `/etc/fstab` eingetragen werden. Diese Datei wird beim Systemstart ausgelesen und alle dort definierten Mounts werden automatisch ausgeführt.

Ermittle zuerst die UUID der zweiten Partition mit `lsblk -f` und kopiere sie.

Bearbeite dann die Datei:

```bash
sudo nano /etc/fstab
```

Füge folgende Einträge am Ende hinzu:

```bash
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
/dev/sdb1       /disk1          ext4    defaults,nofail 0       2
UUID=<YOUR_SDB2_UUID> /disk2    xfs    defaults,nofail 0       2
```

::: info Mount-Optionen erklärt
- **`defaults`**: Standardoptionen (`rw`, `suid`, `dev`, `exec`, `auto`, `nouser`, `async`)
- **`nofail`**: Der Boot-Prozess schlägt nicht fehl, wenn das Volume nicht verfügbar ist
- **`0`** (dump): Kein Backup durch `dump`
- **`2`** (pass): Dateisystem-Check nach dem Root-Dateisystem
:::

Teste die Konfiguration, ohne einen Neustart durchführen zu müssen:

```bash
sudo mount -a
```

Dieser Befehl liest die `fstab` und mountet alle dort definierten, noch nicht gemounteten Dateisysteme. Nach einem Server-Reboot sollten beide Partitionen automatisch gemountet sein.