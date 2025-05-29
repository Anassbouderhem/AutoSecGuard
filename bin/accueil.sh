#!/bin/bash
clear

# Welcome banner
echo -e "\e[36m      ***************************************************** WELCOME **********************************************************\e[0m"
echo "                                                 Welcome to AutoSecGuard script v1.0"

# Centering helpers
get_center_padding() {
  local input="$1"
  local termwidth=$(tput cols)
  local clean_text=$(echo -e "$input" | sed 's/\x1b\[[0-9;]*m//g')
  echo $(( (termwidth - ${#clean_text}) / 2 ))
}

print_centered() {
  local text="$1"
  local padding=$(get_center_padding "$text")
  printf "%*s%s\n" "$padding" "" "$text"
}

typewriter() {
  local text="$1"
  local color="$2"
  local delay="${3:-0.05}"
  
  local padding=$(get_center_padding "$text")
  printf "%*s" "$padding" ""
  
  for (( i=0; i<${#text}; i++ )); do
    echo -ne "${color}${text:$i:1}\e[0m"
    sleep "$delay"
  done
  printf "\n"
}

# Build the block
declare -a full_block

# Add figlet title (if available)
if command -v figlet &>/dev/null && command -v lolcat &>/dev/null; then
  mapfile -t figlet_lines < <(figlet "AutoSecGuard" | lolcat -F 0.3)
  for line in "${figlet_lines[@]}"; do
    print_centered "$line"
    sleep 0.01
  done
else
  print_centered "╔═══════════════╗"
  print_centered "║ AutoSecGuard  ║"
  print_centered "╚═══════════════╝"
fi

# Special treatment for the "Developed by" line with color and typewriter effect
typewriter "Developed by Team-A01" "\e[1;32m" 0.1  # Bright green color
echo ""

# ASCII art lock
print_centered "████████████████████████████"
print_centered "████████████████████████████"
print_centered "██▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒██"
print_centered "██▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒██"
print_centered "██▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒██"
print_centered "██▒▒▒▒▄▄▄▄▄▄▄▄▄▄▄▄▄▄▒▒▒▒▒▒██"
print_centered "██▒▒▒▒██████████████▒▒▒▒▒▒██"
print_centered "██▒▒▒▒██    LOCK    ██▒▒▒▒██"
print_centered "██▒▒▒▒██████████████▒▒▒▒▒▒██"
print_centered "██▒▒▒▒▀▀▀▀▀▀▀▀▀▀▀▀▀▀▒▒▒▒▒▒██"
print_centered "██▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒██"
print_centered "██▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒██"
print_centered "████████████████████████████"
print_centered "████████████████████████████"

# Bottom text
print_centered "╔══════════════════════════════╗"
print_centered "║    Linux Security Guardian   ║"
print_centered "╚══════════════════════════════╝"
echo ""

# Final prompt with typewriter effect
typewriter "Appuyez sur Entrée pour continuer..." "\e[1;33m" 0.03  # Yellow color
read


"$(dirname "$0")/autosecguard.sh"
