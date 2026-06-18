#!/bin/bash
# STATE-restore.sh
# Download, decrypt, and extract .pulumi archive from Azure Blob Storage

read -p "Are you sure you want to continue and override state with remote from $STATE_CONT_NAME? (y/n): " answer

if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
    echo "Proceeding..."
else
    echo "Aborted."
    exit 1
fi

# --- Configuration ---
RESOURCE_GROUP=$STATE_RG_NAME
STORAGE_ACCOUNT=${RESOURCE_GROUP//-}
CONTAINER_NAME=backup
OVERWRITE=true
ARCHIVE_FILE=".pulumi.tar.gz"
ENC_FILE="${ARCHIVE_FILE}.enc"

# Pre-shared encryption key (32 bytes for AES-256)
# Export this before running: export STATE_ENC_KEY="your32bytekey"
ENC_KEY=$STATE_ENC_KEY
if [[ -z "$ENC_KEY" ]]; then
  echo "Error: STATE_ENC_KEY environment variable not set"
  exit 1
fi

# --- Get Storage account key ---
STORAGE_KEY=$(az storage account keys list \
    --account-name $STORAGE_ACCOUNT \
    --resource-group $RESOURCE_GROUP \
    --query "[0].value" -o tsv)

# --- Download encrypted archive ---
echo "Downloading $ENC_FILE from blob $CONTAINER_NAME/$ENC_FILE..."
az storage blob download \
    --account-name $STORAGE_ACCOUNT \
    --account-key $STORAGE_KEY \
    --container-name $CONTAINER_NAME \
    --name "$ENC_FILE" \
    --file "$ENC_FILE" \
    --overwrite

# --- Decrypt archive ---
echo "Decrypting $ENC_FILE to $ARCHIVE_FILE..."
openssl enc -d -aes-256-cbc -salt -pbkdf2 -pass pass:"$ENC_KEY" -in "$ENC_FILE" -out "$ARCHIVE_FILE"

rm -rf .pulumi  # Clean up existing .pulumi folder before extraction

# --- Extract archive ---
echo "Extracting $ARCHIVE_FILE..."
tar -xzf "$ARCHIVE_FILE"

# --- Clean up temporary files ---
rm -f "$ENC_FILE" "$ARCHIVE_FILE"

echo "Restore and decryption complete!"
