# AutoSecGuard - Système de Sécurité et Performance Linux

## Description

**AutoSecGuard** est un système intégré de **surveillance**, de **sécurité** et de **gestion des performances** pour les systèmes Linux. Il a pour objectifs principaux :

-  Surveiller et protéger les **fichiers système critiques**
-  Monitorer les **performances système** (CPU / RAM)
-  Gérer et neutraliser les **processus trop gourmands**
-  Restaurer automatiquement le système après un incident
-  Générer des **logs et rapports détaillés**

## Fonctionnalités

- **Surveillance de l’intégrité** : Calcul et vérification des checksums SHA256 des fichiers critiques
- **Monitoring système** : Utilisation de `ps`, `top` et `awk` pour suivre la charge CPU et mémoire
- **Gestion des processus** : Identification et arrêt automatique des processus excessifs
- **Restauration post-incident** : Récupération depuis des backups
- **Rapports et journaux** :
  - `history.log` : journal centralisé des événements
  - `integrity_report.csv` : état de l'intégrité des fichiers
  - `var/checksums/*.sha256` : fichiers de hachage
  - `backups/` : répertoires de sauvegarde

## Dépendances

Le système nécessite les outils suivants :

- `bash` – Shell de script principal
- `coreutils` – Pour `sha256sum`, `date`, etc.
- `procps` – Pour `ps`, `top`, etc.
- `awk` – Traitement de texte et génération de rapports

## Arborescence


├── README.md
├── bin
│   └── autosecguard.sh
├── src
│   ├── interface
│   │   ├── interactive.sh
│   │   └── logging.sh
│   ├── modes
│   │   └── modes_exe.sh
│   ├── performance
│   │   ├── process_manager.sh
│   │   └── resources_monitor.sh
│   └── security
│       ├── hash_check.sh
│       ├── restore.sh
│       ├── scan_active.sh
│       └── surveillance.sh
└── var
    ├── backups
    │   ├── auth.log.20250601_140803.bak
    │   ├── passwd.20250601_140803.bak
    │   └── process_snapshots
    │      
    │      
    ├── checksums
    │   ├── auth.log.sha256
    │   ├── history.log.sha256
    │   ├── passwd.sha256
    │   └── shadow.sha256
    ├── log
    │   └── history.log
    ├── reports
    │   └── integrity_report.csv
    └── stop_signal

## Auteur

**Team-A01**  
[ENSET Mohammedia – 2025](https://enset-media.ac.ma/)

---

© 2025 AutoSecGuard – Tous droits réservés.
