#!/bin/bash

# Default log level - can be overridden by core.sh after reading config
FRAMEWORK_LOG_LEVEL="INFO" # Allowed: DEBUG, INFO, WARNING, ERROR
ENABLE_COLORS=false       # Default, can be overridden

# Function to set log level (called from core.sh)
set_log_level() {
  if [[ "$1" =~ ^(DEBUG|INFO|WARNING|ERROR)$ ]]; then
    FRAMEWORK_LOG_LEVEL="$1"
    # echo "[$(date +"%Y-%m-%d %H:%M:%S")] [INFO] Log level set to: $FRAMEWORK_LOG_LEVEL" # Bootstrap log
  else
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] [ERROR] Invalid log level: $1. Using $FRAMEWORK_LOG_LEVEL." >&2
  fi
}

# Function to set color preference (called from core.sh)
set_color_preference() {
  if [ "$1" == "true" ]; then
    ENABLE_COLORS=true
    # Define colors
    RESET='\033[0m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m' # For DEBUG
    CYAN='\033[0;36m' # For INFO
  else
    ENABLE_COLORS=false
    RESET='' RED='' GREEN='' YELLOW='' BLUE='' CYAN=''
  fi
}

_log() {
  local level="$1"
  shift
  local message="$*"
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  local color_prefix=""
  local color_suffix="$RESET"

  # Determine if message should be logged based on level
  case "$level" in
    DEBUG)
      [ "$FRAMEWORK_LOG_LEVEL" != "DEBUG" ] && return 0
      color_prefix="$BLUE"
      ;;
    INFO)
      # DEBUG and INFO levels log INFO messages
      [ "$FRAMEWORK_LOG_LEVEL" != "DEBUG" ] && [ "$FRAMEWORK_LOG_LEVEL" != "INFO" ] && return 0
      color_prefix="$CYAN"
      ;;
    WARNING)
      # DEBUG, INFO, WARNING levels log WARNING messages
      [ "$FRAMEWORK_LOG_LEVEL" == "ERROR" ] && return 0
      color_prefix="$YELLOW"
      ;;
    ERROR)
      # All levels log ERROR messages
      color_prefix="$RED"
      ;;
    *) # Default for unknown levels, log as is
      color_prefix=""
      color_suffix=""
      ;;
  esac

  if [ "$ENABLE_COLORS" = false ]; then
    color_prefix=""
    color_suffix=""
  fi
  
  # Output to stderr for WARNING and ERROR, stdout for INFO and DEBUG
  if [ "$level" == "ERROR" ] || [ "$level" == "WARNING" ]; then
    echo -e "${color_prefix}[$timestamp] [$level] $message${color_suffix}" >&2
  else
    echo -e "${color_prefix}[$timestamp] [$level] $message${color_suffix}"
  fi
}

log_debug() {
  _log "DEBUG" "$@"
}

log_info() {
  _log "INFO" "$@"
}

log_warning() {
  _log "WARNING" "$@"
}

log_error() {
  _log "ERROR" "$@"
}

# Initialize with defaults (can be overridden by core.sh)
set_color_preference false # Start with colors off, core.sh will enable
# log_info "utils.sh initialized. Default log level: $FRAMEWORK_LOG_LEVEL. Colors: $ENABLE_COLORS" # Test message
# log_debug "This is a debug test message."
# log_warning "This is a warning test message."
# log_error "This is an error test message."
