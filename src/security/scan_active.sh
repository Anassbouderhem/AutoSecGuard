#!/bin/bash

# Surveillance active avec arrêt automatique après un nombre limité d'itérations
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Chargement de logging.sh 
source "$BASE_DIR/src/interface/logging.sh" || {
    echo "Erreur: Impossible de charger logging.sh" >&2
    exit 1
}

FILES=("/etc/passwd" "/etc/shadow" "/var/log/auth.log")
BACKUP_DIR="$BASE_DIR/var/backups"
CHECKSUM_DIR="$BASE_DIR/var/checksums"

# Création des dossiers nécessaires
mkdir -p "$BACKUP_DIR"
mkdir -p "$CHECKSUM_DIR"


# Générer les checksums de référence
function generate_checksums() {
    for file in "${FILES[@]}"; do
        if [ -f "$file" ]; then
            sha256sum "$file" > "$CHECKSUM_DIR/$(basename "$file").sha256"
        fi
    done
}

# Vérifier modifications et journaliser accès
function monitor_files() {
    for file in "${FILES[@]}"; do
        if [ -f "$file" ]; then
            current_hash=$(sha256sum "$file" | awk '{print $1}')
            saved_hash=$(cat "$CHECKSUM_DIR/$(basename "$file").sha256" 2>/dev/null | awk '{print $1}')

            if [[ "$current_hash" != "$saved_hash" ]]; then
                log "ALERTE" "MODIFICATION détectée sur $file" 

                # Sauvegarde horodatée
                timestamp=$(date +"%Y%m%d_%H%M%S")
                cp "$file" "$BACKUP_DIR/$(basename "$file").$timestamp.bak"

                sha256sum "$file" > "$CHECKSUM_DIR/$(basename "$file").sha256"
            fi

            last_access=$(stat -c %X "$file")
            readable_access=$(date -d @"$last_access" '+%F %T')
            log "INFO" "ACCÈS à $file → $readable_access" 
        fi
    done
}

# ---------- Exécution automatique ----------

echo "Démarrage de la surveillance active (automatisée)..."
generate_checksums

MAX_ITER=5       # Nombre d'itérations
SLEEP_DURATION=5 # Pause entre chaque itération (secondes)

for ((i=1; i<=MAX_ITER; i++)); do
    echo "--- Vérification $i / $MAX_ITER ---"
    monitor_files
    sleep "$SLEEP_DURATION"
done

echo "Surveillance terminée automatiquement après $MAX_ITER vérifications."
