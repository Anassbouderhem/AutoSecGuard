#!/bin/bash

# Appel a fonction loggin
source ./src/interface/logging.sh

# Dossiers et fichiers à surveiller
CHECKSUM_DIR="./var/checksums"
FILES=("/etc/passwd" "/etc/shadow" "/home/abdlatif-nabgha/Desktop/Developers/Bash/AutoSecGuard/var/log/history.log")

# Création du dossier de checksums s'il n'existe pas
mkdir -p "$CHECKSUM_DIR"

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        current_hash=$(sha256sum "$file" | awk '{print $1}')
        saved_hash_file="$CHECKSUM_DIR/$(basename "$file").sha256"
        
        if [ ! -f "$saved_hash_file" ]; then
            log "INFO" "Création d'un nouveau checksum pour $(basename "$file")"
            sha256sum "$file" > "$saved_hash_file"
        else
            saved_hash=$(awk '{print $1}' "$saved_hash_file")
            
            if [[ "$current_hash" != "$saved_hash" ]]; then
                log "ALERTE" "Intégrité compromise pour $file (Empreinte modifiée)"
                # Optionnel : Ajouter une sauvegarde automatique ici
            else
                log "INFO" "$file est intact (vérification d'intégrité OK)"
            fi
        fi
    else
        log "AVERTISSEMENT" "Fichier $file introuvable"
    fi
done