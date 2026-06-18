#!/bin/bash
# upload-STATE.sh
# Encrypt and upload terraform.STATE and terraform.STATE.backup to Azure Blob Storage

read -p "Are you sure you want to continue and override state remote for $STATE_CONT_NAME? (y/n): " answer

if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
    echo "Proceeding..."
else
    echo "Aborted."
    exit 1
fi

BACKUP_FILE=backup-$(pulumi stack --show-name).json
pulumi stack export > $BACKUP_FILE

# --- Configuration ---
RESOURCE_GROUP=$STATE_RG_NAME
STORAGE_ACCOUNT=${RESOURCE_GROUP//-}
CONTAINER_NAME=backup
OVERWRITE=true
ARCHIVE_FILE=".pulumi.tar.gz"
ENC_FILE="${ARCHIVE_FILE}.enc"

# Pre-shared encryption key (32 bytes for AES-256)
# Ideally export this as an environment variable: export STATE_ENC_KEY="your32bytekey"
ENC_KEY=$STATE_ENC_KEY
if [[ -z "$ENC_KEY" ]]; then
  echo "Error: STATE_ENC_KEY environment variable not set"
  exit 1
fi

# --- Archive .pulumi folder ---
echo "Archiving .pulumi folder..."
tar -czf "$ARCHIVE_FILE" .pulumi/

# --- Get Storage account key ---
STORAGE_KEY=$(az storage account keys list \
    --account-name $STORAGE_ACCOUNT \
    --resource-group $RESOURCE_GROUP \
    --query "[0].value" -o tsv)

# --- Encrypt archive ---
echo "Encrypting $ARCHIVE_FILE..."
openssl enc -aes-256-cbc -salt -pbkdf2 -pass pass:"$ENC_KEY" -in "$ARCHIVE_FILE" -out "$ENC_FILE"

# --- Upload encrypted files ---
echo "Uploading $ENC_FILE to blob $CONTAINER_NAME/$ENC_FILE.enc..."
az storage blob upload \
    --account-name $STORAGE_ACCOUNT \
    --account-key $STORAGE_KEY \
    --container-name $CONTAINER_NAME \
    --name "$ENC_FILE" \
    --file "$ENC_FILE" \
    --overwrite $OVERWRITE


# --- Clean up temporary files ---
rm -f "$ARCHIVE_FILE" "$ENC_FILE"

echo "Upload complete! .pulumi folder is encrypted in blob storage."