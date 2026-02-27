# Volumes

Volumes sind persistente Blockspeicher, die unabhängig vom Lebenszyklus eines Servers existieren. Sie können an Server angehängt, formatiert und gemountet werden und behalten ihre Daten auch dann, wenn der Server gelöscht wird.

## Was sind Volumes?

In der Cloud ist der lokale Speicher eines Servers flüchtig. Wenn ein Server gelöscht und neu erstellt wird, gehen alle Daten verloren. Volumes lösen dieses Problem, indem sie einen separaten, persistenten Speicher bereitstellen.

### Vorteile

- Daten bleiben erhalten, auch wenn der Server gelöscht wird
- Volumes können zwischen Servern verschoben werden
- Größe ist flexibel wählbar und erweiterbar
- Unabhängiger Lebenszyklus vom Server

## Grundlagen: Partitionen und Dateisysteme

### Block Devices

Volumes erscheinen auf dem Server als Block Device (z.B. `/dev/sdb`). Mit `lsblk` kann man alle angeschlossenen Geräte anzeigen:

```bash
lsblk
```

### Dateisysteme

Bevor ein Volume genutzt werden kann, muss ein Dateisystem darauf erstellt werden:

| Dateisystem | Beschreibung                                |
| ----------- | ------------------------------------------- |
| ext4        | Standard-Linux-Dateisystem mit Journaling   |
| XFS         | Hochperformant, besonders für große Dateien |
| Btrfs       | Erweiterte Features wie Snapshots und RAID  |

```bash
# ext4 Dateisystem erstellen
sudo mkfs -t ext4 /dev/sdb1

# XFS Dateisystem erstellen
sudo mkfs -t xfs /dev/sdb2
```

### Mounten

Mounten bedeutet, ein Dateisystem an einem bestimmten Verzeichnis im Dateisystembaum verfügbar zu machen:

```bash
# Mount-Verzeichnis erstellen
sudo mkdir /disk1

# Volume mounten
sudo mount /dev/sdb1 /disk1

# Alle Mounts anzeigen
df -h

# Volume unmounten
sudo umount /disk1
```

Typische Mount Points:

| Pfad     | Verwendung             |
| -------- | ---------------------- |
| `/mnt`   | Temporäre Mount Points |
| `/media` | Wechselmedien          |
| `/var`   | Variable Daten         |
| `/home`  | Benutzerverzeichnisse  |

### Partitionierung

Mit `fdisk` können Volumes in mehrere Partitionen aufgeteilt werden:

```bash
sudo fdisk /dev/sdb
```

Innerhalb von `fdisk`:

- `n`: Neue Partition erstellen
- `p`: Partitionstabelle anzeigen
- `w`: Änderungen schreiben und beenden

## Persistentes Mounten mit fstab

Manuell gemountete Volumes gehen nach einem Neustart verloren. Um Mounts dauerhaft zu machen, werden sie in `/etc/fstab` eingetragen:

```bash
sudo vim /etc/fstab
```

```text
# <file system>           <mount point>  <type>  <options>        <dump>  <pass>
/dev/sdb1                  /disk1         ext4    defaults,nofail  0       2
UUID=<DEINE_SDB2_UUID>     /disk2         xfs     defaults,nofail  0       2
```

::: tip UUID statt Device-Name
UUIDs sind stabiler als Device-Namen (`/dev/sdb1`), da sich Letztere nach einem Neustart ändern können. UUID ermitteln mit:

```bash
blkid /dev/sdb2
```

:::

Konfiguration testen ohne Neustart:

```bash
sudo mount -a
```

### Mount-Optionen

| Option     | Bedeutung                                                   |
| ---------- | ----------------------------------------------------------- |
| `defaults` | Standardoptionen (rw, suid, dev, exec, auto, nouser, async) |
| `nofail`   | System bootet auch wenn das Volume nicht verfügbar ist      |
| `discard`  | Aktiviert TRIM-Support für SSDs                             |

## Volumes mit Terraform

### Volume erstellen und anhängen

```hcl
resource "hcloud_volume" "volume01" {
  name      = "volume1"
  size      = 10
  server_id = hcloud_server.debian_server.id
  automount = true
  format    = "xfs"
}
```

Mit `automount = true` und `format` wird das Volume automatisch formatiert und unter `/mnt/HC_Volume_<ID>` gemountet.

### Volume Output

```hcl
output "volume_id" {
  value       = hcloud_volume.volume01.id
  description = "ID des Volumes"
}
```

### Server und Volume entkoppeln

Für mehr Kontrolle können Volume und Server unabhängig erstellt und dann verbunden werden:

```hcl
resource "hcloud_volume" "data_volume" {
  name     = "data-volume"
  size     = 10
  location = var.server_location
  format   = "xfs"
}

resource "hcloud_server" "debian_server" {
  name        = "debian-server"
  image       = "debian-12"
  server_type = "cx22"
  location    = var.server_location
}

resource "hcloud_volume_attachment" "volume_attachment" {
  volume_id = hcloud_volume.data_volume.id
  server_id = hcloud_server.debian_server.id
}
```

::: warning Standort beachten
Volume und Server müssen sich am gleichen Standort befinden. Verwende die gleiche `location`-Variable für beide Ressourcen.
:::

## Mounten mit Cloud-init automatisieren

Statt manuell zu mounten, kann Cloud-init das Volume beim ersten Boot automatisch einbinden:

```yaml
#cloud-config
runcmd:
  - mkdir -p /volume01
  - echo "`/bin/ls /dev/disk/by-id/*${volId}` /volume01 xfs discard,nofail,defaults 0 0" >> /etc/fstab
  - systemctl daemon-reload
  - mount -a
```

Die Variable `${volId}` wird über Terraform's `templatefile()` eingesetzt:

```hcl
resource "local_file" "user_data" {
  content = templatefile("tpl/userData.yml", {
    volId = hcloud_volume.data_volume.id
  })
  filename = "gen/userData.yml"
}
```

## Nützliche Befehle

```bash
# Alle Block Devices anzeigen
lsblk

# Speicherbelegung anzeigen
df -h

# UUID eines Devices anzeigen
blkid /dev/sdb1

# Dateisystem prüfen
sudo fsck /dev/sdb1

# Dateisystem vergrößern (ext4)
sudo resize2fs /dev/sdb1
```

## Weiterführende Links

- [Hetzner Docs: Volumes](https://docs.hetzner.com/cloud/volumes/getting-started)
- [Terraform: hcloud_volume](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs/resources/volume)
- [Lecture Notes: Volumes](https://freedocs.mi.hdm-stuttgart.de/sdi_cloudProvider_volume.html)
