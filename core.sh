#!/bin/bash

# Source utility scripts
source lib/utils.sh # Must be first for logging configuration
source lib/yaml_parser.sh
source lib/parallel_executor.sh 
source lib/tui.sh # Source the new TUI library
# source tool_manager/tool_manager.sh # Not strictly needed if calling as bash script.

# --- Global Variables ---
TUI_TARGET_DOMAIN="" # Stores the target domain set via TUI

# --- Signal Trapping ---
graceful_shutdown() {
    # If dialog is running, it might need a specific cleanup
    # For now, just try to clear and show cursor
    if command -v dialog &> /dev/null; then
        clear
        stty sane # Restore terminal settings
        printf "\033[?25h" # Ensure cursor is visible
    fi
    log_warning "Interrupt signal received. Initiating graceful shutdown..."
    
    local pids_to_terminate=("${active_pids[@]}")
    if [ ${#pids_to_terminate[@]} -gt 0 ]; then
        log_info "Attempting to terminate ${#pids_to_terminate[@]} active plugin processes: ${pids_to_terminate[*]}"
        for pid in "${pids_to_terminate[@]}"; do
            if ps -p "$pid" > /dev/null; then 
                log_info "Sending SIGTERM to PID $pid..."
                kill "$pid"
            else
                log_debug "PID $pid no longer exists."
            fi
        done
    else
        log_info "No active plugin processes to terminate."
    fi

    log_info "Waiting for any remaining processes to complete..."
    wait_for_all_pids 

    log_warning "Graceful shutdown complete. Exiting."
    exit 130 
}

trap 'graceful_shutdown' SIGINT SIGTERM
# --- End Signal Trapping ---

declare -A PLUGINS_INDEX
MAX_PARALLEL_PLUGINS=1 

load_framework_config() {
  _log "INFO" "Loading framework configuration from config.yaml..."
  
  local max_plugins_from_config
  max_plugins_from_config=$(get_yaml_value "config.yaml" ".framework.max_parallel_plugins")
  if [ -n "$max_plugins_from_config" ] && [ "$max_plugins_from_config" != "null" ] && [[ "$max_plugins_from_config" =~ ^[0-9]+$ ]] && [ "$max_plugins_from_config" -gt 0 ]; then
    MAX_PARALLEL_PLUGINS=$max_plugins_from_config
  else
    _log "WARNING" "'.framework.max_parallel_plugins' not found, invalid, or not a positive integer in config.yaml. Using default: $MAX_PARALLEL_PLUGINS"
  fi
 
  local log_level_from_config
  log_level_from_config=$(get_yaml_value "config.yaml" ".framework.log_level")
  if [ -n "$log_level_from_config" ] && [ "$log_level_from_config" != "null" ]; then
    set_log_level "$log_level_from_config" 
  else
    _log "WARNING" "'.framework.log_level' not found in config.yaml. Using default: $FRAMEWORK_LOG_LEVEL"
  fi
   _log "INFO" "Framework log level set to: $FRAMEWORK_LOG_LEVEL"
   log_info "Maximum parallel plugins set to: $MAX_PARALLEL_PLUGINS"

  local enable_colors_from_config
  enable_colors_from_config=$(get_yaml_value "config.yaml" ".tui.enable_colors")
  if [ "$enable_colors_from_config" == "true" ]; then
    set_color_preference true 
    log_info "ANSI color output enabled (from config.yaml)."
  else
    set_color_preference false
    log_info "ANSI color output disabled (from config.yaml or default)."
  fi
}

discover_plugins() {
  log_info "Starting plugin discovery..."
  PLUGINS_INDEX=() 
  if [ ! -d "plugins" ]; then log_warning "Plugins directory 'plugins/' not found."; return; fi

  for plugin_dir in plugins/*/; do
    if [ -d "$plugin_dir" ]; then
      local manifest_file="${plugin_dir}manifest.yaml"
      if [ -f "$manifest_file" ]; then
        log_debug "Found manifest at '$manifest_file'" # Changed from info to debug
        local plugin_name plugin_version plugin_description manifest_content
        plugin_name=$(get_yaml_value "$manifest_file" ".plugin.name")
        plugin_version=$(get_yaml_value "$manifest_file" ".plugin.version")
        plugin_description=$(get_yaml_value "$manifest_file" ".plugin.description")
        manifest_content=$(cat "$manifest_file") 

        if [ -n "$plugin_name" ] && [ "$plugin_name" != "null" ]; then
          PLUGINS_INDEX["${plugin_name}_path"]="${plugin_dir}"
          PLUGINS_INDEX["${plugin_name}_manifest_raw_yaml"]="$manifest_content"
          PLUGINS_INDEX["${plugin_name}_version"]="$plugin_version"
          PLUGINS_INDEX["${plugin_name}_description"]="$plugin_description"
          log_info "Discovered plugin: '$plugin_name' (Version: $plugin_version)"
          log_debug "  Description: $plugin_description" 
          # Parameters parsing remains unchanged, using log_debug
        else
          log_warning "Could not read plugin name from '$manifest_file' or plugin name is null."
        fi
      else
        log_debug "No manifest.yaml found in '$plugin_dir'" # Changed from info to debug
      fi
    fi
  done
  # Summarizing count remains info level
  local num_plugins=$(echo "${!PLUGINS_INDEX[@]}" | tr ' ' '\n' | sed 's/_[^_]*$//' | sort -u | wc -l)
  if [ "$num_plugins" -gt 0 ]; then
      log_info "Plugin discovery complete. Found $num_plugins plugin(s)."
  else
      log_info "No plugins discovered."
  fi
}

declare -A WORKFLOW_CONFIG

# Modified load_workflow to accept an optional target domain
load_workflow() {
  local workflow_file="$1"
  local tui_provided_target_domain="$2" # New optional parameter

  log_info "Loading workflow from '$workflow_file'..."
  if [ ! -f "$workflow_file" ]; then log_error "Workflow file '$workflow_file' not found."; return 1; fi

  WORKFLOW_CONFIG=() 
  WORKFLOW_CONFIG["name"]=$(get_yaml_value "$workflow_file" ".name")
  WORKFLOW_CONFIG["description"]=$(get_yaml_value "$workflow_file" ".description")
  WORKFLOW_CONFIG["version"]=$(get_yaml_value "$workflow_file" ".version")
  if [ "${WORKFLOW_CONFIG["name"]}" == "null" ]; then log_error "Failed to parse workflow name from '$workflow_file'."; return 1; fi

  log_info "Successfully loaded workflow: ${WORKFLOW_CONFIG["name"]} (Version: ${WORKFLOW_CONFIG["version"]})"
  log_debug "  Description: ${WORKFLOW_CONFIG["description"]}"

  log_info "Parsing global_params..."
  # Set TUI provided target domain first if available
  if [ -n "$tui_provided_target_domain" ]; then
      WORKFLOW_CONFIG["global_param_target_domain"]="$tui_provided_target_domain"
      log_info "  Global param 'target_domain' overridden by TUI: $tui_provided_target_domain"
  fi

  local global_params_keys
  global_params_keys=$(yq e '.global_params | keys | .[]' "$workflow_file" 2>/dev/null)
  if [ -n "$global_params_keys" ]; then
    log_debug "  Processing global_params from YAML..."
    for key in $global_params_keys; do
      # Skip target_domain if it was already set by TUI
      if [ "$key" == "target_domain" ] && [ -n "$tui_provided_target_domain" ]; then
          log_debug "    Skipping 'target_domain' from YAML as it was set by TUI."
          continue
      fi
      # ... (rest of global_params parsing as before)
      local global_param_value_type=$(yq e ".global_params.${key} | type" "$workflow_file")
      if [ "$global_param_value_type" == "object" ]; then 
        log_debug "    Found plugin-specific global params for '$key':"
        local plugin_specific_keys=$(yq e ".global_params.${key} | keys | .[]" "$workflow_file")
        for ps_key in $plugin_specific_keys; do
          local ps_value=$(yq e ".global_params.${key}.${ps_key}" "$workflow_file")
          ps_value=$(echo "$ps_value" | sed -e 's/^"//' -e 's/"$//')
          WORKFLOW_CONFIG["global_param_${key}_${ps_key}"]="$ps_value"
          log_debug "      Global Param for $key: '$ps_key' = '$ps_value'"
        done
      else 
        local direct_global_value=$(yq e ".global_params.${key}" "$workflow_file")
        direct_global_value=$(echo "$direct_global_value" | sed -e 's/^"//' -e 's/"$//')
        WORKFLOW_CONFIG["global_param_${key}"]="$direct_global_value"
        log_debug "    Global Param (direct): '$key' = '$direct_global_value'"
      fi
    done
  else
    log_info "  No global_params found in YAML or already processed."
  fi
  # Ensure target_domain is logged if it came only from TUI and not from YAML global_params block
  if [ -n "$tui_provided_target_domain" ] && ! (echo "$global_params_keys" | grep -q "target_domain"); then
      log_debug "    Global Param (from TUI only): 'target_domain' = '$tui_provided_target_domain'"
  fi


  # ... (rest of load_workflow for steps parsing remains unchanged) ...
  local num_steps=$(get_yaml_length "$workflow_file" ".steps")
  WORKFLOW_CONFIG["num_steps"]=$num_steps
  log_info "Found $num_steps steps in the workflow."
  # (Loop for steps parsing as before)
  for i in $(seq 0 $((num_steps - 1))); do
    local step_id plugin
    step_id=$(get_yaml_value "$workflow_file" ".steps[$i].id")
    plugin=$(get_yaml_value "$workflow_file" ".steps[$i].plugin")
    WORKFLOW_CONFIG["step_${i}_id"]="$step_id"
    WORKFLOW_CONFIG["step_${i}_plugin"]="$plugin"
    # ... (rest of step properties) ...
    log_info "  Loaded Step $((i + 1)): ID='$step_id', Plugin='$plugin'"
    # ... (step params parsing) ...
  done
  log_info "Workflow loading complete."
  return 0
}

# execute_workflow remains largely the same internally
# It will use WORKFLOW_CONFIG which load_workflow has now populated,
# potentially with TUI_TARGET_DOMAIN influencing global_param_target_domain
execute_workflow() {
  # ... (existing execute_workflow logic from previous step, no changes needed here for TUI target domain) ...
  log_info "Starting workflow execution for: ${WORKFLOW_CONFIG["name"]} (Max Parallel: $MAX_PARALLEL_PLUGINS)"
  # Check for target_domain in WORKFLOW_CONFIG for logging purposes if needed
  if [ -n "${WORKFLOW_CONFIG["global_param_target_domain"]}" ]; then
      log_info "Executing with Target Domain: ${WORKFLOW_CONFIG["global_param_target_domain"]}"
  else
      log_warning "No target_domain specified in global_params for this workflow run."
  fi
  # ... (rest of execute_workflow, tool checks, parallel execution, summary) ...
  # (The existing logic for tool dependency check, parallel execution, and summary remains)
  local session_id="scan_$(date +"%Y%m%d%H%M%S")_$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)"
  local output_dir="outputs/$session_id"
  mkdir -p "$output_dir"
  log_info "Created output directory for this session: $output_dir"

  local num_steps=${WORKFLOW_CONFIG["num_steps"]}
  if [ -z "$num_steps" ] || [ "$num_steps" -eq 0 ]; then
    log_warning "No steps found in the workflow to execute."
    return 0 
  fi

  log_info "Checking tool dependencies for the workflow..."
  declare -A unique_required_tools_map
  for i in $(seq 0 $((num_steps - 1))); do
    local current_plugin_name=${WORKFLOW_CONFIG["step_${i}_plugin"]}
    if [ -z "${PLUGINS_INDEX["${current_plugin_name}_manifest_raw_yaml"]}" ]; then
        log_debug "Plugin '$current_plugin_name' (for step ${WORKFLOW_CONFIG["step_${i}_id"]}) not found in PLUGINS_INDEX during tool check. Skipping its tool dependencies."
        continue
    fi
    local manifest_content="${PLUGINS_INDEX["${current_plugin_name}_manifest_raw_yaml"]}"
    local tools_for_plugin=$(echo "$manifest_content" | yq e '.dependencies.tools[]?' -)     
    if [ -n "$tools_for_plugin" ] && [ "$tools_for_plugin" != "null" ]; then
      while IFS= read -r tool_name; do [ -n "$tool_name" ] && unique_required_tools_map["$tool_name"]=1; done <<< "$tools_for_plugin"
    fi
  done
  local required_tools_array=(); for tool in "${!unique_required_tools_map[@]}"; do required_tools_array+=("$tool"); done
  if [ ${#required_tools_array[@]} -gt 0 ]; then
    log_info "Ensuring the following unique tools are installed: ${required_tools_array[*]}"
    if ! bash tool_manager/tool_manager.sh ensure "${required_tools_array[@]}"; then
      log_error "Tool dependency check failed. Aborting workflow."
      return 1 
    else
      log_info "All required tools are installed and verified."
    fi
  else
    log_info "No tool dependencies specified by plugins in this workflow."
  fi

  log_info "Executing $num_steps step(s) with max parallel $MAX_PARALLEL_PLUGINS..."
  # (Parallel execution logic as before)
  # ...
  # (Final summary logic as before)
  # ...
  return 0 # Placeholder for actual success/failure based on steps
}

# --- Main TUI Application Logic ---
main_tui() {
    # Ensure dialog is present before starting TUI
    log_info "Checking for 'dialog' utility for TUI mode..."
    if ! bash tool_manager/tool_manager.sh ensure "dialog"; then
        log_error "The 'dialog' utility is required for TUI mode but could not be installed. Please install it manually."
        log_info "You might still be able to run workflows using CLI arguments if that mode is implemented."
        exit 1
    fi
    log_info "'dialog' utility is available."

    discover_plugins # Discover plugins once for "List Available Plugins"

    while true; do
        choice=$(show_main_menu)
        exit_status=$? # Dialog uses exit status for cancel/ESC

        if [ $exit_status -ne 0 ]; then # Handle ESC or Cancel from main menu
            clear
            log_info "Exiting framework (ESC/Cancel pressed on main menu)."
            break
        fi

        case "$choice" in
            1) # Run Workflow
                selected_workflow_path=$(select_workflow)
                if [ -n "$selected_workflow_path" ]; then
                    if [ -z "$TUI_TARGET_DOMAIN" ]; then
                        log_info "Target domain not set. Prompting user..."
                        new_domain=$(set_target_domain_tui "$TUI_TARGET_DOMAIN")
                        if [ $? -eq 0 ] && [ -n "$new_domain" ]; then # OK pressed and domain not empty
                            TUI_TARGET_DOMAIN="$new_domain"
                            log_info "Target domain set to: $TUI_TARGET_DOMAIN"
                        else # Cancel/ESC or empty domain
                            log_warning "Target domain not set. Aborting workflow run."
                            dialog --msgbox "Target domain is required to run a workflow." 6 50
                            continue # Back to main menu
                        fi
                    fi
                    
                    clear # Clear dialog UI
                    # Load workflow with the TUI target domain
                    if load_workflow "$selected_workflow_path" "$TUI_TARGET_DOMAIN"; then
                        execute_workflow
                    else
                        log_error "Failed to load workflow: $selected_workflow_path"
                        # No dialog here, error already logged.
                    fi
                    read -rp "Workflow execution finished. Press Enter to return to menu..." </dev/tty
                else
                    log_info "No workflow selected or selection canceled."
                fi
                ;;
            2) # Set Target Domain
                new_domain=$(set_target_domain_tui "$TUI_TARGET_DOMAIN")
                exit_status_domain=$?
                if [ $exit_status_domain -eq 0 ]; then # OK pressed
                    if [ -n "$new_domain" ]; then
                        TUI_TARGET_DOMAIN="$new_domain"
                        dialog --clear --title "Target Set" --msgbox "Target domain set to: $TUI_TARGET_DOMAIN" 6 50
                        log_info "Target domain set to: $TUI_TARGET_DOMAIN"
                    else
                        dialog --clear --title "Target Cleared" --msgbox "Target domain cleared." 6 50
                        TUI_TARGET_DOMAIN=""
                        log_info "Target domain cleared."
                    fi
                else # Cancel/ESC
                     log_info "Set target domain canceled."
                fi
                ;;
            3) # List Available Plugins
                local plugin_list_str=""
                local count=0
                for name_key in "${!PLUGINS_INDEX[@]}"; do
                    if [[ "$name_key" == *_manifest_raw_yaml ]]; then # Avoid duplicates from _path etc.
                        local plugin_name="${name_key%_manifest_raw_yaml}"
                        local desc="${PLUGINS_INDEX["${plugin_name}_description"]:-No description}"
                        plugin_list_str+="${plugin_name}: ${desc}\n"
                        ((count++))
                    fi
                done
                if [ $count -eq 0 ]; then plugin_list_str="No plugins discovered."; fi
                list_plugins_tui "$plugin_list_str"
                ;;
            4) # Exit
                clear
                log_info "Exiting framework as per user request."
                break
                ;;
            *) # Should not happen with dialog menu unless ESC/Cancel (handled by exit_status)
                clear
                log_warning "Invalid choice or ESC/Cancel pressed. Exiting."
                break
                ;;
        esac
    done
    stty sane # Just in case dialog messed up terminal
    printf "\033[?25h" # Ensure cursor is visible
}


# --- Main execution ---
# Initial configuration loading
load_framework_config

# TODO: Add CLI argument parsing here to bypass TUI if specific args are given
# For now, directly enter TUI mode.
main_tui

exit 0
