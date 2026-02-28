resource "tls_private_key" "host_key" { 
  algorithm = "ED25519"
  count = var.serverCount
}

resource "hcloud_server" "helloServer" {
  count        = var.serverCount
  name         = "${var.serverName}-${count.index + 1}"
  image        =  "debian-13"
  server_type  =  "cx23"
  firewall_ids = [hcloud_firewall.fw.id]
  ssh_keys     = [hcloud_ssh_key.loginUser.id]
  user_data    = local_file.user_data[count.index].content
}

resource "local_file" "user_data" {
  count = var.serverCount
  content = templatefile("tpl/userData.yml", {
    loginUser = var.loginUser
    sshKey    = chomp(file("~/.ssh/id_ed25519.pub"))
    tls_private_key = indent(4, tls_private_key.host_key[count.index].private_key_openssh)
  })
  filename = "${var.serverName}-${count.index+1}/gen/userData.yml"
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

resource "local_file" "known_hosts" { 
  count = var.serverCount
  content = "${var.serverName}-${count.index + 1}.${var.dnsZone} ${tls_private_key.host_key[count.index].public_key_openssh}"
  filename        = "${var.serverName}-${count.index + 1}/gen/known_hosts"
  file_permission = "644"
}

resource "local_file" "ssh_script" { 
  count = var.serverCount
  content = templatefile("${path.module}/tpl/ssh.sh", {
    devopsUsername = var.loginUser,
    dnsName = "${var.serverName}-${count.index + 1}.${var.dnsZone}"
  })
  filename        = "${var.serverName}-${count.index + 1}/bin/ssh"
  file_permission = "755"
}

resource "local_file" "scp_script" { 
  count = var.serverCount
  content = templatefile("${path.module}/tpl/scp.sh", {
    devopsUsername = var.loginUser,
    dnsName = "${var.serverName}-${count.index + 1}.${var.dnsZone}"
  })
  filename        = "${var.serverName}-${count.index + 1}/bin/scp"
  file_permission = "755"
}

provider "dns" {
  update {
    server        = "ns1.sdi.hdm-stuttgart.cloud"
    key_name      = "${var.groupName}.key."
    key_algorithm = "hmac-sha512"
    key_secret    = var.dns_secret
  }
}

resource "dns_a_record_set" "workhorse" {
  count = var.serverCount
  name = "${var.serverName}-${count.index+1}"
  zone = "${var.dnsZone}."
  ttl = 10
  addresses = [hcloud_server.helloServer[count.index].ipv4_address]
}

resource "null_resource" "dns_root" {
  triggers = {
    server_ip = hcloud_server.helloServer[0].ipv4_address
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "server ns1.sdi.hdm-stuttgart.cloud
      update delete ${var.dnsZone}. A
      update add ${var.dnsZone}. 10 A ${hcloud_server.helloServer[0].ipv4_address}
      send" | nsupdate -y "hmac-sha512:${var.groupName}.key:${var.dns_secret}"
    EOT
  }
}

resource "dns_cname_record" "aliases" {
  count = length(var.serverAliases)
  name  = var.serverAliases[count.index]
  zone  = "${var.dnsZone}."
  ttl   = 10
  cname = "${var.serverName}-1.${var.dnsZone}."
  lifecycle {
    precondition {
      condition     = !contains(var.serverAliases, var.serverName)
      error_message = "Der Server-Name darf nicht gleichzeitig als Alias (CNAME) definiert sein."
    }
  }
}
