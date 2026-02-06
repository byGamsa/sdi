provider "dns" {
  update {
    server        = "ns1.sdi.hdm-stuttgart.cloud"
    key_name      = "${var.groupName}.key."
    key_algorithm = "hmac-sha512"
    key_secret    = var.dns_secret
  }
}

resource "dns_a_record_set" "workhorse" {
  name = var.serverName
  zone = "${var.dnsZone}."
  ttl = 10
  addresses = [var.serverIp]
}

resource "null_resource" "dns_root" {
  triggers = {
    server_ip = var.serverIp
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "server ns1.sdi.hdm-stuttgart.cloud
      update delete ${var.dnsZone}. A
      update add ${var.dnsZone}. 10 A ${var.serverIp}
      send" | nsupdate -y "hmac-sha512:${var.groupName}.key:${var.dns_secret}"
    EOT
  }
}

resource "dns_cname_record" "aliases" {
  count = length(var.serverAliases)
  name  = var.serverAliases[count.index]
  zone  = "${var.dnsZone}."
  ttl   = 10
  cname = "${var.serverName}.${var.dnsZone}."
  lifecycle {
    precondition {
      condition     = !contains(var.serverAliases, var.serverName)
      error_message = "Der Server-Name darf nicht gleichzeitig als Alias (CNAME) definiert sein."
    }
  }
}