#!/bin/bash
# cet script automatise l'execution de programm
echo "🔧 Initialisation d'AutoSecGuard..."

# 1. Créer les dossiers nécessaires
mkdir -p var/backups/{system,checksums,process_snapshots}

# 2. Donner les permissions d’exécution
chmod +x src/security/*.sh
chmod +x bin/autosecguard

# 3. Sauvegarder les fichiers sensibles
echo "📦 Sauvegarde des fichiers sensibles..."
sudo cp /etc/passwd var/backup/passwd.bak
sudo cp /etc/shadow var/backup/shadow.bak
sudo cp /var/log/auth.log var/backup/auth.log.bak

# 4. Générer les fichiers de hash
echo "🔒 Génération des hashs..."
sudo sha256sum /etc/passwd > var/checksums/passwd.hash
sudo sha256sum /etc/shadow > var/checksums/shadow.hash
sudo sha256sum /var/log/auth.log > var/checksums/auth.log.hash

echo "✅ Installation terminée avec succès."

