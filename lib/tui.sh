#!/bin/bash

# TUI functions using dialog
# Make sure utils.sh is sourced by the calling script (core.sh) for logging in these functions if needed.

# Function to show the main menu
# Output: Choice number (1-4) or empty if canceled/ESC
show_main_menu() {
    local choice
    choice=$(dialog --clear --backtitle "Workflow Orchestration Framework" \
                    --title "Main Menu" \
                    --menu "Select an option:" 15 50 4 \
                    1 "Run Workflow" \
                    2 "Set Target Domain" \
                    3 "List Available Plugins" \
                    4 "Exit" \
                    2>&1 >/dev/tty)
    echo "$choice"
}

# Function to select a workflow file from the workflows/ directory
# Output: Full path to selected workflow file or empty if canceled/ESC
select_workflow() {
    local workflow_files=()
    local i=1
    while IFS= read -r -d $'\0' file; do
        workflow_files+=("$i" "$(basename "$file")")
        workflow_files+=("$(realpath "$file")") # Store full path secretly
        ((i++))
    done < <(find workflows/ -maxdepth 1 -type f -name "*.yaml" -print0 2>/dev/null)

    if [ ${#workflow_files[@]} -eq 0 ]; then
        dialog --clear --backtitle "Workflow Orchestration Framework" \
               --title "Select Workflow" --msgbox "No workflow (.yaml) files found in workflows/ directory." 8 50
        echo ""
        return
    fi

    # Reformat for --menu: tag1 item1 tag2 item2 ...
    local menu_options=()
    local j=0
    while [ $j -lt ${#workflow_files[@]} ]; do
        menu_options+=("${workflow_files[j]}" "${workflow_files[j+1]}") # tag item
        j=$((j+2)) # Move past the full path
        j=$((j+1)) # And past the tag for next item
    done
    
    local choice
    choice=$(dialog --clear --backtitle "Workflow Orchestration Framework" \
                    --title "Select Workflow" \
                    --menu "Choose a workflow to run:" 20 70 15 \
                    "${menu_options[@]}" \
                    2>&1 >/dev/tty)
    
    if [ -z "$choice" ]; then # Canceled
        echo ""
        return
    fi

    # Find the full path corresponding to the choice
    # choice is the tag (1, 2, etc.)
    local k=0
    while [ $k -lt ${#workflow_files[@]} ]; do
        if [ "${workflow_files[k]}" == "$choice" ]; then
            echo "${workflow_files[k+2]}" # Output the full path
            return
        fi
        k=$((k+3)) # Move to the next set of tag, item, fullpath
    done
    echo "" # Should not happen if choice is valid
}

# Function to set the target domain
# Output: The entered domain or empty if canceled/ESC
set_target_domain_tui() {
    local current_domain="$1" # Pass current domain to pre-fill
    local domain
    domain=$(dialog --clear --backtitle "Workflow Orchestration Framework" \
                   --title "Set Target Domain" \
                   --inputbox "Enter the target domain (e.g., example.com):" 8 60 "$current_domain" \
                   2>&1 >/dev/tty)
    echo "$domain"
}

# Function to list available plugins (Bonus)
# Input: PLUGINS_INDEX (associative array) must be accessible or its content passed
# This is tricky as it needs access to PLUGINS_INDEX from core.sh
# For now, it will expect a pre-formatted string.
# A better way would be for core.sh to prepare the string and pass it.
list_plugins_tui() {
    local plugin_info_string="$1" # Expects a string like "Plugin1: Desc1\nPlugin2: Desc2"

    if [ -z "$plugin_info_string" ]; then
        plugin_info_string="No plugins discovered or information available."
    fi

    dialog --clear --backtitle "Workflow Orchestration Framework" \
           --title "Available Plugins" \
           --msgbox "$plugin_info_string" 20 70
}

# --- Test functions if run directly ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Ensure utils.sh is sourced for logging if testing standalone
    # This requires utils.sh to be in ../lib relative to this script's location
    if [ -f "$(dirname "$0")/../lib/utils.sh" ]; then
        source "$(dirname "$0")/../lib/utils.sh"
        set_log_level "DEBUG"
        set_color_preference true
        log_info "tui.sh: Sourced utils.sh for standalone testing."
    else
        echo "tui.sh: [WARNING] utils.sh not found at ../lib/utils.sh for standalone testing."
    fi

    # Test show_main_menu
    # local menu_choice
    # menu_choice=$(show_main_menu)
    # echo "Main menu choice: $menu_choice"
    # read -p "Press enter to continue"

    # Test select_workflow (requires workflows/ dir and some .yaml files)
    # mkdir -p ../../workflows # Assuming script is in lib/
    # touch ../../workflows/test1.yaml ../../workflows/another_test.yaml
    # local selected_wf
    # selected_wf=$(select_workflow)
    # echo "Selected workflow: $selected_wf"
    # rm -rf ../../workflows
    # read -p "Press enter to continue"

    # Test set_target_domain
    # local domain
    # domain=$(set_target_domain_tui "prefill.com")
    # echo "Set domain: $domain"
    # read -p "Press enter to continue"
    
    # Test list_plugins
    # list_plugins_tui "PluginA: Does A\nPluginB: Does B and is very long so it wraps around the screen nicely to show how msgbox handles it."
    # read -p "Press enter to continue"
    
    clear
    echo "tui.sh standalone tests finished."
fi
