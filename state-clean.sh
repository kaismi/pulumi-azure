#!/bin/bash

rm -rf backup-$(pulumi stack --show-name).json

echo "Clean complete!"