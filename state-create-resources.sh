#!/bin/bash

RG_NAME=$STATE_RG_NAME
SA_NAME=${RG_NAME//-}
CONT_NAME=backup

# Create resource group
az group create --name "$RG_NAME" --location westeurope

# Create storage account
az storage account create \
  --name "$SA_NAME" \
  --resource-group "$RG_NAME" \
  --location westeurope \
  --sku Standard_LRS \
  --encryption-services blob

# Create container
az storage container create \
  --name "$CONT_NAME" \
  --account-name "$SA_NAME"