#!/bin/bash

# Create SSH keys to be used to access the OpenStack instances.
# This is helpful for having more control on security configuration.

set -eu

ssh_dir="${HOME}/.ssh"

input() {
    read -rp "$1: " value
    echo "$value"
}


echo "This utility will assist you in creating a valid SSH key."

mkdir -p "$ssh_dir"

key_tag=$(input 'Key tag')
echo

if [ -z "$key_tag" ]
then
    echo "Please specify a tag name for the key. Output will be ~/.ssh/ostack-TAGNAME-rsa-key."
    exit 1
fi

key_name="ostack-${key_tag}-rsa-key"

echo "Generating the key as ${ssh_dir}/${key_name} ..."
ssh-keygen -o -t rsa -b 4096 -C "OpenStack $key_tag" -f "${ssh_dir}/${key_name}" -N "" -q

ls -lh "${ssh_dir}/${key_name}"*

# Add private SSH key to known keys.
find ~/.ssh/ -type f -exec grep -l 'PRIVATE' {} \; | xargs ssh-add &> /dev/null

echo "Done"