provider "digitalocean" {
  token = "${var.do_token}"
}

# Blueprint tags

resource "digitalocean_tag" "bp" {
  name = "bp"
}

resource "digitalocean_tag" "bp-mysqlgrouprepl" {
  name = "bp-mysqlgrouprepl"
}

resource "digitalocean_tag" "bp-mysqlgrouprepl-mysql" {
  name = "bp-mysqlgrouprepl-mysql"
}

resource "digitalocean_tag" "bp-mysqlgrouprepl-proxysql" {
  name = "bp-mysqlgrouprepl-proxysql"
}

# Droplet resources

resource "digitalocean_droplet" "mysql-node" {
  count              = "3"
  name               = "mysql-node-${count.index + 1}"
  image              = "ubuntu-16-04-x64"
  region             = "nyc3"
  size               = "s-1vcpu-1gb"
  private_networking = true
  ssh_keys           = ["${var.ssh_keys}"]

  tags = [
    "${digitalocean_tag.bp.id}",
    "${digitalocean_tag.bp-mysqlgrouprepl.id}",
    "${digitalocean_tag.bp-mysqlgrouprepl-mysql.id}",
  ]

  user_data = "${file("${path.module}/files/userdata")}"
}

resource "digitalocean_droplet" "mysql-proxy" {
  count              = "1"
  name               = "mysql-proxy-${count.index + 1}"
  image              = "ubuntu-16-04-x64"
  region             = "nyc3"
  size               = "s-1vcpu-1gb"
  private_networking = true
  ssh_keys           = ["${var.ssh_keys}"]

  tags = [
    "${digitalocean_tag.bp.id}",
    "${digitalocean_tag.bp-mysqlgrouprepl.id}",
    "${digitalocean_tag.bp-mysqlgrouprepl-proxysql.id}",
  ]

  user_data = "${file("${path.module}/files/userdata")}"
}

# Resources for the Ansible dynamic inventory script

resource "ansible_host" "ansible_mysql_node" {
  count              = "${digitalocean_droplet.mysql-node.count}"
  inventory_hostname = "${digitalocean_droplet.mysql-node.*.name[count.index]}"
  groups             = ["mysql_nodes"]

  vars {
    ansible_host = "${digitalocean_droplet.mysql-node.*.ipv4_address[count.index]}"
  }
}

resource "ansible_host" "ansible_mysql_proxy" {
  count              = "${digitalocean_droplet.mysql-proxy.count}"
  inventory_hostname = "${digitalocean_droplet.mysql-proxy.*.name[count.index]}"
  groups             = ["mysql_proxy"]

  vars {
    ansible_host = "${digitalocean_droplet.mysql-proxy.*.ipv4_address[count.index]}"
  }
}
