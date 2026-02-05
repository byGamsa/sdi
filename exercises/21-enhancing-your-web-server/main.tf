resource "tls_private_key" "host_key" {
  algorithm = "ED25519"
}

resource "hcloud_server" "debian_server" {
  name         = "debian-server"
  image        =  "debian-13"
  server_type  =  "cx23"
  location     = var.server_location
  firewall_ids = [hcloud_firewall.fw.id]
  ssh_keys     = [hcloud_ssh_key.loginUser.id]
  user_data    = local_file.user_data.content
}

resource "hcloud_volume" "volume01" {
  name      = "volume01"
  size      = 10
  location = var.server_location 
  format    = "xfs"
}

resource "hcloud_volume_attachment" "volume_attachment" { 
  volume_id = hcloud_volume.volume01.id
  server_id = hcloud_server.debian_server.id
  automount = false
}

resource "local_file" "user_data" {
  content = templatefile("tpl/userData.yml", {
    loginUser = var.loginUser
    sshKey    = chomp(file("~/.ssh/id_ed25519.pub"))
    tls_private_key = indent(4, tls_private_key.host_key.private_key_openssh)
    volumename = hcloud_volume.volume01.name
    device = hcloud_volume.volume01.linux_device
  })
  filename = "gen/userData.yml"
}

resource "hcloud_firewall" "fw" {
  name = "firewall-1"
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
} 

resource "hcloud_ssh_key" "loginUser" {
  name       = "my_ssh_key"
  public_key = var.ssh_login_public_key
}

module "host_metadata" {
  source      = "../modules/host-meta-data"
  name        = hcloud_server.debian_server.name
  location    = hcloud_server.debian_server.location
  ipv4Address = hcloud_server.debian_server.ipv4_address
  ipv6Address = hcloud_server.debian_server.ipv6_address
}

module "ssh-known-hosts" {
  source = "../modules/ssh-known-hosts"
  public_key = tls_private_key.host_key.public_key_openssh
  ipv4Address = hcloud_server.debian_server.ipv4_address
  hostname = hcloud_server.debian_server.name
  login_user = var.loginUser
}

provider "dns" {
  update {
    server        = "ns1.sdi.hdm-stuttgart.cloud"
    key_name      = "g1.key."
    key_algorithm = "hmac-sha512"
    key_secret    = var.dns_secret
  }
}

resource "dns_a_record_set" "server_a" {
  name = "www.g1.sdi.hdm-stuttgart.cloud" 
  zone = "sdi.hdm-stuttgart.cloud."      
  ttl  = 600
  addresses = [hcloud_server.debian_server.ipv4_address]
}

resource "null_resource" "dns_root" {
  triggers = {
    server_ip = hcloud_server.debian_server.ipv4_address
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "server ns1.sdi.hdm-stuttgart.cloud
      update add www.g1.sdi.hdm-stuttgart.cloud 10 A ${hcloud_server.debian_server.ipv4_address}
      send" | nsupdate -y "hmac-sha512:g1.key:${var.dns_secret}"
    EOT
  }
}