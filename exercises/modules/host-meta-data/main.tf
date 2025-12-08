resource "local_file" "host_data" {
  content = templatefile("${path.module}/tpl/hostdata.json", {
    ip4      = var.ipv4Address
    ip6      = var.ipv6Address
    location = var.location
  })
  filename = "gen/${var.name}.json"
}