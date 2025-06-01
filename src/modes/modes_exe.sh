#!/bin/bash



### Chargement des dépendances ###
PROJECT_ROOT="$(dirname "$(dirname "$(realpath "$0")")")"
source "$PROJECT_ROOT/src/interface/logging.sh"


### Fonctions d'Exécution ###
# mode fork
mode_fork() {
  local taches=("$@")
  local pids=()
  local status=0

  log "INFO" "Lancement mode Fork (${#taches[@]} taches)"

  # Lancer les tâches en arrière-plan
  for tache in "${taches[@]}"; do
    eval "$tache" | while IFS= read -r ligne; do
      log "INFO" "[FORK] $ligne"  # Modification: [THREAD] -> [FORK]
    done &
    pids+=($!)
  done

  # Attendre toutes les tâches sans sous-shell
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      exit_code=$?
      status=1
      log "ERROR" "Echec dans le fork PID $pid (Code : $exit_code)"
    fi
  done

  if [[ $status -eq 0 ]]; then
    log "SUCCESS" "Mode Fork terminé sans erreur"
  else
    log "ERROR" "Des erreurs sont survenues dans le mode Fork"
  fi

  return $status
}


# mode thread
mode_thread(){
  local taches=("$@")
  local max_threads=$(nproc)    #nproc: nbr des cpus
  local status=0
  log "INFO" "Lancement mode Thread (${#taches[@]} taches) (max $max_threads threads)"
  for tache in "${taches[@]}" ; do (
    set -e # arreter l'execution en cas d'erreur
    eval "$tache" | while IFS= read -r ligne; do    # lancer l'éxection 
     log "INFO" "[THREAD] $ligne"
      done  
  ) &   #en mode arrière plan
  while (( $(jobs -r | wc -l) >= max_threads )); do   # limiter le nbr des threads qui s'exécutent en parallèle
    sleep 0.1
  done
done
wait || status=1

if [[ $status -eq 0 ]]; then
  log "SUCCESS" "Mode Thread terminé sans erreur"
else
  log "ERROR" "Des erreurs sont survenues dans le mode Thread"
fi

return $status
}

# mode subshell
mode_subshell() {
  local taches=("$@")
  local status=0
  log "INFO" "Lancement mode Subshell (${#taches[@]} taches)"
  for tache in "${taches[@]}"; do (
    set -o errexit    #stop sur une erreur
    set -o pipefail   # Active la gestion stricte des erreurs dans les pipelines pour détecter toute deffaillance
    trap 'log "ERROR"  "Erreur dans subshell: $BASH_COMMAND"' ERR  #jounaliser la commande qui a échoué
    eval "$tache" | while IFS= read -r ligne; do    # lancer l'éxecution 
     log "INFO" "[SUBSHELL] $ligne"  # Modification: [THREAD] -> [SUBSHELL]
      done  
  )
  (( status |= $? ))  # # Stocke l’erreur si au moins une commande echoue
  done

  if [[ $status -eq 0 ]]; then
    log "SUCCESS" "Mode Subshell terminé sans erreur"
  else
    log "ERROR" "Des erreurs sont survenues dans le mode Subshell"
  fi
  return $status
}