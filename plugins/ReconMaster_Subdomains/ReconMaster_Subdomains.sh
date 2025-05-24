#!/bin/bash

# Source utilities
UTILS_PATH_GUESS_1="$(dirname "$0")/../../lib/utils.sh" 
UTILS_PATH_GUESS_2="../../lib/utils.sh" 

if [ -f "$UTILS_PATH_GUESS_1" ]; then
    source "$UTILS_PATH_GUESS_1"
elif [ -f "$UTILS_PATH_GUESS_2" ]; then
    source "$UTILS_PATH_GUESS_2"
else
    echo "ReconMaster_Subdomains: [ERROR] utils.sh not found. Critical for logging. Exiting." >&2
    exit 1
fi

set_log_level "${FRAMEWORK_LOG_LEVEL:-INFO}" 
set_color_preference "${ENABLE_COLORS:-false}" 

# --- Default Parameter Values ---
TARGET_DOMAIN=""
OUT_OF_SCOPE_FILE=""
IN_SCOPE_FILE=""
# Passive
ENABLE_PASSIVE_ENUM="true"
ENABLE_CRT_ENUM="true"
ENABLE_TLS_ENUM="true"
# Active Core
ENABLE_ACTIVE_RESOLVE="true" 
# Active Advanced (v0.2.0)
ENABLE_NOERROR_ENUM="true"
ENABLE_BRUTEFORCE_ENUM="true"
ENABLE_PERMUTATION_ENUM="true"
ENABLE_REGEX_PERMUTATION_ENUM="false"
ENABLE_DNS_RECORD_ENUM="true"
# New v0.3.0 Techniques
ENABLE_RECURSIVE_PASSIVE_ENUM="true"
ENABLE_RECURSIVE_BRUTE_ENUM="true"
ENABLE_SCRAPING_ENUM="true"
ENABLE_ANALYTICS_ENUM="true"
# Paths & Configs
RESOLVERS_FILE="config/resolvers.txt" 
TRUSTED_RESOLVERS_FILE="config/resolvers_trusted.txt" 
DEEP_SCAN_MODE="false"
# Subfinder
GITHUB_TOKENS_FILE="${HOME}/.config/reconftw/github_tokens.txt"
GITLAB_TOKENS_FILE="${HOME}/.config/reconftw/gitlab_tokens.txt"
SUBFINDER_TIMEOUT=30 
SUBFINDER_CONFIG_FILE=""
SUBFINDER_SOURCES=""
SUBFINDER_ALL_SOURCES="true"
CRT_LIMIT=5000 
# Puredns / Massdns
MASSDNS_PATH="massdns"
PUREDNS_PUBLIC_LIMIT=2000
PUREDNS_TRUSTED_LIMIT=10000
PUREDNS_WILDCARDTEST_LIMIT=50
PUREDNS_WILDCARDBATCH_LIMIT=1000000
# Wordlists
SUBS_WORDLIST="config/wordlists/subdomains_common.txt"
SUBS_WORDLIST_BIG="config/wordlists/subdomains_big.txt"
RECURSIVE_BRUTE_WORDLIST="config/wordlists/subdomains_recursive_brute.txt" # New
PERMUTATIONS_LIST_FILE="config/wordlists/permutations_common.txt"
# Permutations
PERMUTATION_OPTION_TOOL="gotator"
GOTATOR_FLAGS="-silent -md"
PERMUTATIONS_CHARACTER_LIMIT="1M"
# Regex Permutations
REGULATOR_SCRIPT_PATH="tools/regulator/main.py"
REGULATOR_VENV_PYTHON="tools/regulator/venv/bin/python3"
# DNSX
DNSX_WILDCARD_FILTER_LEVEL=3
# HTTPX
HTTPX_THREADS=50
HTTPX_TIMEOUT=10
HTTPX_RETRIES=2
HTTPX_RATELIMIT=150 # New
# Recursive
DEEP_RECURSIVE_PASSIVE_LIMIT=25 # New
# Scraping
DEEP_LIMIT_FOR_SCRAPING=500 # New
KATANA_DEPTH=2 # New
KATANA_THREADS=10 # New
OUTPUT_DIR="." # Provided by core.sh

declare -A RESULTS_JSON_MAP

# --- Argument Parser ---
log_debug "ReconMaster_Subdomains: Parsing arguments..."
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --target_domain) TARGET_DOMAIN="$2"; shift ;;
        --out_of_scope_file) OUT_OF_SCOPE_FILE="$2"; shift ;;
        --in_scope_file) IN_SCOPE_FILE="$2"; shift ;;
        # Technique Toggles (Passive, Active Core, Active Advanced)
        --enable_passive_enum) ENABLE_PASSIVE_ENUM="$2"; shift ;;
        --enable_crt_enum) ENABLE_CRT_ENUM="$2"; shift ;;
        --enable_tls_enum) ENABLE_TLS_ENUM="$2"; shift ;;
        --enable_active_resolve) ENABLE_ACTIVE_RESOLVE="$2"; shift ;;
        --enable_noerror_enum) ENABLE_NOERROR_ENUM="$2"; shift ;;
        --enable_bruteforce_enum) ENABLE_BRUTEFORCE_ENUM="$2"; shift ;;
        --enable_permutation_enum) ENABLE_PERMUTATION_ENUM="$2"; shift ;;
        --enable_regex_permutation_enum) ENABLE_REGEX_PERMUTATION_ENUM="$2"; shift ;;
        --enable_dns_record_enum) ENABLE_DNS_RECORD_ENUM="$2"; shift ;;
        # New v0.3.0 Technique Toggles
        --enable_recursive_passive_enum) ENABLE_RECURSIVE_PASSIVE_ENUM="$2"; shift ;;
        --enable_recursive_brute_enum) ENABLE_RECURSIVE_BRUTE_ENUM="$2"; shift ;;
        --enable_scraping_enum) ENABLE_SCRAPING_ENUM="$2"; shift ;;
        --enable_analytics_enum) ENABLE_ANALYTICS_ENUM="$2"; shift ;;
        # Paths & Configs
        --resolvers_file) RESOLVERS_FILE="$2"; shift ;;
        --trusted_resolvers_file) TRUSTED_RESOLVERS_FILE="$2"; shift ;;
        --deep_scan_mode) DEEP_SCAN_MODE="$2"; shift ;;
        --github_tokens_file) GITHUB_TOKENS_FILE="$2"; shift ;;
        --gitlab_tokens_file) GITLAB_TOKENS_FILE="$2"; shift ;;
        --subfinder_timeout) SUBFINDER_TIMEOUT="$2"; shift ;;
        --subfinder_config_file) SUBFINDER_CONFIG_FILE="$2"; shift ;;
        --subfinder_sources) SUBFINDER_SOURCES="$2"; shift ;;
        --subfinder_all_sources) SUBFINDER_ALL_SOURCES="$2"; shift ;;
        --crt_limit) CRT_LIMIT="$2"; shift ;;
        --massdns_path) MASSDNS_PATH="$2"; shift ;;
        --puredns_public_limit) PUREDNS_PUBLIC_LIMIT="$2"; shift ;;
        --puredns_trusted_limit) PUREDNS_TRUSTED_LIMIT="$2"; shift ;;
        --puredns_wildcardtest_limit) PUREDNS_WILDCARDTEST_LIMIT="$2"; shift ;;
        --puredns_wildcardbatch_limit) PUREDNS_WILDCARDBATCH_LIMIT="$2"; shift ;;
        --subs_wordlist) SUBS_WORDLIST="$2"; shift ;;
        --subs_wordlist_big) SUBS_WORDLIST_BIG="$2"; shift ;;
        --recursive_brute_wordlist) RECURSIVE_BRUTE_WORDLIST="$2"; shift ;; # New
        --permutations_list_file) PERMUTATIONS_LIST_FILE="$2"; shift ;;
        --permutation_option_tool) PERMUTATION_OPTION_TOOL="$2"; shift ;;
        --gotator_flags) GOTATOR_FLAGS="$2"; shift ;;
        --permutations_character_limit) PERMUTATIONS_CHARACTER_LIMIT="$2"; shift ;;
        --regulator_script_path) REGULATOR_SCRIPT_PATH="$2"; shift ;;
        --regulator_venv_python) REGULATOR_VENV_PYTHON="$2"; shift ;;
        --dnsx_wildcard_filter_level) DNSX_WILDCARD_FILTER_LEVEL="$2"; shift ;;
        --httpx_threads) HTTPX_THREADS="$2"; shift ;;
        --httpx_timeout) HTTPX_TIMEOUT="$2"; shift ;;
        --httpx_retries) HTTPX_RETRIES="$2"; shift ;;
        --httpx_ratelimit) HTTPX_RATELIMIT="$2"; shift ;; # New
        --deep_recursive_passive_limit) DEEP_RECURSIVE_PASSIVE_LIMIT="$2"; shift ;; # New
        --deep_limit_for_scraping) DEEP_LIMIT_FOR_SCRAPING="$2"; shift ;; # New
        --katana_depth) KATANA_DEPTH="$2"; shift ;; # New
        --katana_threads) KATANA_THREADS="$2"; shift ;; # New
        --output_dir) OUTPUT_DIR="$2"; shift ;;
        *) log_warning "ReconMaster_Subdomains: Unknown parameter: $1" ;;
    esac
    shift
done

# --- Parameter Validation & Setup ---
if [ -z "$TARGET_DOMAIN" ]; then log_error "ReconMaster_Subdomains: Critical parameter --target_domain not provided. Exiting."; exit 1; fi
if [ -z "$OUTPUT_DIR" ] || [ "$OUTPUT_DIR" == "." ]; then log_error "ReconMaster_Subdomains: Critical parameter --output_dir not provided. Exiting."; exit 1; fi
SUBDOMAINS_DIR="$OUTPUT_DIR/subdomains"; WEBS_DIR="$OUTPUT_DIR/webs"; TMP_DIR="$OUTPUT_DIR/.tmp/subdomains_tmp"
mkdir -p "$SUBDOMAINS_DIR" "$WEBS_DIR" "$TMP_DIR"
log_info "ReconMaster_Subdomains: Output in $SUBDOMAINS_DIR, $WEBS_DIR. Temp in $TMP_DIR"
# (Resolver file checks as before)


# --- Helper Functions (delete_out_scoped as before) ---
delete_out_scoped() {
    local input_file="$1"
    if [ -z "$OUT_OF_SCOPE_FILE" ] || [ ! -s "$OUT_OF_SCOPE_FILE" ]; then cat "$input_file"; return; fi
    grep -vFf "$OUT_OF_SCOPE_FILE" "$input_file"
}

# --- Existing Sub-Task Functions (Passive, CRT, TLS, NoError, Brute, Permut, RegexPermut, DNS - from v0.2.0, assumed correct for brevity) ---
sub_passive_original() { log_info "ReconMaster_Subdomains: (Skipped in this snippet) Passive Enumeration for $TARGET_DOMAIN"; }
sub_crt_original() { log_info "ReconMaster_Subdomains: (Skipped in this snippet) CRT.sh Enumeration for $TARGET_DOMAIN"; }
sub_active_original_resolve() { 
    local input_file="$1"; local resolved_out="$2";
    log_info "ReconMaster_Subdomains: (Skipped in this snippet) Active DNS Resolution for domains in $input_file to $resolved_out";
    touch "$resolved_out"; # Ensure output file exists
    if [ -s "$input_file" ] && (! command -v puredns &>/dev/null || ! command -v "$MASSDNS_PATH" &>/dev/null); then
        log_warning "puredns/massdns not found, copying input to resolved for active_resolve_placeholder."
        cat "$input_file" > "$resolved_out"
    fi
}
sub_tls_original() { log_info "ReconMaster_Subdomains: (Skipped in this snippet) TLS Enumeration"; }
sub_noerror_original() { log_info "ReconMaster_Subdomains: (Skipped in this snippet) No-Error Enumeration"; }
sub_brute_original() { log_info "ReconMaster_Subdomains: (Skipped in this snippet) Dictionary Bruteforce"; }
sub_permut_original() { log_info "ReconMaster_Subdomains: (Skipped in this snippet) Permutation Enumeration"; }
sub_regex_permut_original() { log_info "ReconMaster_Subdomains: (Skipped in this snippet) Regex Permutation Enumeration"; }
sub_dns_original() { log_info "ReconMaster_Subdomains: (Skipped in this snippet) DNS Record Enumeration"; }


# --- New v0.3.0 Task Functions ---

sub_recursive_passive_original() {
    local current_resolved_list="$1" # Main resolved list to update
    local recursive_passive_raw_out="$TMP_DIR/subs_recursive_passive_raw.txt"
    local recursive_passive_resolved_out="$TMP_DIR/subs_recursive_passive_resolved.txt"
    local top_subs_for_recursive="$TMP_DIR/top_subs_for_recursive_passive.txt"

    log_info "ReconMaster_Subdomains: Starting Recursive Passive Enumeration for $TARGET_DOMAIN"
    if [ ! -s "$current_resolved_list" ]; then
        log_warning "ReconMaster_Subdomains: No existing resolved subdomains to perform recursive passive scan on. Skipping."
        return
    fi
    if ! command -v dsieve &>/dev/null || ! command -v subfinder &>/dev/null; then
        log_error "ReconMaster_Subdomains: dsieve or subfinder not found. Skipping recursive passive scan."
        RESULTS_JSON_MAP["recursive_passive_error"]="dsieve or subfinder not found"
        return
    fi
    
    # Select top N subdomains (levels deep) using dsieve
    # dsieve -if <input_file> -f <field_number_of_domain> -n <limit> -d <depth_limit>
    # Assuming current_resolved_list has one domain per line. Field is 1.
    cat "$current_resolved_list" | dsieve -d "$DEEP_RECURSIVE_PASSIVE_LIMIT" > "$top_subs_for_recursive"

    if [ ! -s "$top_subs_for_recursive" ]; then
        log_info "ReconMaster_Subdomains: No subdomains selected by dsieve for recursive passive scan. Skipping."
        return
    fi
    log_info "ReconMaster_Subdomains: Running subfinder recursively on $(wc -l < "$top_subs_for_recursive") selected subdomains..."
    
    local subfinder_cmd_recursive="subfinder -l \"$top_subs_for_recursive\" -t $((SUBFINDER_TIMEOUT * 60)) -o \"$recursive_passive_raw_out\""
    if [ "$SUBFINDER_ALL_SOURCES" == "true" ]; then subfinder_cmd_recursive+=" -all"; fi
    if [ -n "$SUBFINDER_CONFIG_FILE" ] && [ -f "$SUBFINDER_CONFIG_FILE" ]; then subfinder_cmd_recursive+=" -config $SUBFINDER_CONFIG_FILE"; fi
    # Do not use -sources with -l and -all typically, depends on subfinder version behavior.
    eval "$subfinder_cmd_recursive"

    if [ -s "$recursive_passive_raw_out" ]; then
        log_info "ReconMaster_Subdomains: Resolving new subdomains from recursive passive scan..."
        sub_active_original_resolve "$recursive_passive_raw_out" "$recursive_passive_resolved_out"
        if [ -s "$recursive_passive_resolved_out" ]; then
            cat "$recursive_passive_resolved_out" | anew "$current_resolved_list"
            log_info "ReconMaster_Subdomains: Added $(wc -l < "$recursive_passive_resolved_out") new resolved subdomains from recursive passive scan."
        fi
    else
        log_info "ReconMaster_Subdomains: Recursive passive subfinder found no new subdomains."
    fi
    log_info "ReconMaster_Subdomains: Recursive Passive Enumeration completed."
}

sub_recursive_brute_original() {
    local current_resolved_list="$1"
    local recursive_brute_permutations_raw="$TMP_DIR/subs_recursive_brute_perms_raw.txt"
    local recursive_brute_resolved_out="$TMP_DIR/subs_recursive_brute_resolved.txt"
    local top_subs_for_recursive_brute="$TMP_DIR/top_subs_for_recursive_brute.txt"

    log_info "ReconMaster_Subdomains: Starting Recursive Bruteforce for $TARGET_DOMAIN"
    if [ ! -s "$current_resolved_list" ]; then log_warning "No existing subdomains for recursive bruteforce. Skipping."; return; fi
    if [ ! -f "$RECURSIVE_BRUTE_WORDLIST" ]; then
        log_error "Recursive bruteforce wordlist '$RECURSIVE_BRUTE_WORDLIST' not found. Skipping."
        RESULTS_JSON_MAP["recursive_brute_error"]="Wordlist not found: $RECURSIVE_BRUTE_WORDLIST"
        return
    fi
    if ! command -v dsieve &>/dev/null || ! command -v ripgen &>/dev/null || ! command -v puredns &>/dev/null; then
        log_error "dsieve, ripgen, or puredns not found. Skipping recursive bruteforce."
        RESULTS_JSON_MAP["recursive_brute_error"]="dsieve, ripgen, or puredns not found"
        return
    fi

    cat "$current_resolved_list" | dsieve -d "$DEEP_RECURSIVE_PASSIVE_LIMIT" > "$top_subs_for_recursive_brute" # Use same limit as passive for selecting bases
    if [ ! -s "$top_subs_for_recursive_brute" ]; then log_info "No subdomains selected for recursive bruteforce base. Skipping."; return; fi

    log_info "ReconMaster_Subdomains: Generating recursive bruteforce candidates with ripgen..."
    ripgen -d "$top_subs_for_recursive_brute" -w "$RECURSIVE_BRUTE_WORDLIST" > "$recursive_brute_permutations_raw"

    if [ -s "$recursive_brute_permutations_raw" ]; then
        log_info "ReconMaster_Subdomains: Resolving candidates from recursive bruteforce..."
        sub_active_original_resolve "$recursive_brute_permutations_raw" "$recursive_brute_resolved_out"
        if [ -s "$recursive_brute_resolved_out" ]; then
            cat "$recursive_brute_resolved_out" | anew "$current_resolved_list"
            log_info "Added $(wc -l < "$recursive_brute_resolved_out") new resolved subdomains from recursive bruteforce."
        fi
    else
        log_info "Recursive bruteforce (ripgen) generated no candidates."
    fi
    # Optional: Further permutations on these new subs if DEEP_SCAN_MODE is true (complex, matches reconftw logic)
    if [ "$DEEP_SCAN_MODE" == "true" ] && [ -s "$recursive_brute_resolved_out" ]; then
        log_info "Deep scan mode: Performing further permutations on newly found recursive brute subs..."
        # This could call sub_permut_original with recursive_brute_resolved_out as input,
        # but ensure it appends to current_resolved_list. For simplicity, this step is noted but not deeply nested here.
    fi
    log_info "ReconMaster_Subdomains: Recursive Bruteforce completed."
}

sub_scraping_original() {
    local live_web_hosts_input_file="$1" # Path to file containing live web hosts (http(s)://sub.domain)
    local current_resolved_list="$2" # Main resolved list to update
    local scraped_subs_raw="$TMP_DIR/subs_scraping_raw.txt"
    local scraped_subs_resolved="$TMP_DIR/subs_scraping_resolved.txt"
    local httpx_json_output_file="$WEBS_DIR/web_probing_full_info_${TARGET_DOMAIN}.jsonl" # JSON Lines format

    log_info "ReconMaster_Subdomains: Starting Web Scraping for $TARGET_DOMAIN"
    if [ ! -s "$live_web_hosts_input_file" ]; then
        log_warning "ReconMaster_Subdomains: No live web hosts provided for scraping. Skipping."
        # Try to run httpx on current resolved list if live_web_hosts_input_file is empty but current_resolved_list is not
        if [ -s "$current_resolved_list" ]; then
            log_info "Attempting to probe current resolved list for web scraping input..."
            local temp_live_hosts_for_scraping="$TMP_DIR/temp_live_hosts_for_scraping.txt"
            httpx -l "$current_resolved_list" -silent -t "$HTTPX_THREADS" -timeout "$HTTPX_TIMEOUT" -retries "$HTTPX_RETRIES" -rl "$HTTPX_RATELIMIT" -o "$temp_live_hosts_for_scraping"
            if [ -s "$temp_live_hosts_for_scraping" ]; then
                live_web_hosts_input_file="$temp_live_hosts_for_scraping"
            else
                log_warning "No live hosts found from current resolved list either. Scraping aborted."
                return
            fi
        else
             log_warning "No resolved subdomains available to generate live hosts for scraping. Scraping aborted."
            return
        fi
    fi
    
    local count_live_hosts=$(wc -l < "$live_web_hosts_input_file")
    if [ "$count_live_hosts" -gt "$DEEP_LIMIT_FOR_SCRAPING" ] && [ "$DEEP_SCAN_MODE" == "false" ]; then
        log_warning "Over $DEEP_LIMIT_FOR_SCRAPING live web hosts ($count_live_hosts). Limiting scraping to first $DEEP_LIMIT_FOR_SCRAPING hosts. Enable DEEP_SCAN_MODE to scrape all."
        head -n "$DEEP_LIMIT_FOR_SCRAPING" "$live_web_hosts_input_file" > "$TMP_DIR/live_web_hosts_limited.txt"
        live_web_hosts_input_file="$TMP_DIR/live_web_hosts_limited.txt"
    fi

    if ! command -v katana &>/dev/null || ! command -v httpx &>/dev/null || ! command -v unfurl &>/dev/null; then
        log_error "katana, httpx, or unfurl not found. Skipping Web Scraping."
        RESULTS_JSON_MAP["scraping_error"]="katana, httpx, or unfurl not found"
        return
    fi

    log_info "ReconMaster_Subdomains: Running httpx for detailed info and katana for scraping on $(wc -l < "$live_web_hosts_input_file") web hosts..."
    # httpx for full info gathering, outputting to JSON lines for easier aggregation
    httpx -l "$live_web_hosts_input_file" -silent -t "$HTTPX_THREADS" -timeout "$HTTPX_TIMEOUT" -retries "$HTTPX_RETRIES" -rl "$HTTPX_RATELIMIT" -json -o "$httpx_json_output_file"
    if [ -s "$httpx_json_output_file" ]; then RESULTS_JSON_MAP["web_probing_full_info_file"]="webs/$(basename "$httpx_json_output_file")"; fi
    
    local katana_crawl_depth=$KATANA_DEPTH
    if [ "$DEEP_SCAN_MODE" == "true" ]; then katana_crawl_depth=3; fi

    katana -list "$live_web_hosts_input_file" -jc -d "$katana_crawl_depth" -c "$KATANA_THREADS" -silent -aff -ef js,css,png,jpeg,jpg,gif,svg,woff,ttf,eot,ico,pdf,zip,tar.gz,rar,mp4,mp3,webm \
        | unfurl -u domains \
        | grep "\.$TARGET_DOMAIN$" \
        | anew > "$scraped_subs_raw"

    if [ -s "$scraped_subs_raw" ]; then
        log_info "ReconMaster_Subdomains: Resolving new subdomains found from scraping..."
        sub_active_original_resolve "$scraped_subs_raw" "$scraped_subs_resolved"
        if [ -s "$scraped_subs_resolved" ]; then
            cat "$scraped_subs_resolved" | anew "$current_resolved_list"
            log_info "Added $(wc -l < "$scraped_subs_resolved") new resolved subdomains from web scraping."
        fi
    else
        log_info "ReconMaster_Subdomains: Web scraping found no new potential subdomains."
    fi
    log_info "ReconMaster_Subdomains: Web Scraping task completed."
}

sub_analytics_original() {
    local live_web_hosts_input_file="$1" # Path to file containing live web hosts
    local current_resolved_list="$2" # Main resolved list to update
    local analytics_raw_out="$TMP_DIR/subs_analytics_raw.txt"
    local analytics_resolved_out="$TMP_DIR/subs_analytics_resolved.txt"

    log_info "ReconMaster_Subdomains: Starting Analytics-based Subdomain Discovery for $TARGET_DOMAIN"
    if [ ! -s "$live_web_hosts_input_file" ]; then
        log_warning "ReconMaster_Subdomains: No live web hosts provided for analytics relationships. Skipping."
         if [ -s "$current_resolved_list" ]; then # Fallback to current_resolved_list if no live hosts
            log_info "Attempting to use current resolved list for analytics input..."
            # analyticsrelationships.py might need URLs, not just domains.
            # This part needs careful adaptation based on analyticsrelationships.py's input requirements.
            # For now, assuming it can take domains and figure out URLs or we pass URLs.
            # Let's assume we pass domains and it handles it.
            live_web_hosts_input_file="$current_resolved_list" # Use domains if no live http hosts
        else
            log_warning "No resolved subdomains available for analytics. Analytics task aborted."
            return
        fi
    fi
    if ! command -v analyticsrelationships &>/dev/null; then # This assumes analyticsrelationships.py is in PATH or aliased
        log_error "ReconMaster_Subdomains: analyticsrelationships tool not found. Skipping."
        RESULTS_JSON_MAP["analytics_error"]="analyticsrelationships tool not found"
        return
    fi

    log_info "ReconMaster_Subdomains: Running analyticsrelationships on $(wc -l < "$live_web_hosts_input_file") inputs..."
    # The command might need adjustment based on how analyticsrelationships.py takes input (file, stdin)
    # and what it outputs. Assuming it outputs domains to stdout.
    analyticsrelationships -l "$live_web_hosts_input_file" | grep "\.$TARGET_DOMAIN$" | anew > "$analytics_raw_out"

    if [ -s "$analytics_raw_out" ]; then
        log_info "ReconMaster_Subdomains: Resolving new subdomains found from analytics relationships..."
        sub_active_original_resolve "$analytics_raw_out" "$analytics_resolved_out"
        if [ -s "$analytics_resolved_out" ]; then
            cat "$analytics_resolved_out" | anew "$current_resolved_list"
            log_info "Added $(wc -l < "$analytics_resolved_out") new resolved subdomains from analytics relationships."
        fi
    else
        log_info "ReconMaster_Subdomains: Analytics relationships scan found no new potential subdomains."
    fi
    log_info "ReconMaster_Subdomains: Analytics-based Subdomain Discovery completed."
}


# --- Main Function: subdomains_recon_main (Updated for v0.3.0) ---
subdomains_recon_main() {
    log_info "ReconMaster_Subdomains: ===== Starting Full Subdomain Recon v0.3.0 for $TARGET_DOMAIN ====="
    
    local all_raw_subs_combined="$TMP_DIR/all_raw_subs_combined.txt"
    local initial_scope_processed="$TMP_DIR/initial_scope_processed.txt"
    local current_resolved_subs="$SUBDOMAINS_DIR/resolved_subdomains_${TARGET_DOMAIN}.txt" 
    local final_resolved_subs_file="$current_resolved_subs" 
    local live_web_subs_file="$WEBS_DIR/live_web_subdomains_${TARGET_DOMAIN}.txt" # Initial list of live hosts

    touch "$all_raw_subs_combined" "$current_resolved_subs" "$live_web_subs_file"

    if [ -n "$IN_SCOPE_FILE" ] && [ -f "$IN_SCOPE_FILE" ]; then
        log_info "Adding domains from in-scope file: $IN_SCOPE_FILE"
        cat "$IN_SCOPE_FILE" | anew "$all_raw_subs_combined"
    fi

    # Initial Passive Phase
    if [ "$ENABLE_PASSIVE_ENUM" == "true" ]; then sub_passive_original; if [ -s "$TMP_DIR/all_passive_raw.txt" ]; then cat "$TMP_DIR/all_passive_raw.txt" | anew "$all_raw_subs_combined"; fi; fi
    if [ "$ENABLE_CRT_ENUM" == "true" ]; then sub_crt_original; if [ -s "$TMP_DIR/crtsh_subs.txt" ]; then cat "$TMP_DIR/crtsh_subs.txt" | anew "$all_raw_subs_combined"; fi; fi
    
    log_info "Filtering out-of-scope domains from raw list..."
    delete_out_scoped "$all_raw_subs_combined" > "$initial_scope_processed"
    log_info "$(wc -l < "$initial_scope_processed") domains after initial passive gathering & scope filtering."

    # Initial Active Resolution & TLS (operates on passive results)
    if [ "$ENABLE_ACTIVE_RESOLVE" == "true" ]; then
        sub_active_original_resolve "$initial_scope_processed" "$current_resolved_subs"
    else
        log_info "Active DNS resolution of initial passive list disabled. Using raw unique list."
        cat "$initial_scope_processed" | anew > "$current_resolved_subs"
    fi
    log_info "$(wc -l < "$current_resolved_subs") domains after initial resolution/pass-through."
    if [ "$ENABLE_TLS_ENUM" == "true" ]; then sub_tls_original "$current_resolved_subs" "$current_resolved_subs"; fi

    # Advanced Active Enumeration (operates on current_resolved_subs)
    if [ "$ENABLE_NOERROR_ENUM" == "true" ]; then sub_noerror_original "$current_resolved_subs"; fi
    if [ "$ENABLE_BRUTEFORCE_ENUM" == "true" ]; then sub_brute_original "$current_resolved_subs"; fi
    if [ "$ENABLE_PERMUTATION_ENUM" == "true" ]; then sub_permut_original "$current_resolved_subs"; fi
    if [ "$ENABLE_REGEX_PERMUTATION_ENUM" == "true" ]; then sub_regex_permut_original "$current_resolved_subs"; fi
    if [ "$ENABLE_DNS_RECORD_ENUM" == "true" ]; then sub_dns_original "$current_resolved_subs"; fi 

    # Recursive Enumeration (operates on current_resolved_subs)
    if [ "$ENABLE_RECURSIVE_PASSIVE_ENUM" == "true" ]; then sub_recursive_passive_original "$current_resolved_subs"; fi
    if [ "$ENABLE_RECURSIVE_BRUTE_ENUM" == "true" ]; then sub_recursive_brute_original "$current_resolved_subs"; fi
    
    # At this point, current_resolved_subs should be fairly comprehensive before scraping/analytics
    # Generate initial list of live web hosts for scraping/analytics
    if [ -s "$current_resolved_subs" ]; then
        if command -v httpx &>/dev/null; then
            log_info "Probing for initial live web servers for scraping/analytics input..."
            httpx -l "$current_resolved_subs" -t "$HTTPX_THREADS" -timeout "$HTTPX_TIMEOUT" -retries "$HTTPX_RETRIES" -rl "$HTTPX_RATELIMIT" -silent -o "$live_web_subs_file"
            if [ -s "$live_web_subs_file" ]; then
                log_info "Initial live web subdomains for scraping/analytics saved to $live_web_subs_file ($(wc -l < "$live_web_subs_file") entries)."
            else
                log_info "httpx found no initial live web servers from resolved list."; touch "$live_web_subs_file"
            fi
        else log_warning "httpx not found. Cannot generate live web host list for scraping/analytics."; touch "$live_web_subs_file"; fi
    else log_info "No resolved subdomains to probe for initial web server list."; touch "$live_web_subs_file"; fi

    # Scraping & Analytics (operates on live_web_subs_file or current_resolved_subs as fallback)
    if [ "$ENABLE_SCRAPING_ENUM" == "true" ]; then sub_scraping_original "$live_web_subs_file" "$current_resolved_subs"; fi
    if [ "$ENABLE_ANALYTICS_ENUM" == "true" ]; then sub_analytics_original "$live_web_subs_file" "$current_resolved_subs"; fi

    # Final processing of resolved subdomains
    if [ -s "$current_resolved_subs" ]; then
        cat "$current_resolved_subs" | anew | delete_out_scoped - | sort -u > "${final_resolved_subs_file}.sorted"
        mv "${final_resolved_subs_file}.sorted" "$final_resolved_subs_file"
        log_info "Final resolved subdomains saved to $final_resolved_subs_file ($(wc -l < "$final_resolved_subs_file") entries)."
        RESULTS_JSON_MAP["resolved_subdomains_file"]="subdomains/$(basename "$final_resolved_subs_file")"
        RESULTS_JSON_MAP["resolved_subdomains_count"]=$(wc -l < "$final_resolved_subs_file")
    else
        log_warning "No resolved subdomains found after all steps."
        touch "$final_resolved_subs_file"; RESULTS_JSON_MAP["resolved_subdomains_file"]="subdomains/$(basename "$final_resolved_subs_file")"; RESULTS_JSON_MAP["resolved_subdomains_count"]=0
    fi

    # Final web probing on the *very final* list of resolved subdomains (if scraping/analytics added more)
    # This updates live_web_subs_file and the JSON results for it.
    if [ -s "$final_resolved_subs_file" ]; then
        if command -v httpx &>/dev/null; then
            log_info "Performing final probing for live web servers on the complete resolved subdomains list..."
            # Overwrite or use a new name for this final httpx pass if needed
            httpx -l "$final_resolved_subs_file" -t "$HTTPX_THREADS" -timeout "$HTTPX_TIMEOUT" -retries "$HTTPX_RETRIES" -rl "$HTTPX_RATELIMIT" -silent -o "$live_web_subs_file"
            if [ -s "$live_web_subs_file" ]; then
                log_info "Final live web subdomains saved to $live_web_subs_file ($(wc -l < "$live_web_subs_file") entries)."
                RESULTS_JSON_MAP["live_web_subdomains_file"]="webs/$(basename "$live_web_subs_file")"
                RESULTS_JSON_MAP["live_web_subdomains_count"]=$(wc -l < "$live_web_subs_file")
            else
                log_info "Final httpx pass found no live web servers."; touch "$live_web_subs_file"; RESULTS_JSON_MAP["live_web_subdomains_count"]=0
            fi
        fi
    else log_info "No final resolved subdomains to probe for web servers."; touch "$live_web_subs_file"; fi
    
    local raw_files_list=""; for f in "$TMP_DIR"/*_raw.txt "$TMP_DIR"/*_subs.txt; do [ -e "$f" ] && raw_files_list+="$(basename "$f"),"; done
    RESULTS_JSON_MAP["raw_subdomains_files_list_tmp"]="${raw_files_list%,}"

    log_info "ReconMaster_Subdomains: ===== Subdomain Recon v0.3.0 for $TARGET_DOMAIN Finished ====="
}

# --- Main Execution & Results ---
subdomains_recon_main

log_info "ReconMaster_Subdomains: Aggregating results into $OUTPUT_DIR/results.json"
results_file_path="$OUTPUT_DIR/results.json"
printf '{\n' > "$results_file_path"
printf '  "plugin_name": "ReconMaster_Subdomains",\n' >> "$results_file_path"
printf '  "version": "0.3.0",\n' >> "$results_file_path" # Updated version
printf '  "target_domain": "%s",\n' "$TARGET_DOMAIN" >> "$results_file_path"
printf '  "execution_parameters": {\n' >> "$results_file_path"
# Add all relevant enable flags
printf '    "enable_passive_enum": "%s",\n' "$ENABLE_PASSIVE_ENUM" >> "$results_file_path"
# ... (include all other ENABLE_ flags from manifest)
printf '    "enable_recursive_passive_enum": "%s",\n' "$ENABLE_RECURSIVE_PASSIVE_ENUM" >> "$results_file_path"
printf '    "enable_recursive_brute_enum": "%s",\n' "$ENABLE_RECURSIVE_BRUTE_ENUM" >> "$results_file_path"
printf '    "enable_scraping_enum": "%s",\n' "$ENABLE_SCRAPING_ENUM" >> "$results_file_path"
printf '    "enable_analytics_enum": "%s",\n' "$ENABLE_ANALYTICS_ENUM" >> "$results_file_path"
printf '    "deep_scan_mode": "%s"\n' "$DEEP_SCAN_MODE" >> "$results_file_path"
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
summary="ReconMaster_Subdomains v0.3.0 tasks completed for $TARGET_DOMAIN. Final stats in outputs map."
printf '  "summary": "%s"\n' "$summary" >> "$results_file_path"
printf '}\n' >> "$results_file_path"

log_info "ReconMaster_Subdomains: All tasks completed. Results summary at $results_file_path"
exit 0
