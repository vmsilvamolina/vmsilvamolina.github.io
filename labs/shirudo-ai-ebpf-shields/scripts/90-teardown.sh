#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
az group delete -n "$AZ_RG" --yes --no-wait && echo "resource group $AZ_RG deletion started"
