#!/bin/bash
# Répertoire et fichier de logs
LOG_DIR="/var/log/autosecguard"
mkdir -p "$LOG_DIR" || { echo "Erreur : Impossible de créer $LOG_DIR (permission refusée)"; exit 1; }
LOG_FILE="$LOG_DIR/history.log"

log() {
  local level=$1; shift
  local temps
  temps="$(date '+%Y-%m-%d-%H-%M-%S')"
  local username
  username="$(whoami)"
  local hostname
  hostname="$(hostname -s)"
  local message="$*"
  echo "$temps : $hostname : -autosecguard- : $level : $username : $message" | tee -a "$LOG_FILE"   
}

error() {
    local code="$1"
    shift
    local temps
    temps="$(date '+%Y-%m-%d-%H-%M-%S')"
    local username
    username="$(whoami)"
    local message="$*"
    local hostname
    hostname="$(hostname -s)"
    echo "$temps : $hostname : -autosecguard- : $username : ERROR : $message" | tee -a "$LOG_FILE"
    exit "$code"
}

# mode fork
mode_fork(){
  local taches=("$@")
  local pids=()
  local status=0
  log "INFO" "Lancement mode Fork (${#taches[@]} taches)"
  for tache in "${taches[@]}"; do (
    eval "$tache" || exit $?
    ) &
    pids+=($!)           #$!: stocke le pid de la dérnière commande lancé en mode arriere plan     $?: stocke le code sortie de la dérnière commande executé      
  done

  for pid in "${pids[@]}"; do (
    if ! wait "$pid"; then
      status=1
      exit_code=$?
      log "ERROR" "Echec dans le fork PID $pid (Code : $exit_code)"
    fi
  )
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
     log "INFO" "[THREAD] $ligne"
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

control(){
  case $1 in 
    -f) mode_fork "${@:2}" ;;
    -t) mode_thread "${@:2}" ;;
    -s) mode_subshell "${@:2}" ;;
    *)
      log "ERROR" "Mode inconnu: $1"
      return 1
      ;;
    esac
}