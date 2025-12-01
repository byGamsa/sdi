resource "hcloud_server" "helloServer" {
  name         = "hello"
  image        =  "debian-13"
  server_type  =  "cx23"
  firewall_ids = [hcloud_firewall.fw.id]
  ssh_keys     = [hcloud_ssh_key.loginUser.id]
  user_data    = local_file.user_data.content
}

resource "local_file" "user_data" {
  content = templatefile("tpl/userData.yml", {
    loginUser = "devops"
    sshKey    = chomp(file("~/.ssh/id_ed25519.pub"))
  })
  filename = "gen/userData.yml"
}

resource "hcloud_firewall" "fw" {
  name = "firewall-2"
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