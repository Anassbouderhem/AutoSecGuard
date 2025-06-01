#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Chargement de logging.sh 
source "$BASE_DIR/src/interface/logging.sh" || {
    echo "Erreur: Impossible de charger logging.sh" >&2
    exit 1
}

# Dossiers et fichiers à surveiller
CHECKSUM_DIR="$BASE_DIR/var/checksums"
REPORT_CSV="$BASE_DIR/var/reports/integrity_report.csv"
FILES=("/etc/passwd" "/etc/shadow" "$BASE_DIR/var/log/history.log")

# Création des dossiers nécessaires
mkdir -p "$CHECKSUM_DIR"
mkdir -p "$(dirname "$REPORT_CSV")"

# Initialiser le rapport CSV 
if [ ! -f "$REPORT_CSV" ]; then
    echo "Date,Heure,Fichier,Statut,Action" > "$REPORT_CSV"
fi

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        current_hash=$(sha256sum "$file" | awk '{print $1}')
        saved_hash_file="$CHECKSUM_DIR/$(basename "$file").sha256"
        now_date=$(date '+%Y-%m-%d')
        now_time=$(date '+%H:%M:%S')

        if [ ! -f "$saved_hash_file" ]; then
            log "INFO" "Création d'un nouveau checksum pour $(basename "$file")"
            sha256sum "$file" > "$saved_hash_file"
            echo "$now_date,$now_time,$file,INIT,Checksum créé" >> "$REPORT_CSV"
        else
            saved_hash=$(awk '{print $1}' "$saved_hash_file")
            
            if [[ "$current_hash" != "$saved_hash" ]]; then
                log "ALERTE" "Intégrité compromise pour $file (Empreinte modifiée)"
                # Sauvegarde horodatée
                backup_file="$BASE_DIR/var/backups/$(basename "$file").$(date '+%Y%m%d%H%M%S').bak"
                mkdir -p "$(dirname "$backup_file")"
                cp "$file" "$backup_file"
                # Mise à jour checksum
                sha256sum "$file" > "$saved_hash_file"
                echo "$now_date,$now_time,$file,MODIFIÉ,Sauvegarde créée: $(basename "$backup_file")" >> "$REPORT_CSV"
            else
                log "INFO" "$file est intact (vérification d'intégrité OK)"
                echo "$now_date,$now_time,$file,OK,Checksum inchangé" >> "$REPORT_CSV"
            fi
        fi
    else
        now_date=$(date '+%Y-%m-%d')
        now_time=$(date '+%H:%M:%S')
        log "AVERTISSEMENT" "Fichier $file introuvable"
        echo "$now_date,$now_time,$file,ABSENT,Fichier non trouvé" >> "$REPORT_CSV"
    fi
done
