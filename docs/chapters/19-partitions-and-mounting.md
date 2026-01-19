# 19. Partitions and mounting 
Dieses Kapitel behandelt die Verwaltung externer Block-Storage-Volumes. In dieser Übung bindest du ein neues Volume an einen Server an und führst die Schritte zum Partitionieren, Formatieren, Einhängen manuell durch und automatisierst den Prozess, sodass das Volume auch nach einem Neustart dauerhaft eingebunden bleibt.

## Solution Overview
...

## Architecture
### Components

1. Terraform Configuration - Defines the infrastructure
2. Cloud-Init Template - Configures the server after boot
3. Firewall Rules - Secures the server
4. SSH Key Management - Enables secure access

## Implementation

Für folgende Aufgabe verwenden wir die Codebasis welche in Aufgabe 18 bereits aufgesetzt wurde

### 1. Mounted Volume erstellen und anbinden

Zu allererst muss das neue Volume definiert und an die Server Ressource gemounted werden. Außerdem definieren wir eine Output Direktive welche uns nach die id des Volumes übergibt

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

:::

### 2. Manual Partitioning and Mounting

### 2.1. Ergebnisse überprüfen

Nach dem Neustart verschaffe dir mit dem Befehl `df -h` einen Überblick über die lokalen Dateisysteme, um das neu angebundene Volume zu identifizieren. Es sollte dann aussehen wie folgt:

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

### 2.2. Unmounte den auto-mounted Volume
Verwende den Befehl `sudo umount /mnt/HC_Volume_<VOLUME_ID>`, dafür darf man sich nicht im Volume Verzeichnis selbst befinden, da es sich um ein busy target handelt `umount: /mnt/HC_Volume_104441845: target is busy.`.

### 2.3. Volume partitionieren
Im Folgenden Schritt wollen wir das Volume in 2 Partionen teilen. Verwende dafür den Befehl `sudo fdisk /dev/sdb`. 
Zu allererst müssen wir die bestehende Datenpartition löschen:

```bash
Command (m for help): d
Partition number (1,14,15, default 15): 1
Partition 1 has been deleted.
```

Mit `p` lässt sich die aktuelle Partitionstabelle prüfen:

```bash
Command (m for help): p

Disk /dev/sdb: 38.15 GiB, 80003072 sectors
Disklabel type: gpt
Device      Start    End      Sectors  Size Type
/dev/sdb14   2048     4095     2048    1M BIOS boot
/dev/sdb15   4096   503807   499712  244M EFI System
```

Erste Partition erstellen (~5 GiB)

```bash
Command (m for help): n
Partition number (1-13,16-128, default 1): ⏎
First sector (34-80003038, default 503808): ⏎
Last sector, +/-sectors or +/-size{K,M,G,T,P} (503808-80003038, default 80001023): +5G
```

Zweite Partition erstellen (Rest des Volumes)

```bash
Command (m for help): n
Partition number (2-13,16-128, default 2): ⏎
First sector (10989568-80003038, default 10989568): ⏎
Last sector, +/-sectors or +/-size{K,M,G,T,P} (10989568-80003038, default 80001023): ⏎
```

Ergebnis prüfen:

```bash
Command (m for help): p

Device     Boot    Start      End  Sectors Size Id Type
/dev/sdb1           2048 10487807 10485760   5G 83 Linux
/dev/sdb2       10487808 20971519 10483712   5G 83 Linux
```

### 2.3 Dateisysteme auf neuen Partitionen erstellen
Nachdem wir das Volume in zwei Partitionen geteilt haben, erstellen wir nun unterschiedliche Dateisysteme auf jeder Partition.

#### Ext4-Dateisystem auf der ersten Partition

```bash
sudo mkfs -t ext4 /dev/sdb1
```

#### XFS-Dateisystem auf der zweiten Partition

```bash
sudo mkfs -t xfs /dev/sdb2
```

#### Überprüfung der Dateisysteme

```bash
lsblk -f
```

### 2.4. Erstelle zwei Ordner für das mounting

```bash
sudo mkdir /disk1 /disk2
```

### 2.5. Mounting der ersten Partition an den ersten Ordner

```bash
sudo mount /dev/sdb1 /disk1
```

### 2.6. Mounting der zweiten Partition an den zweiten Ordner anhand der UUID

```bash
UUID=$(sudo blkid -s UUID -o value /dev/sdb2)
sudo mount UUID=$UUID /disk2
```

### 2.7. Zuerst file in disk1 erstellen, dann unmounten und beobachten
```bash
sudo umount /disk1
```

Ergebnis: Alle erstellten Dateien in dem Ordner `disk1` verschwinden

### Dauerhaftes Mounting mit `fstab`

Um das Mounting persistent zu machen, müssen wir im ersten Schritt nochmal die UUID der zweiten Partition herausfinden. Diese wird über den Befehl `lsblk -f` angezeigt und sollte kopiert werden.

Für das persistente Mounting muss anschließend die Datei `/etc/fstab` bearbeitet werden:
```bash
sudo nano /etc/fstab
```

Hier müssen jetzt folgende Zeilen verknüpft werden, sodass das Mounting persistent ist.  

```bash
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
/dev/sdb1       /disk1          ext4    defaults,nofail 0       2
UUID=<YOUR_SDB2_UUID> /disk2    xfs    defaults,nofail 0       2
```

Dieses File wird mit dem Befehl `sudo mount -a` gelesen und das Mounting sollte dadurch erfolgen. Nach einem Server-Reboot sollten beide Partitionen noch gemounted sein.