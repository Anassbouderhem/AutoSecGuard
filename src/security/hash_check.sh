#!/bin/bash

CHECKSUM_DIR="./var/checksums"
FILES=("/etc/passwd" "/etc/shadow" "/var/log/auth.log")

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        current_hash=$(sha256sum "$file" | awk '{print $1}')
        saved_hash_file="$CHECKSUM_DIR/$(basename $file).sha256"
        if [ ! -f "$saved_hash_file" ]; then
            echo "Checksum pour $(basename $file) non trouvé. Création."
            sha256sum "$file" > "$saved_hash_file"
        else
            saved_hash=$(cat "$saved_hash_file" | awk '{print $1}')
            if [[ "$current_hash" != "$saved_hash" ]]; then
                echo "ALERTE: Intégrité compromise pour $file"
            else
                echo "$file est intact."
            fi
        fi
    else
        echo "Fichier $file introuvable."
    fi
done
