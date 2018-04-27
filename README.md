## MySQL Group Replication with ProxySQL

Welcome to the MySQL Group Replication Blueprint repository.  This repository can be used to quickly set up a replicated database group using [MySQL group replication](https://dev.mysql.com/doc/refman/5.7/en/group-replication.html) to scale read requests and help ensure availability.  Access to the group is provided by [ProxySQL](http://www.proxysql.com/), a powerful, flexible routing component that can intelligently route queries and respond to changes on the backend.

This process should take between five to ten minutes.

By default, after cloning the project and executing the Terraform and Ansible steps described below, you will have a three member group replication database layer to handle your project's data.  The Blueprint will also create a server with ProxySQL installed and configured to connect with the group.  Due to security considerations, this component is best installed on the same server as your application server.

## Architecture of MySQL Group Replication Blueprint

![Architecture diagram of MySQL group replication blueprint]()

* **3** 1GB Droplets for MySQL group replication members
	* Specs: 1 VCPU, 1GB memory, and 25GB SSD
	* Datacenter: NYC3
	* OS: Ubuntu 16.04
	* Software: MySQL server (upstream package)

* **1** 1GB Droplet for the ProxySQL routing component
	* Specs: 1 VCPU, 1GB memory, and 25GB SSD
	* Datacenter: NYC3
	* OS: Ubuntu 16.04
	* Software: ProxySQL

Using the given Droplet sizes, **this infrastructure will cost $20 a month** to run.

In addition to the above software packages, a demonstration database called `playground` will be configured on the backend loaded with a small amount of dummy data.  An associated user called `playgrounduser` will be configured within MySQL and within the ProxySQL routing component.

## Quickstart

Here are the steps to get up and running.

### Requirements

The software required to run DigitalOcean Blueprints are provided within a Docker image.  You will need to install Docker locally to run these playbooks.  You can find up-to-date instructions on how to download and install Docker on your computer [on the Docker website](https://www.docker.com/community-edition#/download).

If you'd prefer not to install Docker locally, you can create a dedicated control Droplet using the [DigitalOcean Docker One-click application](https://www.digitalocean.com/products/one-click-apps/docker/) instead.  You will also need [git](https://git-scm.com/downloads) available if it's not already installed.

### Clone the Repo

To get started, clone this repository to your Docker server into a writeable directory:

```
cd ~
git clone https://github.com/do-community/do-blueprint-mysqlgrouprepl
```

### Add a Bash Alias for the Infrastructure Tools Docker Container

Open your shell configuration file using your preferred text editor:

```
nano ~/.bashrc
```

Inside, at the bottom, add a function and definition for `complete` to simplify usage of the Docker image:

```
. . .
function bp() {
    docker run -it --rm \
    -v "${PWD}":"/blueprint" \
    -v "${HOME}/.terraform.d":"/root/.terraform.d" \
    -v "${HOME}/.bp-ssh":"/root/.bp-ssh" \
    -v "${HOME}/.config":"/root/.config" \
    -e ANSIBLE_TF_DIR='./terraform' \
    -e HOST_HOSTNAME="${HOSTNAME}" \
    -e HOST_UID="$(id -u)" \
    -e HOST_GID="$(id -g)" \
    docommunity/bp "$@"
}

complete -W "terraform doctl ./terraform.py ansible ansible-connection ansible-doc ansible-inventory ansible-pull ansible-config ansible-console ansible-galaxy ansible-playbook ansible-vault" "bp"
```

Save and close the file when you are finished.  Source the file to read in the new function to your current session:

```
source ~/.bashrc
```

### Run the `setup.yml` Local Playbook

Next, enter the repository directory and run the `setup.yml` playbook.  This will configure the local repository and credentials.

*Note*: The initial run of this playbook may show some warnings since the Ansible dynamic inventory script cannot yet find a valid state file from Terraform.  This is expected and the warnings will not be present once a Terraform state file is created.

```
bp ansible-playbook setup.yml
```

Enter your DigitalOcean read/write API key if prompted (you can generate a read/write API key by visiting the [API section of the DigitalOcean Control Panel](https://cloud.digitalocean.com/settings/api/tokens) and clicking "Generate New Token").  Confirm the operation to create a dedicated SSH key pair by typing "yes" at when prompted.  As part of this configuration, a dedicated SSH key pair will be generated for managing Blueprints infrastructure and added to your DigitalOcean account.

The playbook will:

* Check the `doctl` configuration to try to find an existing DigitalOcean API key
* Prompt you to enter an API key if it could not find one in the `doctl` configuration
* Check if a dedicated `~/.ssh/blueprint-id_rsa` SSH key pair is already available locally.
* Generate the `~/.ssh/blueprint-id_rsa` key pair if required and add it to your DigitalOcean account.
* Install the Terraform Ansible provider and the associated Ansible dynamic inventory script that allows Ansible to read from the Terraform state file
* Generate a `terraform/terraform.tfvars` file with your DigitalOcean API key and SSH key defined
* Initialize the `terraform` directory so that it's ready to use.
* Install the Ansible roles needed to run the main playbook.

Once the `setup.yml` playbook has finished, follow the instructions in the final output to complete the configuration.  Adjust the ownership of the generated SSH keys:

```
sudo chown $USER:$USER ~/.ssh/blueprint-id_rsa*
```

You can optionally add the key to your local SSH agent:

```
eval `ssh-agent`
ssh-add ~/.ssh/blueprint-id_rsa
```

Otherwise, when SSHing into your Blueprint infrastructure, you will need to pass in the appropriate SSH key using the `-i` flag:

```
ssh -i ~/.ssh/blueprint-id_rsa <username>@<server_ip>
```

### Create the Infrastructure

Move into the `terraform` directory.  Adjust the `terraform.tfvars` and `main.tf` file if necessary (to adjust the number or size of your servers for instance).  When you are ready, create your infrastructure with `terraform apply`:

```
cd terraform
bp terraform apply
```

Type `yes` to confirm the operation.

### Apply the Configuration

Move back to the main repository directory.  Use the `ansible -m ping` command to check whether the hosts are accessible yet:

```
bp ansible -m ping all
```

This command will return failures if the servers are not yet accepting SSH connections or if the userdata script that installs Python has not yet completed.  Run the command again until these failures disappear from all hosts.

Once the hosts are pinged successfully, apply the configuration with the `ansible-playbook` command. The infrastructure will be configured primarily using the values of the variables set in the `group_vars` directory and in the role defaults:

```
bp ansible-playbook site.yml
```

### Accessing the Hosts

To display the IP addresses for your infrastructure, you can run the `./terraform.py` script manually by typing:

```
bp ./terraform.py
```

Among other information, you should be able to see the IP addresses of each of your servers:

```
  . . .
  "_meta": {
    "hostvars": {
      "mysql-node-1": {
        "ansible_host": "198.51.100.5"
      }, 
      "mysql-proxy-1": {
        "ansible_host": "198.51.100.6"
      }, 
      "mysql-node-3": {
        "ansible_host": "198.51.100.7"
      }, 
      "mysql-node-2": {
        "ansible_host": "198.51.100.8"
      }
    }
  }
}
```

### Testing the Deployment

Once the infrastructure is configured, you can SSH into the ProxySQL server to check the setup.  SSH into the ProxySQL host from the computer with your Blueprint repository (this machine will have the correct SSH credentials).

Afterwards, you can use ProxySQL in the following ways:

#### Connect through ProxySQL to the playground database

Connect to the demonstration database by using the connection information in the `playgrounduser.cnf` defaults file, located in the `root` user's home diretory by default:

```
mysql --defaults-file=playgrounduser.cnf
```

From here, you can view the contents of the sample table:

```
SELECT * FROM playground.equipment;
```
```
+----+--------+-------+--------+
| id | type   | quant | color  |
+----+--------+-------+--------+
|  1 | slide  |     2 | blue   |
|  8 | swing  |    10 | yellow |
| 15 | seesaw |     3 | green  |
+----+--------+-------+--------+
3 rows in set (0.00 sec)
```

Writing to the table should also work correctly.  ProxySQL will ensure that the operation goes to the primary write server:

```
INSERT INTO playground.equipment (type, quant, color) VALUES ('ladder', 4, 'orange');
```
```
Query OK, 1 row affected (0.00 sec)
```

If you exit back into the shell, you can see ProxySQL cycle through the backend pool of read-only hosts for non-write operations:

```
mysql --defaults-file=playgrounduser.cnf -e 'select @@hostname'
```
```
+--------------+
| @@hostname   |
+--------------+
| mysql-node-2 |
+--------------+
```

Issuing the command a few more times will usually cycle through other backends (some repeats may occur, but that's generally okay):

```
mysql --defaults-file=playgrounduser.cnf -e 'select @@hostname'
```
```
+--------------+
| @@hostname   |
+--------------+
| mysql-node-3 |
+--------------+
```

#### Connect to the ProxySQL administration interface

You can connect to the ProxySQL administration interface to manage the ProxySQL instance and query MySQL group health data.  This will use the primary defaults file for the `root` user automatically:

```
mysql
```

From here, you view information about your ProxySQL configuration by querying the tables available.  For instance, to view the connected backends, type:

```
SELECT * FROM runtime_mysql_servers;
```
```
+--------------+----------------+------+--------+--------+-------------+-----------------+---------------------+---------+----------------+---------+
| hostgroup_id | hostname       | port | status | weight | compression | max_connections | max_replication_lag | use_ssl | max_latency_ms | comment |
+--------------+----------------+------+--------+--------+-------------+-----------------+---------------------+---------+----------------+---------+
| 2            | 198.51.100.5   | 3306 | ONLINE | 1      | 0           | 1000            | 0                   | 1       | 0              |         |
| 3            | 198.51.100.7   | 3306 | ONLINE | 1      | 0           | 1000            | 0                   | 1       | 0              |         |
| 3            | 198.51.100.5   | 3306 | ONLINE | 1      | 0           | 1000            | 0                   | 1       | 0              |         |
| 3            | 198.51.100.8   | 3306 | ONLINE | 1      | 0           | 1000            | 0                   | 1       | 0              |         |
+--------------+----------------+------+--------+--------+-------------+-----------------+---------------------+---------+----------------+---------+
4 rows in set (0.00 sec)
```

Here, you can see four rows representing three servers (one of the servers is in both the 2 and 3 host groups).  To see what these hostgroup IDs represent, query the associated table:

```
select * from runtime_mysql_group_replication_hostgroups;
```
```
+------------------+-------------------------+------------------+-------------------+--------+-------------+-----------------------+-------------------------+---------+
| writer_hostgroup | backup_writer_hostgroup | reader_hostgroup | offline_hostgroup | active | max_writers | writer_is_also_reader | max_transactions_behind | comment |
+------------------+-------------------------+------------------+-------------------+--------+-------------+-----------------------+-------------------------+---------+
| 2                | 4                       | 3                | 1                 | 1      | 1           | 1                     | 100                     | NULL    |
+------------------+-------------------------+------------------+-------------------+--------+-------------+-----------------------+-------------------------+---------+
1 row in set (0.01 sec)
```

With this mapping, we can see that the group is configured to allow both reads and writes to go to the primary host, while the other hosts are only capable of accepting reads.

You can learn more about how the ProxySQL model of operation by reading [the project's wiki pages](https://github.com/sysown/proxysql/wiki).

### Deprovisioning the Infrastructure

To destroy all of the servers in this Blueprint, move into the `terraform` directory again and use the `destroy` action:

```
cd terraform
bp terraform destroy
```

You will be prompted to confirm the action.  While you can easiliy spin up the infrastructure again using the Terraform and Ansible steps, keep in mind that any data you added will be lost on deletion.

## Ansible Roles

This repository uses the following roles to configure the MySQL group replication and ProxySQL servers:

* [MySQL group replication role](https://github.com/do-community/ansible-role-mysql)
* [ProxySQL role](https://github.com/do-community/ansible-role-proxysql)

You can read the README files associated with each role to understand how to adjust the configuration.

## How Do I Use This With My Existing Infrastructure?

If you already have an application server or servers, you can adapt the `terraform/main.tf` file to your needs.  You will want to remove the `mysql-proxy` `digitalocean_droplet` resource (which provisions a new application server) and set the `ansible_mysql_proxy` `ansible_host` resource to use the hostname and IP address of your existing infrastructure.  The `inventory_hostname` should be set to the name you want to use within Ansible and `ansible_host` should be set to the server's IP address.  You can configure as many of these resources as required.

If you already have a database server, you will need to dump the existing data to a file and then import it into the cluster.  This can be done manually once the cluster is provisioned, or can be done by Ansible if you place a dump file per database into the top-level `files` directory and configure the `mysql_databases` Ansible variable to load each file.

## Customizing this Blueprint

You can customize this Blueprint in a number of ways depending on your needs.

### Modifying Infrastructure Scale

**Note:** Adjusting the scale will affect the cost of your deployment.

To adjust the scale of your infrastructure, open the `terraform/main.tf`file in a text editor:

```
nano terraform/main.tf
```

You can change the number of MySQL group replication members involved in your database layer by adjusting the `count` parameter in the `digitalocean_droplet` definition for the `mysql-node` resources:

```
. . .
resource "digitalocean_droplet" "mysql-node" {
  count     = "3"
  . . .
```

Read the [MySQL documentation on group replication fault tolerance](https://dev.mysql.com/doc/refman/5.7/en/group-replication-fault-tolerance.html) to understand the ways different configurations affect availability.  You should always deploy an odd number of MySQL servers to balance primary election majorities with fault tolerance.  According to the documentation, [a maximum of nine members are permitted](https://dev.mysql.com/doc/refman/5.7/en/group-replication-frequently-asked-questions.html#group-replication-maximum-number-servers).

To deploy more ProxySQL nodes, adjust the `count` parameter in the `digitalocean_droplet` definition for the `mysql-proxy` resources:

```
. . .
resource "digitalocean_droplet" "mysql-proxy" {
  count     = "1"
  . . .
```

This will create additional servers with ProxySQL configured to access your group.  Usually, these servers should be configured with your application software after the ProxySQL service has been configured.

To vertically scale either the MySQL servers or the ProxySQL application servers, you can adjust the `size` parameter associated with the instances.  Use `bp doctl compute size list` to get a list of available Droplet sizes.

### Adjusting the Software Configuration

To adjust the way MySQL group replication or ProxySQL are deployed you need to modify the parameters that the Ansible playbook uses to configure each service.  The Ansible configuration for these components is primarily defined within the top-level `group_vars` directory and in the role defaults files (found in `roles/<role_name>/defaults/main.yml` after running the `setup.yml` playbook).

Configuration items that are needed by both MySQL and ProxySQL servers are defined in `group_vars/all.yml`  These variables typically use a `shared_` prefix and are referenced in the more specific `group_vars` files and to translate them to the variables the individual roles expect.  The `group_vars/mysql_nodes.yml` file is used to define configuration specific to the MySQL group members.  The `group_vars/mysql_proxy.yml` file is used to define configuration specific to the ProxySQL servers.

To understand what each variable means and how they work, read the variable descriptions within the README files associated with the individual roles.
