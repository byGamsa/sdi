locals {
  target_host = var.hostname != null && var.hostname != "" ? var.hostname : var.ipv4Address
}

resource "local_file" "known_hosts" {
  content = join(" "
    ,[ var.ipv4Address
    , var.public_key ]
  )
  filename        = "gen/known_hosts"
}

resource "local_file" "ssh_script" {
  content = templatefile("${path.module}/tpl/ssh.sh", {
    ip = var.ipv4Address
    devopsUsername = var.login_user
  })
  filename = "bin/ssh_${local.target_host}"
  file_permission = "755"
}

resource "local_file" "scp_script" {
  content = templatefile("${path.module}/tpl/scp.sh", {
    ip = var.ipv4Address
    devopsUsername = var.login_user
  })
  filename = "bin/scp_${local.target_host}"
  file_permission = "755"
}