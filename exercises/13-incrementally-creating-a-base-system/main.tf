resource "hcloud_server" "helloServer" {
  name         = "hello"
  image        =  "debian-13"
  server_type  =  "cx23"
  firewall_ids = [hcloud_firewall.sshFw.id]
  ssh_keys     = [hcloud_ssh_key.loginUser.id]
}

resource "hcloud_firewall" "sshFw" {
  name = "firewall-1"
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_ssh_key" "loginUser" {
  name       = "my_ssh_key"
  public_key = var.ssh_login_public_key
}