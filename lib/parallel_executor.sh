#!/bin/bash

# Array to store PIDs of active background jobs
active_pids=()
# Associative array to store log file paths for each PID
declare -A pid_log_stdout
declare -A pid_log_stderr

# Function to launch a command in the background
# Usage: launch_in_background "<command_string>" "<log_file_stdout>" "<log_file_stderr>"
launch_in_background() {
  local command_string="$1"
  local log_stdout="$2"
  local log_stderr="$3"

  # Create directories for log files if they don't exist
  mkdir -p "$(dirname "$log_stdout")"
  mkdir -p "$(dirname "$log_stderr")"

  # Execute the command in the background
  # Ensure the command string is evaluated correctly, especially with arguments
  eval "$command_string" > "$log_stdout" 2> "$log_stderr" &
  local pid=$!
  echo $pid # Return the PID
}

# Function to add a PID to the active_pids array
# Usage: add_pid <pid> <log_stdout> <log_stderr>
add_pid() {
  local pid="$1"
  local log_stdout="$2"
  local log_stderr="$3"
  active_pids+=("$pid")
  pid_log_stdout["$pid"]="$log_stdout"
  pid_log_stderr["$pid"]="$log_stderr"
  #log_info "Added PID $pid to active_pids. Current PIDs: ${active_pids[*]}"
}

# Function to wait for a specific PID to complete
# Usage: wait_for_pid <pid_to_wait_for>
wait_for_pid() {
  local pid_to_wait_for="$1"
  local exit_code=-1

  #log_info "Waiting for PID $pid_to_wait_for..."
  if ! wait "$pid_to_wait_for"; then
    exit_code=$?
    log_debug "PID $pid_to_wait_for finished. Raw exit code: $exit_code" # Retain original exit code
    # The actual exit code from 'wait' is $? when it returns.
    # If 'wait $pid' itself fails (e.g., no such PID), it will also be non-zero.
  else
    exit_code=0 # Explicitly set to 0 on success
    log_info "PID $pid_to_wait_for completed successfully. Exit code: $exit_code"
  fi

  # Log error if non-zero exit code
  if [ "$exit_code" -ne 0 ]; then
    log_error "PID $pid_to_wait_for (Log files: Stdout='${pid_log_stdout[$pid_to_wait_for]}', Stderr='${pid_log_stderr[$pid_to_wait_for]}') completed with error. Exit code: $exit_code"
  fi

  # Remove PID from active_pids
  local new_pids=()
  for p in "${active_pids[@]}"; do
    if [ "$p" != "$pid_to_wait_for" ]; then
      new_pids+=("$p")
    fi
  done
  active_pids=("${new_pids[@]}")
  unset pid_log_stdout["$pid_to_wait_for"]
  unset pid_log_stderr["$pid_to_wait_for"]
  #log_info "Removed PID $pid_to_wait_for. Current PIDs: ${active_pids[*]}"
  
  echo $exit_code # Return the exit code
}

# Function to wait for all PIDs in active_pids
wait_for_all_pids() {
  log_info "Waiting for all ${#active_pids[@]} active PIDs: ${active_pids[*]}"
  local pids_to_wait_on=("${active_pids[@]}") # Create a copy to iterate over
  local any_errors=0

  for pid_to_wait_for in "${pids_to_wait_on[@]}"; do
    # Check if the PID is still in the primary active_pids array,
    # as it might have been waited for and removed by another process/logic if that were possible,
    # or if wait_for_pid was called externally.
    local still_needs_wait=0
    for p_check in "${active_pids[@]}"; do
        if [ "$p_check" == "$pid_to_wait_for" ]; then
            still_needs_wait=1
            break
        fi
    done
    
    if [ "$still_needs_wait" -eq 1 ]; then
        log_debug "Calling wait_for_pid for $pid_to_wait_for from wait_for_all_pids."
        local individual_exit_code
        individual_exit_code=$(wait_for_pid "$pid_to_wait_for") # This will handle logging for the specific PID
        if [ "$individual_exit_code" -ne 0 ]; then
            any_errors=1
        fi
    else
        log_debug "PID $pid_to_wait_for was already removed from active_pids. Skipping in wait_for_all_pids."
    fi
  done
  
  # active_pids should be empty now because wait_for_pid removes them.
  # If it's not, it might indicate an issue or a PID added during the wait_for_all_pids loop.
  if [ ${#active_pids[@]} -ne 0 ]; then
    log_warning "wait_for_all_pids: active_pids is not empty after waiting for all initially copied PIDs. Remaining: ${active_pids[*]}"
    # Clear it defensively
    active_pids=()
  fi

  if [ "$any_errors" -ne 0 ]; then
    log_warning "wait_for_all_pids: One or more background tasks failed."
  else
    log_info "wait_for_all_pids: All background tasks completed (individual success/failure logged above)."
  fi
}

# Function to get the number of active PIDs
get_active_pid_count() {
  echo "${#active_pids[@]}"
}

# Function to get the oldest PID (first one added)
get_oldest_pid() {
    if [ ${#active_pids[@]} -gt 0 ]; then
        echo "${active_pids[0]}"
    else
        echo ""
    fi
}

# Example usage (for testing this script directly)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Testing parallel_executor.sh..."
  source "$(dirname "$0")/utils.sh" # Assuming utils.sh is in the same directory for standalone testing

  add_pid 123 "/tmp/log1.out" "/tmp/log1.err"
  add_pid 456 "/tmp/log2.out" "/tmp/log2.err"
  echo "Active PIDs: $(get_active_pid_count)" # Expected: 2

  # Simulate launching
  log_info "Simulating launch of PID 789 (sleep 2s)"
  pid_test_1=$(launch_in_background "sleep 2 && echo 'Test PID 789 done.'" "/tmp/test_789.out" "/tmp/test_789.err")
  add_pid "$pid_test_1" "/tmp/test_789.out" "/tmp/test_789.err"
  log_info "Launched PID $pid_test_1. Active PIDs: $(get_active_pid_count)"


  log_info "Simulating launch of PID 790 (sleep 1s)"
  pid_test_2=$(launch_in_background "sleep 1 && echo 'Test PID 790 done.'" "/tmp/test_790.out" "/tmp/test_790.err")
  add_pid "$pid_test_2" "/tmp/test_790.out" "/tmp/test_790.err"
  log_info "Launched PID $pid_test_2. Active PIDs: $(get_active_pid_count)"

  oldest=$(get_oldest_pid) # This would be 123 in this mocked scenario, not useful without actual processes
  log_info "Oldest PID (conceptual): $oldest"


  log_info "Waiting for PID $pid_test_2..."
  exit_code_2=$(wait_for_pid "$pid_test_2")
  log_info "PID $pid_test_2 finished with exit code $exit_code_2. Active PIDs: $(get_active_pid_count)"
  cat "/tmp/test_790.out"

  log_info "Waiting for all remaining PIDs..."
  wait_for_all_pids
  log_info "All PIDs finished. Active PIDs: $(get_active_pid_count)" # Expected: 0
  cat "/tmp/test_789.out"
  
  rm -f /tmp/test_*.{out,err} /tmp/log*.{out,err}
  echo "Test complete."
fi
