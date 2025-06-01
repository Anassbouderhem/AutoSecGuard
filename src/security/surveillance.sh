#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Chargement de logging.sh 
source "$BASE_DIR/src/interface/logging.sh" || {
    echo "Erreur: Impossible de charger logging.sh" >&2
    exit 1
}

# Fichiers sensibles à surveiller
FILES=("/etc/passwd" "/etc/shadow" "/var/log/auth.log")

# Dossiers basés sur BASE_DIR
BACKUP_DIR="$BASE_DIR/var/backups"
CHECKSUM_DIR="$BASE_DIR/var/checksums"


# Calcul des checksums
generate_checksums() {
    for file in "${FILES[@]}"; do
        if [ -f "$file" ]; then
            sha256sum "$file" > "$CHECKSUM_DIR/$(basename "$file").sha256"
        fi
    done
}

# Sauvegarde horodatée
backup_file() {
    local file="$1"
    local ts
    ts=$(date '+%Y%m%d_%H%M%S')
    cp "$file" "$BACKUP_DIR/$(basename "$file").$ts.bak"
}

# Vérification d'intégrité
check_integrity() {
    for file in "${FILES[@]}"; do
        if [ -f "$file" ]; then
            current_hash=$(sha256sum "$file" | awk '{print $1}')
            saved_hash=$(cat "$CHECKSUM_DIR/$(basename "$file").sha256" 2>/dev/null | awk '{print $1}')
            if [[ "$current_hash" != "$saved_hash" ]]; then
                log " MODIFICATION" "Le fichier $file a été modifié"
                backup_file "$file"
                sha256sum "$file" > "$CHECKSUM_DIR/$(basename "$file").sha256"
                log "ALERTE" "Modification détectée sur $file"
            fi
        fi
    done
}

# Surveillance des accès
monitor_access() {
    for file in "${FILES[@]}"; do
        if [ -f "$file" ]; then
            last_access=$(stat -c '%x' "$file")
            log "INFO" "$file accédé le $last_access"
        fi
    done
}

# MAIN
log "\n=== Lancement de la surveillance : $(date '+%F %T') ==="
generate_checksums
check_integrity
monitor_access
log "---  Fin de vérification ---" 
