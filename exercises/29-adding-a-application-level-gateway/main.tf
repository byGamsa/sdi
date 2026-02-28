resource "tls_private_key" "host_key" { 
  algorithm = "ED25519"
}

resource "hcloud_network" "privateNet" {
  name     = "Private Network"
  ip_range = "10.0.0.0/8"
}

resource "hcloud_network_subnet" "privateSubnet" {
  network_id   = hcloud_network.privateNet.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = var.privateSubnet.ipAndNetmask
}

resource "hcloud_primary_ip" "gateway_ip" {
  name          = "gateway-ip"
  location    = var.location
  type          = "ipv4"
  assignee_type = "server"
  auto_delete   = false 
}

resource "hcloud_server" "gateway" {
  name = "gateway"
  image        =  "debian-13"
  server_type  =  "cx23"
  location   = var.location
  firewall_ids = [hcloud_firewall.fw.id]
  ssh_keys     = [hcloud_ssh_key.loginUser.id]
  user_data    = local_file.gateway_data.content
  public_net {
    ipv4 = hcloud_primary_ip.gateway_ip.id
    ipv6_enabled = true
  }
  network {
    network_id = hcloud_network.privateNet.id
    ip         = "10.0.1.10"
  }
  depends_on = [        
    hcloud_network_subnet.privateSubnet
  ]
}

resource "hcloud_server" "intern" {
  name = "intern"
  image        =  "debian-13"
  server_type  =  "cx23"
  ssh_keys     = [hcloud_ssh_key.loginUser.id]
  user_data    = local_file.intern_data.content
  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }
  network {
    network_id = hcloud_network.privateNet.id
    ip         = "10.0.1.20"
  }
  depends_on = [
    hcloud_network_subnet.privateSubnet
    ,null_resource.waitForProxy
  ]
}

resource "local_file" "gateway_data" {
  content = templatefile("tpl/gateway.yml", {
    tls_private_key = indent(4, tls_private_key.host_key.private_key_openssh)
    loginUser = var.loginUser
    sshKey    = chomp(file("~/.ssh/id_ed25519.pub"))
    dnsDomainName = var.privateSubnet.dnsDomainName
  })
  filename = "gen/gateway.yml"
}

resource "local_file" "intern_data" {
  content = templatefile("tpl/intern.yml", {
    tls_private_key = indent(4, tls_private_key.host_key.private_key_openssh)
    loginUser = var.loginUser
    sshKey    = chomp(file("~/.ssh/id_ed25519.pub"))
    dnsDomainName = var.privateSubnet.dnsDomainName
  })
  filename = "gen/intern.yml"
}

resource "local_file" "waitForAptProxy" {
  content = templatefile("tpl/waitForAptProxy.sh", {
    interface = "10.0.1.10"
  })
  filename        = "gen/waitForAptProxy.sh"
  file_permission = "0755"
}

resource "null_resource" "waitForProxy" {
  depends_on = [hcloud_server.gateway]

  connection {
    type  = "ssh"
    user  = var.loginUser
    agent = true
    host  = hcloud_server.gateway.ipv4_address
  }

  provisioner "remote-exec" {
    script = local_file.waitForAptProxy.filename
  }
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
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_ssh_key" "loginUser" {
  name       = "my_ssh_key_joel"
  public_key = var.ssh_login_public_key
}

resource "local_file" "known_hosts" { 
  content = join(" "
    ,[ hcloud_server.gateway.ipv4_address
    , tls_private_key.host_key.public_key_openssh ]
  )
  filename        = "gen/known_hosts"
  file_permission = "644"
}

resource "local_file" "ssh_script" { 
  content = templatefile("${path.module}/tpl/ssh.sh", {
    devopsUsername = var.loginUser,
    ip = hcloud_server.gateway.ipv4_address
  })
  filename        = "bin/ssh"
  file_permission = "755"
}

resource "local_file" "scp_script" { 
  content = templatefile("${path.module}/tpl/scp.sh", {
    devopsUsername = var.loginUser,
    ip = hcloud_server.gateway.ipv4_address
  })
  filename        = "bin/scp"
  file_permission = "755"
}