#!/usr/bin/env bash
# Operator host: Azure D8s_v5 (nested virtualization), Ubuntu 26.04, 128 GiB, SSH only from my IP.
source "$(dirname "$0")/lib.sh"
exec > >(tee "$RESULTS/10-deploy.txt") 2>&1
myip=$(curl -s https://ifconfig.me)
hdr "Resource group + VM"
az group create -n "$AZ_RG" -l "$AZ_LOCATION" --tags purpose=shirudo-lab -o none
az network nsg create -g "$AZ_RG" -n "$AZ_VM-nsg" -o none
az network nsg rule create -g "$AZ_RG" --nsg-name "$AZ_VM-nsg" -n ssh-from-me --priority 100 \
  --source-address-prefixes "$myip/32" --destination-port-ranges 22 --protocol Tcp --access Allow -o none
az vm create -g "$AZ_RG" -n "$AZ_VM" --image "$AZ_IMAGE" --size "$AZ_SIZE" \
  --os-disk-size-gb 128 --storage-sku Premium_LRS \
  --admin-username azureuser --ssh-key-values "$SSH_KEY.pub" \
  --public-ip-sku Standard --nsg "$AZ_VM-nsg" --custom-data "$LAB_DIR/infra/cloud-init.yaml" \
  --query '{ip:publicIpAddress,size:hardwareProfile}' -o json
echo "ssh allowed from $myip/32 only"
