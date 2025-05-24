#!/bin/bash

# Adjust paths based on current script location (tool_manager/)
UTILS_PATH="../lib/utils.sh"
YAML_PARSER_PATH="../lib/yaml_parser.sh"
TOOL_DB_PATH="tool_db.yaml" # Assumes tool_db.yaml is in the same directory

# Ensure utils.sh and yaml_parser.sh are executable and sourced
if [ ! -f "$UTILS_PATH" ]; then
    echo "[ERROR] utils.sh not found at $UTILS_PATH" >&2
    exit 1
fi
source "$UTILS_PATH"

if [ ! -f "$YAML_PARSER_PATH" ]; then
    log_error "yaml_parser.sh not found at $YAML_PARSER_PATH"
    exit 1
fi
source "$YAML_PARSER_PATH"

# Initialize logging (it will use defaults until core.sh potentially overrides)
# This is important if tool_manager.sh is run standalone.
if command -v set_log_level &> /dev/null; then
    set_log_level "INFO" # Default for standalone runs
fi
if command -v set_color_preference &> /dev/null; then
    set_color_preference true # Default for standalone runs
fi


# Function to get tool data from tool_db.yaml
# Usage: _get_tool_data <tool_name> <field_name>
_get_tool_data() {
    local tool_name="$1"
    local field_name="$2"
    # yq query: finds the tool by name, then selects the field. -e exits with error if path not found.
    get_yaml_value "$TOOL_DB_PATH" ".tools[] | select(.name==\"$tool_name\") | .$field_name"
}

# Function to check if a tool is installed
# Usage: check_tool <tool_name>
check_tool() {
    local tool_name="$1"
    log_info "Checking if tool '$tool_name' is installed..."

    local check_command
    check_command=$(_get_tool_data "$tool_name" "check_command")

    if [ -z "$check_command" ] || [ "$check_command" == "null" ]; then
        log_warning "No check_command defined for tool '$tool_name' in $TOOL_DB_PATH."
        return 1 # Cannot determine if installed
    fi

    log_debug "Executing check_command for '$tool_name': $check_command"
    if eval "$check_command" >/dev/null 2>&1; then
        log_info "Tool '$tool_name' is installed."
        return 0 # Success, tool is found
    else
        log_info "Tool '$tool_name' is NOT installed."
        return 1 # Failure, tool is not found
    fi
}

# Function to install a tool
# Usage: install_tool <tool_name>
install_tool() {
    local tool_name="$1"
    log_info "Attempting to install tool '$tool_name'..."

    local install_command
    install_command=$(_get_tool_data "$tool_name" "install_command")

    if [ -z "$install_command" ] || [ "$install_command" == "null" ]; then
        log_error "No install_command defined for tool '$tool_name' in $TOOL_DB_PATH. Cannot install."
        return 1
    fi

    # Security warning for sudo
    if [[ "$install_command" == *sudo* ]]; then
        log_warning "The install command for '$tool_name' contains 'sudo'. Ensure you understand the command being run: $install_command"
        # Add a small delay or prompt for user confirmation if interactive
        # For now, just log and proceed.
    fi

    log_info "Executing install_command for '$tool_name': $install_command"
    
    # Execute the install command. Capture stdout/stderr for logging.
    # Using a temporary file for command output to avoid complex eval issues with output redirection.
    local output_file
    output_file=$(mktemp) 
    
    if eval "$install_command" >"$output_file" 2>&1; then
        log_info "Installation command for '$tool_name' executed. Output:"
        cat "$output_file" # Log the output from the command
    else
        log_error "Installation command for '$tool_name' failed. Output:"
        cat "$output_file" # Log the error output
        rm "$output_file"
        # Even if install command fails, proceed to check_tool to see if it's magically there
    fi
    rm "$output_file"

    log_info "Verifying installation of '$tool_name' after attempt..."
    if check_tool "$tool_name"; then # check_tool already logs success
        return 0
    else
        log_error "Failed to install or verify tool '$tool_name'."
        return 1
    fi
}

# Function to ensure a list of tools are installed
# Usage: ensure_tools "tool1" "tool2" ...
ensure_tools() {
    local required_tools=("$@")
    local all_tools_ready=true

    if [ ${#required_tools[@]} -eq 0 ]; then
        log_info "No tools specified for 'ensure_tools'."
        return 0
    fi

    log_info "Ensuring the following tools are installed: ${required_tools[*]}"

    for tool_name in "${required_tools[@]}"; do
        if ! check_tool "$tool_name"; then
            if ! install_tool "$tool_name"; then
                log_error "Failed to ensure tool '$tool_name' is installed. This may impact workflow execution."
                all_tools_ready=false
                # Depending on strictness, one might 'exit 1' here.
                # For now, we'll try to install all and report overall status.
            fi
        fi
    done

    if [ "$all_tools_ready" = true ]; then
        log_info "All required tools are installed and verified."
        return 0
    else
        log_error "One or more required tools could not be installed or verified."
        return 1 # Indicate failure
    fi
}

# Main argument parsing for standalone execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # This block executes if the script is run directly
    log_debug "tool_manager.sh executed directly."

    if [ "$#" -lt 1 ]; then
        log_error "Usage: $0 <command> [tool_name...]"
        log_info "Commands: check <tool_name>, install <tool_name>, ensure <tool_name1> [tool_name2 ...]"
        exit 1
    fi

    COMMAND="$1"
    shift

    case "$COMMAND" in
        check)
            if [ "$#" -ne 1 ]; then log_error "Usage: $0 check <tool_name>"; exit 1; fi
            check_tool "$1"
            ;;
        install)
            if [ "$#" -ne 1 ]; then log_error "Usage: $0 install <tool_name>"; exit 1; fi
            install_tool "$1"
            ;;
        ensure)
            if [ "$#" -lt 1 ]; then log_error "Usage: $0 ensure <tool_name1> [tool_name2 ...]"; exit 1; fi
            ensure_tools "$@" # Pass all remaining arguments as tool names
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            log_info "Commands: check <tool_name>, install <tool_name>, ensure <tool_name1> [tool_name2 ...]"
            exit 1
            ;;
    esac
    exit $? # Exit with the status of the last command
else
    log_debug "tool_manager.sh sourced, not executed directly."
fi
