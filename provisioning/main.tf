locals {
  # general
  common_tags = ["ada", "cineca", "dev"]
  ssh_pub_key = "~/.ssh/ostack-${var.ssh_tag}-rsa-key.pub" # Custom user cloud-init
}

#========================================
# Network
locals {
  # CIDRs
  any_ip      = "0.0.0.0/0"
  #my_vpn    = "XXX.XXX.XXX.XX/XX" # Customize!
}

module "mini_hpc_network" {
  source  = "gitlab.hpc.cineca.it/adacloud/network/openstack"
  version = "1.0.0"

  name = "${var.name_prefix}-mini-hpc"
  subnets = [
    {
      name = "${var.name_prefix}-mini-hpc"
      cidr = var.cidr
      dns_nameservers = [
        "8.8.8.8", # Google
        "1.1.1.1", # Cloudflare
      ]
    }
  ]
}

module "mini_hpc_router" {
  source  = "gitlab.hpc.cineca.it/adacloud/router/openstack"
  version = "1.0.0"

  is_external = true
  name        = "${var.name_prefix}-mini-hpc"
}

resource "openstack_networking_router_interface_v2" "mini_hpc_assign" {
  router_id = module.mini_hpc_router.id
  subnet_id = module.mini_hpc_network.subnets[0].id
}

#========================================
# Security groups

locals {
  ping_any = {
    description = "Ping from any IP."
    direction   = "ingress"
    protocol    = "icmp"
    allowed_ip  = local.any_ip
  }

  ssh_any = {
    description = "SSH from any IP."
    direction   = "ingress"
    protocol    = "tcp"
    port        = 22
    allowed_ip  = local.any_ip
  }
  #ssh_my_vpn = {
  #  description = "SSH from my VPN."
  #  direction   = "ingress"
  #  protocol    = "tcp"
  #  port        = 22
  #  allowed_ip  = local.my_vpn # Customize before uncommenting!
  #}

  http_any = {
    description = "HTTP rule."
    direction   = "ingress"
    protocol    = "tcp"
    port        = 80
    allowed_ip  = local.any_ip
  }

  open_tcp_in_cluster = {
    description = "Open all TCP ports in the cluster."
    direction   = "ingress"
    protocol    = "tcp"
    port_range_min = 0
    port_range_max = 0
    allowed_ip  = var.cidr
  }

  # See here the documentation for the SLURM ports: https://slurm.schedmd.com/network.html
  # slurmctld = {
  #   description = "SLURM Controller port."
  #   direction   = "ingress"
  #   protocol    = "tcp"
  #   port        = 6817
  #   allowed_ip  = local.any_ip
  # }

  # slurmd = {
  #   description = "SLURM daemon port."
  #   direction   = "ingress"
  #   protocol    = "tcp"
  #   port        = 6818
  #   allowed_ip  = local.any_ip
  # }

  # slurmdbd = {
  #   description = "SLURM Database daemon port."
  #   direction   = "ingress"
  #   protocol    = "tcp"
  #   port        = 6819
  #   allowed_ip  = local.any_ip
  # }
}

module "nodes_secgroup" {
  source  = "gitlab.hpc.cineca.it/adacloud/security-group/openstack"
  version = "1.0.0"

  description = "Enable access to the virtual machines."
  name        = "${var.name_prefix}-nodes"
  rules       = [local.ping_any, local.ssh_any, local.open_tcp_in_cluster]
}

#========================================
# Cluster compute

locals {

  login = [{
    name = "${var.name_prefix}-login",
    ip   = cidrhost(module.mini_hpc_network.subnets[0].cidr, 200)
  }]

  compute = [
    for i in range(var.num_compute_nodes) : {
      name = format("${var.name_prefix}-node-%02d", i),
      ip   = cidrhost(module.mini_hpc_network.subnets[0].cidr, 50 + i)
    }
  ]

  controller = [
    for i in range(var.use_separate_controller ? 1 : 0) : {
      name = "${var.name_prefix}-controller",
      ip   = cidrhost(module.mini_hpc_network.subnets[0].cidr, 201)
    }
  ]

  hosts = concat(local.login, local.compute, local.controller)

  login_cloud_config_file = format("%s/cloud-init/%s", path.root, var.shared_filesystem_type == "cinder" ? "login-cinder.yaml" : "node.yaml")
  compute_cloud_config_file = format("%s/cloud-init/%s", path.root, "node.yaml")
  controller_cloud_config_file = format("%s/cloud-init/%s", path.root, "node.yaml")
}


module "login_node_config" {
  source  = "gitlab.hpc.cineca.it/adacloud/cloud-config-cloud-init/openstack"
  version = "1.0.0"
  config_content = templatefile(local.login_cloud_config_file,
    {
      node_type    = "login"
      username     = var.username
      ssh_pub_keys = [file(local.ssh_pub_key)] 
      hostname     = local.login[0].name
      upgrade      = true
      packages     = ["nfs-utils"]
      share_export_path  = var.shared_filesystem_type == "manila" ? module.manila_share[0].share_export_path : null
      cinder_volume_size_gb = var.share_size
      hosts_list = local.hosts
    }
  )
}

module "compute_node_config" {
  source  = "gitlab.hpc.cineca.it/adacloud/cloud-config-cloud-init/openstack"
  version = "1.0.0"
  count = var.num_compute_nodes
  config_content = templatefile(local.compute_cloud_config_file,
    {
      node_type    = "compute"
      username     = var.username
      ssh_pub_keys = [file(local.ssh_pub_key)] 
      hostname     = local.compute[count.index].name
      upgrade      = true
      packages     = ["nfs-utils"]
      share_export_path  = var.shared_filesystem_type == "manila" ? module.manila_share[0].share_export_path : "${local.login[0].ip}:/home"
      hosts_list   = local.hosts
    }
  )
}

module "login_node" {
  source  = "gitlab.hpc.cineca.it/adacloud/compute/openstack"
  version = "2.1.0"
  name      = local.login[0].name
  node_tags = concat(local.common_tags, ["slurm", "mini-hpc", "login"])
  flavor_name          = var.flavor_login_node
  boot_disk_image_name = var.image_name
  security_group_ids = [module.nodes_secgroup.id]
  machine_config       = module.login_node_config.rendered
  network_id = module.mini_hpc_network.id
  network_subnet_id = module.mini_hpc_network.subnets[0].id
  network_fixed_ip_v4 = local.login[0].ip
  assign_floating_ip = var.login_node_floating_ip == ""
}

# Associate the floating IP with login node port
resource "openstack_networking_floatingip_associate_v2" "login_node_floating_ip_associate" {
  count = var.login_node_floating_ip != "" ? 1 : 0
  floating_ip = var.login_node_floating_ip
  port_id     = module.login_node.port_id
}

module "compute_nodes" {
  source  = "gitlab.hpc.cineca.it/adacloud/compute/openstack"
  version = "2.1.0"
  count = var.num_compute_nodes
  name      = local.compute[count.index].name
  node_tags = concat(local.common_tags, ["slurm", "mini-hpc"])
  flavor_name          = var.flavor_compute_node
  boot_disk_image_name = var.image_name
  security_group_ids = [module.nodes_secgroup.id]
  machine_config       = module.compute_node_config[count.index].rendered
  network_id = module.mini_hpc_network.id
  network_subnet_id = module.mini_hpc_network.subnets[0].id
  network_fixed_ip_v4 = local.compute[count.index].ip
  depends_on = [module.login_node]
}

# Conditionally create the slurm-controller instance
module "controller_node_config" {
  count = var.use_separate_controller ? 1 : 0
  source  = "gitlab.hpc.cineca.it/adacloud/cloud-config-cloud-init/openstack"
  version = "1.0.0"
  config_content = templatefile(local.controller_cloud_config_file,
    {
      node_type    = "controller"
      username     = var.username
      ssh_pub_keys = [file(local.ssh_pub_key)] 
      hostname     = local.controller[0].name
      upgrade      = true
      packages     = ["nfs-utils"]
      share_export_path  = var.shared_filesystem_type == "manila" ? module.manila_share[0].share_export_path : "/home"
      hosts_list   = local.hosts
      nfs_server_ip = local.login[0].ip
    }
  )
}


module "controller_node" {
  count = var.use_separate_controller ? 1 : 0
  source = "gitlab.hpc.cineca.it/adacloud/compute/openstack"
  version = "2.1.0"
  name = local.controller[0].name
  node_tags = concat(local.common_tags, ["slurm", "mini-hpc", "controller"])
  flavor_name = var.flavor_controller_node
  boot_disk_image_name = var.image_name
  security_group_ids = [module.nodes_secgroup.id]
  machine_config = module.controller_node_config[0].rendered
  network_id = module.mini_hpc_network.id
  network_subnet_id = module.mini_hpc_network.subnets[0].id
}

# Shared FS
locals {
  all_ip = var.use_separate_controller ? concat([module.login_node.private_ip], [module.controller_node[0].private_ip], module.compute_nodes[*].private_ip) : concat([module.login_node.private_ip], module.compute_nodes[*].private_ip)
}
# Manila share
module "manila_share" {
  count = var.shared_filesystem_type == "manila" ? 1 : 0
  source = "gitlab.hpc.cineca.it/adacloud/share/openstack"
  version = "1.0.0"
  name = "${var.name_prefix}-share"
  protocol = "NFS"
  access_type = "ip"
  access_level = "rw"
  private_ip_computes = local.all_ip
  size = var.share_size
  network = {
    id = module.mini_hpc_network.id
    subnet_id = module.mini_hpc_network.subnets[0].id
  }
}

# Cinder share
resource "openstack_blockstorage_volume_v3" "shared_volume" {
  count = var.shared_filesystem_type == "cinder" ? 1 : 0
  name = "${var.name_prefix}-shared-volume"
  size = var.share_size
  volume_type = var.cinder_volume_type
}

resource "openstack_compute_volume_attach_v2" "attach_shared_volume" {
  count = var.shared_filesystem_type == "cinder" ? 1 : 0
  instance_id = module.login_node.id
  volume_id   = openstack_blockstorage_volume_v3.shared_volume[0].id
}

# Ansible inventory
locals {
  bastion_host = var.login_node_floating_ip == "" ? module.login_node.floating_ip : var.login_node_floating_ip
}

module "inventory_group_all" {
  source = "gitlab.hpc.cineca.it/adacloud/inventory-group/ansible"
  version = "1.0.0"
  name = "all"
  variables = {
    ansible_user = var.username
    ansible_ssh_private_key_file = replace(local.ssh_pub_key, ".pub", "")
    ansible_python_interpreter = "/usr/bin/python3",
    bastion_host = local.bastion_host
  }
}

module "inventory_group_openhpc_login" {
  source = "gitlab.hpc.cineca.it/adacloud/inventory-group/ansible"
  version = "1.0.0"
  name  = "openhpc_login"
  hosts = [module.login_node.name]
  # Here the ip is needed because the hostname of the login node is not resolvable from the login node itself
  variables = {
    ansible_host = local.bastion_host
    ansible_ssh_common_args = "-o StrictHostKeyChecking=no"
  }
}

module "inventory_group_openhpc_compute" {
  source = "gitlab.hpc.cineca.it/adacloud/inventory-group/ansible"
  version = "1.0.0"
  name  = "openhpc_compute"
  hosts = [for host in local.compute[*].name : host]
  variables = {
    ansible_ssh_common_args = "-J ${var.username}@${local.bastion_host} -o StrictHostKeyChecking=no"
  }
}

module "inventory_group_openhpc_controller" {
  count = var.use_separate_controller ? 1 : 0
  source = "gitlab.hpc.cineca.it/adacloud/inventory-group/ansible"
  version = "1.0.0"
  name  = "openhpc_control"
  hosts = [module.controller_node[0].name]
  variables = {
    ansible_ssh_common_args = "-J ${var.username}@${local.bastion_host} -o StrictHostKeyChecking=no"
  }
}

module "inventory_group_cluster_login" {
  source = "gitlab.hpc.cineca.it/adacloud/inventory-group/ansible"
  version = "1.0.0"
  name  = "cluster_login"
  children = ["openhpc_login"]
}

module "inventory_group_cluster_control" {
  source = "gitlab.hpc.cineca.it/adacloud/inventory-group/ansible"
  version = "1.0.0"
  name  = "cluster_control"
  children = [var.use_separate_controller ? "openhpc_control" : "openhpc_login"]
}

module "inventory_group_cluster_batch" {
  source = "gitlab.hpc.cineca.it/adacloud/inventory-group/ansible"
  version = "1.0.0"
  name  = "cluster_batch"
  children = ["openhpc_compute"]
}


resource "local_file" "ansible_inventory" {
  filename = "inventory.ini"
  file_permission = 0655
  content = join("\n", [
    module.inventory_group_all.rendered,
    module.inventory_group_openhpc_login.rendered,
    module.inventory_group_openhpc_compute.rendered,
    var.use_separate_controller ? module.inventory_group_openhpc_controller[0].rendered : "",
    module.inventory_group_cluster_login.rendered,
    module.inventory_group_cluster_control.rendered,
    module.inventory_group_cluster_batch.rendered
  ])
}