#!/bin/bash

BACKUP_DIR="./var/backups"
FILES=("passwd" "shadow" "auth.log")

for filename in "${FILES[@]}"; do
    backup_file="$BACKUP_DIR/$filename.bak"
    original_file="/etc/$filename"
    if [ -f "$backup_file" ]; then
        echo "Restauration de $original_file depuis $backup_file"
        sudo cp "$backup_file" "$original_file"
    else
        echo "Backup pour $original_file non trouvé."
    fi
done
