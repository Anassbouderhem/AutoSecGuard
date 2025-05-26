#!/bin/bash

# Ce script fait une surveillance active en continu avec vérifications périodiques

# Chemins relatifs à la racine du projet
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOGFILE="$BASE_DIR/var/log/security_access.log"

# Création du dossier log 
mkdir -p "$(dirname "$LOGFILE")" || {
    echo "ERREUR: Impossible de créer le dossier log" >&2
    exit 1
}
# Fonction pour calculer hash
function generate_checksums() {
    for file in "${FILES[@]}"; do
        if [ -f "$file" ]; then
            sha256sum "$file" > "$CHECKSUM_DIR/$(basename $file).sha256"
        fi
    done
}

# Fonction de surveillance intégrée : check modifications + log accès simples
function monitor_files() {
    for file in "${FILES[@]}"; do
        if [ -f "$file" ]; then
            current_hash=$(sha256sum "$file" | awk '{print $1}')
            saved_hash=$(cat "$CHECKSUM_DIR/$(basename $file).sha256" 2>/dev/null | awk '{print $1}')

            # Check modification
            if [[ "$current_hash" != "$saved_hash" ]]; then
                echo "$(date): Modification détectée sur $file" | tee -a "$LOGFILE"
                cp "$file" "$BACKUP_DIR/$(basename $file).bak"
                sha256sum "$file" > "$CHECKSUM_DIR/$(basename $file).sha256"
            fi

            # Log dernier accès
            last_access=$(stat -c %X "$file")
            echo "$(date): Dernier accès à $file : $last_access" >> "$LOGFILE"
        fi
    done
}

echo "Démarrage de la surveillance active en continu..."

# Générer les checksums au début
generate_checksums

# Boucle infinie de surveillance toutes les 60 secondes (modifiable)
while true; do
    monitor_files
    sleep 60
done
