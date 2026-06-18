#!/bin/bash
# STATE-restore.sh
# Restore and decrypt terraform.STATE and terraform.STATE.backup from Azure Blob Storage

read -p "Are you sure you want to continue and override state with remote from $STATE_CONT_NAME? (y/n): " answer

if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
    echo "Proceeding..."
else
    echo "Aborted."
    exit 1
fi

BACKUP_FILE=backup-$(pulumi stack --show-name).json

# --- Configuration ---
RESOURCE_GROUP=$STATE_RG_NAME
STORAGE_ACCOUNT=${RESOURCE_GROUP//-}
CONTAINER_NAME=backup
OVERWRITE=true

# Pre-shared encryption key (32 bytes for AES-256)
# Export this before running: export STATE_ENC_KEY="your32bytekey"
ENC_KEY=$STATE_ENC_KEY
if [[ -z "$ENC_KEY" ]]; then
  echo "Error: STATE_ENC_KEY environment variable not set"
  exit 1
fi

# Temporary encrypted filenames
ENC_FILE="${BACKUP_FILE}.enc"

# --- Get Storage account key ---
STORAGE_KEY=$(az storage account keys list \
    --account-name $STORAGE_ACCOUNT \
    --resource-group $RESOURCE_GROUP \
    --query "[0].value" -o tsv)

# --- Download encrypted terraform.STATE ---
echo "Downloading $ENC_FILE from blob $CONTAINER_NAME/$ENC_FILE..."
az storage blob download \
    --account-name $STORAGE_ACCOUNT \
    --account-key $STORAGE_KEY \
    --container-name $CONTAINER_NAME \
    --name "$ENC_FILE" \
    --file "$ENC_FILE" \
    --overwrite

# --- Decrypt files ---
echo "Decrypting $ENC_FILE to $BACKUP_FILE..."
openssl enc -d -aes-256-cbc -salt -pbkdf2 -pass pass:"$ENC_KEY" -in "$ENC_FILE" -out "$BACKUP_FILE"

# --- Clean up temporary encrypted files ---
rm -f "$ENC_FILE"

echo "Restore and decryption complete!"

pulumi stack import < $BACKUP_FILE