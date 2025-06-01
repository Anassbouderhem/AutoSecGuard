# Fonction pour demander le mode (thread, fork, subshell)
choose_mode() {
    local mode=""
    while true; do
    affiche=$'\n\e[36m=== Choisissez le mode d\'exécution ===\e[0m\n 1) thread\n 2) fork\n 3) subshell\n======================================\n'

        read -rp "$affiche Votre choix [1-3] : " mode_choice
        
        case "$mode_choice" in
            1) mode="mode_thread"; break ;;
            2) mode="mode_fork"; break ;;
            3) mode="mode_subshell"; break ;;
            *) 
                printf "\e[31mChoix invalide, veuillez réessayer.\e[0m\n"
                sleep 1
                ;;
        esac
    done
    echo "$mode"
}

interactive_mode() {
    while true; do
        clear
        echo -e "\e[34m=================== AutoSecGuard - Menu Principal ===================\e[0m"
        echo -e "\e[33m(h) Aide      (r) Restauration système (root)     (a) Scan actif (root)\e[0m"
        echo -e "\e[33m(c) Vérification hash       (s) Surveillance continue (root)\e[0m"
        echo -e "\e[33m(p) Performance            (k) Arrêter la surveillance\e[0m"
        echo -e "\e[33m(q) Quitter\e[0m"
        echo -e "\e[34m=====================================================================\e[0m"
        read -rp "Votre choix : " choice

        case "${choice,,}" in
            h)  
                clear
                show_help
                read -rp "Appuyez sur Entrée pour revenir au menu..." _
                ;;
            r)
                mode=$(choose_mode)
                clear
                echo "Lancement de la restauration système en mode $mode..."
                run_restore "$mode" && echo -e "\e[32mRestauration terminée avec succès.\e[0m" || echo -e "\e[31mErreur lors de la restauration.\e[0m"
                read -rp "Appuyez sur Entrée pour revenir au menu..." _
                ;;
            a)
                mode=$(choose_mode)
                clear
                echo "Lancement du scan actif (mode $mode)..."
                run_security "$mode"
                read -rp "Scan terminé. Appuyez sur Entrée pour revenir au menu..." _
                ;;
            c)
                clear
                echo "Vérification d'intégrité..."
                "$PROJECT_ROOT/src/security/hash_check.sh"
                read -rp "Vérification terminée. Appuyez sur Entrée pour revenir au menu..." _
                ;;
            s)
                mode=$(choose_mode)
                clear
                echo "Démarrage de la surveillance continue (mode $mode)..."
                "$PROJECT_ROOT/src/security/surveillance.sh" "$mode" &
                echo -e "\e[32mSurveillance lancée en arrière-plan.\e[0m"
                read -rp "Appuyez sur Entrée pour revenir au menu..." _
                ;;
            p)
                mode=$(choose_mode)
                clear
                read -rp "Seuil CPU (%) [80]: " cpu
                cpu=${cpu:-80}
                while ! [[ "$cpu" =~ ^[0-9]+$ ]] || ((cpu < 1 || cpu > 100)); do
                    echo -e "\e[31mVeuillez entrer un nombre entre 1 et 100.\e[0m"
                    read -rp "Seuil CPU (%) [80]: " cpu
                    cpu=${cpu:-80}
                done

                read -rp "Seuil RAM (%) [50]: " ram
                ram=${ram:-50}
                while ! [[ "$ram" =~ ^[0-9]+$ ]] || ((ram < 1 || ram > 100)); do
                    echo -e "\e[31mVeuillez entrer un nombre entre 1 et 100.\e[0m"
                    read -rp "Seuil RAM (%) [50]: " ram
                    ram=${ram:-50}
                done
                # Demander le niveau de granularité
                read -rp "Granularité (low/high/critical) [low]: " granularity
                granularity=${granularity,,}
                granularity=${granularity:-low}
                if [[ ! "$granularity" =~ ^(low|high|critical)$ ]]; then
                    echo -e "\e[31mValeur invalide. Utilisation de 'low' par défaut.\e[0m"
                    granularity="low"
                fi

                # Demander l'intervalle de rafraîchissement
                read -rp "Intervalle de rafraîchissement (en secondes) [5]: " refresh
                refresh=${refresh:-5}
                while ! [[ "$refresh" =~ ^[0-9]+$ ]] || ((refresh < 1)); do
                    echo -e "\e[31mVeuillez entrer un entier positif.\e[0m"
                    read -rp "Intervalle de rafraîchissement (en secondes) [5]: " refresh
                    refresh=${refresh:-5}
                done

                # Action automatique
                read -rp "Action automatique (kill/renice/none) [none]: " action
                action=${action,,}
                action=${action:-none}
                if [[ ! "$action" =~ ^(kill|renice|none)$ ]]; then
                    echo -e "\e[31mAction invalide. Utilisation de 'none'.\e[0m"
                    action="none"
                fi

                # Exécution
            # Demander si on veut activer/désactiver certaines parties
            read -rp "Activer le moniteur de ressources ? [O/n] " monitor_choice
            monitor_choice=${monitor_choice,,}
            enable_monitor=true
            [[ "$monitor_choice" == "n" ]] && enable_monitor=false

            read -rp "Activer le gestionnaire de processus ? [O/n] " manager_choice
            manager_choice=${manager_choice,,}
            enable_manager=true
            [[ "$manager_choice" == "n" ]] && enable_manager=false

            # Construction des arguments
            args=( "$mode" --cpu "$cpu" --ram "$ram" --granularity "$granularity" --refresh "$refresh" --action "$action" --auto )
            ! $enable_monitor && args+=( --no-monitor )
            ! $enable_manager && args+=( --no-manager )

            # Exécution
            echo "Démarrage de l’analyse de performance avec les paramètres choisis..."
            run_performance "${args[@]}" &


                ;;
            k)
                read -rp "Entrez le PID à arrêter (ou laissez vide pour signal doux): " pid
                if [[ -z "$pid" ]]; then
                    touch "$STOP_FILE"
                    echo -e "\e[33mSignal d'arrêt envoyé.\e[0m"
                else
                    if kill "$pid" 2>/dev/null; then
                        echo -e "\e[32mProcessus $pid arrêté.\e[0m"
                    else
                        echo -e "\e[31mÉchec de l'arrêt du processus $pid.\e[0m"
                    fi
                fi
                read -rp "Appuyez sur Entrée pour revenir au menu..." _
                ;;
            q)
                echo -e "\e[36mMerci d'avoir utilisé AutoSecGuard. À bientôt !\e[0m"
                exit 0
                ;;
            *)
                echo -e "\e[31mOption invalide. Veuillez réessayer.\e[0m"
                sleep 1
                ;;
        esac
    done
}
