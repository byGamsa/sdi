output "ip_addr" {
  value       = hcloud_server.gateway.ipv4_address
  description = "The server's IPv4 address"
}

output "datacenter" {
  value       = hcloud_server.gateway.datacenter
  description = "The server's datacenter"
}