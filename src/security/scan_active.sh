#!/bin/bash

# Surveillance active avec arrêt automatique après un nombre limité d'itérations
source ./src/interface/logging.sh

FILES=("/etc/passwd" "/etc/shadow" "/var/log/auth.log")
BACKUP_DIR="./var/backups"
CHECKSUM_DIR="./var/checksums"
LOGFILE="./var/log/history.log"

# Création des dossiers nécessaires
mkdir -p "$BACKUP_DIR"
mkdir -p "$CHECKSUM_DIR"
mkdir -p "$(dirname "$LOGFILE")" || {
    echo "ERREUR: Impossible de créer le dossier log" >&2
    exit 1
}

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
                log "$(date): Modification détectée sur $file" | tee -a "$LOGFILE"
                cp "$file" "$BACKUP_DIR/$(basename "$file").bak"
                sha256sum "$file" > "$CHECKSUM_DIR/$(basename "$file").sha256"
            fi

            last_access=$(stat -c %X "$file")
            log "$(date): Dernier accès à $file : $last_access" >> "$LOGFILE"
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
