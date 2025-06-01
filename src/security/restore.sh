#!/bin/bash

BACKUP_DIR="./var/backups"
FILES=("passwd" "shadow" "auth.log")
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$BASE_DIR/src/interface/logging.sh" || {
    echo "Erreur: Impossible de charger logging.sh" >&2
    exit 1
}

for filename in "${FILES[@]}"; do
    backup_file="$BACKUP_DIR/$filename.bak"
    original_file="/etc/$filename"
    if [ -f "$backup_file" ]; then
        log "RESTORE" "Restauration de $original_file depuis $backup_file"
        sudo cp "$backup_file" "$original_file"
    else
        log "WARNING" "Aucune sauvegarde trouvée pour $original_file"
    fi
done
