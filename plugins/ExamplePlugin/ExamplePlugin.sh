#!/bin/bash

# Attempt to source utils.sh.
# This path assumes the plugin script is executed from its own directory,
# and core.sh is two levels up.
UTILS_PATH_GUESS_1="$(dirname "$0")/../../lib/utils.sh" # If script is in plugins/ExamplePlugin/
UTILS_PATH_GUESS_2="../../lib/utils.sh" # If CWD is plugins/ExamplePlugin/ during execution

if [ -f "$UTILS_PATH_GUESS_1" ]; then
    source "$UTILS_PATH_GUESS_1"
elif [ -f "$UTILS_PATH_GUESS_2" ]; then
    source "$UTILS_PATH_GUESS_2"
else
    # Fallback to plain echo if utils.sh is not found
    echo "ExamplePlugin: [WARNING] utils.sh not found, using basic echo for logging."
    log_info() { echo "ExamplePlugin: [INFO] $*"; }
    log_debug() { echo "ExamplePlugin: [DEBUG] $*"; }
    log_warning() { echo "ExamplePlugin: [WARNING] $*"; }
    log_error() { echo "ExamplePlugin: [ERROR] $*" >&2; }
    # Set dummy color preference if not available
    set_color_preference() { :; }
    set_log_level() { :; }
fi

# Initialize logging within the plugin (it will use its own defaults or what's inherited)
# If utils.sh was sourced, these functions are defined.
set_log_level "${FRAMEWORK_LOG_LEVEL:-INFO}" # Inherit or default
set_color_preference "${ENABLE_COLORS:-false}" # Inherit or default


# Default values for parameters
OUTPUT_DIR="."
SPECIFIC_PARAM="default_specific_plugin_value"
ANOTHER_PARAM=0
SOME_GLOBAL_PARAM="default_global_plugin_value"
SLEEP_DURATION=1 
FORCE_ERROR=false # New parameter

# Store all args for JSON output
ALL_ARGS="$@"

# Simple argument parser
log_debug "ExamplePlugin: Parsing arguments..."
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --output-dir)
      OUTPUT_DIR="$2"; shift 2
      ;;
    --specific_param_for_step1)
      SPECIFIC_PARAM="$2"; shift 2
      ;;
    --another_param)
      ANOTHER_PARAM="$2"; shift 2
      ;;
    --some_global_param_for_plugin)
      SOME_GLOBAL_PARAM="$2"; shift 2
      ;;
    --sleep_duration)
      SLEEP_DURATION="$2"; shift 2
      ;;
    --force-error) # New argument
      FORCE_ERROR="$2"; shift 2
      ;;
    *) 
      log_warning "ExamplePlugin: Unknown option: $1"
      shift 
      ;;
  esac
done

log_info "ExamplePlugin: --- Resolved Parameters (from inside plugin) ---"
log_info "ExamplePlugin: Output Directory: $OUTPUT_DIR"
log_info "ExamplePlugin: Specific Param for Step 1: $SPECIFIC_PARAM"
log_info "ExamplePlugin: Another Param: $ANOTHER_PARAM"
log_info "ExamplePlugin: Some Global Param for Plugin: $SOME_GLOBAL_PARAM"
log_info "ExamplePlugin: Sleep Duration: $SLEEP_DURATION seconds"
log_info "ExamplePlugin: Force Error: $FORCE_ERROR"
log_debug "ExamplePlugin: All args received by plugin: $ALL_ARGS"
log_info "ExamplePlugin: ---------------------------------------------"

if [ "$FORCE_ERROR" == "true" ]; then
    log_error "ExamplePlugin: Forced error triggered as per --force-error flag!"
    # Create a dummy results.json to indicate failure, if desired by convention
    results_file_on_error="${OUTPUT_DIR}/results.json"
    printf '{\n' > "$results_file_on_error"
    printf '  "plugin_name": "ExamplePlugin",\n' >> "$results_file_on_error"
    printf '  "summary": "ExamplePlugin failed due to forced error.",\n' >> "$results_file_on_error"
    printf '  "error_details": "Forced error triggered via --force-error flag."\n' >> "$results_file_on_error"
    printf '}\n' >> "$results_file_on_error"
    log_info "ExamplePlugin: Wrote error information to $results_file_on_error"
    exit 1 # Exit with a non-zero status
fi

log_info "ExamplePlugin: Starting work (sleeping for $SLEEP_DURATION seconds)..."
sleep "$SLEEP_DURATION"
log_info "ExamplePlugin: Finished work."

if [ ! -d "$OUTPUT_DIR" ]; then
  log_info "ExamplePlugin: Output directory $OUTPUT_DIR does not exist. Creating it."
  mkdir -p "$OUTPUT_DIR"
fi

execution_log="${OUTPUT_DIR}/execution_log.txt" 
log_debug "ExamplePlugin: Writing execution log to $execution_log"
echo "This is an execution log from ExamplePlugin." > "$execution_log"
echo "ExamplePlugin executed successfully after sleeping for $SLEEP_DURATION seconds." >> "$execution_log"
current_time=$(date +"%Y-%m-%d %H:%M:%S")
echo "$current_time: Plugin executed with parameters:" >> "$execution_log"
echo "$current_time: Output Dir: $OUTPUT_DIR" >> "$execution_log"
# ... (other params to execution_log) ...

results_file="${OUTPUT_DIR}/results.json"
log_info "ExamplePlugin: Creating results.json at $results_file"

printf '{\n' > "$results_file"
printf '  "plugin_name": "ExamplePlugin",\n' >> "$results_file"
printf '  "execution_parameters": {\n' >> "$results_file"
printf '    "specific_param_for_step1": "%s",\n' "$SPECIFIC_PARAM" >> "$results_file"
printf '    "another_param": %s,\n' "$ANOTHER_PARAM" >> "$results_file" 
printf '    "some_global_param_for_plugin": "%s",\n' "$SOME_GLOBAL_PARAM" >> "$results_file"
printf '    "sleep_duration": %s,\n' "$SLEEP_DURATION" >> "$results_file"
printf '    "force_error_flag": "%s"\n' "$FORCE_ERROR" >> "$results_file"
printf '  },\n' >> "$results_file"
printf '  "findings": [\n' >> "$results_file"
printf '    {"item": "dummy_item_1", "details": "Details for item 1 generated by ExamplePlugin"},\n' >> "$results_file"
printf '    {"item": "dummy_item_2", "details": "Details for item 2 with sleep %s"}\n' "$SLEEP_DURATION" >> "$results_file"
printf '  ],\n' >> "$results_file"
printf '  "summary": "ExamplePlugin executed successfully with specific_param: %s and slept for %s seconds.",\n' "$SPECIFIC_PARAM" "$SLEEP_DURATION" >> "$results_file"
printf '  "output_files": {\n' >> "$results_file"
printf '    "execution_log": "%s",\n' "$(basename "$execution_log")" >> "$results_file"
printf '    "results_json": "%s"\n' "$(basename "$results_file")" >> "$results_file"
printf '  }\n' >> "$results_file"
printf '}\n' >> "$results_file"

log_info "ExamplePlugin: Successfully created $results_file"
log_info "ExamplePlugin: Successfully created $execution_log"

exit 0
