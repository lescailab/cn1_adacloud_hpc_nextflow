variable "name_prefix" {
  description = "The prefix to use for all resources"
  type        = string
  default     = "ohpc"
}

variable "ssh_tag" {
  description = "The tag to use for SSH key in in ~/.ssh/ostack-<ssh_tag>-rsa-key"
  type        = string
  default     = "slurm"
}

variable "share_size" {
  description = "The size in GB of the shared filesystem"
  type        = number
  default     = 10
}

variable "num_compute_nodes" {
  description = "The number of compute nodes to create"
  type        = number
  default     = 2
}

variable "use_separate_controller" {
  description = "Whether to use a separate controller node"
  type        = bool
  default     = false
}

variable "flavor_login_node" {
  description = "The instance flavor for the login nodes"
  type        = string
  default     = "fl.ada.xxs"
}

variable "flavor_compute_node" {
  description = "The instance flavor for the compute nodes"
  type        = string
  default     = "fl.ada.xs"
}

variable "flavor_controller_node" {
  description = "The instance flavor for the controller node (if enabled)"
  type        = string
  default     = "fl.ada.xxs"
}

variable "image_name" {
  description = "The image name to use for all instances"
  type        = string
  default     = "Rocky Linux 9.4"
}

variable "username" {
  description = "The username for SSH access"
  type        = string
  default     = "itsme"
}

variable "cidr" {
  description = "The CIDR to use for the network"
  type        = string
  default     = "10.26.1.0/24"
}

variable "shared_filesystem_type" {
  description = "Type of shared filesystem to use (manila or cinder)"
  type        = string
  default     = "manila" # Options: "manila", "cinder"
}

variable "cinder_volume_type" {
  description = "Type of volume in case of cinder shared filesystem to use (__DEFAULT__ for non crypted volume, LUKS for encrypted volume)."
  type        = string
  default     = "__DEFAULT__" # Options: "__DEFAULT__"; "LUKS" for encrypted volumes
}

variable "login_node_floating_ip" {
  description = "The fixed ip which will be used to communicate to the cluster, leave empty for automatic allocation."
  type        = string
  default     = ""
}
