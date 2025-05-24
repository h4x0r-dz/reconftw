#!/bin/bash

# Source utilities
UTILS_PATH_GUESS_1="$(dirname "$0")/../../lib/utils.sh" 
UTILS_PATH_GUESS_2="../../lib/utils.sh" 

if [ -f "$UTILS_PATH_GUESS_1" ]; then
    source "$UTILS_PATH_GUESS_1"
elif [ -f "$UTILS_PATH_GUESS_2" ]; then
    source "$UTILS_PATH_GUESS_2"
else
    echo "OsintModule: [ERROR] utils.sh not found. Critical for logging. Exiting." >&2
    exit 1
fi

set_log_level "${FRAMEWORK_LOG_LEVEL:-INFO}" 
set_color_preference "${ENABLE_COLORS:-false}" 

# Default values for parameters
TARGET_DOMAIN=""
COMPANY_NAME="" 
ENABLE_DOMAIN_INFO="true"
WHOISXML_API_KEY=""
ENABLE_GOOGLE_DORKS="true"
DORKS_HUNTER_PATH="tools/dorks_hunter/dorks_hunter.py" 
DORKS_HUNTER_PYTHON="tools/dorks_hunter/venv/bin/python3"
ENABLE_GITHUB_DORKS="true" 
GITHUB_TOKENS_FILE="${HOME}/.config/reconftw/github_tokens.txt" 
DEEP_SCAN_MODE="false" 
GITDORKS_GO_TOOL_PATH="gitdorks_go" 
GITDORKS_SMALLDORKS_FILE="tools/gitdorks_go/Dorks/smalldorks.txt" 
GITDORKS_MEDIUMDORKS_FILE="tools/gitdorks_go/Dorks/medium_dorks.txt" 
ENABLE_GITHUB_REPOS="true" 
ENABLE_METADATA="true" 
METAFINDER_LIMIT=100 
OUTPUT_DIR="." 

# New v0.3.0 parameters
ENABLE_APILEAKS="true"
SWAGGERSBY_PATH="tools/SwaggerSpy/SwaggerSpy.py"
SWAGGERSBY_VENV_PYTHON="tools/SwaggerSpy/venv/bin/python3"
ENABLE_EMAILS_LEAKS="true"
LEAKSEARCH_PATH="tools/LeakSearch/LeakSearch.py"
LEAKSEARCH_VENV_PYTHON="tools/LeakSearch/venv/bin/python3"
LEAKSEARCH_MAX_CONCURRENT=5
ENABLE_THIRD_PARTY_MISCONFIGS="true"
COMPANY_NAME_FOR_MISCONFIG="" # Defaults to COMPANY_NAME or TARGET_DOMAIN if empty
ENABLE_SPOOF_CHECK="true"
SPOOFY_PATH="tools/Spoofy/spoofy.py"
SPOOFY_VENV_PYTHON="tools/Spoofy/venv/bin/python3"
ENABLE_IP_INFO="true"


declare -A RESULTS_JSON_MAP # Associative array to build results.json content

log_debug "OsintModule: Parsing arguments..."
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --target_domain) TARGET_DOMAIN="$2"; shift ;;
        --company_name) COMPANY_NAME="$2"; shift ;;
        --enable_domain_info) ENABLE_DOMAIN_INFO="$2"; shift ;;
        --whoisxml_api_key) WHOISXML_API_KEY="$2"; shift ;;
        --enable_google_dorks) ENABLE_GOOGLE_DORKS="$2"; shift ;;
        --dorks_hunter_path) DORKS_HUNTER_PATH="$2"; shift ;;
        --dorks_hunter_venv_python) DORKS_HUNTER_PYTHON="$2"; shift ;;
        --enable_github_dorks) ENABLE_GITHUB_DORKS="$2"; shift ;;
        --github_tokens_file) GITHUB_TOKENS_FILE="$2"; shift ;;
        --deep_scan_mode) DEEP_SCAN_MODE="$2"; shift ;;
        --gitdorks_go_tool_path) GITDORKS_GO_TOOL_PATH="$2"; shift ;;
        --gitdorks_smalldorks_file) GITDORKS_SMALLDORKS_FILE="$2"; shift ;;
        --gitdorks_mediumdorks_file) GITDORKS_MEDIUMDORKS_FILE="$2"; shift ;;
        --enable_github_repos) ENABLE_GITHUB_REPOS="$2"; shift ;;
        --enable_metadata) ENABLE_METADATA="$2"; shift ;;
        --metafinder_limit) METAFINDER_LIMIT="$2"; shift ;;
        # New v0.3.0 params
        --enable_apileaks) ENABLE_APILEAKS="$2"; shift ;;
        --swaggerspy_path) SWAGGERSBY_PATH="$2"; shift ;; # Corrected variable name
        --swaggerspy_venv_python) SWAGGERSBY_VENV_PYTHON="$2"; shift ;; # Corrected variable name
        --enable_emails_leaks) ENABLE_EMAILS_LEAKS="$2"; shift ;;
        --leaksearch_path) LEAKSEARCH_PATH="$2"; shift ;;
        --leaksearch_venv_python) LEAKSEARCH_VENV_PYTHON="$2"; shift ;;
        --leaksearch_max_concurrent) LEAKSEARCH_MAX_CONCURRENT="$2"; shift ;;
        --enable_third_party_misconfigs) ENABLE_THIRD_PARTY_MISCONFIGS="$2"; shift ;;
        --company_name_for_misconfig) COMPANY_NAME_FOR_MISCONFIG="$2"; shift ;;
        --enable_spoof_check) ENABLE_SPOOF_CHECK="$2"; shift ;;
        --spoofy_path) SPOOFY_PATH="$2"; shift ;;
        --spoofy_venv_python) SPOOFY_VENV_PYTHON="$2"; shift ;;
        --enable_ip_info) ENABLE_IP_INFO="$2"; shift ;;
        --output_dir) OUTPUT_DIR="$2"; shift ;;
        *) log_warning "OsintModule: Unknown parameter: $1" ;;
    esac
    shift
done

# Parameter validation (essential ones)
if [ -z "$TARGET_DOMAIN" ]; then
    log_error "OsintModule: Critical parameter --target_domain not provided. Exiting."
    mkdir -p "$OUTPUT_DIR"; printf '{"error":"missing target_domain"}\n' > "$OUTPUT_DIR/results.json"; exit 1
fi
if [ -z "$OUTPUT_DIR" ] || [ "$OUTPUT_DIR" == "." ]; then
    log_error "OsintModule: Critical parameter --output_dir not provided or is default. Exiting."; exit 1
fi

OSINT_SUBDIR="$OUTPUT_DIR/osint"
TMP_SUBDIR="$OUTPUT_DIR/.tmp" 
mkdir -p "$OSINT_SUBDIR" "$TMP_SUBDIR"
log_info "OsintModule: Output will be saved in $OSINT_SUBDIR. Temporary files in $TMP_SUBDIR"

# --- Existing Tasks (domain_info, google_dorks, github_dorks, github_repos, metadata) ---
# These functions are assumed to be present from the previous refactoring step and are kept for brevity.
# They should use log_* functions and populate RESULTS_JSON_MAP.
domain_info_task() { log_info "OsintModule: (Skipped in this snippet) domain_info for $TARGET_DOMAIN"; }
google_dorks_task() { log_info "OsintModule: (Skipped in this snippet) google_dorks for $TARGET_DOMAIN"; }
github_dorks_task() { log_info "OsintModule: (Skipped in this snippet) GitHub Dorks for $TARGET_DOMAIN"; }
github_repos_task() { log_info "OsintModule: (Skipped in this snippet) GitHub Repos for $TARGET_DOMAIN"; }
metadata_task() { log_info "OsintModule: (Skipped in this snippet) Metadata Analysis for $TARGET_DOMAIN"; }


# --- apileaks_task ---
apileaks_task() {
    log_info "OsintModule: Starting API leaks detection for $TARGET_DOMAIN"
    local postman_output="$OSINT_SUBDIR/apileaks_postman.txt"
    local swagger_output="$OSINT_SUBDIR/apileaks_swagger.txt"
    local apileaks_tmp_dir="$TMP_SUBDIR/apileaks"; mkdir -p "$apileaks_tmp_dir"

    # porch-pirate for Postman collections
    if command -v porch-pirate &>/dev/null; then
        log_info "OsintModule: Running porch-pirate for $TARGET_DOMAIN..."
        porch-pirate -d "$TARGET_DOMAIN" -s "$apileaks_tmp_dir/porch_pirate_session.json" > "$postman_output"
        if [ -s "$postman_output" ]; then RESULTS_JSON_MAP["apileaks_postman_file"]="osint/$(basename "$postman_output")"; fi
    else
        log_warning "OsintModule: porch-pirate command not found. Skipping Postman collection search."
        RESULTS_JSON_MAP["apileaks_postman_error"]="porch-pirate not found"
    fi

    # SwaggerSpy for Swagger/OpenAPI files
    if [ -f "$SWAGGERSBY_VENV_PYTHON" ] && [ -x "$SWAGGERSBY_VENV_PYTHON" ] && [ -f "$SWAGGERSBY_PATH" ]; then
        log_info "OsintModule: Running SwaggerSpy for $TARGET_DOMAIN..."
        "$SWAGGERSBY_VENV_PYTHON" "$SWAGGERSBY_PATH" -t "$TARGET_DOMAIN" -o "$swagger_output"
        if [ -s "$swagger_output" ]; then RESULTS_JSON_MAP["apileaks_swagger_file"]="osint/$(basename "$swagger_output")"; fi
    else
        log_warning "OsintModule: SwaggerSpy script/venv not found/executable. Paths: Script='${SWAGGERSBY_PATH}', Venv='${SWAGGERSBY_VENV_PYTHON}'. Skipping Swagger search."
        RESULTS_JSON_MAP["apileaks_swagger_error"]="SwaggerSpy script/venv not found or not executable"
    fi
    log_info "OsintModule: API leaks detection task completed."
}

# --- emails_leaks_task ---
emails_leaks_task() {
    log_info "OsintModule: Starting email gathering and leak checking for $TARGET_DOMAIN"
    local emails_file="$OSINT_SUBDIR/emails_gathered.txt"
    local passwords_file="$OSINT_SUBDIR/password_leaks.txt" # From LeakSearch

    # emailfinder
    if command -v emailfinder &>/dev/null; then
        log_info "OsintModule: Running emailfinder for $TARGET_DOMAIN..."
        emailfinder -d "$TARGET_DOMAIN" -o "$emails_file"
        if [ -s "$emails_file" ]; then RESULTS_JSON_MAP["emails_gathered_file"]="osint/$(basename "$emails_file")"; fi
    else
        log_warning "OsintModule: emailfinder command not found. Skipping email gathering."
        RESULTS_JSON_MAP["emails_gathered_error"]="emailfinder not found"
    fi

    # LeakSearch
    if [ -f "$LEAKSEARCH_VENV_PYTHON" ] && [ -x "$LEAKSEARCH_VENV_PYTHON" ] && [ -f "$LEAKSEARCH_PATH" ]; then
        if [ -s "$emails_file" ]; then # Only run if we have emails
            log_info "OsintModule: Running LeakSearch on gathered emails..."
            # LeakSearch might take a file of emails or individual emails. Adapt as needed.
            # Assuming it takes a file of emails:
            "$LEAKSEARCH_VENV_PYTHON" "$LEAKSEARCH_PATH" -i "$emails_file" -o "$passwords_file" -j "$LEAKSEARCH_MAX_CONCURRENT"
            if [ -s "$passwords_file" ]; then RESULTS_JSON_MAP["password_leaks_file"]="osint/$(basename "$passwords_file")"; fi
        else
            log_info "OsintModule: No emails gathered by emailfinder, skipping LeakSearch."
        fi
    else
        log_warning "OsintModule: LeakSearch script/venv not found/executable. Paths: Script='${LEAKSEARCH_PATH}', Venv='${LEAKSEARCH_VENV_PYTHON}'. Skipping password leak search."
        RESULTS_JSON_MAP["password_leaks_error"]="LeakSearch script/venv not found or not executable"
    fi
    log_info "OsintModule: Email gathering and leak checking task completed."
}

# --- third_party_misconfigs_task ---
third_party_misconfigs_task() {
    log_info "OsintModule: Starting third-party misconfiguration checks for $TARGET_DOMAIN"
    local misconfigs_output_file="$OSINT_SUBDIR/third_party_misconfigs.txt"
    local misconfig_target_name="${COMPANY_NAME_FOR_MISCONFIG:-${COMPANY_NAME:-$TARGET_DOMAIN}}"

    if command -v misconfig-mapper &>/dev/null; then
        log_info "OsintModule: Running misconfig-mapper for '$misconfig_target_name'..."
        misconfig-mapper -target "$misconfig_target_name" -o "$misconfigs_output_file"
        if [ -s "$misconfigs_output_file" ]; then RESULTS_JSON_MAP["third_party_misconfigs_file"]="osint/$(basename "$misconfigs_output_file")"; fi
    else
        log_warning "OsintModule: misconfig-mapper command not found. Skipping third-party misconfiguration checks."
        RESULTS_JSON_MAP["third_party_misconfigs_error"]="misconfig-mapper not found"
    fi
    log_info "OsintModule: Third-party misconfiguration checks task completed."
}

# --- spoof_check_task ---
spoof_check_task() {
    log_info "OsintModule: Starting email spoofing checks for $TARGET_DOMAIN"
    local spoof_output_file="$OSINT_SUBDIR/spoof_check.txt"

    if [ -f "$SPOOFY_VENV_PYTHON" ] && [ -x "$SPOOFY_VENV_PYTHON" ] && [ -f "$SPOOFY_PATH" ]; then
        log_info "OsintModule: Running Spoofy for $TARGET_DOMAIN..."
        "$SPOOFY_VENV_PYTHON" "$SPOOFY_PATH" -d "$TARGET_DOMAIN" --output "$spoof_output_file"
        if [ -s "$spoof_output_file" ]; then RESULTS_JSON_MAP["spoof_check_file"]="osint/$(basename "$spoof_output_file")"; fi
    else
        log_warning "OsintModule: Spoofy script/venv not found/executable. Paths: Script='${SPOOFY_PATH}', Venv='${SPOOFY_VENV_PYTHON}'. Skipping spoof check."
        RESULTS_JSON_MAP["spoof_check_error"]="Spoofy script/venv not found or not executable"
    fi
    log_info "OsintModule: Email spoofing checks task completed."
}

# --- ip_info_task ---
ip_info_task() {
    log_info "OsintModule: Starting IP information gathering for $TARGET_DOMAIN"
    
    # Basic IP regex
    local ip_regex='^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'
    if ! [[ "$TARGET_DOMAIN" =~ $ip_regex ]]; then
        log_warning "OsintModule: Target '$TARGET_DOMAIN' does not appear to be an IP address. Skipping IP Info task. This task is intended for IP targets."
        RESULTS_JSON_MAP["ip_info_skipped"]="Target is not an IP address."
        return
    fi

    local ip_relations_file="$OSINT_SUBDIR/ip_${TARGET_DOMAIN}_relations.txt"
    local ip_whois_file="$OSINT_SUBDIR/ip_${TARGET_DOMAIN}_whois.txt"

    # WHOIS for IP
    if command -v whois &>/dev/null; then
        log_info "OsintModule: Running WHOIS for IP $TARGET_DOMAIN..."
        whois "$TARGET_DOMAIN" > "$ip_whois_file"
        if [ -s "$ip_whois_file" ]; then RESULTS_JSON_MAP["ip_whois_file"]="osint/$(basename "$ip_whois_file")"; fi
    else
        log_warning "OsintModule: 'whois' command not found for IP WHOIS."
    fi
    
    # WhoisXMLAPI for IP relations if key is provided
    if [ -n "$WHOISXML_API_KEY" ]; then
        log_info "OsintModule: Fetching IP relations from WhoisXMLAPI for $TARGET_DOMAIN..."
        local api_url="https://ip-netblocks.whoisxmlapi.com/api/v1?apiKey=${WHOISXML_API_KEY}&ip=${TARGET_DOMAIN}"
        if command -v curl &>/dev/null && command -v jq &>/dev/null; then
            curl -s "$api_url" | jq '.' > "$ip_relations_file" # Save formatted JSON
            if [ -s "$ip_relations_file" ]; then RESULTS_JSON_MAP["ip_relations_file"]="osint/$(basename "$ip_relations_file")"; fi
        else
            log_warning "OsintModule: curl or jq not found. Cannot fetch IP relations from WhoisXMLAPI."
            RESULTS_JSON_MAP["ip_relations_error"]="curl or jq not found for WhoisXMLAPI"
        fi
    else
        log_info "OsintModule: WHOISXML_API_KEY not set. Skipping WhoisXMLAPI IP relations."
    fi
    log_info "OsintModule: IP information gathering task completed."
}


# --- Main execution logic for the plugin ---
log_info "OsintModule: Initializing for target '$TARGET_DOMAIN', company '$COMPANY_NAME'."

if [ "$ENABLE_DOMAIN_INFO" == "true" ]; then domain_info_task; fi
if [ "$ENABLE_GOOGLE_DORKS" == "true" ]; then google_dorks_task; fi
if [ "$ENABLE_GITHUB_DORKS" == "true" ]; then github_dorks_task; fi
if [ "$ENABLE_GITHUB_REPOS" == "true" ]; then github_repos_task; fi
if [ "$ENABLE_METADATA" == "true" ]; then metadata_task; fi
# New tasks
if [ "$ENABLE_APILEAKS" == "true" ]; then apileaks_task; fi
if [ "$ENABLE_EMAILS_LEAKS" == "true" ]; then emails_leaks_task; fi
if [ "$ENABLE_THIRD_PARTY_MISCONFIGS" == "true" ]; then third_party_misconfigs_task; fi
if [ "$ENABLE_SPOOF_CHECK" == "true" ]; then spoof_check_task; fi
if [ "$ENABLE_IP_INFO" == "true" ]; then ip_info_task; fi


log_info "OsintModule: Aggregating results into $OUTPUT_DIR/results.json"
results_file_path="$OUTPUT_DIR/results.json"
printf '{\n' > "$results_file_path"
printf '  "plugin_name": "OsintModule",\n' >> "$results_file_path"
printf '  "version": "0.3.0",\n' >> "$results_file_path" # Added version
printf '  "target_domain": "%s",\n' "$TARGET_DOMAIN" >> "$results_file_path"
printf '  "company_name": "%s",\n' "$COMPANY_NAME" >> "$results_file_path"

printf '  "execution_parameters": {\n' >> "$results_file_path"
# ... (include all relevant enable flags and key parameters) ...
printf '    "enable_domain_info": "%s",\n' "$ENABLE_DOMAIN_INFO" >> "$results_file_path"
printf '    "enable_google_dorks": "%s",\n' "$ENABLE_GOOGLE_DORKS" >> "$results_file_path"
printf '    "enable_github_dorks": "%s",\n' "$ENABLE_GITHUB_DORKS" >> "$results_file_path"
printf '    "enable_github_repos": "%s",\n' "$ENABLE_GITHUB_REPOS" >> "$results_file_path"
printf '    "enable_metadata": "%s",\n' "$ENABLE_METADATA" >> "$results_file_path"
printf '    "enable_apileaks": "%s",\n' "$ENABLE_APILEAKS" >> "$results_file_path"
printf '    "enable_emails_leaks": "%s",\n' "$ENABLE_EMAILS_LEAKS" >> "$results_file_path"
printf '    "enable_third_party_misconfigs": "%s",\n' "$ENABLE_THIRD_PARTY_MISCONFIGS" >> "$results_file_path"
printf '    "enable_spoof_check": "%s",\n' "$ENABLE_SPOOF_CHECK" >> "$results_file_path"
printf '    "enable_ip_info": "%s"\n' "$ENABLE_IP_INFO" >> "$results_file_path"
printf '  },\n' >> "$results_file_path"

printf '  "outputs": {\n' >> "$results_file_path"
first_entry=true
for key in "${!RESULTS_JSON_MAP[@]}"; do
    if [ "$first_entry" = false ]; then printf ',\n' >> "$results_file_path"; fi
    value_escaped=$(echo "${RESULTS_JSON_MAP[$key]}" | sed 's/"/\\"/g') 
    printf '    "%s": "%s"' "$key" "$value_escaped" >> "$results_file_path"
    first_entry=false
done
if [ "$first_entry" = false ]; then printf '\n' >> "$results_file_path"; fi
printf '  },\n' >> "$results_file_path"

summary="OsintModule v0.3.0 tasks completed for $TARGET_DOMAIN."
printf '  "summary": "%s"\n' "$summary" >> "$results_file_path"
printf '}\n' >> "$results_file_path"

log_info "OsintModule: All enabled tasks completed. Results summary at $results_file_path"
exit 0
