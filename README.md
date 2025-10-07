# Slurm mini-HPC Cluster with Nextflow on ADA Cloud

This repository contains an **Infrastructure-as-Code** recipe for deploying a lightweight Slurm cluster on **CINECA’s ADA Cloud** that is ready to run **Nextflow pipelines** out of the box.

It uses **Terraform/OpenTofu** to provision the virtual machines, **Ansible** to install the **OpenHPC Slurm stack** and additional HPC tools such as **Docker**, **Micromamba**, and **Nextflow**, and provides a simple workflow for connecting to the login node and running example pipelines.

---

## Introduction

The mini-HPC cluster is designed for users who need a simple way to experiment with **Slurm** and **Nextflow** on ADA Cloud.

The cluster comprises:

- One login node exposing a floating IP address.
- A configurable number of compute nodes.
- An optional controller node (disabled by default).
- A shared `/home` filesystem exported via **Manila** or **Cinder**.

The deployment process is split into two phases:

1. **Provision the infrastructure** on ADA Cloud using Terraform/OpenTofu.  
2. **Configure the nodes** with Ansible, installing OpenHPC, Slurm and additional tools (Docker, Micromamba and Nextflow).

---

## Prerequisites

Before you begin, you will need:

- An **OpenStack project** on ADA Cloud. If you do not have one, contact [CINECA HPC Support](mailto:superc@cineca.it).  
- **OpenStack application credentials** for ADA Cloud.  
- A **GitLab personal access token** with `read_api` scope. Add it to `~/.terraformrc` so Terraform can download CINECA’s private modules.  
- Local tools: `Git`, `Terraform` (or `OpenTofu`), `Ansible`, and an SSH client.  
- An **SSH key**. Use `scripts/sshkeygen.sh` to generate a key pair and specify its tag via the `ssh_tag` variable.

---

## Provisioning

### 1. Clone and Configure

Clone this repository and copy the variable template:

~~~bash
git clone https://github.com/lescailab/cn1_adacloud_hpc_nextflow.git
cd cn1_adacloud_hpc_nextflow/provisioning
mkdir -p conf
cp conf/cluster.tfvars.tpl conf/cluster.tfvars
~~~

Edit `conf/cluster.tfvars` to set your cluster parameters. Important variables include:

| Variable | Description |
|-----------|--------------|
| `name_prefix` | Prefix for all resource names. |
| `ssh_tag` | Tag of the SSH key generated earlier. |
| `username` | User account created on the VMs. |
| `num_compute_nodes` | Number of compute nodes (default: 2). |
| `use_separate_controller` | Create a dedicated controller node if `true`. |
| `shared_filesystem_type` | `"manila"`, `"cinder"` or encrypted `"cinder"`. |
| `share_size` | Size of the shared filesystem in GB. |
| `login_node_floating_ip` | Optional existing floating IP to assign to the login node. |

---

### 2. Initialize and Apply

From the `provisioning` directory run:

~~~bash
terraform init
terraform apply -var-file=conf/cluster.tfvars
~~~

Terraform creates the network, volume, security groups, and virtual machines.  
When complete it outputs `login_node_floating_ip`, which you will use to connect to the cluster.  
A file `inventory.ini` is also created for Ansible.

---

### 3. Select Storage Type

The cluster exports a shared `/home` filesystem. You can choose between:

- **Manila share (default)** – requires authorization to create generic shares.  
- **Cinder volume** – set `shared_filesystem_type="cinder"` and specify `share_size`.  
- **Encrypted Cinder volume** – set `cinder_volume_type="LUKS"`.

---

## Installation and Configuration

### 1. Install Ansible Roles

After provisioning, install the required roles:

~~~bash
cd provisioning
ansible-galaxy role install -fr requirements.yml -p playbooks/roles
~~~

---

### 2. Configure the Cluster

Run the main playbook:

~~~bash
ansible-playbook playbooks/main.yml -i inventory.ini
~~~

This playbook:

- Installs **OpenHPC** and configures **Slurm** on the login, controller, and compute nodes.  
- Installs **Docker CE**, **Micromamba**, and **Nextflow**.  
- Ensures **Java 17** is available and downloads the **Nextflow binary** to `/usr/local/bin`.

---

## Usage

### Connect to the Cluster

SSH to the login node using the floating IP printed by Terraform:

~~~bash
ssh -i ~/.ssh/ostack-<ssh_tag>-rsa-key <username>@<login_node_floating_ip>
~~~

List node status:

~~~bash
sinfo -N
~~~

Start an interactive session on a compute node:

~~~bash
srun --pty bash
~~~

---

### Run Nextflow

Nextflow is installed globally and can be invoked directly.  
The simplest workflow is the built-in **Hello World** example.

Create a file named `hello-world.nf` on the login node with the following content:

~~~groovy
nextflow.enable.dsl=2

process sayHello {
    output:
        path 'output.txt'
    """
    echo 'Hello, World!' > output.txt
    """
}

workflow {
    sayHello()
}
~~~

Run it locally to verify your installation:

~~~bash
nextflow run hello-world.nf
~~~

You should see the `sayHello` process complete successfully and find `output.txt` in the work directory.

To execute workflows via **Slurm**, create a `nextflow.config` file specifying:

~~~groovy
process.executor = 'slurm'
~~~

and other cluster options, then run:

~~~bash
nextflow run <pipeline> -c nextflow.config
~~~

Published pipelines such as `nf-core/rnaseq` can be executed with appropriate profiles (e.g. `-profile test,docker`).

---

## Clean Up

Destroy your resources when finished:

~~~bash
terraform destroy -var-file=conf/cluster.tfvars
~~~

---

## Important Notice

The code in this repository is property of **CINECA** and is released under the **Apache License**.  
It has been tested only on **ADA Cloud**.

For support contact **CINECA HPC User Support**: [superc@cineca.it](mailto:superc@cineca.it)

---

## References

- [Repository on GitHub](https://github.com/lescailab/cn1_adacloud_hpc_nextflow)  
- [Hello World Tutorial](https://training.nextflow.io/2.1.1/hello_nextflow/01_hello_world/)