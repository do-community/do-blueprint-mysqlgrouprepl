output "mysql-node-public-ips" {
  value = ["${digitalocean_droplet.mysql-node.*.ipv4_address}"]
}

output "mysql-node-private-ips" {
  value = ["${digitalocean_droplet.mysql-node.*.ipv4_address_private}"]
}

output "mysql-proxysql-public-ips" {
  value = ["${digitalocean_droplet.mysql-proxy.*.ipv4_address}"]
}

output "mysql-proxysql-private-ips" {
  value = ["${digitalocean_droplet.mysql-proxy.*.ipv4_address_private}"]
}
