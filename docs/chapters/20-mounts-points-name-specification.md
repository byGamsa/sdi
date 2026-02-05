# 20. Mount point's name specification

Folgende Aufgabe baut auf der vorherigen Aufgabe (Aufgabe 19) auf. In dieser Aufgabe werden wir
- Eine gemeinsame Location für Server und Volume festlegen (z. B. nbg1)
- Server und Volume unabhängig erstellen
- Volume nicht automatisch mounten (automount = false)
- Volume in /etc/fstab eintragen

### Location wird als Variable erstellt und eingefügt
Die Variable stellt sicher, dass Server und Volume am gleichen Standort erstellt werden.
Anschließend wird die location zu dem Server und dem Volume hinzugefügt.

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

### Server und Volume werden unabhängig voneinander erstellen und automount abschalten
`automount = false` stellt sicher, dass Cloud-init den Mountpunkt selbst erstellt
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

### Volume in `/etc/fstab` eintragen
Mountpoint `/volume01` wird erstellt und in `/etc/fstab` eingetragen
`daemon-reload` und `mount -a` sorgen dafür, dass der Mount sofort aktiv und reboot-sicher ist
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