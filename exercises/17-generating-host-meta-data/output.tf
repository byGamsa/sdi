output "ip_addr" {
  value       = hcloud_server.debian_server.ipv4_address
  description = "The server's IPv4 address"
}

output "datacenter" {
  value       = hcloud_server.debian_server.datacenter
  description = "The server's datacenter"
}