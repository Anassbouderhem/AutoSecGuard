#!/bin/bash

# Appel des fonctions de logging
source ./src/interface/logging.sh

# Fichiers sensibles à surveiller
FILES=("/etc/passwd" "/etc/shadow" "/var/log/auth.log")

# Dossiers de sauvegarde et checksum
BACKUP_DIR="./var/backups"
CHECKSUM_DIR="./var/checksums"

# Création des dossiers s'ils n'existent pas
mkdir -p "$BACKUP_DIR"
mkdir -p "$CHECKSUM_DIR"

# Fichier log local pour accès/modifications (à simplifier pour la démo)
LOGFILE="./var/log/history.log"
touch "$LOGFILE"

# Fonction pour calculer hash et sauvegarder dans checksum dir
function generate_checksums() {
    for file in "${FILES[@]}"; do
        if [ -f "$file" ]; then
            sha256sum "$file" > "$CHECKSUM_DIR/$(basename $file).sha256"
        fi
    done
}

# Fonction pour sauvegarder les fichiers dans backup dir
function backup_files() {
    for file in "${FILES[@]}"; do
        if [ -f "$file" ]; then
            cp "$file" "$BACKUP_DIR/$(basename $file).bak"
        fi
    done
}

# Fonction de surveillance simple : vérifier changements par comparaison hash
function check_integrity() {
    for file in "${FILES[@]}"; do
        if [ -f "$file" ]; then
            current_hash=$(sha256sum "$file" | awk '{print $1}')
            saved_hash=$(cat "$CHECKSUM_DIR/$(basename $file).sha256" 2>/dev/null | awk '{print $1}')
            if [[ "$current_hash" != "$saved_hash" ]]; then
                log "ALERTE" "Modification détectée sur $file"
                # Optionnel : sauvegarder backup avant modification (ou après)
                cp "$file" "$BACKUP_DIR/$(basename $file).bak"
                # Mettre à jour checksum
                sha256sum "$file" > "$CHECKSUM_DIR/$(basename $file).sha256"
            fi
        fi
    done
}

# Fonction surveillance des accès (exemple simplifié via audit des accès)
# Cette partie nécessite auditd ou un mécanisme avancé, ici on simule par last access time
function monitor_access() {
    for file in "${FILES[@]}"; do
        if [ -f "$file" ]; then
            last_access=$(stat -c %X "$file")
            # On peut garder un historique simple dans un fichier, ici juste log simple
            echo "$(date): Dernier accès à $file : $last_access" >> "$LOGFILE"
            # Ici, on peut ajouter une logique pour détecter accès anormaux (fréquence, heures, utilisateurs)
        fi
    done
}

# MAIN

echo "----- Lancement de la surveillance à $(date) -----" >> "$LOGFILE"
generate_checksums
backup_files
check_integrity
monitor_access
