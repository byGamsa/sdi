# 20. Eigenen Mount-Point definieren

Originale Aufgabenstellung: [Lecture Notes](https://freedocs.mi.hdm-stuttgart.de/sdi_cloudProvider_volume.html#sdi_cloudProvider_volume_qanda_mountPointName)

In dieser Übung wird das Volume-Mounting weiter automatisiert und verbessert. Server und Volume werden unabhängig voneinander erstellt und über eine `hcloud_volume_attachment` Ressource verbunden. Anstelle des automatischen Mountings durch Hetzner übernimmt Cloud-Init die Einrichtung: Es erstellt den Mount-Punkt, trägt das Volume in `/etc/fstab` ein und sorgt dafür, dass alles sofort und nach jedem Neustart verfügbar ist.

## Codebasis

Diese Aufgabe baut auf der Infrastruktur aus [Aufgabe 19](/exercises/19-partitions-and-mounting) auf. Die dort manuell durchgeführten Schritte werden hier automatisiert.

## Übungsschritte

### 1. Server-Location als Variable definieren

Server und Volume müssen im gleichen Hetzner-Rechenzentrum liegen, damit sie miteinander verbunden werden können. Über eine gemeinsame Variable stellen wir das sicher:

::: code-group

```hcl [variable.tf]
variable "server_location" { // [!code ++:6]
  description = "Location of the server"
  type        = string
  nullable    = false
  default     = "nbg1"
}
```

```hcl [main.tf]
resource "hcloud_server" "debian_server" {
  name         = "debian-server"
  image        =  "debian-13"
  server_type  =  "cx23"
  location     = var.server_location // [!code ++]
  firewall_ids = [hcloud_firewall.fw.id]
  ssh_keys     = [hcloud_ssh_key.loginUser.id]
  user_data    = local_file.user_data.content
}
resource "hcloud_volume" "volume01" {
  name      = "volume1"
  size      = 10
  server_id = hcloud_server.debian_server.id
  location = var.server_location // [!code ++]
  automount = true
  format    = "xfs"
}
```

:::

::: info
Gängige Locations bei Hetzner sind `nbg1` (Nürnberg), `fsn1` (Falkenstein) und `hel1` (Helsinki). Server und Volumes in unterschiedlichen Locations können nicht verbunden werden.
:::

### 2. Server und Volume entkoppeln

Im vorherigen Schritt war das Volume direkt an den Server gebunden (`server_id` im Volume). Jetzt entkoppeln wir beides und verwenden eine separate `hcloud_volume_attachment` Ressource.

Außerdem deaktivieren wir `automount`, damit Cloud-Init den Mountpunkt selbst konfiguriert:

::: code-group

```hcl [main.tf]
resource "hcloud_volume" "volume01" {
  name      = "volume1"
  size      = 10
  server_id = hcloud_server.debian_server.id // [!code --]
  location = var.server_location
  automount = true // [!code --]
  format    = "xfs"
}
resource "hcloud_volume_attachment" "volume_attachment" {
  volume_id = hcloud_volume.volume01.id
  server_id = hcloud_server.debian_server.id
  automount = false // [!code ++]
}
```

:::

::: info
Durch die Entkopplung kann das Volume den Server überleben. Wenn du den Server zerstörst und neu erstellst, bleibt das Volume mit seinen Daten erhalten und kann an den neuen Server angehängt werden.
:::

### 3. Volume in fstab per Cloud-Init eintragen

Jetzt automatisieren wir den gesamten Mount-Prozess über Cloud-Init. Dafür übergeben wir den Volume-Namen und den Device-Pfad als Variablen an das Template. Cloud-Init erstellt dann den Mountpunkt `/volume01`, trägt ihn in `/etc/fstab` ein und führt `mount -a` aus:

::: code-group

```hcl [main.tf]
resource "local_file" "user_data" {
  content = templatefile("tpl/userData.yml", {
    loginUser = var.loginUser
    sshKey    = chomp(file("~/.ssh/id_ed25519.pub"))
    tls_private_key = indent(4, tls_private_key.host_key.private_key_openssh)
    volumename = hcloud_volume.volume01.name // [!code ++]
    device = hcloud_volume.volume01.linux_device // [!code ++]
  })
  filename = "gen/userData.yml"
```

```hcl [tpl/userData.yml]
runcmd:
  - systemctl start nginx
  - systemctl enable nginx
  - udevadm trigger -c add -s block -p ID_VENDOR=HC --verbose -p ID_MODEL=Volume
  - mkdir -p /volume01 // [!code ++]
  - echo "${device} /volume01 xfs defaults,nofail 0 2" >> /etc/fstab // [!code ++]
  - systemctl daemon-reload // [!code ++]
  - mount -a // [!code ++]
  - reboot
```

:::
