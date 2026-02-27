output "ip_addr" {
  value       = hcloud_server.helloServer[*].ipv4_address
  description = "The server's IPv4 address"
}

output "datacenter" {
  value       = hcloud_server.helloServer[*].datacenter
  description = "The server's datacenter"
}