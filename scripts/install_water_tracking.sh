#!/usr/bin/env bash

set -euo pipefail

# Installs the water-tracking files from this repository into a Home Assistant
# config directory. The script can be run from any working directory.

REPO_OWNER="wilman-labs"
REPO_NAME="Smart-Garden-watering-system"
REPO_REF="${REPO_REF:-main}"
RAW_BASE_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_REF}"

FILES=(
  "configuration/water_tracking.yaml"
  "automations/manual_watering_log.yaml"
  "configuration/lovelace_water_card.yaml"
)

HA_CONFIG_DIR="${HA_CONFIG_DIR:-}"
BACKUP_EXISTING=""

usage() {
  cat <<'EOF'
Usage:
  install_water_tracking.sh [--ha-config DIR]
  install_water_tracking.sh /path/to/home-assistant-config

Options:
  --ha-config DIR   Home Assistant config directory to install into
  -h, --help        Show this help message

Environment:
  HA_CONFIG_DIR     Same as --ha-config
  REPO_REF          Git ref to download from (default: main)
EOF
}

info() {
  printf '[INFO] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*" >&2
}

error() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

have_command() {
  command -v "$1" >/dev/null 2>&1
}

prompt_yes_no() {
  local prompt="$1"
  local default_answer="$2"
  local reply

  while true; do
    read -r -p "$prompt " reply || true
    reply="${reply:-$default_answer}"

    case "${reply,,}" in
      y|yes) return 0 ;;
      n|no) return 1 ;;
      *)
        printf 'Please answer y or n.\n'
        ;;
    esac
  done
}

detect_ha_config_dir() {
  local candidates=()

  if [[ -n "$HA_CONFIG_DIR" ]]; then
    printf '%s\n' "$HA_CONFIG_DIR"
    return 0
  fi

  if [[ -f "$PWD/configuration.yaml" ]]; then
    printf '%s\n' "$PWD"
    return 0
  fi

  if [[ -f "$PWD/config/configuration.yaml" ]]; then
    printf '%s\n' "$PWD/config"
    return 0
  fi

  candidates=(
    "/config"
    "$HOME/.homeassistant"
    "$HOME/homeassistant"
    "$HOME/.config/homeassistant"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate/configuration.yaml" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  read -r -p "Home Assistant config directory not found automatically. Enter it now: " HA_CONFIG_DIR
  [[ -n "$HA_CONFIG_DIR" ]] || error "No Home Assistant config directory provided."
  printf '%s\n' "$HA_CONFIG_DIR"
}

prepare_ha_config_dir() {
  local dir="$1"

  if [[ ! -d "$dir" ]]; then
    if prompt_yes_no "Directory '$dir' does not exist. Create it? [y/N]" "n"; then
      mkdir -p "$dir"
      info "Created Home Assistant config directory: $dir"
    else
      error "Installation cancelled."
    fi
  fi

  if [[ ! -f "$dir/configuration.yaml" ]]; then
    warn "No configuration.yaml found in '$dir'."
    prompt_yes_no "Continue anyway? [y/N]" "n" || error "Installation cancelled."
  fi

  mkdir -p "$dir/configuration" "$dir/automations"
}

download_file() {
  local repo_path="$1"
  local output_path="$2"
  local url="${RAW_BASE_URL}/${repo_path}"

  mkdir -p "$(dirname "$output_path")"

  if have_command curl; then
    curl -fsSL "$url" -o "$output_path"
  elif have_command wget; then
    wget -qO "$output_path" "$url"
  else
    error "Neither curl nor wget is installed. Please install one of them and retry."
  fi
}

sed_escape() {
  printf '%s' "$1" | sed 's/[\/&]/\\&/g'
}

replace_placeholder() {
  local file="$1"
  local placeholder="$2"
  local replacement="$3"
  local escaped_replacement

  escaped_replacement="$(sed_escape "$replacement")"
  sed -i "s|${placeholder}|${escaped_replacement}|g" "$file"
}

maybe_backup_existing_files() {
  local dir="$1"
  local timestamp="$2"
  local existing_files=()
  local target_path
  local repo_path

  for repo_path in "${FILES[@]}"; do
    target_path="${dir}/${repo_path}"
    [[ -e "$target_path" ]] && existing_files+=("$target_path")
  done

  if [[ ${#existing_files[@]} -eq 0 ]]; then
    return 0
  fi

  if [[ -z "$BACKUP_EXISTING" ]]; then
    if prompt_yes_no "Existing water-tracking files found. Back them up before overwrite? [Y/n]" "y"; then
      BACKUP_EXISTING="yes"
    else
      BACKUP_EXISTING="no"
    fi
  fi

  if [[ "$BACKUP_EXISTING" != "yes" ]]; then
    return 0
  fi

  for target_path in "${existing_files[@]}"; do
    cp "$target_path" "${target_path}.bak.${timestamp}"
    info "Backed up $(basename "$target_path") to ${target_path}.bak.${timestamp}"
  done
}

prompt_for_replacements() {
  local temp_dir="$1"
  local valve_id
  local zone
  local automation_id

  if ! prompt_yes_no "Replace placeholder entity IDs now? [Y/n]" "y"; then
    warn "Skipping placeholder replacement. The installed files will still contain example entity IDs."
    return 0
  fi

  for zone in 1 2 3 4; do
    read -r -p "Valve entity ID for Zone ${zone} (leave blank to keep switch.zone_${zone}_valve): " valve_id
    if [[ -n "$valve_id" ]]; then
      replace_placeholder "${temp_dir}/configuration/water_tracking.yaml" "switch.zone_${zone}_valve" "$valve_id"
      replace_placeholder "${temp_dir}/automations/manual_watering_log.yaml" "switch.zone_${zone}_valve" "$valve_id"
    fi
  done

  read -r -p "Blueprint automation entity ID (leave blank to keep automation.smart_garden_watering): " automation_id
  if [[ -n "$automation_id" ]]; then
    replace_placeholder "${temp_dir}/automations/manual_watering_log.yaml" "automation.smart_garden_watering" "$automation_id"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ha-config)
        [[ $# -ge 2 ]] || error "Missing value for --ha-config."
        HA_CONFIG_DIR="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        if [[ -z "$HA_CONFIG_DIR" ]]; then
          HA_CONFIG_DIR="$1"
          shift
        else
          error "Unknown argument: $1"
        fi
        ;;
    esac
  done
}

main() {
  local temp_dir
  local timestamp
  local repo_path

  parse_args "$@"

  HA_CONFIG_DIR="$(detect_ha_config_dir)"
  prepare_ha_config_dir "$HA_CONFIG_DIR"

  temp_dir="$(mktemp -d)"
  timestamp="$(date +%Y%m%d%H%M%S)"
  trap 'rm -rf -- "${temp_dir:-}"' EXIT

  info "Installing water-tracking files into: $HA_CONFIG_DIR"
  info "Downloading files from: ${RAW_BASE_URL}"

  for repo_path in "${FILES[@]}"; do
    download_file "$repo_path" "${temp_dir}/${repo_path}"
    info "Downloaded ${repo_path}"
  done

  prompt_for_replacements "$temp_dir"
  maybe_backup_existing_files "$HA_CONFIG_DIR" "$timestamp"

  for repo_path in "${FILES[@]}"; do
    cp "${temp_dir}/${repo_path}" "${HA_CONFIG_DIR}/${repo_path}"
    chmod 0644 "${HA_CONFIG_DIR}/${repo_path}"
    info "Installed ${repo_path} -> ${HA_CONFIG_DIR}/${repo_path}"
  done

  cat <<EOF

Water tracking files installed successfully.

Next steps:
1. In ${HA_CONFIG_DIR}/configuration.yaml, include:
   homeassistant:
     packages:
       water_tracking: !include configuration/water_tracking.yaml

2. Also include:
   automation: !include automations/manual_watering_log.yaml
   (or keep using your existing automation include directory pattern)

3. Reload YAML in Home Assistant or restart HA.

4. Paste ${HA_CONFIG_DIR}/configuration/lovelace_water_card.yaml into a Lovelace Manual card.
EOF
}

main "$@"
